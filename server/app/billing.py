from __future__ import annotations

import hmac
import time
from datetime import datetime, timezone
from typing import Annotated, Any

from fastapi import APIRouter, Depends, HTTPException, Request, Response
from pydantic import BaseModel, ConfigDict, Field
from sqlalchemy.orm import Session

from .auth import AuthContext, UserDep, VerifierDep, require_user
from .config import Settings
from .models import Subscription
from .routes import get_session, get_settings

router = APIRouter(tags=["billing"])

DAY_MS = 24 * 60 * 60 * 1000
ACTIVE_STATUSES = frozenset({"active", "grace", "cancelled"})
STATUS_BY_EVENT = {
    "INITIAL_PURCHASE": "active",
    "RENEWAL": "active",
    "UNCANCELLATION": "active",
    "PRODUCT_CHANGE": "active",
    "BILLING_ISSUE": "grace",
    "CANCELLATION": "cancelled",
    "EXPIRATION": "expired",
}


def _now_ms() -> int:
    return int(time.time() * 1000)


def _now() -> datetime:
    return datetime.now(timezone.utc)


def _iso_utc(ms: int) -> str:
    return (
        datetime.fromtimestamp(ms / 1000, tz=timezone.utc)
        .isoformat()
        .replace("+00:00", "Z")
    )


def _is_active(row: Subscription | None, now_ms: int) -> bool:
    if row is None or row.status not in ACTIVE_STATUSES:
        return False
    return row.expires_at_ms is None or row.expires_at_ms > now_ms


def entitlement_payload(row: Subscription | None) -> dict[str, Any]:
    now_ms = _now_ms()
    return {
        "active": _is_active(row, now_ms),
        "status": row.status if row is not None else "none",
        "source": row.source if row is not None else None,
        "productId": row.product_id if row is not None else None,
        "expiresAt": (
            _iso_utc(row.expires_at_ms)
            if row is not None and row.expires_at_ms is not None
            else None
        ),
        "checkedAt": _iso_utc(now_ms),
    }


def _apply(
    session: Session,
    user_id: str,
    *,
    status: str,
    product_id: str | None,
    expires_at_ms: int | None,
    event_ms: int,
    event_type: str,
    preserve_expiry: bool = False,
    source: str = "revenuecat",
) -> bool:
    row = session.get(Subscription, user_id)
    if row is not None and event_ms <= row.last_event_ms:
        return False
    if row is None:
        row = Subscription(user_id=user_id, last_event_ms=0)
    row.status = status
    row.source = source
    if product_id is not None:
        row.product_id = product_id
    if not preserve_expiry:
        row.expires_at_ms = expires_at_ms
    row.last_event_ms = event_ms
    row.last_event_type = event_type
    row.updated_at = _now()
    session.add(row)
    return True


@router.get("/entitlements")
def get_entitlements(
    user: UserDep,
    response: Response,
    session: Session = Depends(get_session),
) -> dict[str, Any]:
    response.headers["Cache-Control"] = "no-store"
    return entitlement_payload(session.get(Subscription, user.user_id))


class DevGrantRequest(BaseModel):
    model_config = ConfigDict(populate_by_name=True, extra="forbid")

    days: int = Field(default=30, ge=1, le=3650)
    product_id: str = Field(default="dev_monthly", alias="productId", max_length=120)


def _require_dev_user(
    request: Request,
    verifier: VerifierDep,
    settings: Settings = Depends(get_settings),
) -> AuthContext:
    if not settings.dev_auth:
        raise HTTPException(status_code=404, detail="Not found.")
    return require_user(request, verifier)


DevUserDep = Annotated[AuthContext, Depends(_require_dev_user)]


@router.post("/entitlements/dev-grant")
def dev_grant(
    body: DevGrantRequest,
    user: DevUserDep,
    session: Session = Depends(get_session),
) -> dict[str, Any]:
    now_ms = _now_ms()
    row = session.get(Subscription, user.user_id)
    if row is None:
        row = Subscription(user_id=user.user_id, last_event_ms=0)
    row.status = "active"
    row.source = "dev"
    row.product_id = body.product_id
    row.expires_at_ms = now_ms + body.days * DAY_MS
    row.last_event_ms = now_ms
    row.last_event_type = "DEV_GRANT"
    row.updated_at = _now()
    session.add(row)
    session.commit()
    return entitlement_payload(row)


@router.post("/entitlements/dev-revoke")
def dev_revoke(
    user: DevUserDep,
    session: Session = Depends(get_session),
) -> dict[str, Any]:
    row = session.get(Subscription, user.user_id)
    if row is not None:
        session.delete(row)
        session.commit()
    return entitlement_payload(None)


def _int_field(payload: dict[str, Any], name: str) -> int | None:
    value = payload.get(name)
    return value if isinstance(value, int) else None


def _str_field(payload: dict[str, Any], name: str) -> str | None:
    value = payload.get(name)
    return value if isinstance(value, str) and value else None


@router.post("/webhooks/revenuecat")
async def revenuecat_webhook(
    request: Request,
    session: Session = Depends(get_session),
    settings: Settings = Depends(get_settings),
) -> dict[str, Any]:
    secret = settings.revenuecat_webhook_secret
    if not secret:
        raise HTTPException(status_code=503, detail="Webhook not configured.")
    authorization = request.headers.get("authorization", "")
    if not hmac.compare_digest(authorization, secret):
        raise HTTPException(status_code=401, detail="Invalid webhook authorization.")

    try:
        payload = await request.json()
    except Exception as error:
        raise HTTPException(status_code=400, detail="Invalid JSON body.") from error
    if not isinstance(payload, dict):
        raise HTTPException(status_code=400, detail="Invalid webhook payload.")
    event = payload.get("event")
    if not isinstance(event, dict):
        raise HTTPException(status_code=400, detail="Missing event.")

    app_user_id = _str_field(event, "app_user_id")
    event_type = _str_field(event, "type")
    if not app_user_id:
        raise HTTPException(status_code=400, detail="Missing app_user_id.")
    if not event_type:
        raise HTTPException(status_code=400, detail="Missing event type.")

    event_ms = _int_field(event, "event_timestamp_ms") or _now_ms()
    expiry_ms = _int_field(event, "expiration_at_ms")
    product_id = _str_field(event, "product_id")

    if event_type == "TRANSFER":
        raw_from = event.get("transferred_from")
        raw_to = event.get("transferred_to")
        sources = raw_from if isinstance(raw_from, list) else []
        targets = raw_to if isinstance(raw_to, list) else []
        applied = False
        for user_id in sources:
            if isinstance(user_id, str) and user_id:
                applied |= _apply(
                    session,
                    user_id,
                    status="expired",
                    product_id=None,
                    expires_at_ms=None,
                    event_ms=event_ms,
                    event_type=event_type,
                    preserve_expiry=True,
                )
        for user_id in targets:
            if isinstance(user_id, str) and user_id:
                applied |= _apply(
                    session,
                    user_id,
                    status="active",
                    product_id=product_id,
                    expires_at_ms=expiry_ms,
                    event_ms=event_ms,
                    event_type=event_type,
                )
        session.commit()
        return {"applied": applied, "status": "transferred" if applied else "stale"}

    status = STATUS_BY_EVENT.get(event_type)
    if status is None:
        return {"applied": False, "reason": "ignored"}

    applied = _apply(
        session,
        app_user_id,
        status=status,
        product_id=product_id,
        expires_at_ms=expiry_ms,
        event_ms=event_ms,
        event_type=event_type,
        preserve_expiry=status == "expired",
    )
    if not applied:
        return {"applied": False, "reason": "stale"}
    session.commit()

    row = session.get(Subscription, app_user_id)
    response = entitlement_payload(row)
    return {"applied": True, "active": response["active"], "status": response["status"]}
