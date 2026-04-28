"""Resolve NES reference ROM via local config or env var, verify SHA256.

The ROM is never committed to the repository. Probes call resolve_rom() with
the expected SHA256 (locked in the design spec) before any extraction.
"""

from __future__ import annotations

import hashlib
import os
from pathlib import Path

ENV_VAR = "ZELDA_NES_ROM"


class RomNotFoundError(FileNotFoundError):
    pass


class RomHashMismatchError(ValueError):
    pass


def resolve_rom(expected_sha256: str) -> Path:
    """Return the NES ROM path. Raises if missing or if hash mismatches."""
    raw = os.environ.get(ENV_VAR)
    if not raw:
        raise RomNotFoundError(
            f"Set {ENV_VAR} to the path of Legend of Zelda, The (USA).nes"
        )
    path = Path(raw)
    if not path.is_file():
        raise RomNotFoundError(f"{ENV_VAR}={raw} does not point to a file")

    h = hashlib.sha256()
    with path.open("rb") as f:
        for chunk in iter(lambda: f.read(64 * 1024), b""):
            h.update(chunk)
    actual = h.hexdigest()
    if actual.lower() != expected_sha256.lower():
        raise RomHashMismatchError(
            f"NES ROM hash mismatch: expected {expected_sha256}, got {actual}"
        )
    return path


if __name__ == "__main__":
    import sys
    if len(sys.argv) != 2:
        print(f"Usage: {sys.argv[0]} <expected-sha256>", file=sys.stderr)
        sys.exit(2)
    try:
        path = resolve_rom(sys.argv[1])
    except (RomNotFoundError, RomHashMismatchError) as e:
        print(f"ERROR: {e}", file=sys.stderr)
        sys.exit(1)
    print(path)
