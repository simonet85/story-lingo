from __future__ import annotations

import re
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
from server.tests.support import (  # noqa: E402
    ADMIN_SESSION_SECRET,
    ADMIN_TOKEN,
    DEV_SECRET,
    build_pack,
)


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


@pytest.fixture
def admin_settings(settings: Settings) -> Settings:
    return replace(
        settings,
        admin_token=ADMIN_TOKEN,
        admin_session_secret=ADMIN_SESSION_SECRET,
    )


@pytest.fixture
def admin_app(admin_settings: Settings):
    app = create_app(admin_settings)
    source = build_pack(Path(admin_settings.content_dir).parent / "admin-source")
    with app.state.session_factory() as session:
        publish_pack(source, admin_settings.content_dir, session, is_free=True)
    return app


@pytest.fixture
def admin_client(admin_app):
    with TestClient(admin_app) as test_client:
        yield test_client


@pytest.fixture
def admin_login(admin_client):
    def login(password: str = ADMIN_TOKEN):
        return admin_client.post(
            "/admin/login",
            data={"password": password},
            follow_redirects=False,
        )

    return login


@pytest.fixture
def admin_csrf(admin_client, admin_login):
    response = admin_login()
    assert response.status_code == 303, response.text
    page = admin_client.get("/admin/books")
    match = re.search(r'name="csrf" value="([0-9a-f]{32})"', page.text)
    assert match is not None, page.text
    return match.group(1)
