from __future__ import annotations

import json
import threading
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Dict, Optional

_STORE_PATH = Path(__file__).with_name("session_store.json")
_LOCK = threading.Lock()


def _utc_now() -> datetime:
    return datetime.now(timezone.utc)


def _today_str(now: Optional[datetime] = None) -> str:
    return (now or _utc_now()).date().isoformat()


def _load_store() -> Dict[str, Any]:
    if not _STORE_PATH.exists():
        return {"users": {}}
    try:
        return json.loads(_STORE_PATH.read_text())
    except json.JSONDecodeError:
        return {"users": {}}


def _save_store(store: Dict[str, Any]) -> None:
    _STORE_PATH.write_text(json.dumps(store, indent=2, sort_keys=True))


def _ensure_today_session(store: Dict[str, Any], user_id: str, now: Optional[datetime] = None) -> Dict[str, Any]:
    today = _today_str(now)
    users = store.setdefault("users", {})
    session = users.get(user_id)

    if not session or session.get("date") != today:
        session = {
            "date": today,
            "startedAt": None,
            "endedAt": None,
            "climbs": [],
        }
        users[user_id] = session

    return session


def start_today_session(user_id: str) -> Dict[str, Any]:
    now = _utc_now()
    with _LOCK:
        store = _load_store()
        session = _ensure_today_session(store, user_id, now)
        if session["startedAt"] is None:
            session["startedAt"] = now.isoformat()
            session["endedAt"] = None
        _save_store(store)
        return session


def end_today_session(user_id: str) -> Dict[str, Any]:
    now = _utc_now()
    with _LOCK:
        store = _load_store()
        session = _ensure_today_session(store, user_id, now)
        if session["startedAt"] is None:
            session["startedAt"] = now.isoformat()
        session["endedAt"] = now.isoformat()
        _save_store(store)
        return session


def add_climb_event(
    user_id: str,
    status: str,
    attempts: int,
    duration_seconds: int,
) -> Dict[str, Any]:
    now = _utc_now()
    with _LOCK:
        store = _load_store()
        session = _ensure_today_session(store, user_id, now)
        if session["startedAt"] is None:
            session["startedAt"] = now.isoformat()
        session["endedAt"] = None
        session["climbs"].append(
            {
                "timestamp": now.isoformat(),
                "status": status,
                "attempts": attempts,
                "durationSeconds": duration_seconds,
            }
        )
        _save_store(store)
        return session


def get_today_session_stats(user_id: str) -> Dict[str, Any]:
    now = _utc_now()
    with _LOCK:
        store = _load_store()
        session = _ensure_today_session(store, user_id, now)
        started_at = _parse_datetime(session.get("startedAt"))
        ended_at = _parse_datetime(session.get("endedAt"))
        elapsed_seconds = 0
        if started_at:
            end_time = ended_at or now
            elapsed_seconds = max(0, int((end_time - started_at).total_seconds()))

        sends = 0
        for climb in session.get("climbs", []):
            if climb.get("status") in {"COMPLETED", "FLASH", "ONSIGHT"}:
                sends += 1

        return {
            "climbs": len(session.get("climbs", [])),
            "sends": sends,
            "elapsedSeconds": elapsed_seconds,
            "isActive": started_at is not None and ended_at is None,
        }


def _parse_datetime(value: Optional[str]) -> Optional[datetime]:
    if not value:
        return None
    try:
        return datetime.fromisoformat(value)
    except ValueError:
        return None
