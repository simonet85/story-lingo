from __future__ import annotations

from datetime import datetime

from sqlalchemy import BigInteger, Boolean, DateTime, Integer, String, Text
from sqlalchemy.orm import Mapped, mapped_column

from .db import Base


class Book(Base):
    __tablename__ = "books"

    id: Mapped[str] = mapped_column(String(120), primary_key=True)
    title: Mapped[str] = mapped_column(String(300))
    title_fr: Mapped[str] = mapped_column(String(300))
    author: Mapped[str] = mapped_column(String(200))
    level: Mapped[str] = mapped_column(String(8))
    description_fr: Mapped[str] = mapped_column(String(1000))
    pack_version: Mapped[str] = mapped_column(String(20))
    chapter_count: Mapped[int] = mapped_column(Integer)
    total_minutes: Mapped[int] = mapped_column(Integer)
    new_word_count: Mapped[int] = mapped_column(Integer)
    folder: Mapped[str] = mapped_column(String(120))
    is_free: Mapped[bool] = mapped_column(Boolean, default=True)
    updated_at: Mapped[datetime] = mapped_column(DateTime(timezone=True))


class SyncRecord(Base):
    __tablename__ = "sync_records"

    user_id: Mapped[str] = mapped_column(String(120), primary_key=True)
    namespace: Mapped[str] = mapped_column(String(32), primary_key=True)
    record_id: Mapped[str] = mapped_column(String(240), primary_key=True)
    updated_at_ms: Mapped[int] = mapped_column(BigInteger)
    deleted: Mapped[bool] = mapped_column(Boolean, default=False)
    payload: Mapped[str | None] = mapped_column(Text, nullable=True)
    revision: Mapped[int] = mapped_column(Integer, index=True)
    server_updated_at: Mapped[datetime] = mapped_column(DateTime(timezone=True))


class SyncState(Base):
    __tablename__ = "sync_states"

    user_id: Mapped[str] = mapped_column(String(120), primary_key=True)
    revision: Mapped[int] = mapped_column(Integer, default=0)


class Subscription(Base):
    __tablename__ = "subscriptions"

    user_id: Mapped[str] = mapped_column(String(120), primary_key=True)
    status: Mapped[str] = mapped_column(String(16))
    source: Mapped[str] = mapped_column(String(16))
    product_id: Mapped[str | None] = mapped_column(String(120), nullable=True)
    expires_at_ms: Mapped[int | None] = mapped_column(BigInteger, nullable=True)
    last_event_ms: Mapped[int] = mapped_column(BigInteger, default=0)
    last_event_type: Mapped[str | None] = mapped_column(String(40), nullable=True)
    updated_at: Mapped[datetime] = mapped_column(DateTime(timezone=True))
