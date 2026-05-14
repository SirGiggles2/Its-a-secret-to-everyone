"""Phase 13 close — Optional 4-Player Genesis Mode matrix contract.

Phase 13 is an OPTIONAL feature per master plan; closed as
DEFERRED_FEATURE pending re-evaluation after Phase 14 Full Quest
Completion proves 1-player end-to-end. This contract verifies the
findings docs exist and the deferred-feature stance is unambiguous.

1-player substrate MUST be unchanged by Phase 13 close. The contract
verifies:
- `src/state/link_state.h` (single-Link substrate) untouched.
- No new `players[]` array or `PlayerState` type introduced.
- Findings docs land for Tasks 13.1-13.5 with DEFERRED_FEATURE stance.
"""

from __future__ import annotations

from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]


def read(path: str) -> str:
    return (ROOT / path).read_text(encoding="utf-8")


def need(text: str, needle: str, ctx: str) -> None:
    if needle not in text:
        raise AssertionError(f"{ctx}: missing {needle!r}")


def reject(text: str, needle: str, ctx: str) -> None:
    if needle in text:
        raise AssertionError(f"{ctx}: unexpected {needle!r}")


def test_phase13_findings_present() -> None:
    fdir = ROOT / "docs" / "audit" / "drain_findings"
    expected = [f"phase13_task_13_{n}.md" for n in range(1, 6)]
    missing = [n for n in expected if not (fdir / n).exists()]
    if missing:
        raise AssertionError(
            "Missing Phase 13 findings docs: " + ", ".join(missing)
        )


def test_findings_carry_deferred_feature_stance() -> None:
    for n in range(1, 6):
        body = read(f"docs/audit/drain_findings/phase13_task_13_{n}.md")
        need(body, "DEFERRED_FEATURE", f"Task 13.{n} stance")


def test_phase12_supplemental_findings_present() -> None:
    """Task 12.4 + 12.5 supersession docs that landed alongside this
    phase close — required because master-plan Phase 12 has 6 tasks
    but Phase 12 was closed earlier with only 12.0/12.1/12.2/12.3."""
    for n in (4, 5):
        path = ROOT / "docs" / "audit" / "drain_findings" / f"phase12_task_12_{n}.md"
        if not path.exists():
            raise AssertionError(f"Phase 12 supplemental doc missing: {path.name}")


def test_single_link_substrate_untouched() -> None:
    """Phase 13 close MUST NOT have introduced multi-player substrate."""
    link_state = read("src/state/link_state.h")
    # 1-player invariant: LINK_MOVING_DIR is the canonical accessor;
    # multi-player would expose PLAYER_MOVING_DIR(idx) instead.
    need(link_state, "LINK_MOVING_DIR", "1-player Link substrate invariant")
    # Reject premature multi-player surface unless it lands as a
    # follow-up PR with this contract relaxed.
    for forbidden in (
        "PlayerState players[",
        "PLAYER_MOVING_DIR(",
        "active_player_count",
    ):
        if forbidden in link_state:
            raise AssertionError(
                f"Phase 13 substrate landed prematurely — found "
                f"{forbidden!r} in link_state.h. Close-stance is "
                "DEFERRED_FEATURE; substrate must land in a focused "
                "follow-up PR."
            )


if __name__ == "__main__":
    test_phase13_findings_present()
    test_findings_carry_deferred_feature_stance()
    test_phase12_supplemental_findings_present()
    test_single_link_substrate_untouched()
    print(
        "PASS: Phase 13 matrix contract "
        "(5 findings DEFERRED_FEATURE + 2 ph12 supplemental + 1-player invariant)"
    )
