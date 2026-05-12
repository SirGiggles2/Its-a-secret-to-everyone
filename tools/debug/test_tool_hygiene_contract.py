from __future__ import annotations

from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]


def read(path: str) -> str:
    return (ROOT / path).read_text(encoding="utf-8")


def need(text: str, needle: str, label: str) -> None:
    if needle not in text:
        raise AssertionError(f"{label}: missing {needle!r}")


def reject(text: str, needle: str, label: str) -> None:
    if needle in text:
        raise AssertionError(f"{label}: unexpected {needle!r}")


def test_uw_walk_contract_checks_debug_build_source_list() -> None:
    test_src = read("RoomRom/tools/test_uw_walk_model.py")
    need(test_src, 'ROOT / "tools" / "debug" / "build_debug.py"',
         "UW walk model contract must inspect Debug build source list")
    reject(test_src, 'ROOT / "RoomRom" / "build.bat"',
           "UW walk model contract must not inspect retired standalone build")


def test_intro_asset_tests_are_directly_runnable() -> None:
    test_src = read("tools/tests/test_extract_intro_assets.py")
    need(test_src, "sys.path.insert(0, str(REPO))",
         "direct execution must add repo root before importing tools package")


def test_extraction_probe_stays_inside_repo_reports() -> None:
    probe_src = read("tools/test_extraction_directly.py")
    reject(probe_src, "WHAT IF", "probe must not hard-code retired external tree")
    need(probe_src, "builds/reports/extraction_direct",
         "probe output should stay under ignored build reports")
    need(probe_src, "REFERENCE_ROM",
         "probe should allow explicit reference ROM override")


if __name__ == "__main__":
    test_uw_walk_contract_checks_debug_build_source_list()
    test_intro_asset_tests_are_directly_runnable()
    test_extraction_probe_stays_inside_repo_reports()
    print("PASS: Tool hygiene contract")
