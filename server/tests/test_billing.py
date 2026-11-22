from __future__ import annotations

import json
from pathlib import Path

import pytest
from fastapi.testclient import TestClient

from server.app.config import Settings
from server.app.main import create_app
from server.app.packs import publish_pack
from server.tests.support import DEV_SECRET, build_pack

FUTURE_MS = 9_999_999_999_000


def _settings(tmp_path: Path, **overrides) -> Settings:
    return Settings(
        database_url=f"sqlite:///{(tmp_path / 'api.db').as_posix()}",
        content_dir=tmp_path / "packs",
        public_base_url=None,
        **overrides,
    )


def _login(client: TestClient, email: str = "reader@example.com"):
    response = client.post("/v1/auth/dev/login", json={"email": email})
    assert response.status_code == 200, response.text
    payload = response.json()
    return payload["accessToken"], payload["user"]["id"]


def _auth(token: str) -> dict[str, str]:
    return {"Authorization": f"Bearer {token}"}


@pytest.fixture
def billing_client(tmp_path: Path):
    settings = _settings(
        tmp_path,
        dev_auth=True,
        dev_auth_secret=DEV_SECRET,
        revenuecat_webhook_secret="hook-secret",
    )
    app = create_app(settings)
    with TestClient(app) as client:
        yield client


def _event(
    user_id: str,
    *,
    event_type: str = "INITIAL_PURCHASE",
    event_ms: int = 1000,
    expires_ms: int | None = FUTURE_MS,
    **extra,
) -> dict:
    event = {
        "id": f"evt-{event_type}-{event_ms}",
        "type": event_type,
        "app_user_id": user_id,
        "event_timestamp_ms": event_ms,
        "product_id": "storylingo_yearly",
    }
    if expires_ms is not None:
        event["expiration_at_ms"] = expires_ms
    event.update(extra)
    return {"api_version": "1.0", "event": event}


WEBHOOK_HEADERS = {"Authorization": "hook-secret"}


def test_entitlements_require_auth(billing_client: TestClient) -> None:
    response = billing_client.get("/v1/entitlements")
    assert response.status_code == 401


def test_entitlements_inactive_without_subscription(
    billing_client: TestClient,
) -> None:
    token, _ = _login(billing_client)
    response = billing_client.get("/v1/entitlements", headers=_auth(token))
    assert response.status_code == 200
    assert response.headers["cache-control"] == "no-store"
    payload = response.json()
    assert payload["active"] is False
    assert payload["status"] == "none"
    assert payload["expiresAt"] is None


def test_dev_grant_then_revoke(billing_client: TestClient) -> None:
    token, _ = _login(billing_client)
    granted = billing_client.post(
        "/v1/entitlements/dev-grant",
        headers=_auth(token),
        json={"days": 30, "productId": "dev_monthly"},
    )
    assert granted.status_code == 200, granted.text
    payload = granted.json()
    assert payload["active"] is True
    assert payload["source"] == "dev"
    assert payload["productId"] == "dev_monthly"
    assert payload["expiresAt"] is not None

    check = billing_client.get("/v1/entitlements", headers=_auth(token)).json()
    assert check["active"] is True

    revoked = billing_client.post(
        "/v1/entitlements/dev-revoke", headers=_auth(token)
    )
    assert revoked.status_code == 200
    assert revoked.json()["active"] is False
    assert revoked.json()["status"] == "none"


def test_dev_routes_are_hidden_without_dev_auth(tmp_path: Path) -> None:
    app = create_app(_settings(tmp_path))
    with TestClient(app) as client:
        response = client.post(
            "/v1/entitlements/dev-grant", json={"days": 30}
        )
        assert response.status_code == 404
        response = client.post("/v1/entitlements/dev-revoke")
        assert response.status_code == 404


def test_webhook_requires_configuration(tmp_path: Path) -> None:
    app = create_app(_settings(tmp_path))
    with TestClient(app) as client:
        response = client.post(
            "/v1/webhooks/revenuecat", json=_event("user-1")
        )
        assert response.status_code == 503


def test_webhook_rejects_wrong_secret(billing_client: TestClient) -> None:
    response = billing_client.post(
        "/v1/webhooks/revenuecat",
        headers={"Authorization": "nope"},
        json=_event("user-1"),
    )
    assert response.status_code == 401


def test_webhook_lifecycle_and_stale_events(billing_client: TestClient) -> None:
    token, user_id = _login(billing_client, "billing@example.com")

    purchase = billing_client.post(
        "/v1/webhooks/revenuecat",
        headers=WEBHOOK_HEADERS,
        json=_event(user_id, event_ms=1000),
    )
    assert purchase.status_code == 200, purchase.text
    assert purchase.json()["applied"] is True

    state = billing_client.get("/v1/entitlements", headers=_auth(token)).json()
    assert state["active"] is True
    assert state["status"] == "active"
    assert state["productId"] == "storylingo_yearly"
    assert state["expiresAt"] is not None

    duplicate = billing_client.post(
        "/v1/webhooks/revenuecat",
        headers=WEBHOOK_HEADERS,
        json=_event(user_id, event_ms=1000),
    )
    assert duplicate.json() == {"applied": False, "reason": "stale"}

    renewal = billing_client.post(
        "/v1/webhooks/revenuecat",
        headers=WEBHOOK_HEADERS,
        json=_event(user_id, event_type="RENEWAL", event_ms=2000),
    )
    assert renewal.json()["applied"] is True

    stale = billing_client.post(
        "/v1/webhooks/revenuecat",
        headers=WEBHOOK_HEADERS,
        json=_event(user_id, event_type="RENEWAL", event_ms=1500),
    )
    assert stale.json() == {"applied": False, "reason": "stale"}

    expiration = billing_client.post(
        "/v1/webhooks/revenuecat",
        headers=WEBHOOK_HEADERS,
        json=_event(user_id, event_type="EXPIRATION", event_ms=3000),
    )
    assert expiration.json()["applied"] is True
    expired = billing_client.get("/v1/entitlements", headers=_auth(token)).json()
    assert expired["active"] is False
    assert expired["status"] == "expired"


def test_cancellation_stays_active_until_expiry(
    billing_client: TestClient,
) -> None:
    token, user_id = _login(billing_client, "cancel@example.com")
    billing_client.post(
        "/v1/webhooks/revenuecat",
        headers=WEBHOOK_HEADERS,
        json=_event(user_id, event_ms=1000),
    )
    cancelled = billing_client.post(
        "/v1/webhooks/revenuecat",
        headers=WEBHOOK_HEADERS,
        json=_event(user_id, event_type="CANCELLATION", event_ms=2000),
    )
    assert cancelled.json()["applied"] is True
    state = billing_client.get("/v1/entitlements", headers=_auth(token)).json()
    assert state["active"] is True
    assert state["status"] == "cancelled"


def test_billing_issue_enters_grace(billing_client: TestClient) -> None:
    token, user_id = _login(billing_client, "grace@example.com")
    billing_client.post(
        "/v1/webhooks/revenuecat",
        headers=WEBHOOK_HEADERS,
        json=_event(user_id, event_ms=1000),
    )
    billing_client.post(
        "/v1/webhooks/revenuecat",
        headers=WEBHOOK_HEADERS,
        json=_event(user_id, event_type="BILLING_ISSUE", event_ms=2000),
    )
    state = billing_client.get("/v1/entitlements", headers=_auth(token)).json()
    assert state["active"] is True
    assert state["status"] == "grace"


def test_transfer_expires_source_and_unlocks_target(
    billing_client: TestClient,
) -> None:
    source_token, source_user = _login(billing_client, "source@example.com")
    target_token, target_user = _login(billing_client, "target@example.com")
    billing_client.post(
        "/v1/webhooks/revenuecat",
        headers=WEBHOOK_HEADERS,
        json=_event(source_user, event_ms=1000),
    )
    transfer = billing_client.post(
        "/v1/webhooks/revenuecat",
        headers=WEBHOOK_HEADERS,
        json=_event(
            source_user,
            event_type="TRANSFER",
            event_ms=2000,
            transferred_from=[source_user],
            transferred_to=[target_user],
        ),
    )
    assert transfer.status_code == 200, transfer.text
    assert transfer.json()["applied"] is True

    source_state = billing_client.get(
        "/v1/entitlements", headers=_auth(source_token)
    ).json()
    target_state = billing_client.get(
        "/v1/entitlements", headers=_auth(target_token)
    ).json()
    assert source_state["active"] is False
    assert source_state["status"] == "expired"
    assert target_state["active"] is True
    assert target_state["status"] == "active"


def test_unknown_event_type_is_ignored(billing_client: TestClient) -> None:
    _, user_id = _login(billing_client)
    response = billing_client.post(
        "/v1/webhooks/revenuecat",
        headers=WEBHOOK_HEADERS,
        json=_event(user_id, event_type="SUBSCRIBER_ALIAS", event_ms=1000),
    )
    assert response.status_code == 200
    assert response.json() == {"applied": False, "reason": "ignored"}


def test_invalid_webhook_body_is_rejected(billing_client: TestClient) -> None:
    missing_event = billing_client.post(
        "/v1/webhooks/revenuecat",
        headers=WEBHOOK_HEADERS,
        json={"api_version": "1.0"},
    )
    assert missing_event.status_code == 400

    non_object = billing_client.post(
        "/v1/webhooks/revenuecat",
        headers=WEBHOOK_HEADERS,
        json=[],
    )
    assert non_object.status_code == 400


def test_publication_defaults_to_paid_and_exposes_flag(tmp_path: Path) -> None:
    settings = _settings(tmp_path)
    app = create_app(settings)
    source = build_pack(tmp_path / "source", book_id="paid-book")
    with app.state.session_factory() as session:
        book = publish_pack(source, settings.content_dir, session)
        assert book.is_free is False

    with TestClient(app) as client:
        catalogue = client.get("/v1/catalogue").json()["books"]
        assert catalogue[0]["isFree"] is False
        manifest = client.get("/v1/books/paid-book").json()
        assert manifest["isFree"] is False
        sidecar = json.loads(
            (settings.content_dir / "paid-book" / ".download.json").read_text(
                encoding="utf-8"
            )
        )
        assert sidecar["bookId"] == "paid-book"

    with app.state.session_factory() as session:
        republished = publish_pack(source, settings.content_dir, session)
        assert republished.is_free is False
        freed = publish_pack(source, settings.content_dir, session, is_free=True)
        assert freed.is_free is True
        kept_free = publish_pack(source, settings.content_dir, session)
        assert kept_free.is_free is True
        paid_again = publish_pack(source, settings.content_dir, session, is_free=False)
        assert paid_again.is_free is False


def test_manifest_endpoint_overrides_a_legacy_pack_flag(tmp_path: Path) -> None:
    settings = _settings(tmp_path)
    app = create_app(settings)
    source = build_pack(tmp_path / "source", book_id="legacy-book")
    with app.state.session_factory() as session:
        book = publish_pack(source, settings.content_dir, session, is_free=False)
    manifest_path = settings.content_dir / book.id / "manifest.json"
    raw = json.loads(manifest_path.read_text(encoding="utf-8"))
    raw.pop("isFree", None)
    manifest_path.write_text(json.dumps(raw), encoding="utf-8")

    with TestClient(app) as client:
        manifest = client.get("/v1/books/legacy-book").json()

    assert manifest["isFree"] is False
