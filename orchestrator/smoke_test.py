#!/usr/bin/env python3
"""Smoke test for local RP memory service."""

from __future__ import annotations

import json
import tempfile
import threading
from http.server import ThreadingHTTPServer
from pathlib import Path
from urllib.parse import urlencode
from urllib.request import Request, urlopen

from server import init_db, make_handler


def request_json(base_url: str, method: str, path: str, body: dict | None = None) -> dict:
    data = None if body is None else json.dumps(body).encode("utf-8")
    req = Request(
        base_url + path,
        data=data,
        method=method,
        headers={"Content-Type": "application/json"},
    )
    with urlopen(req, timeout=5) as response:
        return json.loads(response.read().decode("utf-8"))


def main() -> None:
    with tempfile.TemporaryDirectory() as tmp:
        db_path = Path(tmp) / "rp_memory.sqlite"
        init_db(db_path)
        server = ThreadingHTTPServer(("127.0.0.1", 0), make_handler(db_path))
        thread = threading.Thread(target=server.serve_forever, daemon=True)
        thread.start()
        base_url = f"http://127.0.0.1:{server.server_port}"

        health = request_json(base_url, "GET", "/health")
        event = request_json(
            base_url,
            "POST",
            "/events",
            {"type": "scene", "actor": "Narrator", "content": "Moon gate opens.", "tags": ["omen"]},
        )
        summary = request_json(
            base_url,
            "POST",
            "/summaries",
            {"scope": "world", "title": "Opening", "summary": "Moon gate now active."},
        )
        cue = request_json(
            base_url,
            "POST",
            "/scene/visual-cue",
            {"scene_id": "intro", "cue": "silver moon gate", "style": "painterly"},
        )
        query = urlencode({"q": "Moon"})
        search = request_json(base_url, "GET", f"/memory/search?{query}")
        state = request_json(base_url, "GET", "/state/world")

        assert health["ok"]
        assert event["id"] == 1
        assert summary["id"] == 1
        assert cue["id"] == 1
        assert len(search["events"]) == 1
        assert len(search["summaries"]) == 1
        assert state["stats"] == {"events": 1, "summaries": 1, "visual_cues": 1}

        server.shutdown()
        server.server_close()
        thread.join(timeout=5)
        print("smoke ok")


if __name__ == "__main__":
    main()
