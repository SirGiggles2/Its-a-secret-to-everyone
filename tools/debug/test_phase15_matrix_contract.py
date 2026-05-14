"""Phase 15 close — Genesis-Specific Optimization matrix contract.

Phase 15 splits:
- 15.1 Instrumentation FULL (substrate predates Phase 15; inline 15a
  work from Phase 6 onward — perf_probe, cycle_probe,
  cycle_profile_buckets, cycle_profile_report, compare_perf,
  per_subsystem_cycle_check).
- 15.2-15.12 PARTIAL (measurement + optimization gated on Phase 14
  GREEN correctness pass per master plan rule "broad rewrites allowed
  ONLY when probes show real budget or hardware risk").

Contract verifies:
- 12 findings docs present (15.1-15.12).
- Instrumentation substrate files exist on disk.
- Baseline placeholder doc exists.
"""

from __future__ import annotations

from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]


def test_phase15_findings_present() -> None:
    fdir = ROOT / "docs" / "audit" / "drain_findings"
    expected = [f"phase15_task_15_{n}.md" for n in range(1, 13)]
    missing = [n for n in expected if not (fdir / n).exists()]
    if missing:
        raise AssertionError(
            "Missing Phase 15 findings docs: " + ", ".join(missing)
        )


def test_perf_instrumentation_substrate_present() -> None:
    for p in (
        "tools/perf_probe.lua",
        "tools/cycle_probe.lua",
        "tools/cycle_profile_buckets.lua",
        "tools/cycle_profile_buckets.json",
        "tools/cycle_profile_report.py",
        "tools/compare_perf.py",
        "tools/per_subsystem_cycle_check.py",
        "tools/bizhawk_perf_sample.lua",
    ):
        if not (ROOT / p).exists():
            raise AssertionError(f"perf instrumentation missing: {p}")


def test_baseline_placeholder_present() -> None:
    path = ROOT / "docs" / "audit" / "genesis_budget_baseline.md"
    if not path.exists():
        raise AssertionError("genesis_budget_baseline.md missing")
    body = path.read_text(encoding="utf-8")
    if "Placeholder" not in body and "baseline" not in body.lower():
        raise AssertionError(
            "genesis_budget_baseline.md: expected Placeholder marker or "
            "baseline copy"
        )


if __name__ == "__main__":
    test_phase15_findings_present()
    test_perf_instrumentation_substrate_present()
    test_baseline_placeholder_present()
    print(
        "PASS: Phase 15 matrix contract "
        "(12 findings + 8 perf instrumentation TUs + baseline placeholder)"
    )
