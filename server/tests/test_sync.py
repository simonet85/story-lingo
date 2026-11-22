from __future__ import annotations

import json


def record(
    namespace: str = "reading",
    record_id: str = "sleepy-hollow/chapter-01",
    updated_at: int = 1000,
    *,
    payload=None,
    deleted: bool = False,
):
    return {
        "namespace": namespace,
        "id": record_id,
        "updatedAt": updated_at,
        "deleted": deleted,
        "payload": payload,
    }


def push(client, headers, *records):
    return client.post(
        "/v1/sync/push", json={"records": list(records)}, headers=headers
    )


def pull(client, headers, since: int = 0):
    return client.get(f"/v1/sync/pull?since={since}", headers=headers)


def test_push_and_pull_require_auth(dev_client):
    assert dev_client.post("/v1/sync/push", json={"records": []}).status_code == 401
    assert dev_client.get("/v1/sync/pull").status_code == 401


def test_push_accepts_and_pull_returns(dev_client, auth_headers):
    headers = auth_headers()
    response = push(
        dev_client,
        headers,
        record(payload={"paragraphId": "p-02", "completed": False}),
    )
    assert response.status_code == 200
    body = response.json()
    assert body["serverRevision"] == 1
    assert len(body["records"]) == 1
    winner = body["records"][0]
    assert winner["namespace"] == "reading"
    assert winner["updatedAt"] == 1000
    assert winner["payload"] == {"paragraphId": "p-02", "completed": False}

    pulled = pull(dev_client, headers)
    assert pulled.status_code == 200
    assert pulled.json()["revision"] == 1
    assert pulled.json()["records"] == body["records"]

    empty = pull(dev_client, headers, since=1)
    assert empty.json() == {"revision": 1, "records": []}


def test_older_update_is_ignored(dev_client, auth_headers):
    headers = auth_headers()
    first = push(
        dev_client, headers, record(updated_at=2000, payload={"minutes": 9})
    ).json()
    stale = push(
        dev_client, headers, record(updated_at=1000, payload={"minutes": 3})
    ).json()
    assert stale["serverRevision"] == first["serverRevision"]
    assert stale["records"][0]["updatedAt"] == 2000
    assert stale["records"][0]["payload"] == {"minutes": 9}


def test_newer_update_wins(dev_client, auth_headers):
    headers = auth_headers()
    push(dev_client, headers, record(updated_at=2000, payload={"minutes": 3}))
    newer = push(
        dev_client, headers, record(updated_at=3000, payload={"minutes": 9})
    ).json()
    assert newer["serverRevision"] == 2
    assert newer["records"][0]["payload"] == {"minutes": 9}
    pulled = pull(dev_client, headers, since=1).json()
    assert pulled["revision"] == 2
    assert len(pulled["records"]) == 1
    assert pulled["records"][0]["payload"] == {"minutes": 9}


def test_same_timestamp_is_idempotent(dev_client, auth_headers):
    headers = auth_headers()
    push(dev_client, headers, record(updated_at=2000, payload={"level": "a2"}))
    again = push(
        dev_client, headers, record(updated_at=2000, payload={"level": "b1"})
    ).json()
    assert again["serverRevision"] == 1
    assert again["records"][0]["payload"] == {"level": "a2"}


def test_tombstone_propagates_and_can_be_undone(dev_client, auth_headers):
    headers = auth_headers()
    push(
        dev_client,
        headers,
        record("words", "book/hello", 1000, payload={"word": "hello"}),
    )
    deleted = push(
        dev_client,
        headers,
        record("words", "book/hello", 2000, deleted=True),
    ).json()
    assert deleted["serverRevision"] == 2
    assert deleted["records"][0]["deleted"] is True
    assert deleted["records"][0]["payload"] is None

    pulled = pull(dev_client, headers).json()
    assert pulled["records"][0]["deleted"] is True

    restored = push(
        dev_client,
        headers,
        record("words", "book/hello", 3000, payload={"word": "hello"}),
    ).json()
    assert restored["serverRevision"] == 3
    assert restored["records"][0]["deleted"] is False
    assert restored["records"][0]["payload"] == {"word": "hello"}


def test_tombstone_with_payload_is_normalized(dev_client, auth_headers):
    headers = auth_headers()
    body = push(
        dev_client,
        headers,
        record("words", "book/hello", 1000, deleted=True, payload={"word": "x"}),
    ).json()
    assert body["records"][0]["payload"] is None


def test_batch_shares_revision(dev_client, auth_headers):
    headers = auth_headers()
    body = push(
        dev_client,
        headers,
        record("srs", "book/alpha", 1000, payload={"reviews": 1}),
        record("srs", "book/beta", 1000, payload={"reviews": 2}),
    ).json()
    assert body["serverRevision"] == 1
    assert {record["id"] for record in body["records"]} == {"book/alpha", "book/beta"}

    pulled = pull(dev_client, headers).json()
    assert {record["id"] for record in pulled["records"]} == {
        "book/alpha",
        "book/beta",
    }

    push(
        dev_client,
        headers,
        record("srs", "book/gamma", 2000, payload={"reviews": 3}),
    )
    delta = pull(dev_client, headers, since=1).json()
    assert [entry["id"] for entry in delta["records"]] == ["book/gamma"]


def test_users_are_isolated(dev_client, auth_headers):
    alice = auth_headers("alice@example.com")
    bob = auth_headers("bob@example.com")
    push(dev_client, alice, record(payload={"paragraphId": "p-02"}))
    assert pull(dev_client, bob).json() == {"revision": 0, "records": []}

    bob_push = push(dev_client, bob, record(payload={"paragraphId": "p-09"})).json()
    assert bob_push["serverRevision"] == 1
    assert pull(dev_client, alice).json()["records"][0]["payload"] == {
        "paragraphId": "p-02"
    }


def test_all_namespaces_are_accepted(dev_client, auth_headers):
    headers = auth_headers()
    namespaces = ["reading", "words", "srs", "program", "prefs"]
    records = [
        record(namespace, f"id-{index}", 1000, payload={"ok": True})
        for index, namespace in enumerate(namespaces)
    ]
    response = push(dev_client, headers, *records)
    assert response.status_code == 200
    assert len(response.json()["records"]) == len(namespaces)


def test_unknown_namespace_is_rejected(dev_client, auth_headers):
    response = push(
        dev_client,
        auth_headers(),
        record("telemetry", "event-1", 1000, payload={"name": "x"}),
    )
    assert response.status_code == 422


def test_missing_payload_is_rejected(dev_client, auth_headers):
    response = push(dev_client, auth_headers(), record(updated_at=1000))
    assert response.status_code == 422


def test_non_object_payload_is_rejected(dev_client, auth_headers):
    response = push(
        dev_client,
        auth_headers(),
        record(updated_at=1000, payload=["not", "an", "object"]),
    )
    assert response.status_code == 422


def test_too_many_records_are_rejected(dev_client, auth_headers):
    records = [
        record("reading", f"id-{index}", 1000, payload={}) for index in range(501)
    ]
    response = push(dev_client, auth_headers(), *records)
    assert response.status_code == 422


def test_oversized_payload_is_rejected(dev_client, auth_headers):
    payload = {"blob": "x" * (64 * 1024)}
    response = push(dev_client, auth_headers(), record(payload=payload))
    assert response.status_code == 422


def test_pull_since_ahead_of_revision_returns_empty(dev_client, auth_headers):
    headers = auth_headers()
    push(dev_client, headers, record(payload={"a": 1}))
    response = pull(dev_client, headers, since=999)
    assert response.status_code == 200
    assert response.json() == {"revision": 1, "records": []}


def test_payload_round_trips_unicode(dev_client, auth_headers):
    headers = auth_headers()
    payload = {"word": "éclair", "translationFr": "éclair au chocolat"}
    body = push(dev_client, headers, record("words", "x/éclair", 1000, payload=payload)).json()
    assert body["records"][0]["payload"] == payload
    raw = dev_client.get(
        "/v1/sync/pull?since=0", headers=headers
    ).content.decode("utf-8")
    assert "éclair au chocolat" in json.loads(raw)["records"][0]["payload"].values()
