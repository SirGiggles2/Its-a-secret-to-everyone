"""signing.py — run signatures for evidence blocks (spec §4.1 step 3).

NOT a security boundary: anyone with repo write access holds the key.
It is a discipline boundary — fabricating evidence must require
deliberately re-running the producer, not a moment of optimism.
"""
from __future__ import annotations

import hashlib
import hmac
import json
import secrets
from pathlib import Path

SIGNED_FIELDS = ("command", "verdict_line", "inputs")


def load_or_create_key(path: Path) -> bytes:
    """Read the per-repo HMAC key, generating one on first use."""
    if path.exists():
        return path.read_bytes()
    path.parent.mkdir(parents=True, exist_ok=True)
    key = secrets.token_bytes(32)
    path.write_bytes(key)
    return key


def canonical(payload: dict) -> bytes:
    """Field-order-independent, whitespace-stable serialization."""
    subset = {k: payload.get(k) for k in SIGNED_FIELDS}
    return json.dumps(
        subset, sort_keys=True, separators=(",", ":"), ensure_ascii=False
    ).encode("utf-8")


def sign(key: bytes, payload: dict) -> str:
    return hmac.new(key, canonical(payload), hashlib.sha256).hexdigest()


def verify(key: bytes, payload: dict, signature: str) -> bool:
    return hmac.compare_digest(sign(key, payload), signature or "")
