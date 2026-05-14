"""Phase 17 close — Public Builder Release matrix contract.

Phase 17 is the terminal release phase. Most tasks are
DEFERRED_RELEASE pending Phase 14 GREEN runs + hardware tests.
This contract verifies findings docs exist + ROM-hash-pin
manifests are present (Phase 17.4 partial) + the legal-policy
inheritance from Phase 10 is intact.
"""

from __future__ import annotations

import json
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]


def test_phase17_findings_present() -> None:
    fdir = ROOT / "docs" / "audit" / "drain_findings"
    expected = [f"phase17_task_17_{n}.md" for n in range(1, 6)]
    missing = [n for n in expected if not (fdir / n).exists()]
    if missing:
        raise AssertionError(
            "Missing Phase 17 findings docs: " + ", ".join(missing)
        )


def test_rom_hash_pin_inherited() -> None:
    """Phase 17.4 inherits the audio MANIFEST's nes_rom_sha256 pin."""
    raw = (ROOT / "data" / "audio" / "MANIFEST.json").read_text(encoding="utf-8")
    m = json.loads(raw)
    if not m.get("nes_rom_sha256"):
        raise AssertionError(
            "data/audio/MANIFEST.json: missing nes_rom_sha256 pin"
        )


def test_legal_policy_inherited_from_phase10() -> None:
    """Phase 17.1 + 17.4 reference Phase 10.1.1 legal policy."""
    for p in (
        "docs/audit/audio_legal_policy.md",
        "docs/audit/audio_driver_decision.md",
    ):
        if not (ROOT / p).exists():
            raise AssertionError(
                f"Phase 17 inherits Phase 10 policy doc; missing: {p}"
            )


def test_master_plan_present() -> None:
    """Phase 17 completion note references the master plan."""
    plan = ROOT / "docs" / "superpowers" / "plans" / "2026-05-02-title-roomrom-full-port-master-plan.md"
    if not plan.exists():
        raise AssertionError(f"master plan missing: {plan}")


def test_root_readme_present() -> None:
    """Phase 17.4 substrate."""
    readme = ROOT / "README.md"
    if not readme.exists():
        raise AssertionError("README.md missing — Phase 17.4 substrate prerequisite")


if __name__ == "__main__":
    test_phase17_findings_present()
    test_rom_hash_pin_inherited()
    test_legal_policy_inherited_from_phase10()
    test_master_plan_present()
    test_root_readme_present()
    print(
        "PASS: Phase 17 matrix contract "
        "(5 findings + ROM hash pin + legal policy inheritance + master plan + README)"
    )
