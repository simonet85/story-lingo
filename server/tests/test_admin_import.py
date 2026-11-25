from __future__ import annotations

import io
import re
import zipfile
from dataclasses import replace
from pathlib import Path

from fastapi.testclient import TestClient

from server.app.main import create_app
from server.tests.support import ADMIN_TOKEN


def zip_bytes(source: Path, prefix: str = "") -> bytes:
    buffer = io.BytesIO()
    with zipfile.ZipFile(buffer, "w", zipfile.ZIP_DEFLATED) as archive:
        for path in sorted(source.rglob("*")):
            if path.is_file():
                archive.write(
                    path, f"{prefix}{path.relative_to(source).as_posix()}"
                )
    return buffer.getvalue()


def upload(
    client: TestClient,
    csrf: str,
    payload: bytes,
    *,
    access: str = "keep",
    filename: str = "pack.zip",
):
    return client.post(
        "/admin/import",
        data={"csrf": csrf, "access": access},
        files={"file": (filename, payload, "application/zip")},
        follow_redirects=False,
    )


def csrf_from(client: TestClient) -> str:
    page = client.get("/admin/books")
    match = re.search(r'name="csrf" value="([0-9a-f]{32})"', page.text)
    assert match is not None, page.text
    return match.group(1)


def test_import_publishes_a_pack(
    admin_client, admin_csrf, admin_settings, make_pack
):
    source = make_pack("import-source", book_id="imported-book")
    response = upload(
        admin_client, admin_csrf, zip_bytes(source), access="free"
    )
    assert response.status_code == 303, response.text
    assert response.headers["location"].startswith(
        "/admin/books?notice=imported"
    )
    manifest = admin_client.get("/v1/books/imported-book")
    assert manifest.status_code == 200
    assert manifest.json()["isFree"] is True
    folder = Path(admin_settings.content_dir) / "imported-book"
    assert (folder / "manifest.json").is_file()
    assert (folder / "audio" / "chapter-01.mp3").is_file()


def test_import_accepts_a_single_root_folder(
    admin_client, admin_csrf, make_pack
):
    source = make_pack("nested-source", book_id="nested-book")
    response = upload(
        admin_client, admin_csrf, zip_bytes(source, prefix="nested/")
    )
    assert response.status_code == 303, response.text
    manifest = admin_client.get("/v1/books/nested-book")
    assert manifest.status_code == 200
    assert manifest.json()["isFree"] is False


def test_import_rejects_an_archive_without_manifest(
    admin_client, admin_csrf
):
    buffer = io.BytesIO()
    with zipfile.ZipFile(buffer, "w") as archive:
        archive.writestr("readme.txt", "pas de manifeste")
    response = upload(admin_client, admin_csrf, buffer.getvalue())
    assert response.status_code == 400
    assert "manifest.json introuvable" in response.text


def test_import_rejects_zip_slip_entries(admin_client, admin_csrf):
    buffer = io.BytesIO()
    with zipfile.ZipFile(buffer, "w") as archive:
        archive.writestr("../evil.txt", b"nope")
    response = upload(admin_client, admin_csrf, buffer.getvalue())
    assert response.status_code == 400
    assert "Chemin non autorisé" in response.text


def test_import_rejects_a_corrupted_archive(admin_client, admin_csrf):
    response = upload(admin_client, admin_csrf, b"not a zip")
    assert response.status_code == 400
    assert "Fichier ZIP invalide." in response.text


def test_import_rejects_a_non_zip_filename(admin_client, admin_csrf, make_pack):
    source = make_pack("tar-source", book_id="tar-book")
    response = upload(
        admin_client,
        admin_csrf,
        zip_bytes(source),
        filename="pack.tar",
    )
    assert response.status_code == 400
    assert "archive .zip" in response.text


def test_import_rejects_an_invalid_pack(
    admin_client, admin_csrf, make_pack
):
    source = make_pack(
        "bad-source",
        book_id="bad-book",
        manifest_overrides={"title": ""},
    )
    response = upload(admin_client, admin_csrf, zip_bytes(source))
    assert response.status_code == 400
    assert admin_client.get("/v1/books/bad-book").status_code == 404


def test_import_preserves_or_overrides_the_access_flag(
    admin_client, admin_csrf, make_pack
):
    source = make_pack("flag-source", book_id="flag-book")
    payload = zip_bytes(source)

    assert upload(admin_client, admin_csrf, payload, access="free").status_code == 303
    assert admin_client.get("/v1/books/flag-book").json()["isFree"] is True

    assert upload(admin_client, admin_csrf, payload, access="keep").status_code == 303
    assert admin_client.get("/v1/books/flag-book").json()["isFree"] is True

    assert upload(admin_client, admin_csrf, payload, access="paid").status_code == 303
    assert admin_client.get("/v1/books/flag-book").json()["isFree"] is False

    assert upload(admin_client, admin_csrf, payload, access="keep").status_code == 303
    assert admin_client.get("/v1/books/flag-book").json()["isFree"] is False


def test_import_rejects_an_unknown_access_value(
    admin_client, admin_csrf, make_pack
):
    source = make_pack("choice-source", book_id="choice-book")
    response = upload(
        admin_client, admin_csrf, zip_bytes(source), access="anything"
    )
    assert response.status_code == 400
    assert "Choix d&#39;accès invalide." in response.text


def test_import_rejects_an_oversized_archive(
    admin_settings, make_pack
):
    tiny = replace(admin_settings, admin_max_upload_bytes=200)
    app = create_app(tiny)
    source = make_pack("big-source", book_id="big-book")
    payload = zip_bytes(source)
    assert len(payload) > tiny.admin_max_upload_bytes
    with TestClient(app) as client:
        login = client.post(
            "/admin/login",
            data={"password": ADMIN_TOKEN},
            follow_redirects=False,
        )
        assert login.status_code == 303
        response = upload(client, csrf_from(client), payload)
        assert response.status_code == 413
        assert "trop volumineuse" in response.text
        assert client.get("/v1/books/big-book").status_code == 404
