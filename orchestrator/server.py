#!/usr/bin/env python3
"""Local RP memory HTTP service backed by SQLite."""

from __future__ import annotations

import argparse
import json
import os
import sqlite3
from contextlib import contextmanager
from datetime import datetime, timezone
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from typing import Any
from urllib.parse import parse_qs, urlparse


ROOT = Path(__file__).resolve().parents[1]
DEFAULT_DB = ROOT / "data" / "rp_memory.sqlite"


def utc_now() -> str:
    return datetime.now(timezone.utc).isoformat(timespec="seconds")


def db_connect(db_path: Path) -> sqlite3.Connection:
    db_path.parent.mkdir(parents=True, exist_ok=True)
    conn = sqlite3.connect(db_path)
    conn.row_factory = sqlite3.Row
    conn.execute("PRAGMA journal_mode=WAL")
    conn.execute("PRAGMA foreign_keys=ON")
    return conn


@contextmanager
def open_db(db_path: Path):
    conn = db_connect(db_path)
    try:
        yield conn
        conn.commit()
    finally:
        conn.close()


def init_db(db_path: Path) -> None:
    with open_db(db_path) as conn:
        conn.executescript(
            """
            CREATE TABLE IF NOT EXISTS events (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                created_at TEXT NOT NULL,
                event_type TEXT NOT NULL,
                actor TEXT,
                scene_id TEXT,
                content TEXT NOT NULL,
                tags TEXT NOT NULL DEFAULT '[]',
                payload TEXT NOT NULL DEFAULT '{}'
            );

            CREATE TABLE IF NOT EXISTS summaries (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                created_at TEXT NOT NULL,
                scope TEXT NOT NULL,
                title TEXT,
                content TEXT NOT NULL,
                payload TEXT NOT NULL DEFAULT '{}'
            );

            CREATE TABLE IF NOT EXISTS visual_cues (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                created_at TEXT NOT NULL,
                scene_id TEXT,
                cue TEXT NOT NULL,
                prompt TEXT,
                style TEXT,
                payload TEXT NOT NULL DEFAULT '{}'
            );

            CREATE INDEX IF NOT EXISTS idx_events_created_at ON events(created_at);
            CREATE INDEX IF NOT EXISTS idx_events_scene_id ON events(scene_id);
            CREATE INDEX IF NOT EXISTS idx_summaries_scope_created_at
                ON summaries(scope, created_at);
            CREATE INDEX IF NOT EXISTS idx_visual_cues_scene_id
                ON visual_cues(scene_id);
            """
        )


def json_dumps(value: Any) -> str:
    return json.dumps(value, ensure_ascii=True, sort_keys=True)


def row_to_dict(row: sqlite3.Row) -> dict[str, Any]:
    out = dict(row)
    for key in ("tags", "payload"):
        if key in out and isinstance(out[key], str):
            try:
                out[key] = json.loads(out[key])
            except json.JSONDecodeError:
                pass
    return out


def normalize_tags(value: Any) -> list[str]:
    if value is None:
        return []
    if isinstance(value, str):
        return [part.strip() for part in value.split(",") if part.strip()]
    if isinstance(value, list):
        return [str(part) for part in value]
    return [str(value)]


def content_from(data: dict[str, Any], *keys: str) -> str:
    for key in keys:
        value = data.get(key)
        if value is not None:
            return value if isinstance(value, str) else json_dumps(value)
    return json_dumps(data)


class MemoryHandler(BaseHTTPRequestHandler):
    db_path = DEFAULT_DB
    server_version = "WorldBuildingMemory/0.1"

    def do_OPTIONS(self) -> None:
        self.send_response(204)
        self.send_common_headers()
        self.end_headers()

    def do_GET(self) -> None:
        parsed = urlparse(self.path)
        if parsed.path in ("/health", "/healthz"):
            self.write_json({"ok": True, "db": str(self.db_path)})
            return
        if parsed.path == "/memory/search":
            query = parse_qs(parsed.query).get("q", [""])[0].strip()
            limit = self.parse_limit(parsed.query)
            self.write_json(search_memory(self.db_path, query, limit))
            return
        if parsed.path == "/state/world":
            self.write_json(world_state(self.db_path))
            return
        self.write_error(404, "not_found")

    def do_POST(self) -> None:
        parsed = urlparse(self.path)
        try:
            data = self.read_json()
        except ValueError as exc:
            self.write_error(400, "bad_json", str(exc))
            return

        if parsed.path == "/events":
            self.write_json(create_event(self.db_path, data), status=201)
            return
        if parsed.path == "/summaries":
            self.write_json(create_summary(self.db_path, data), status=201)
            return
        if parsed.path == "/scene/visual-cue":
            self.write_json(create_visual_cue(self.db_path, data), status=201)
            return
        self.write_error(404, "not_found")

    def read_json(self) -> dict[str, Any]:
        raw_len = self.headers.get("Content-Length", "0")
        try:
            length = int(raw_len)
        except ValueError as exc:
            raise ValueError("Content-Length must be integer") from exc
        body = self.rfile.read(length) if length > 0 else b"{}"
        try:
            data = json.loads(body.decode("utf-8"))
        except json.JSONDecodeError as exc:
            raise ValueError(exc.msg) from exc
        if not isinstance(data, dict):
            raise ValueError("JSON body must be object")
        return data

    def parse_limit(self, query: str) -> int:
        raw = parse_qs(query).get("limit", ["25"])[0]
        try:
            return min(max(int(raw), 1), 100)
        except ValueError:
            return 25

    def write_json(self, data: dict[str, Any], status: int = 200) -> None:
        body = json.dumps(data, ensure_ascii=True, indent=2).encode("utf-8")
        self.send_response(status)
        self.send_common_headers()
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def write_error(self, status: int, code: str, detail: str | None = None) -> None:
        body: dict[str, Any] = {"ok": False, "error": code}
        if detail:
            body["detail"] = detail
        self.write_json(body, status=status)

    def send_common_headers(self) -> None:
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Access-Control-Allow-Methods", "GET, POST, OPTIONS")
        self.send_header("Access-Control-Allow-Headers", "Content-Type")

    def log_message(self, fmt: str, *args: Any) -> None:
        print("%s - %s" % (self.address_string(), fmt % args))


def create_event(db_path: Path, data: dict[str, Any]) -> dict[str, Any]:
    created_at = str(data.get("created_at") or utc_now())
    event_type = str(data.get("event_type") or data.get("type") or "event")
    content = content_from(data, "content", "text", "description")
    tags = normalize_tags(data.get("tags"))
    payload = {k: v for k, v in data.items() if k not in {
        "created_at", "event_type", "type", "content", "text", "description",
        "actor", "scene_id", "tags",
    }}
    with open_db(db_path) as conn:
        cur = conn.execute(
            """
            INSERT INTO events
                (created_at, event_type, actor, scene_id, content, tags, payload)
            VALUES (?, ?, ?, ?, ?, ?, ?)
            """,
            (
                created_at,
                event_type,
                data.get("actor"),
                data.get("scene_id"),
                content,
                json_dumps(tags),
                json_dumps(payload),
            ),
        )
        event_id = int(cur.lastrowid)
    return {"ok": True, "id": event_id, "created_at": created_at}


def create_summary(db_path: Path, data: dict[str, Any]) -> dict[str, Any]:
    created_at = str(data.get("created_at") or utc_now())
    scope = str(data.get("scope") or "world")
    content = content_from(data, "content", "summary", "text")
    payload = {k: v for k, v in data.items() if k not in {
        "created_at", "scope", "title", "content", "summary", "text",
    }}
    with open_db(db_path) as conn:
        cur = conn.execute(
            """
            INSERT INTO summaries (created_at, scope, title, content, payload)
            VALUES (?, ?, ?, ?, ?)
            """,
            (
                created_at,
                scope,
                data.get("title"),
                content,
                json_dumps(payload),
            ),
        )
        summary_id = int(cur.lastrowid)
    return {"ok": True, "id": summary_id, "created_at": created_at}


def create_visual_cue(db_path: Path, data: dict[str, Any]) -> dict[str, Any]:
    created_at = str(data.get("created_at") or utc_now())
    cue = content_from(data, "cue", "content", "text")
    payload = {k: v for k, v in data.items() if k not in {
        "created_at", "scene_id", "cue", "content", "text", "prompt", "style",
    }}
    with open_db(db_path) as conn:
        cur = conn.execute(
            """
            INSERT INTO visual_cues
                (created_at, scene_id, cue, prompt, style, payload)
            VALUES (?, ?, ?, ?, ?, ?)
            """,
            (
                created_at,
                data.get("scene_id"),
                cue,
                data.get("prompt"),
                data.get("style"),
                json_dumps(payload),
            ),
        )
        cue_id = int(cur.lastrowid)
    return {"ok": True, "id": cue_id, "created_at": created_at}


def search_memory(db_path: Path, query: str, limit: int) -> dict[str, Any]:
    if not query:
        return {"ok": True, "query": query, "events": [], "summaries": []}
    pattern = f"%{query}%"
    with open_db(db_path) as conn:
        events = [
            row_to_dict(row)
            for row in conn.execute(
                """
                SELECT id, created_at, event_type, actor, scene_id, content, tags, payload
                FROM events
                WHERE content LIKE ? OR payload LIKE ? OR tags LIKE ?
                ORDER BY created_at DESC, id DESC
                LIMIT ?
                """,
                (pattern, pattern, pattern, limit),
            )
        ]
        summaries = [
            row_to_dict(row)
            for row in conn.execute(
                """
                SELECT id, created_at, scope, title, content, payload
                FROM summaries
                WHERE content LIKE ? OR title LIKE ? OR payload LIKE ?
                ORDER BY created_at DESC, id DESC
                LIMIT ?
                """,
                (pattern, pattern, pattern, limit),
            )
        ]
    return {"ok": True, "query": query, "events": events, "summaries": summaries}


def world_state(db_path: Path) -> dict[str, Any]:
    with open_db(db_path) as conn:
        summaries = [
            row_to_dict(row)
            for row in conn.execute(
                """
                SELECT id, created_at, scope, title, content, payload
                FROM summaries
                ORDER BY created_at DESC, id DESC
                LIMIT 20
                """
            )
        ]
        recent_events = [
            row_to_dict(row)
            for row in conn.execute(
                """
                SELECT id, created_at, event_type, actor, scene_id, content, tags, payload
                FROM events
                ORDER BY created_at DESC, id DESC
                LIMIT 25
                """
            )
        ]
        recent_visual_cues = [
            row_to_dict(row)
            for row in conn.execute(
                """
                SELECT id, created_at, scene_id, cue, prompt, style, payload
                FROM visual_cues
                ORDER BY created_at DESC, id DESC
                LIMIT 10
                """
            )
        ]
        stats = {
            "events": conn.execute("SELECT COUNT(*) FROM events").fetchone()[0],
            "summaries": conn.execute("SELECT COUNT(*) FROM summaries").fetchone()[0],
            "visual_cues": conn.execute("SELECT COUNT(*) FROM visual_cues").fetchone()[0],
        }
    return {
        "ok": True,
        "stats": stats,
        "summaries": summaries,
        "recent_events": recent_events,
        "recent_visual_cues": recent_visual_cues,
    }


def make_handler(db_path: Path) -> type[MemoryHandler]:
    class ConfiguredMemoryHandler(MemoryHandler):
        pass

    ConfiguredMemoryHandler.db_path = db_path
    return ConfiguredMemoryHandler


def run(host: str, port: int, db_path: Path) -> None:
    init_db(db_path)
    server = ThreadingHTTPServer((host, port), make_handler(db_path))
    print(f"Memory service listening on http://{host}:{port}")
    print(f"SQLite DB: {db_path}")
    server.serve_forever()


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--host", default=os.environ.get("RP_MEMORY_HOST", "127.0.0.1"))
    parser.add_argument("--port", type=int, default=int(os.environ.get("RP_MEMORY_PORT", "8001")))
    parser.add_argument(
        "--db",
        type=Path,
        default=Path(os.environ.get("RP_MEMORY_DB", DEFAULT_DB)),
        help="SQLite DB path. Default: data/rp_memory.sqlite",
    )
    return parser.parse_args()


if __name__ == "__main__":
    args = parse_args()
    run(args.host, args.port, args.db.resolve())
