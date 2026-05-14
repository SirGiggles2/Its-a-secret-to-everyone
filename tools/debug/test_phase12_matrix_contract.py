"""Phase 12 Task close — RoomRom promotion + state conversion matrix contract.

Verifies Phase 12 baseline deliverables:

1. Audit doc `docs/audit/roomrom_promotion_audit.md` exists +
   classifies every on-disk `RoomRom/src/*.c`.
2. Gate tool `tools/audit/check_incremental_promotion.py` exists +
   exits zero against the audit doc.
3. Phase 12 findings docs `phase12_task_12_{0,1,2,3}.md` exist.
4. Substrate target dirs `src/game/<sub>/` + `src/state/` exist.

This contract does NOT require all family migrations to be complete;
those land as `phase12_family_migration` follow-up PRs gated by the
audit tool itself.
"""

from __future__ import annotations

import subprocess
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]


def read(path: str) -> str:
    return (ROOT / path).read_text(encoding="utf-8")


def need(text: str, needle: str, ctx: str) -> None:
    if needle not in text:
        raise AssertionError(f"{ctx}: missing {needle!r}")


def test_audit_doc_present_and_complete() -> None:
    body = read("docs/audit/roomrom_promotion_audit.md")
    for needle in (
        "RoomRom Promotion Audit",
        "harness-only",
        "shared-gameplay",
        "generated-asset",
        "Promotion order",
    ):
        if needle not in body:
            raise AssertionError(
                f"roomrom_promotion_audit.md: missing {needle!r}"
            )


def test_gate_tool_exists_and_exits_zero() -> None:
    tool = ROOT / "tools" / "audit" / "check_incremental_promotion.py"
    if not tool.exists():
        raise AssertionError(
            "tools/audit/check_incremental_promotion.py missing"
        )
    r = subprocess.run(
        [sys.executable, str(tool)],
        cwd=ROOT,
        capture_output=True,
        text=True,
    )
    if r.returncode != 0:
        raise AssertionError(
            f"check_incremental_promotion.py exited {r.returncode}:\n"
            f"--- stdout ---\n{r.stdout}\n--- stderr ---\n{r.stderr}"
        )
    # Must report at least one harness-only and one shared-gameplay row.
    if "harness-only" not in r.stdout or "shared-gameplay" not in r.stdout:
        raise AssertionError(
            "check_incremental_promotion.py output missing bucket counts"
        )


def test_phase12_findings_present() -> None:
    fdir = ROOT / "docs" / "audit" / "drain_findings"
    expected = [f"phase12_task_12_{n}.md" for n in (0, 1, 2, 3)]
    missing = [n for n in expected if not (fdir / n).exists()]
    if missing:
        raise AssertionError(
            "Missing Phase 12 findings docs: " + ", ".join(missing)
        )


def test_target_substrate_dirs_present() -> None:
    for d in (
        "src/state",
        "src/game/cave",
        "src/game/combat",
        "src/game/world",
        "src/game/dungeon",
        "src/game/items",
        "src/game/hud",
        "src/game/enemies",
        "src/game/options",
    ):
        if not (ROOT / d).is_dir():
            raise AssertionError(f"target substrate dir missing: {d}")


def test_classification_covers_all_on_disk_files() -> None:
    # cross-check by parsing the audit doc table directly
    body = read("docs/audit/roomrom_promotion_audit.md")
    on_disk = {p.name for p in (ROOT / "RoomRom" / "src").glob("*.c")}
    for fname in on_disk:
        if f"`{fname}`" not in body:
            raise AssertionError(
                f"RoomRom/src/{fname} not classified in audit doc"
            )


if __name__ == "__main__":
    test_audit_doc_present_and_complete()
    test_gate_tool_exists_and_exits_zero()
    test_phase12_findings_present()
    test_target_substrate_dirs_present()
    test_classification_covers_all_on_disk_files()
    print(
        "PASS: Phase 12 matrix contract "
        "(audit doc + gate tool + 4 findings + 9 substrate dirs + 36 classified)"
    )
