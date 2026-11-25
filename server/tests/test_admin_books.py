from __future__ import annotations

from pathlib import Path

from server.app.packs import publish_pack
from server.tests.support import build_pack


def test_books_page_lists_published_books(admin_client, admin_csrf):
    response = admin_client.get("/admin/books")
    assert response.status_code == 200
    assert "demo-book" in response.text
    assert "Demo Book" in response.text
    assert "Livre de démonstration" in response.text
    assert "Gratuit" in response.text
    assert "/admin/books/demo-book" in response.text


def test_book_detail_shows_metadata_and_chapters(admin_client, admin_csrf):
    response = admin_client.get("/admin/books/demo-book")
    assert response.status_code == 200
    assert "Demo Book" in response.text
    assert "Storylingo" in response.text
    assert "chapter-01" in response.text
    assert "Un matin" in response.text
    assert "Modifier" in response.text
    assert 'name="confirm"' in response.text


def test_book_detail_returns_404_for_an_unknown_book(admin_client, admin_csrf):
    assert admin_client.get("/admin/books/missing-book").status_code == 404


def test_books_page_shows_paid_badge(
    admin_client, admin_csrf, admin_app, admin_settings, tmp_path: Path
):
    source = build_pack(tmp_path / "paid-source", book_id="paid-book")
    with admin_app.state.session_factory() as session:
        publish_pack(
            source, admin_settings.content_dir, session, is_free=False
        )
    response = admin_client.get("/admin/books")
    assert "paid-book" in response.text
    assert "Payant" in response.text


def test_books_page_escapes_manifest_values(
    admin_client, admin_csrf, admin_app, admin_settings, tmp_path: Path
):
    source = build_pack(
        tmp_path / "xss-source",
        book_id="xss-book",
        manifest_overrides={
            "title": '<script>alert("x")</script>',
            "titleFr": "<b>injecté</b>",
        },
    )
    with admin_app.state.session_factory() as session:
        publish_pack(
            source, admin_settings.content_dir, session, is_free=False
        )
    response = admin_client.get("/admin/books")
    assert response.status_code == 200
    assert "&lt;script&gt;alert(&#34;x&#34;)&lt;/script&gt;" in response.text
    assert "<script>alert" not in response.text
    assert "&lt;b&gt;injecté&lt;/b&gt;" in response.text
