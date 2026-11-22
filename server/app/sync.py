from __future__ import annotations

import json
from datetime import datetime, timezone
from typing import Any

from fastapi import APIRouter, Depends, Query
from pydantic import BaseModel, ConfigDict, Field, field_validator, model_validator
from sqlalchemy import select
from sqlalchemy.orm import Session

from .auth import UserDep
from .models import SyncRecord, SyncState
from .routes import get_session

NAMESPACES = frozenset({"reading", "words", "srs", "program", "prefs"})
MAX_RECORDS = 500
MAX_PAYLOAD_BYTES = 64 * 1024


class SyncRecordIn(BaseModel):
    model_config = ConfigDict(populate_by_name=True, extra="forbid")

    namespace: str
    id: str
    updated_at: int = Field(alias="updatedAt", ge=0)
    deleted: bool = False
    payload: dict[str, Any] | None = None

    @field_validator("namespace")
    @classmethod
    def _known_namespace(cls, value: str) -> str:
        if value not in NAMESPACES:
            raise ValueError(f"Unknown namespace {value!r}.")
        return value

    @field_validator("id")
    @classmethod
    def _record_id(cls, value: str) -> str:
        if not value or len(value) > 240:
            raise ValueError("Record id must be 1..240 characters.")
        return value

    @model_validator(mode="after")
    def _payload_shape(self) -> SyncRecordIn:
        if self.deleted:
            self.payload = None
            return self
        if not isinstance(self.payload, dict):
            raise ValueError("payload must be a JSON object.")
        encoded = _encode(self.payload)
        if len(encoded.encode("utf-8")) > MAX_PAYLOAD_BYTES:
            raise ValueError("payload is too large.")
        return self


class PushRequest(BaseModel):
    model_config = ConfigDict(extra="forbid")

    records: list[SyncRecordIn] = Field(default_factory=list, max_length=MAX_RECORDS)


def _encode(payload: dict[str, Any] | None) -> str | None:
    if payload is None:
        return None
    return json.dumps(payload, ensure_ascii=False, separators=(",", ":"))


def _decode(payload: str | None) -> dict[str, Any] | None:
    if not payload:
        return None
    try:
        value = json.loads(payload)
    except ValueError:
        return None
    return value if isinstance(value, dict) else None


def _record_out(record: SyncRecord) -> dict[str, Any]:
    return {
        "namespace": record.namespace,
        "id": record.record_id,
        "updatedAt": record.updated_at_ms,
        "deleted": record.deleted,
        "payload": _decode(record.payload),
    }


def _state_for(session: Session, user_id: str) -> SyncState:
    state = session.get(SyncState, user_id)
    if state is None:
        state = SyncState(user_id=user_id, revision=0)
        session.add(state)
        session.flush()
    return state


router = APIRouter(prefix="/sync", tags=["sync"])


@router.post("/push")
def push(
    payload: PushRequest,
    user: UserDep,
    session: Session = Depends(get_session),
) -> dict[str, Any]:
    now = datetime.now(timezone.utc)
    state = _state_for(session, user.user_id)
    accepted: list[SyncRecord] = []
    winners: list[SyncRecord] = []

    for item in payload.records:
        existing = session.get(
            SyncRecord, (user.user_id, item.namespace, item.id)
        )
        if existing is None:
            existing = SyncRecord(
                user_id=user.user_id,
                namespace=item.namespace,
                record_id=item.id,
                updated_at_ms=item.updated_at,
                deleted=item.deleted,
                payload=_encode(item.payload),
                revision=0,
                server_updated_at=now,
            )
            session.add(existing)
            accepted.append(existing)
        elif item.updated_at > existing.updated_at_ms:
            existing.updated_at_ms = item.updated_at
            existing.deleted = item.deleted
            existing.payload = _encode(item.payload)
            existing.server_updated_at = now
            accepted.append(existing)
        winners.append(existing)

    if accepted:
        state.revision += 1
        for record in accepted:
            record.revision = state.revision

    session.commit()
    return {
        "serverRevision": state.revision,
        "serverTime": now.isoformat().replace("+00:00", "Z"),
        "records": [_record_out(record) for record in winners],
    }


@router.get("/pull")
def pull(
    user: UserDep,
    since: int = Query(default=0, ge=0),
    session: Session = Depends(get_session),
) -> dict[str, Any]:
    state = session.get(SyncState, user.user_id)
    revision = state.revision if state is not None else 0
    records = session.scalars(
        select(SyncRecord)
        .where(
            SyncRecord.user_id == user.user_id,
            SyncRecord.revision > since,
        )
        .order_by(
            SyncRecord.revision,
            SyncRecord.namespace,
            SyncRecord.record_id,
        )
    ).all()
    return {
        "revision": revision,
        "records": [_record_out(record) for record in records],
    }
