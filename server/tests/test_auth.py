from __future__ import annotations

import time
from dataclasses import replace
from pathlib import Path

import jwt
import pytest
from fastapi.testclient import TestClient

from server.app.auth import DEV_AUDIENCE, DEV_ISSUER, dev_user_id
from server.app.config import Settings
from server.app.main import create_app
from server.tests.support import DEV_SECRET


def test_dev_login_is_hidden_when_disabled(client):
    response = client.post(
        "/v1/auth/dev/login", json={"email": "reader@example.com"}
    )
    assert response.status_code == 404


def test_dev_login_returns_stable_identity(dev_client):
    first = dev_client.post(
        "/v1/auth/dev/login", json={"email": "  Reader@Example.com "}
    )
    second = dev_client.post(
        "/v1/auth/dev/login", json={"email": "reader@example.com"}
    )
    assert first.status_code == 200
    body = first.json()
    assert body["mode"] == "dev"
    assert body["tokenType"] == "bearer"
    assert body["expiresIn"] == 24 * 60 * 60
    assert body["user"]["email"] == "reader@example.com"
    assert body["user"]["id"] == dev_user_id("reader@example.com")
    assert second.json()["user"]["id"] == body["user"]["id"]


def test_different_emails_get_different_ids(dev_client):
    one = dev_client.post(
        "/v1/auth/dev/login", json={"email": "one@example.com"}
    ).json()
    two = dev_client.post(
        "/v1/auth/dev/login", json={"email": "two@example.com"}
    ).json()
    assert one["user"]["id"] != two["user"]["id"]


def test_dev_login_rejects_invalid_email(dev_client):
    response = dev_client.post(
        "/v1/auth/dev/login", json={"email": "not-an-email"}
    )
    assert response.status_code == 422


def test_me_requires_bearer_token(dev_client):
    response = dev_client.get("/v1/auth/me")
    assert response.status_code == 401
    assert response.headers["www-authenticate"] == "Bearer"
    assert response.json()["detail"]


def test_me_returns_claims(dev_client, dev_login):
    token = dev_login("reader@example.com")
    response = dev_client.get(
        "/v1/auth/me", headers={"Authorization": f"Bearer {token}"}
    )
    assert response.status_code == 200
    assert response.json() == {
        "userId": dev_user_id("reader@example.com"),
        "email": "reader@example.com",
        "mode": "dev",
    }


def test_malformed_authorization_is_rejected(dev_client, dev_login):
    token = dev_login()
    for header in ("Token " + token, "Bearer", "Bearer "):
        response = dev_client.get(
            "/v1/auth/me", headers={"Authorization": header}
        )
        assert response.status_code == 401


def test_wrong_signature_is_rejected(dev_client, dev_login):
    claims = {
        "sub": "dev_x",
        "email": "x@example.com",
        "aud": DEV_AUDIENCE,
        "iss": DEV_ISSUER,
        "exp": int(time.time()) + 3600,
    }
    token = jwt.encode(
        claims, "another-secret-0123456789-abcdefghij", algorithm="HS256"
    )
    response = dev_client.get(
        "/v1/auth/me", headers={"Authorization": f"Bearer {token}"}
    )
    assert response.status_code == 401


def test_expired_token_is_rejected(dev_client):
    now = int(time.time())
    claims = {
        "sub": "dev_x",
        "email": "x@example.com",
        "aud": DEV_AUDIENCE,
        "iss": DEV_ISSUER,
        "iat": now - 7200,
        "exp": now - 3600,
    }
    token = jwt.encode(claims, DEV_SECRET, algorithm="HS256")
    response = dev_client.get(
        "/v1/auth/me", headers={"Authorization": f"Bearer {token}"}
    )
    assert response.status_code == 401


def test_supabase_hs256_token_is_accepted(settings: Settings, tmp_path: Path):
    secret = "supabase-test-secret-0123456789abcdef"
    supabase_settings = replace(
        settings,
        supabase_jwt_secret=secret,
        supabase_audience="authenticated",
        dev_auth=False,
    )
    app = create_app(supabase_settings)
    token = jwt.encode(
        {
            "sub": "8b1f-user",
            "email": "user@example.com",
            "aud": "authenticated",
            "exp": int(time.time()) + 3600,
        },
        secret,
        algorithm="HS256",
    )
    with TestClient(app) as client:
        response = client.get(
            "/v1/auth/me", headers={"Authorization": f"Bearer {token}"}
        )
    assert response.status_code == 200
    assert response.json() == {
        "userId": "8b1f-user",
        "email": "user@example.com",
        "mode": "supabase",
    }


def test_cors_preflight_allows_post_and_authorization(dev_client):
    response = dev_client.options(
        "/v1/sync/push",
        headers={
            "Origin": "http://localhost:7357",
            "Access-Control-Request-Method": "POST",
            "Access-Control-Request-Headers": "authorization,content-type",
        },
    )
    assert response.status_code == 200
    assert "POST" in response.headers["access-control-allow-methods"]
    allowed = response.headers["access-control-allow-headers"].lower()
    assert "authorization" in allowed
    assert "content-type" in allowed


@pytest.mark.parametrize("origin", ["http://localhost:8000", "http://127.0.0.1:3000"])
def test_cors_allows_local_origins(dev_client, origin):
    response = dev_client.get("/v1/health", headers={"Origin": origin})
    assert response.headers["access-control-allow-origin"] == origin
