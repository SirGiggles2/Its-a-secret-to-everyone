"""Phase 16 close — Hardware, Performance, And Polish matrix contract.

Phase 16 tasks split:
- 16.1 Performance gates PARTIAL — Phase 15 instrumentation ratified.
- 16.2 Hardware tests DEFERRED_HARDWARE — physical hardware out of CLI.
- 16.3 Emulator matrix PARTIAL — BizHawk primary; BlastEm/GPGX deferred.
- 16.4 Accessibility PARTIAL — option framework FULL; live verify gated.
- 16.5 Polish pass PARTIAL — alias retirement FULL via banned-name gate;
  debug-code prune + SaveRAM migration deferred to release-prep.

Contract verifies the 5 findings docs exist + banned-filename gate
passes (16.5 alias retirement evidence) + Phase 15 perf instrumentation
substrate is still in tree (16.1 prerequisite).
"""

from __future__ import annotations

import subprocess
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]


def test_phase16_findings_present() -> None:
    fdir = ROOT / "docs" / "audit" / "drain_findings"
    expected = [f"phase16_task_16_{n}.md" for n in range(1, 6)]
    missing = [n for n in expected if not (fdir / n).exists()]
    if missing:
        raise AssertionError(
            "Missing Phase 16 findings docs: " + ", ".join(missing)
        )


def test_banned_filename_gate_passes() -> None:
    """Phase 16.5 alias-retirement evidence."""
    gate = ROOT / "tools" / "gates" / "check_banned_filename.py"
    if not gate.exists():
        raise AssertionError("tools/gates/check_banned_filename.py missing")
    r = subprocess.run(
        [sys.executable, str(gate)],
        cwd=ROOT,
        capture_output=True,
        text=True,
    )
    if r.returncode != 0:
        raise AssertionError(
            f"check_banned_filename.py exited {r.returncode}:\n"
            f"--- stdout ---\n{r.stdout}\n--- stderr ---\n{r.stderr}"
        )


def test_perf_substrate_inherited() -> None:
    """Phase 16.1 inherits Phase 15.1 instrumentation."""
    for p in ("tools/perf_probe.lua", "tools/cycle_probe.lua"):
        if not (ROOT / p).exists():
            raise AssertionError(f"perf substrate missing: {p}")


def test_options_consumer_framework_present() -> None:
    """Phase 16.4 inherits Phase 9.4 options consumer framework."""
    for p in (
        "src/game/options/options_state.h",
        "src/game/options/options_consumer.h",
        "src/game/options/options_consumer.c",
    ):
        if not (ROOT / p).exists():
            raise AssertionError(f"options framework missing: {p}")


if __name__ == "__main__":
    test_phase16_findings_present()
    test_banned_filename_gate_passes()
    test_perf_substrate_inherited()
    test_options_consumer_framework_present()
    print(
        "PASS: Phase 16 matrix contract "
        "(5 findings + banned-name gate + perf substrate + options framework)"
    )
