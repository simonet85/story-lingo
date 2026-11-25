from __future__ import annotations

from server.tests.support import ADMIN_TOKEN


def test_admin_is_disabled_without_token(client):
    assert client.get("/admin/login").status_code == 404
    assert (
        client.post("/admin/login", data={"password": "secret"}).status_code
        == 404
    )


def test_login_page_does_not_leak_token(admin_client):
    response = admin_client.get("/admin/login")
    assert response.status_code == 200
    assert "Connexion administrateur" in response.text
    assert ADMIN_TOKEN not in response.text


def test_bad_password_is_rejected(admin_client):
    response = admin_client.post(
        "/admin/login",
        data={"password": "wrong-password"},
        follow_redirects=False,
    )
    assert response.status_code == 401
    assert "Mot de passe invalide." in response.text
    assert response.headers.get("set-cookie") is None


def test_login_sets_a_hardened_cookie(admin_login):
    response = admin_login()
    assert response.status_code == 303
    assert response.headers["location"] == "/admin/books"
    cookie = response.headers["set-cookie"]
    assert "HttpOnly" in cookie
    assert "SameSite=lax" in cookie
    assert "Path=/admin" in cookie
    assert "Secure" not in cookie
    assert ADMIN_TOKEN not in cookie


def test_books_requires_a_session(admin_client):
    response = admin_client.get("/admin/books", follow_redirects=False)
    assert response.status_code == 303
    assert response.headers["location"] == "/admin/login"


def test_tampered_session_is_rejected(admin_client):
    admin_client.cookies.set("storylingo_admin", "not-a-valid-jwt")
    response = admin_client.get("/admin/books", follow_redirects=False)
    assert response.status_code == 303
    assert response.headers["location"] == "/admin/login"


def test_logout_requires_csrf(admin_client, admin_login):
    admin_login()
    response = admin_client.post(
        "/admin/logout", follow_redirects=False
    )
    assert response.status_code == 403


def test_logout_clears_the_session(admin_client, admin_csrf):
    response = admin_client.post(
        "/admin/logout",
        data={"csrf": admin_csrf},
        follow_redirects=False,
    )
    assert response.status_code == 303
    assert response.headers["location"] == "/admin/login"
    assert (
        admin_client.get("/admin/books", follow_redirects=False).status_code
        == 303
    )


def test_authenticated_pages_do_not_leak_the_token(
    admin_client, admin_csrf
):
    for path in ("/admin/books", "/admin/import"):
        response = admin_client.get(path)
        assert response.status_code == 200
        assert ADMIN_TOKEN not in response.text
        assert 'name="csrf"' in response.text
