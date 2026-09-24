"""completion_gate.py — release gate step for the completion tracker.

Always re-collects. A completion_tracker.json on disk is a report, not
an authority: sources can change after the last collection, so trusting
the file would let packaging proceed from stale GREEN.
"""
from __future__ import annotations

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "audit" / "completion"))

import collect  # noqa: E402


def parse_overrides(raw: list[str]) -> dict[str, dict]:
    """Parse SYSTEM/AXIS:REASON:APPROVED_BY strings into a mapping."""
    out: dict[str, dict] = {}
    for item in raw or []:
        cell, _, rest = item.partition(":")
        reason, _, approved_by = rest.partition(":")
        if not cell or not reason.strip() or not approved_by.strip():
            raise ValueError(
                f"malformed --override {item!r} — expected "
                "SYSTEM/AXIS:REASON:APPROVED_BY"
            )
        out[cell.strip()] = {
            "reason": reason.strip(),
            "approved_by": approved_by.strip(),
        }
    return out


def check(root: Path, overrides: dict[str, dict]) -> tuple[bool, str]:
    """Return (may_package, message). Overrides are recorded, never GREEN."""
    tracker = collect.build(Path(root))
    blocking = [
        c
        for c in tracker["cells"]
        if c["verdict"] == "RED" and f"{c['system']}/{c['axis']}" not in overrides
    ]
    used = [
        key
        for key in overrides
        if any(
            f"{c['system']}/{c['axis']}" == key and c["verdict"] == "RED"
            for c in tracker["cells"]
        )
    ]
    if blocking:
        lines = [f"completion gate: {len(blocking)} of 80 cells RED"]
        lines += [
            f"  {c['system']}/{c['axis']}: {'; '.join(c['reasons'])}"
            for c in blocking[:10]
        ]
        if len(blocking) > 10:
            lines.append(f"  ... and {len(blocking) - 10} more")
        return False, "\n".join(lines)
    if used:
        return True, (
            f"completion gate: PASS with {len(used)} override(s): "
            f"{', '.join(sorted(used))}"
        )
    return True, "completion gate: 80/80 satisfied"
