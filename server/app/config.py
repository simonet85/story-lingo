from __future__ import annotations

import os
from dataclasses import dataclass
from pathlib import Path

DEFAULT_ROOT = Path(__file__).resolve().parents[2]


def _env_flag(name: str) -> bool:
    return os.getenv(name, "").strip().lower() in {"1", "true", "yes", "on"}


def _env_int(name: str, default: int) -> int:
    raw = os.getenv(name, "").strip()
    if not raw:
        return default
    try:
        return max(1, int(raw))
    except ValueError:
        return default


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
    moneyfusion_api_url: str | None = None
    moneyfusion_status_base_url: str = "https://pay.moneyfusion.net"
    moneyfusion_price_monthly_xof: int = 3500
    moneyfusion_price_yearly_xof: int = 30000
    admin_token: str | None = None
    admin_session_secret: str | None = None
    admin_max_upload_bytes: int = 200 * 1024 * 1024

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
            moneyfusion_api_url=(
                os.getenv("STORYLINGO_MONEYFUSION_API_URL") or None
            ),
            moneyfusion_status_base_url=(
                os.getenv("STORYLINGO_MONEYFUSION_STATUS_BASE_URL")
                or "https://pay.moneyfusion.net"
            ).rstrip("/"),
            moneyfusion_price_monthly_xof=_env_int(
                "STORYLINGO_MONEYFUSION_PRICE_MONTHLY_XOF", 3500
            ),
            moneyfusion_price_yearly_xof=_env_int(
                "STORYLINGO_MONEYFUSION_PRICE_YEARLY_XOF", 30000
            ),
            admin_token=os.getenv("STORYLINGO_ADMIN_TOKEN") or None,
            admin_session_secret=(
                os.getenv("STORYLINGO_ADMIN_SESSION_SECRET") or None
            ),
            admin_max_upload_bytes=(
                _env_int("STORYLINGO_ADMIN_MAX_UPLOAD_MB", 200) * 1024 * 1024
            ),
        )
