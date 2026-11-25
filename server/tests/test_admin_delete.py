from __future__ import annotations

import shutil
from pathlib import Path

from server.app.models import Book


def delete(
    client,
    csrf: str,
    book_id: str = "demo-book",
    confirm: str | None = None,
):
    return client.post(
        f"/admin/books/{book_id}/delete",
        data={"csrf": csrf, "confirm": book_id if confirm is None else confirm},
        follow_redirects=False,
    )


def test_delete_requires_the_exact_identifier(
    admin_client, admin_csrf, admin_settings
):
    response = delete(admin_client, admin_csrf, confirm="demo")
    assert response.status_code == 400
    assert "Saisissez l&#39;identifiant exact" in response.text
    catalogue = admin_client.get("/v1/catalogue").json()
    assert any(book["id"] == "demo-book" for book in catalogue["books"])
    assert (Path(admin_settings.content_dir) / "demo-book").is_dir()


def test_delete_archives_the_pack_and_removes_the_book(
    admin_client, admin_csrf, admin_settings, admin_app
):
    response = delete(admin_client, admin_csrf)
    assert response.status_code == 303, response.text
    assert response.headers["location"].startswith(
        "/admin/books?notice=deleted"
    )

    catalogue = admin_client.get("/v1/catalogue").json()
    assert all(book["id"] != "demo-book" for book in catalogue["books"])
    assert admin_client.get("/v1/books/demo-book").status_code == 404
    assert "demo-book" not in admin_client.get("/admin/books").text

    with admin_app.state.session_factory() as session:
        assert session.get(Book, "demo-book") is None

    content_dir = Path(admin_settings.content_dir)
    assert not (content_dir / "demo-book").exists()
    archives = list((content_dir / ".deleted").iterdir())
    assert len(archives) == 1
    archived = archives[0]
    assert archived.name.startswith("demo-book-")
    assert (archived / "manifest.json").is_file()
    assert (archived / "audio" / "chapter-01.mp3").is_file()


def test_delete_works_when_the_pack_folder_is_missing(
    admin_client, admin_csrf, admin_settings
):
    shutil.rmtree(Path(admin_settings.content_dir) / "demo-book")
    response = delete(admin_client, admin_csrf)
    assert response.status_code == 303
    assert admin_client.get("/v1/books/demo-book").status_code == 404


def test_delete_returns_404_for_an_unknown_book(admin_client, admin_csrf):
    assert delete(admin_client, admin_csrf, "missing-book").status_code == 404


def test_delete_requires_csrf(admin_client, admin_login):
    admin_login()
    response = admin_client.post(
        "/admin/books/demo-book/delete",
        data={"confirm": "demo-book"},
        follow_redirects=False,
    )
    assert response.status_code == 403


def test_delete_requires_a_session(admin_client):
    response = admin_client.post(
        "/admin/books/demo-book/delete",
        data={"csrf": "0" * 32, "confirm": "demo-book"},
        follow_redirects=False,
    )
    assert response.status_code == 303
    assert response.headers["location"] == "/admin/login"
