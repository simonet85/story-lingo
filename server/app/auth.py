from __future__ import annotations

import hashlib
import re
from dataclasses import dataclass
from datetime import datetime, timedelta, timezone
from typing import Annotated, Any

import jwt
from fastapi import APIRouter, Depends, HTTPException, Request
from pydantic import BaseModel, field_validator

from .config import Settings

_EMAIL_RE = re.compile(r"^[^@\s]+@[^@\s]+\.[^@\s]+$")
DEV_AUDIENCE = "storylingo-dev"
DEV_ISSUER = "storylingo-dev"
DEV_TOKEN_TTL_SECONDS = 24 * 60 * 60


@dataclass(frozen=True)
class AuthContext:
    user_id: str
    email: str | None
    mode: str


class DevLoginRequest(BaseModel):
    email: str

    @field_validator("email")
    @classmethod
    def _valid_email(cls, value: str) -> str:
        email = value.strip().lower()
        if not _EMAIL_RE.fullmatch(email) or len(email) > 320:
            raise ValueError("Adresse email invalide.")
        return email


def _unauthorized(detail: str) -> HTTPException:
    return HTTPException(
        status_code=401,
        detail=detail,
        headers={"WWW-Authenticate": "Bearer"},
    )


def dev_user_id(email: str) -> str:
    normalized = email.strip().lower()
    return "dev_" + hashlib.sha256(normalized.encode("utf-8")).hexdigest()[:32]


def _context_from_supabase(claims: dict[str, Any]) -> AuthContext | None:
    subject = claims.get("sub")
    if not isinstance(subject, str) or not subject:
        return None
    email = claims.get("email")
    return AuthContext(
        user_id=subject,
        email=email if isinstance(email, str) else None,
        mode="supabase",
    )


class JwtVerifier:
    """Verifies dev or Supabase tokens; Supabase accepts HS256 secret or JWKS."""

    def __init__(self, settings: Settings, dev_secret: str | None) -> None:
        self._settings = settings
        self._dev_secret = dev_secret
        self._jwks: jwt.PyJWKClient | None = None
        if settings.supabase_jwks_url:
            self._jwks = jwt.PyJWKClient(settings.supabase_jwks_url, cache_keys=True)

    def issue_dev_token(self, email: str) -> str:
        if not self._settings.dev_auth or not self._dev_secret:
            raise HTTPException(status_code=404, detail="Not found.")
        now = datetime.now(timezone.utc)
        claims = {
            "sub": dev_user_id(email),
            "email": email,
            "aud": DEV_AUDIENCE,
            "iss": DEV_ISSUER,
            "iat": int(now.timestamp()),
            "exp": int((now + timedelta(seconds=DEV_TOKEN_TTL_SECONDS)).timestamp()),
            "mode": "dev",
        }
        return jwt.encode(claims, self._dev_secret, algorithm="HS256")

    def verify(self, token: str) -> AuthContext:
        for verify in (
            self._verify_dev,
            self._verify_supabase_hs256,
            self._verify_supabase_jwks,
        ):
            context = verify(token)
            if context is not None:
                return context
        raise _unauthorized("Invalid or expired token.")

    def _verify_dev(self, token: str) -> AuthContext | None:
        if not self._settings.dev_auth or not self._dev_secret:
            return None
        try:
            claims = jwt.decode(
                token,
                self._dev_secret,
                algorithms=["HS256"],
                audience=DEV_AUDIENCE,
                issuer=DEV_ISSUER,
            )
        except jwt.InvalidTokenError:
            return None
        subject = claims.get("sub")
        if not isinstance(subject, str) or not subject:
            return None
        email = claims.get("email")
        return AuthContext(
            user_id=subject,
            email=email if isinstance(email, str) else None,
            mode="dev",
        )

    def _verify_supabase_hs256(self, token: str) -> AuthContext | None:
        secret = self._settings.supabase_jwt_secret
        if not secret:
            return None
        try:
            claims = jwt.decode(
                token,
                secret,
                algorithms=["HS256"],
                audience=self._settings.supabase_audience,
                issuer=self._settings.supabase_issuer,
            )
        except jwt.InvalidTokenError:
            return None
        return _context_from_supabase(claims)

    def _verify_supabase_jwks(self, token: str) -> AuthContext | None:
        client = self._jwks
        if client is None:
            return None
        try:
            key = client.get_signing_key_from_jwt(token).key
            claims = jwt.decode(
                token,
                key,
                algorithms=["RS256", "ES256"],
                audience=self._settings.supabase_audience,
                issuer=self._settings.supabase_issuer,
            )
        except Exception:
            return None
        return _context_from_supabase(claims)


def get_settings(request: Request) -> Settings:
    return request.app.state.settings


def get_verifier(request: Request) -> JwtVerifier:
    return request.app.state.auth_verifier


SettingsDep = Annotated[Settings, Depends(get_settings)]
VerifierDep = Annotated[JwtVerifier, Depends(get_verifier)]


def require_user(request: Request, verifier: VerifierDep) -> AuthContext:
    header = request.headers.get("authorization")
    if not header:
        raise _unauthorized("Missing bearer token.")
    scheme, _, token = header.partition(" ")
    if scheme.lower() != "bearer" or not token.strip():
        raise _unauthorized("Malformed bearer token.")
    return verifier.verify(token.strip())


UserDep = Annotated[AuthContext, Depends(require_user)]

router = APIRouter(prefix="/auth", tags=["auth"])


@router.post("/dev/login")
def dev_login(payload: DevLoginRequest, request: Request) -> dict[str, Any]:
    settings: Settings = request.app.state.settings
    if not settings.dev_auth:
        raise HTTPException(status_code=404, detail="Not found.")
    verifier: JwtVerifier = request.app.state.auth_verifier
    token = verifier.issue_dev_token(payload.email)
    return {
        "accessToken": token,
        "tokenType": "bearer",
        "expiresIn": DEV_TOKEN_TTL_SECONDS,
        "mode": "dev",
        "user": {"id": dev_user_id(payload.email), "email": payload.email},
    }


@router.get("/me")
def me(user: UserDep) -> dict[str, Any]:
    return {"userId": user.user_id, "email": user.email, "mode": user.mode}
