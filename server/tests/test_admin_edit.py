from __future__ import annotations

import hashlib

from server.app.models import Book


def edit_payload(csrf: str, **overrides) -> dict[str, str]:
    data = {
        "csrf": csrf,
        "title": "Demo Book Revised",
        "title_fr": "Livre révisé",
        "author": "Auteur révisé",
        "level": "B1",
        "description_fr": "Description révisée.",
        "access": "paid",
    }
    data.update(overrides)
    return data


def edit(client, csrf: str, book_id: str = "demo-book", **overrides):
    return client.post(
        f"/admin/books/{book_id}/edit",
        data=edit_payload(csrf, **overrides),
        follow_redirects=False,
    )


def assert_descriptor_matches_files(client, book_id: str) -> None:
    descriptor = client.get(f"/v1/books/{book_id}/download").json()
    assert descriptor["files"]
    for item in descriptor["files"]:
        response = client.get(item["downloadUrl"])
        assert response.status_code == 200, item
        assert len(response.content) == item["sizeBytes"], item
        assert (
            hashlib.sha256(response.content).hexdigest() == item["sha256"]
        ), item


def test_edit_form_is_prefilled(admin_client, admin_csrf):
    response = admin_client.get("/admin/books/demo-book/edit")
    assert response.status_code == 200
    assert 'value="Demo Book"' in response.text
    assert 'value="Livre de démonstration"' in response.text
    assert 'value="Storylingo"' in response.text
    assert 'value="a2"' in response.text
    assert 'name="access" value="free" checked' in response.text


def test_edit_updates_database_manifest_and_catalogue(
    admin_client, admin_csrf, admin_app
):
    response = edit(admin_client, admin_csrf)
    assert response.status_code == 303, response.text
    assert response.headers["location"].startswith(
        "/admin/books?notice=updated"
    )

    catalogue = admin_client.get("/v1/catalogue").json()
    entry = next(
        book for book in catalogue["books"] if book["id"] == "demo-book"
    )
    assert entry["title"] == "Demo Book Revised"
    assert entry["titleFr"] == "Livre révisé"
    assert entry["author"] == "Auteur révisé"
    assert entry["level"] == "b1"
    assert entry["descriptionFr"] == "Description révisée."
    assert entry["isFree"] is False

    manifest = admin_client.get("/v1/books/demo-book").json()
    assert manifest["title"] == "Demo Book Revised"
    assert manifest["titleFr"] == "Livre révisé"
    assert manifest["isFree"] is False

    detail = admin_client.get("/admin/books/demo-book")
    assert "Livre révisé" in detail.text
    assert "Description révisée." in detail.text
    assert "Payant" in detail.text

    with admin_app.state.session_factory() as session:
        book = session.get(Book, "demo-book")
        assert book is not None
        assert book.title == "Demo Book Revised"


def test_edit_rebuilds_the_download_descriptor(admin_client, admin_csrf):
    assert edit(admin_client, admin_csrf).status_code == 303
    assert_descriptor_matches_files(admin_client, "demo-book")


def test_edit_rejects_an_empty_title(admin_client, admin_csrf):
    response = edit(admin_client, admin_csrf, title="   ")
    assert response.status_code == 400
    assert "Le titre est obligatoire." in response.text
    catalogue = admin_client.get("/v1/catalogue").json()
    entry = next(
        book for book in catalogue["books"] if book["id"] == "demo-book"
    )
    assert entry["title"] == "Demo Book"


def test_edit_rejects_an_overlong_description(admin_client, admin_csrf):
    response = edit(admin_client, admin_csrf, description_fr="x" * 1001)
    assert response.status_code == 400
    assert "ne doit pas dépasser 1000 caractères" in response.text


def test_edit_rejects_an_invalid_access_value(admin_client, admin_csrf):
    response = edit(admin_client, admin_csrf, access="maybe")
    assert response.status_code == 400
    assert "Choix d&#39;accès invalide." in response.text


def test_edit_rejects_an_invalid_level(admin_client, admin_csrf):
    response = edit(admin_client, admin_csrf, level="c9")
    assert response.status_code == 400
    assert "Niveau invalide" in response.text
    catalogue = admin_client.get("/v1/catalogue").json()
    entry = next(
        book for book in catalogue["books"] if book["id"] == "demo-book"
    )
    assert entry["level"] == "a2"


def test_edit_returns_404_for_an_unknown_book(admin_client, admin_csrf):
    response = edit(admin_client, admin_csrf, book_id="missing-book")
    assert response.status_code == 404


def test_edit_requires_csrf(admin_client, admin_login):
    admin_login()
    response = admin_client.post(
        "/admin/books/demo-book/edit",
        data=edit_payload("0" * 32),
        follow_redirects=False,
    )
    assert response.status_code == 403


def test_edit_requires_a_session(admin_client):
    response = admin_client.post(
        "/admin/books/demo-book/edit",
        data=edit_payload("0" * 32),
        follow_redirects=False,
    )
    assert response.status_code == 303
    assert response.headers["location"] == "/admin/login"
