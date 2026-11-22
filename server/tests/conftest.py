from __future__ import annotations

import sys
from dataclasses import replace
from pathlib import Path

import pytest
from fastapi.testclient import TestClient

ROOT = Path(__file__).resolve().parents[2]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from server.app.config import Settings  # noqa: E402
from server.app.main import create_app  # noqa: E402
from server.app.packs import publish_pack  # noqa: E402
from server.tests.support import DEV_SECRET, build_pack  # noqa: E402


@pytest.fixture
def settings(tmp_path: Path) -> Settings:
    return Settings(
        database_url=f"sqlite:///{(tmp_path / 'api.db').as_posix()}",
        content_dir=tmp_path / "packs",
        public_base_url=None,
    )


@pytest.fixture
def app(settings: Settings, tmp_path: Path):
    app = create_app(settings)
    source = build_pack(tmp_path / "source")
    with app.state.session_factory() as session:
        publish_pack(source, settings.content_dir, session, is_free=True)
    return app


@pytest.fixture
def client(app):
    with TestClient(app) as test_client:
        yield test_client


@pytest.fixture
def make_pack(tmp_path: Path):
    def factory(name: str = "pack", **kwargs):
        return build_pack(tmp_path / name, **kwargs)

    return factory


@pytest.fixture
def dev_settings(settings: Settings) -> Settings:
    return replace(settings, dev_auth=True, dev_auth_secret=DEV_SECRET)


@pytest.fixture
def dev_app(dev_settings: Settings):
    app = create_app(dev_settings)
    source = build_pack(Path(dev_settings.content_dir).parent / "source")
    with app.state.session_factory() as session:
        publish_pack(source, dev_settings.content_dir, session, is_free=True)
    return app


@pytest.fixture
def dev_client(dev_app):
    with TestClient(dev_app) as test_client:
        yield test_client


@pytest.fixture
def dev_login(dev_client):
    def login(email: str = "reader@example.com") -> str:
        response = dev_client.post(
            "/v1/auth/dev/login", json={"email": email}
        )
        assert response.status_code == 200, response.text
        return response.json()["accessToken"]

    return login


@pytest.fixture
def auth_headers(dev_login):
    def headers(email: str = "reader@example.com") -> dict[str, str]:
        return {"Authorization": f"Bearer {dev_login(email)}"}

    return headers
