"""Shared helpers for S0 audit probes."""

from __future__ import annotations

import hashlib
import os
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[2]
SRC = REPO_ROOT / "src"
DOCS_AUDIT = REPO_ROOT / "docs" / "audit"
TOOLS_PROBES = REPO_ROOT / "tools" / "probes"


def iter_source_files(extensions: tuple[str, ...] = (".c", ".h", ".asm", ".inc")) -> list[Path]:
    """Return every source file under src/, sorted, excluding *.bak and copies."""
    out: list[Path] = []
    for path in SRC.rglob("*"):
        if not path.is_file():
            continue
        name = path.name
        if name.endswith(".bak") or " - Copy" in name or name.endswith(".txt"):
            continue
        if path.suffix in extensions:
            out.append(path)
    out.sort()
    return out


def sha256_file(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as f:
        for chunk in iter(lambda: f.read(64 * 1024), b""):
            h.update(chunk)
    return h.hexdigest()


def write_audit(filename: str, contents: str) -> Path:
    """Write a file under docs/audit/, creating the directory if needed."""
    DOCS_AUDIT.mkdir(parents=True, exist_ok=True)
    out = DOCS_AUDIT / filename
    out.write_text(contents, encoding="utf-8")
    return out


def relative_to_repo(path: Path) -> str:
    return str(path.relative_to(REPO_ROOT)).replace(os.sep, "/")
