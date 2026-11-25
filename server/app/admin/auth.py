from __future__ import annotations

import hmac
import secrets
from dataclasses import dataclass
from datetime import datetime, timedelta, timezone

import jwt

SESSION_COOKIE = "storylingo_admin"
SESSION_AUDIENCE = "storylingo-admin"
SESSION_ISSUER = "storylingo-admin"
SESSION_TTL_SECONDS = 12 * 60 * 60


@dataclass(frozen=True)
class AdminSession:
    csrf: str


class AdminAuth:
    def __init__(self, token: str, session_secret: str) -> None:
        self._token = token
        self._session_secret = session_secret

    def check_password(self, password: str) -> bool:
        return hmac.compare_digest(
            password.encode("utf-8"), self._token.encode("utf-8")
        )

    def issue(self) -> tuple[str, AdminSession]:
        session = AdminSession(csrf=secrets.token_hex(16))
        now = datetime.now(timezone.utc)
        claims = {
            "sub": "admin",
            "csrf": session.csrf,
            "aud": SESSION_AUDIENCE,
            "iss": SESSION_ISSUER,
            "iat": int(now.timestamp()),
            "exp": int((now + timedelta(seconds=SESSION_TTL_SECONDS)).timestamp()),
        }
        return (
            jwt.encode(claims, self._session_secret, algorithm="HS256"),
            session,
        )

    def read(self, cookie: str | None) -> AdminSession | None:
        if not cookie:
            return None
        try:
            claims = jwt.decode(
                cookie,
                self._session_secret,
                algorithms=["HS256"],
                audience=SESSION_AUDIENCE,
                issuer=SESSION_ISSUER,
            )
        except jwt.InvalidTokenError:
            return None
        csrf = claims.get("csrf")
        if claims.get("sub") != "admin" or not isinstance(csrf, str) or not csrf:
            return None
        return AdminSession(csrf=csrf)
