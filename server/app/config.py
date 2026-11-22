from __future__ import annotations

import os
from dataclasses import dataclass
from pathlib import Path

DEFAULT_ROOT = Path(__file__).resolve().parents[2]


def _env_flag(name: str) -> bool:
    return os.getenv(name, "").strip().lower() in {"1", "true", "yes", "on"}


@dataclass(frozen=True)
class Settings:
    database_url: str
    content_dir: Path
    public_base_url: str | None = None
    supabase_jwks_url: str | None = None
    supabase_jwt_secret: str | None = None
    supabase_issuer: str | None = None
    supabase_audience: str = "authenticated"
    dev_auth: bool = False
    dev_auth_secret: str | None = None
    revenuecat_webhook_secret: str | None = None

    @classmethod
    def from_env(cls, root: Path | None = None) -> Settings:
        root = root or DEFAULT_ROOT
        default_db = root / "server" / "data" / "storylingo.db"
        database_url = os.getenv("STORYLINGO_DATABASE_URL") or (
            f"sqlite:///{default_db.as_posix()}"
        )
        content_dir = Path(
            os.getenv("STORYLINGO_CONTENT_DIR", root / "server" / "data" / "packs")
        )
        public_base_url = os.getenv("STORYLINGO_PUBLIC_BASE_URL") or None
        if public_base_url:
            public_base_url = public_base_url.rstrip("/")
        return cls(
            database_url=database_url,
            content_dir=content_dir,
            public_base_url=public_base_url,
            supabase_jwks_url=os.getenv("STORYLINGO_SUPABASE_JWKS_URL") or None,
            supabase_jwt_secret=os.getenv("STORYLINGO_SUPABASE_JWT_SECRET") or None,
            supabase_issuer=os.getenv("STORYLINGO_SUPABASE_ISSUER") or None,
            supabase_audience=os.getenv(
                "STORYLINGO_SUPABASE_AUDIENCE", "authenticated"
            ),
            dev_auth=_env_flag("STORYLINGO_DEV_AUTH"),
            dev_auth_secret=os.getenv("STORYLINGO_DEV_AUTH_SECRET") or None,
            revenuecat_webhook_secret=(
                os.getenv("STORYLINGO_REVENUECAT_WEBHOOK_SECRET") or None
            ),
        )
