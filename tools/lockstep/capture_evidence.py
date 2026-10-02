"""Validate completed capture records before any acceptance calculation."""
from __future__ import annotations

import re
from pathlib import Path


def completed_ticks(directory: Path, platform: str) -> int:
    prefix = directory / platform
    error = prefix.with_suffix(".err")
    if error.exists():
        raise ValueError(f"{platform}: {error.read_text(encoding='utf-8', errors='replace').strip()}")
    meta = prefix.with_suffix(".txt")
    ram = prefix.with_suffix(".ram")
    if not meta.is_file() or not ram.is_file():
        raise ValueError(f"{platform}: missing completion report or RAM capture")
    ends = re.findall(r"^frames=(\d+)\s*$", meta.read_text(encoding="utf-8", errors="replace"), re.M)
    if len(ends) != 1 or int(ends[0]) <= 0:
        raise ValueError(f"{platform}: missing or invalid completion count")
    count = int(ends[0])
    if ram.stat().st_size != count * 2048:
        raise ValueError(f"{platform}: RAM size does not match {count} completed ticks")
    return count
