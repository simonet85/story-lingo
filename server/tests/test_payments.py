from __future__ import annotations

import json
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

import httpx
import pytest
from fastapi.testclient import TestClient

from server.app import payments as payments_module
from server.app.config import Settings
from server.app.main import create_app
from server.app.models import MoneyFusionPayment
from server.tests.support import DEV_SECRET

PUBLIC_BASE = "https://api.storylingo.test"
MF_API = "https://moneyfusion.test/api/pay"
MONTHLY = "storylingo_pro_monthly_xaf"
YEARLY = "storylingo_pro_yearly_xaf"


class FakeMoneyFusion:
    def __init__(self) -> None:
        self.creation_payload: dict[str, Any] | None = None
        self.creation_status = 200
        self.creation_error: Exception | None = None
        self.creation = {
            "statut": True,
            "token": "demo-1",
            "message": "paiement en cours",
            "url": "https://pay.test/demo-1",
        }
        self.status = {
            "statut": True,
            "message": "ok",
            "data": {
                "statut": "paid",
                "Montant": 3500,
                "frais": 0,
                "moyen": "orange",
                "numeroTransaction": "txn-1",
            },
        }
        self.status_urls: list[str] = []

    def handler(self, request: httpx.Request) -> httpx.Response:
        if request.method == "POST":
            self.creation_payload = json.loads(request.content)
            if self.creation_error is not None:
                raise self.creation_error
            return httpx.Response(self.creation_status, json=self.creation)
        self.status_urls.append(str(request.url))
        return httpx.Response(200, json=self.status)

    def client(self) -> httpx.Client:
        return httpx.Client(transport=httpx.MockTransport(self.handler), timeout=5)


@pytest.fixture
def fake(monkeypatch: pytest.MonkeyPatch) -> FakeMoneyFusion:
    fake = FakeMoneyFusion()
    monkeypatch.setattr(payments_module, "_http_client", fake.client)
    return fake


def _settings(tmp_path: Path, **overrides: Any) -> Settings:
    values: dict[str, Any] = {
        "database_url": f"sqlite:///{(tmp_path / 'api.db').as_posix()}",
        "content_dir": tmp_path / "packs",
        "public_base_url": PUBLIC_BASE,
        "dev_auth": True,
        "dev_auth_secret": DEV_SECRET,
        "moneyfusion_api_url": MF_API,
    }
    values.update(overrides)
    return Settings(**values)


@pytest.fixture
def api(tmp_path: Path, fake: FakeMoneyFusion):
    app = create_app(_settings(tmp_path))
    with TestClient(app) as client:
        yield client, app


def _login(client: TestClient) -> tuple[str, str]:
    response = client.post(
        "/v1/auth/dev/login", json={"email": "reader@example.com"}
    )
    assert response.status_code == 200, response.text
    payload = response.json()
    return payload["accessToken"], payload["user"]["id"]


def _auth(token: str) -> dict[str, str]:
    return {"Authorization": f"Bearer {token}"}


def _start(
    client: TestClient,
    token: str,
    *,
    product: str = MONTHLY,
    numero: str = "01010101",
    nom: str = "John Doe",
) -> dict[str, Any]:
    response = client.post(
        "/v1/payments/moneyfusion",
        headers=_auth(token),
        json={"productId": product, "numeroSend": numero, "nomclient": nom},
    )
    assert response.status_code == 200, response.text
    return response.json()


def _entitlement(client: TestClient, token: str) -> dict[str, Any]:
    response = client.get("/v1/entitlements", headers=_auth(token))
    assert response.status_code == 200, response.text
    return response.json()


def _webhook(client: TestClient, token: str, **kwargs: Any):
    return client.post("/v1/webhooks/moneyfusion", json={"token": token}, **kwargs)


def _expiry_seconds(entitlement: dict[str, Any]) -> float:
    expires = datetime.fromisoformat(
        entitlement["expiresAt"].replace("Z", "+00:00")
    )
    return (expires - datetime.now(timezone.utc)).total_seconds()


def test_creation_requires_auth(api) -> None:
    client, _ = api
    response = client.post(
        "/v1/payments/moneyfusion",
        json={"productId": MONTHLY, "numeroSend": "01010101", "nomclient": "Jo"},
    )
    assert response.status_code == 401


def test_unknown_product_rejected(api) -> None:
    client, _ = api
    token, _ = _login(client)
    response = client.post(
        "/v1/payments/moneyfusion",
        headers=_auth(token),
        json={"productId": "autre", "numeroSend": "01010101", "nomclient": "Jo"},
    )
    assert response.status_code == 400
    assert response.json()["detail"] == "Produit inconnu."


def test_blank_phone_rejected(api) -> None:
    client, _ = api
    token, _ = _login(client)
    response = client.post(
        "/v1/payments/moneyfusion",
        headers=_auth(token),
        json={"productId": MONTHLY, "numeroSend": "  ", "nomclient": "Jo"},
    )
    assert response.status_code == 400


def test_unconfigured_service_returns_503(tmp_path: Path, fake) -> None:
    app = create_app(_settings(tmp_path, moneyfusion_api_url=None))
    with TestClient(app) as client:
        token, _ = _login(client)
        response = client.post(
            "/v1/payments/moneyfusion",
            headers=_auth(token),
            json={
                "productId": MONTHLY,
                "numeroSend": "01010101",
                "nomclient": "Jo",
            },
        )
    assert response.status_code == 503


def test_invalid_price_returns_503(tmp_path: Path, fake) -> None:
    app = create_app(_settings(tmp_path, moneyfusion_price_monthly_xaf=0))
    with TestClient(app) as client:
        token, _ = _login(client)
        response = client.post(
            "/v1/payments/moneyfusion",
            headers=_auth(token),
            json={
                "productId": MONTHLY,
                "numeroSend": "01010101",
                "nomclient": "Jo",
            },
        )
    assert response.status_code == 503


def test_creation_sends_server_price_and_urls(api, fake) -> None:
    client, app = api
    token, _ = _login(client)
    body = _start(client, token)

    assert body == {
        "token": "demo-1",
        "url": "https://pay.test/demo-1",
        "productId": MONTHLY,
        "amount": 3500,
    }
    assert fake.creation_payload == {
        "totalPrice": 3500,
        "article": [{"paiement": 3500}],
        "numeroSend": "01010101",
        "nomclient": "John Doe",
        "return_url": f"{PUBLIC_BASE}/v1/payments/moneyfusion/return",
        "webhook_url": f"{PUBLIC_BASE}/v1/webhooks/moneyfusion",
    }
    with app.state.session_factory() as session:
        row = session.get(MoneyFusionPayment, "demo-1")
        assert row is not None
        assert row.status == "pending"
        assert row.amount == 3500
        assert row.product_id == MONTHLY


def test_moneyfusion_refusal_returns_502(api, fake) -> None:
    client, _ = api
    token, _ = _login(client)
    fake.creation = {"statut": False, "message": "refusé"}
    response = client.post(
        "/v1/payments/moneyfusion",
        headers=_auth(token),
        json={"productId": MONTHLY, "numeroSend": "01010101", "nomclient": "Jo"},
    )
    assert response.status_code == 502


def test_moneyfusion_http_error_returns_502(api, fake) -> None:
    client, _ = api
    token, _ = _login(client)
    fake.creation_status = 500
    response = client.post(
        "/v1/payments/moneyfusion",
        headers=_auth(token),
        json={"productId": MONTHLY, "numeroSend": "01010101", "nomclient": "Jo"},
    )
    assert response.status_code == 502


def test_moneyfusion_network_error_returns_502(api, fake) -> None:
    client, _ = api
    token, _ = _login(client)
    fake.creation_error = httpx.ConnectError("boom")
    response = client.post(
        "/v1/payments/moneyfusion",
        headers=_auth(token),
        json={"productId": MONTHLY, "numeroSend": "01010101", "nomclient": "Jo"},
    )
    assert response.status_code == 502


def test_webhook_unknown_token_returns_404(api) -> None:
    client, _ = api
    response = _webhook(client, "inconnu")
    assert response.status_code == 404


def test_webhook_missing_token_returns_400(api) -> None:
    client, _ = api
    response = client.post("/v1/webhooks/moneyfusion", json={})
    assert response.status_code == 400


def test_webhook_invalid_json_returns_400(api) -> None:
    client, _ = api
    response = client.post(
        "/v1/webhooks/moneyfusion",
        content=b"pas du json",
        headers={"Content-Type": "application/json"},
    )
    assert response.status_code == 400


def test_return_page_is_static(api) -> None:
    client, app = api
    response = client.get("/v1/payments/moneyfusion/return")
    assert response.status_code == 200
    assert "Paiement terminé" in response.text
    with app.state.session_factory() as session:
        assert session.query(MoneyFusionPayment).count() == 0


def test_paid_grants_monthly_entitlement(api, fake) -> None:
    client, app = api
    token, user_id = _login(client)
    body = _start(client, token)

    response = _webhook(client, body["token"])
    assert response.json() == {"ok": True, "applied": True, "status": "paid"}
    assert fake.status_urls == [
        "https://pay.moneyfusion.net/paiementNotif/demo-1"
    ]

    entitlement = _entitlement(client, token)
    assert entitlement["active"] is True
    assert entitlement["source"] == "moneyfusion"
    assert entitlement["productId"] == MONTHLY
    seconds = _expiry_seconds(entitlement)
    assert 29 * 86400 <= seconds <= 30 * 86400

    with app.state.session_factory() as session:
        row = session.get(MoneyFusionPayment, "demo-1")
        assert row is not None
        assert row.status == "paid"
        assert row.transaction_number == "txn-1"
        assert row.applied_at_ms is not None
        assert row.user_id == user_id


def test_replayed_webhook_does_not_extend(api, fake) -> None:
    client, _ = api
    token, _ = _login(client)
    body = _start(client, token)
    _webhook(client, body["token"])
    first = _entitlement(client, token)["expiresAt"]

    response = _webhook(client, body["token"])
    assert response.json() == {"ok": True, "applied": False, "status": "paid"}
    assert _entitlement(client, token)["expiresAt"] == first
    assert len(fake.status_urls) == 1


def test_yearly_grants_365_days(api, fake) -> None:
    client, _ = api
    token, _ = _login(client)
    fake.status["data"]["Montant"] = 30000
    body = _start(client, token, product=YEARLY)
    assert body["amount"] == 30000

    response = _webhook(client, body["token"])
    assert response.json()["applied"] is True
    entitlement = _entitlement(client, token)
    seconds = _expiry_seconds(entitlement)
    assert 364 * 86400 <= seconds <= 365 * 86400


def test_failure_marks_payment_without_grant(api, fake) -> None:
    client, app = api
    token, _ = _login(client)
    body = _start(client, token)
    fake.status["data"]["statut"] = "failure"

    response = _webhook(client, body["token"])
    assert response.json() == {"ok": True, "applied": False, "status": "failed"}
    assert _entitlement(client, token)["active"] is False
    with app.state.session_factory() as session:
        row = session.get(MoneyFusionPayment, "demo-1")
        assert row is not None
        assert row.status == "failed"


def test_pending_status_changes_nothing(api, fake) -> None:
    client, app = api
    token, _ = _login(client)
    body = _start(client, token)
    fake.status["data"]["statut"] = "pending"

    response = _webhook(client, body["token"])
    assert response.json() == {"ok": True, "applied": False, "status": "pending"}
    assert _entitlement(client, token)["active"] is False
    with app.state.session_factory() as session:
        row = session.get(MoneyFusionPayment, "demo-1")
        assert row is not None
        assert row.status == "pending"


def test_amount_mismatch_rejected(api, fake) -> None:
    client, app = api
    token, _ = _login(client)
    body = _start(client, token)
    fake.status["data"]["Montant"] = 100

    response = _webhook(client, body["token"])
    assert response.status_code == 400
    assert _entitlement(client, token)["active"] is False
    with app.state.session_factory() as session:
        row = session.get(MoneyFusionPayment, "demo-1")
        assert row is not None
        assert row.status == "pending"
        assert row.applied_at_ms is None


def test_webhook_accepts_form_body(api) -> None:
    client, _ = api
    token, _ = _login(client)
    body = _start(client, token)

    response = client.post(
        "/v1/webhooks/moneyfusion", data={"token": body["token"]}
    )
    assert response.json()["applied"] is True
    assert _entitlement(client, token)["active"] is True


def test_amount_as_string_is_accepted(api, fake) -> None:
    client, _ = api
    token, _ = _login(client)
    body = _start(client, token)
    fake.status["data"]["Montant"] = "3500"

    response = _webhook(client, body["token"])
    assert response.json()["applied"] is True


def test_products_are_public(api) -> None:
    client, _ = api

    response = client.get("/v1/payments/moneyfusion/products")

    assert response.status_code == 200
    assert response.json() == {
        "products": [
            {
                "productId": MONTHLY,
                "amount": 3500,
                "days": 30,
                "currency": "XAF",
            },
            {
                "productId": YEARLY,
                "amount": 30000,
                "days": 365,
                "currency": "XAF",
            },
        ]
    }


def test_products_reflect_configured_prices(tmp_path: Path, fake) -> None:
    settings = _settings(
        tmp_path,
        moneyfusion_price_monthly_xaf=5000,
        moneyfusion_price_yearly_xaf=48000,
    )
    with TestClient(create_app(settings)) as client:
        response = client.get("/v1/payments/moneyfusion/products")

    amounts = {
        product["productId"]: product["amount"]
        for product in response.json()["products"]
    }
    assert amounts == {MONTHLY: 5000, YEARLY: 48000}


def test_products_unavailable_when_price_is_zero(tmp_path: Path, fake) -> None:
    settings = _settings(tmp_path, moneyfusion_price_monthly_xaf=0)
    with TestClient(create_app(settings)) as client:
        response = client.get("/v1/payments/moneyfusion/products")

    assert response.status_code == 503


def test_products_do_not_expose_moneyfusion_urls(api) -> None:
    client, _ = api

    body = client.get("/v1/payments/moneyfusion/products").text

    assert "moneyfusion" not in body
    assert MF_API not in body
