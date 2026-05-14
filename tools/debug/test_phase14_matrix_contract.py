"""Phase 14 close — Full Quest Completion harness matrix contract.

Phase 14 closes on the SCAFFOLD slice (Task 14.0 dungeon harness
directory + manifest + orchestrator + template). Per-row population
(18 save states + 18 probes) defers as
`phase14_dungeon_harness_population`.

This contract verifies:
- `tools/dungeon_harness/` dir + key files present.
- `manifest.json` parses + carries 18 rows (9 levels x 2 quests).
- `run_all.py` orchestrator exits 0 in --dry-run mode (manifest sane).
- `dungeon_template.lua` template exists and contains expected
  placeholder sections.
- Phase 14 findings docs (14.0-14.3) present.
"""

from __future__ import annotations

import json
import subprocess
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
HARNESS = ROOT / "tools" / "dungeon_harness"


def read(path: str) -> str:
    return (ROOT / path).read_text(encoding="utf-8")


def need(text: str, needle: str, ctx: str) -> None:
    if needle not in text:
        raise AssertionError(f"{ctx}: missing {needle!r}")


def test_dungeon_harness_dir_present() -> None:
    for p in (
        HARNESS,
        HARNESS / "save_states",
        HARNESS / "probes",
        HARNESS / "manifest.json",
        HARNESS / "run_all.py",
        HARNESS / "README.md",
        HARNESS / "probes" / "dungeon_template.lua",
    ):
        if not p.exists():
            raise AssertionError(f"dungeon_harness missing: {p}")


def test_manifest_18_rows() -> None:
    raw = (HARNESS / "manifest.json").read_text(encoding="utf-8")
    m = json.loads(raw)
    if m.get("schema_version") != 1:
        raise AssertionError(
            f"manifest.json: schema_version != 1 ({m.get('schema_version')})"
        )
    rows = m.get("rows", [])
    if len(rows) != 18:
        raise AssertionError(f"manifest.json: expected 18 rows, got {len(rows)}")
    levels = {(r["level"], r["quest"]) for r in rows}
    expected = {(L, Q) for L in range(1, 10) for Q in (1, 2)}
    if levels != expected:
        missing = expected - levels
        raise AssertionError(
            f"manifest.json: missing (level, quest) tuples: {sorted(missing)}"
        )
    # Every row must have required fields.
    required = {"level", "quest", "label", "save_state", "probe", "boss", "reward"}
    for row in rows:
        missing_keys = required - set(row.keys())
        if missing_keys:
            raise AssertionError(
                f"manifest.json row {row.get('label')}: missing {missing_keys}"
            )


def test_run_all_dry_run_exits_zero() -> None:
    r = subprocess.run(
        [sys.executable, str(HARNESS / "run_all.py"), "--dry-run"],
        cwd=ROOT,
        capture_output=True,
        text=True,
    )
    if r.returncode != 0:
        raise AssertionError(
            f"run_all.py --dry-run exited {r.returncode}:\n"
            f"--- stdout ---\n{r.stdout}\n--- stderr ---\n{r.stderr}"
        )
    if "Summary: " not in r.stdout:
        raise AssertionError(
            "run_all.py --dry-run did not print summary line"
        )


def test_template_has_expected_sections() -> None:
    template = read("tools/dungeon_harness/probes/dungeon_template.lua")
    for needle in (
        "SAVE_STATE_PATH",
        "INPUT_SEQUENCE",
        "savestate.load",
        "joypad.set",
        "boss_clear_frame",
        "verdict",
    ):
        need(template, needle, "dungeon_template.lua placeholder section")


def test_phase14_findings_present() -> None:
    fdir = ROOT / "docs" / "audit" / "drain_findings"
    expected = [f"phase14_task_14_{n}.md" for n in (0, 1, 2, 3)]
    missing = [n for n in expected if not (fdir / n).exists()]
    if missing:
        raise AssertionError(
            "Missing Phase 14 findings docs: " + ", ".join(missing)
        )


if __name__ == "__main__":
    test_dungeon_harness_dir_present()
    test_manifest_18_rows()
    test_run_all_dry_run_exits_zero()
    test_template_has_expected_sections()
    test_phase14_findings_present()
    print(
        "PASS: Phase 14 matrix contract "
        "(harness dir + 18-row manifest + run_all dry-run + template + 4 findings)"
    )
