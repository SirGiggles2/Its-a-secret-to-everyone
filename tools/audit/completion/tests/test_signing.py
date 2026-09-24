from __future__ import annotations

from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[4]
sys.path.insert(0, str(ROOT / "tools" / "audit" / "completion"))

import signing


PAYLOAD = {
    "command": "python tools/parity/run.py",
    "verdict_line": "171/171 PASS",
    "inputs": [{"path": "a.c", "sha256": "ab" * 32}],
}


def test_sign_is_deterministic(tmp_path: Path) -> None:
    key = signing.load_or_create_key(tmp_path / ".k")
    assert signing.sign(key, PAYLOAD) == signing.sign(key, PAYLOAD)


def test_sign_is_hex_sha256_length(tmp_path: Path) -> None:
    key = signing.load_or_create_key(tmp_path / ".k")
    assert len(signing.sign(key, PAYLOAD)) == 64


def test_verify_accepts_own_signature(tmp_path: Path) -> None:
    key = signing.load_or_create_key(tmp_path / ".k")
    assert signing.verify(key, PAYLOAD, signing.sign(key, PAYLOAD))


def test_verify_rejects_tampered_input(tmp_path: Path) -> None:
    key = signing.load_or_create_key(tmp_path / ".k")
    sig = signing.sign(key, PAYLOAD)
    tampered = {**PAYLOAD, "inputs": [{"path": "a.c", "sha256": "cd" * 32}]}
    assert not signing.verify(key, tampered, sig)


def test_verify_rejects_dropped_input(tmp_path: Path) -> None:
    """Removing a dependency must invalidate — this is finding A."""
    key = signing.load_or_create_key(tmp_path / ".k")
    sig = signing.sign(key, PAYLOAD)
    assert not signing.verify(key, {**PAYLOAD, "inputs": []}, sig)


def test_key_persists(tmp_path: Path) -> None:
    p = tmp_path / ".k"
    assert signing.load_or_create_key(p) == signing.load_or_create_key(p)


def test_key_ignores_field_order(tmp_path: Path) -> None:
    key = signing.load_or_create_key(tmp_path / ".k")
    reordered = {
        "inputs": PAYLOAD["inputs"],
        "verdict_line": PAYLOAD["verdict_line"],
        "command": PAYLOAD["command"],
    }
    assert signing.verify(key, reordered, signing.sign(key, PAYLOAD))
