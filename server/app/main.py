from __future__ import annotations

import logging
import secrets

from fastapi import FastAPI, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse

from . import auth, billing, payments
from .config import Settings
from .db import Base, make_engine, make_session_factory
from .routes import router
from .sync import router as sync_router

logger = logging.getLogger("storylingo.api")


def create_app(settings: Settings | None = None) -> FastAPI:
    settings = settings or Settings.from_env()
    engine = make_engine(settings.database_url)
    Base.metadata.create_all(engine)

    app = FastAPI(title="Storylingo Content API", version="1.0.0")
    app.state.settings = settings
    app.state.session_factory = make_session_factory(engine)
    dev_secret = settings.dev_auth_secret or (
        secrets.token_urlsafe(32) if settings.dev_auth else None
    )
    app.state.auth_verifier = auth.JwtVerifier(settings, dev_secret)

    app.add_middleware(
        CORSMiddleware,
        allow_origin_regex=r"http://(localhost|127\.0\.0\.1)(:\d+)?",
        allow_methods=["GET", "HEAD", "POST", "OPTIONS"],
        allow_headers=[
            "Authorization",
            "Content-Type",
            "If-None-Match",
            "Range",
        ],
        expose_headers=["ETag", "Content-Range", "Accept-Ranges", "Content-Length"],
        max_age=600,
    )
    app.include_router(router, prefix="/v1")
    app.include_router(auth.router, prefix="/v1")
    app.include_router(sync_router, prefix="/v1")
    app.include_router(billing.router, prefix="/v1")
    app.include_router(payments.router, prefix="/v1")

    @app.exception_handler(Exception)
    async def unhandled_error(request: Request, error: Exception) -> JSONResponse:
        logger.exception("Unhandled error on %s", request.url.path, exc_info=error)
        return JSONResponse(
            status_code=500, content={"detail": "Internal server error."}
        )

    return app
