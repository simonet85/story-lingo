from __future__ import annotations

from pathlib import Path

from sqlalchemy import create_engine
from sqlalchemy.engine import Engine, make_url
from sqlalchemy.orm import DeclarativeBase, sessionmaker


class Base(DeclarativeBase):
    pass


def make_engine(database_url: str) -> Engine:
    url = make_url(database_url)
    if url.get_backend_name() == "sqlite":
        database = url.database
        if database and database != ":memory:":
            Path(database).parent.mkdir(parents=True, exist_ok=True)
        connect_args = {"check_same_thread": False}
    else:
        connect_args = {}
    return create_engine(database_url, connect_args=connect_args, future=True)


def make_session_factory(engine: Engine) -> sessionmaker:
    return sessionmaker(bind=engine, expire_on_commit=False, future=True)
