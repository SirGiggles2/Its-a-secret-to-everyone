"""model.py — the completion grid: 16 systems x 5 axes = 80 cells.

Per docs/superpowers/specs/2026-08-03-completion-tracker-design.md §3.
Pure data + identity. No I/O, no validation, no verdict logic.
"""
from __future__ import annotations

SYSTEMS: tuple[str, ...] = (
    "frontend",
    "save",
    "overworld",
    "caves",
    "dungeons",
    "link",
    "combat",
    "items",
    "enemies",
    "bosses",
    "hud",
    "modes",
    "audio",
    "quest2",
    "perf",
    "builder",
)

AXES: tuple[str, ...] = ("DATA", "BEHAVIOR", "PLAYABLE", "CODE", "LEGAL")

GREEN = "GREEN"
RED = "RED"
NA = "N/A"


def all_cells() -> list[tuple[str, str]]:
    """Every (system, axis) pair in fixed spec order. Stable across runs."""
    return [(s, a) for s in SYSTEMS for a in AXES]
