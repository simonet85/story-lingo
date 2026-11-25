from __future__ import annotations

import json
import time
from decimal import Decimal, InvalidOperation
from typing import Any
from urllib.parse import parse_qs, quote

import httpx
from fastapi import APIRouter, Depends, HTTPException, Request
from fastapi.responses import HTMLResponse
from pydantic import BaseModel, ConfigDict, Field
from sqlalchemy.orm import Session

from .auth import UserDep
from .billing import _apply
from .config import Settings
from .models import MoneyFusionPayment
from .routes import get_session, get_settings

router = APIRouter(tags=["payments"])

DAY_MS = 24 * 60 * 60 * 1000
MONTHLY_PRODUCT = "storylingo_pro_monthly_xof"
YEARLY_PRODUCT = "storylingo_pro_yearly_xof"
_TIMEOUT_SECONDS = 30.0


class _Product:
    __slots__ = ("days", "price")

    def __init__(self, days: int, price: int) -> None:
        self.days = days
        self.price = price


def _products(settings: Settings) -> dict[str, _Product]:
    return {
        MONTHLY_PRODUCT: _Product(30, settings.moneyfusion_price_monthly_xof),
        YEARLY_PRODUCT: _Product(365, settings.moneyfusion_price_yearly_xof),
    }


def _http_client() -> httpx.Client:
    return httpx.Client(timeout=_TIMEOUT_SECONDS)


def _now_ms() -> int:
    return int(time.time() * 1000)


def _require_config(settings: Settings) -> None:
    if not settings.moneyfusion_api_url or not settings.public_base_url:
        raise HTTPException(status_code=503, detail="Paiement indisponible.")
    if any(product.price <= 0 for product in _products(settings).values()):
        raise HTTPException(status_code=503, detail="Paiement indisponible.")


class CreatePaymentRequest(BaseModel):
    model_config = ConfigDict(populate_by_name=True, extra="forbid")

    product_id: str = Field(alias="productId", max_length=64)
    numero_send: str = Field(alias="numeroSend", max_length=32)
    nomclient: str = Field(max_length=120)


def _post_creation(api_url: str, payload: dict[str, Any]) -> dict[str, str]:
    try:
        with _http_client() as client:
            response = client.post(api_url, json=payload)
            response.raise_for_status()
            data = response.json()
    except (httpx.HTTPError, ValueError) as error:
        raise HTTPException(
            status_code=502, detail="Création du paiement impossible."
        ) from error
    if not isinstance(data, dict) or data.get("statut") is not True:
        raise HTTPException(
            status_code=502, detail="Création du paiement impossible."
        )
    token = data.get("token")
    url = data.get("url")
    if not isinstance(token, str) or not token:
        raise HTTPException(
            status_code=502, detail="Création du paiement impossible."
        )
    if not isinstance(url, str) or not url:
        raise HTTPException(
            status_code=502, detail="Création du paiement impossible."
        )
    return {"token": token, "url": url}


def _fetch_status(settings: Settings, token: str) -> dict[str, Any]:
    base = settings.moneyfusion_status_base_url.rstrip("/")
    url = f"{base}/paiementNotif/{quote(token, safe='')}"
    try:
        with _http_client() as client:
            response = client.get(url)
            response.raise_for_status()
            data = response.json()
    except (httpx.HTTPError, ValueError) as error:
        raise HTTPException(
            status_code=502, detail="Statut du paiement indisponible."
        ) from error
    if not isinstance(data, dict) or data.get("statut") is not True:
        raise HTTPException(
            status_code=502, detail="Statut du paiement indisponible."
        )
    inner = data.get("data")
    return inner if isinstance(inner, dict) else {}


def _as_decimal(raw: Any) -> Decimal | None:
    if isinstance(raw, bool):
        return None
    if isinstance(raw, (int, float, str)):
        try:
            value = Decimal(str(raw).strip())
        except (InvalidOperation, ValueError):
            return None
        return value if value.is_finite() else None
    return None


def _paid_amount_matches(status: dict[str, Any], expected: int) -> bool:
    """MoneyFusion reports `Montant` net of its fee, with `frais` alongside."""
    amount = _as_decimal(status.get("Montant"))
    if amount is None:
        return False
    target = Decimal(expected)
    if amount == target:
        return True
    raw_fee = status.get("frais")
    fee = Decimal(0) if raw_fee in (None, "") else _as_decimal(raw_fee)
    if fee is None or fee < 0:
        return False
    return amount + fee == target


@router.get("/payments/moneyfusion/products")
def list_products(
    settings: Settings = Depends(get_settings),
) -> dict[str, Any]:
    products = _products(settings)
    if any(product.price <= 0 for product in products.values()):
        raise HTTPException(status_code=503, detail="Paiement indisponible.")
    return {
        "products": [
            {
                "productId": product_id,
                "amount": product.price,
                "days": product.days,
                "currency": "XOF",
            }
            for product_id, product in products.items()
        ]
    }


@router.post("/payments/moneyfusion")
def create_payment(
    body: CreatePaymentRequest,
    user: UserDep,
    session: Session = Depends(get_session),
    settings: Settings = Depends(get_settings),
) -> dict[str, Any]:
    _require_config(settings)
    product = _products(settings).get(body.product_id)
    if product is None:
        raise HTTPException(status_code=400, detail="Produit inconnu.")
    numero_send = body.numero_send.strip()
    nomclient = body.nomclient.strip()
    if not numero_send or not nomclient:
        raise HTTPException(
            status_code=400, detail="Téléphone et nom requis."
        )

    base = settings.public_base_url.rstrip("/")
    payload = {
        "totalPrice": product.price,
        "article": [{"paiement": product.price}],
        "numeroSend": numero_send,
        "nomclient": nomclient,
        "return_url": f"{base}/v1/payments/moneyfusion/return",
        "webhook_url": f"{base}/v1/webhooks/moneyfusion",
    }
    created = _post_creation(settings.moneyfusion_api_url, payload)

    session.add(
        MoneyFusionPayment(
            token=created["token"],
            user_id=user.user_id,
            product_id=body.product_id,
            amount=product.price,
            status="pending",
            created_at_ms=_now_ms(),
        )
    )
    session.commit()
    return {
        "token": created["token"],
        "url": created["url"],
        "productId": body.product_id,
        "amount": product.price,
    }


async def _webhook_token(request: Request) -> str:
    content_type = request.headers.get("content-type", "")
    try:
        raw = await request.body()
    except Exception as error:
        raise HTTPException(status_code=400, detail="Corps illisible.") from error
    token: Any = None
    if "application/json" in content_type:
        try:
            payload = json.loads(raw.decode("utf-8")) if raw else None
        except (UnicodeDecodeError, ValueError) as error:
            raise HTTPException(
                status_code=400, detail="Corps illisible."
            ) from error
        token = payload.get("token") if isinstance(payload, dict) else None
    else:
        try:
            form = parse_qs(raw.decode("utf-8"), keep_blank_values=True)
        except UnicodeDecodeError as error:
            raise HTTPException(
                status_code=400, detail="Corps illisible."
            ) from error
        values = form.get("token")
        token = values[0] if values else None
    if not isinstance(token, str) or not token:
        raise HTTPException(status_code=400, detail="Token manquant.")
    return token


@router.post("/webhooks/moneyfusion")
async def moneyfusion_webhook(
    request: Request,
    session: Session = Depends(get_session),
    settings: Settings = Depends(get_settings),
) -> dict[str, Any]:
    token = await _webhook_token(request)
    payment = session.get(MoneyFusionPayment, token)
    if payment is None:
        raise HTTPException(status_code=404, detail="Paiement inconnu.")
    if payment.applied_at_ms is not None:
        return {"ok": True, "applied": False, "status": payment.status}

    status = _fetch_status(settings, token)
    remote_status = status.get("statut")
    if remote_status == "paid":
        if not _paid_amount_matches(status, payment.amount):
            raise HTTPException(status_code=400, detail="Montant incohérent.")
        now_ms = _now_ms()
        product = _products(settings).get(payment.product_id)
        days = product.days if product is not None else 30
        applied = _apply(
            session,
            payment.user_id,
            status="active",
            product_id=payment.product_id,
            expires_at_ms=now_ms + days * DAY_MS,
            event_ms=now_ms,
            event_type="MONEYFUSION_PAID",
            source="moneyfusion",
        )
        payment.status = "paid"
        transaction = status.get("numeroTransaction")
        if isinstance(transaction, str) and transaction:
            payment.transaction_number = transaction
        if applied:
            payment.applied_at_ms = now_ms
        session.commit()
        return {"ok": True, "applied": applied, "status": "paid"}

    if remote_status in {"failure", "no paid"}:
        payment.status = "failed"
        session.commit()
        return {"ok": True, "applied": False, "status": "failed"}

    return {"ok": True, "applied": False, "status": "pending"}


@router.get("/payments/moneyfusion/return", response_class=HTMLResponse)
def payment_return() -> str:
    return (
        '<!doctype html><html lang="fr"><head><meta charset="utf-8">'
        '<meta name="viewport" content="width=device-width, initial-scale=1">'
        "<title>Retour à Storylingo</title></head><body>"
        "<h1>Paiement terminé</h1>"
        "<p>Revenez dans l'application Storylingo. L'abonnement est activé "
        "dès confirmation du paiement.</p>"
        "</body></html>"
    )
