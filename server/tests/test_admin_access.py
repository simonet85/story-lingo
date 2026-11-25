from __future__ import annotations


def catalogue_entry(client, book_id: str) -> dict:
    catalogue = client.get("/v1/catalogue").json()
    return next(book for book in catalogue["books"] if book["id"] == book_id)


def set_access(client, csrf: str, book_id: str, access: str):
    return client.post(
        f"/admin/books/{book_id}/access",
        data={"csrf": csrf, "access": access},
        follow_redirects=False,
    )


def test_toggle_free_book_to_paid(admin_client, admin_csrf):
    response = set_access(admin_client, admin_csrf, "demo-book", "paid")
    assert response.status_code == 303
    assert response.headers["location"].startswith(
        "/admin/books?notice=access"
    )
    assert catalogue_entry(admin_client, "demo-book")["isFree"] is False
    manifest = admin_client.get("/v1/books/demo-book").json()
    assert manifest["isFree"] is False


def test_toggle_paid_book_back_to_free(admin_client, admin_csrf):
    assert set_access(
        admin_client, admin_csrf, "demo-book", "paid"
    ).status_code == 303
    assert set_access(
        admin_client, admin_csrf, "demo-book", "free"
    ).status_code == 303
    assert catalogue_entry(admin_client, "demo-book")["isFree"] is True
    assert admin_client.get("/v1/books/demo-book").json()["isFree"] is True


def test_toggle_rejects_an_invalid_value(admin_client, admin_csrf):
    response = set_access(admin_client, admin_csrf, "demo-book", "maybe")
    assert response.status_code == 400


def test_toggle_rejects_an_unknown_book(admin_client, admin_csrf):
    response = set_access(admin_client, admin_csrf, "missing-book", "paid")
    assert response.status_code == 404


def test_toggle_requires_csrf(admin_client, admin_login):
    admin_login()
    response = admin_client.post(
        "/admin/books/demo-book/access",
        data={"access": "paid"},
        follow_redirects=False,
    )
    assert response.status_code == 403


def test_toggle_requires_a_session(admin_client):
    response = admin_client.post(
        "/admin/books/demo-book/access",
        data={"csrf": "0" * 32, "access": "paid"},
        follow_redirects=False,
    )
    assert response.status_code == 303
    assert response.headers["location"] == "/admin/login"
