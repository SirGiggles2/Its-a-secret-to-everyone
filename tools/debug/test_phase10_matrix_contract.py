"""Phase 10 Task close — Audio Finalization matrix contract.

Static check that Phase 10 substrate + policy decisions are present.
Phase 10 work splits into:

1. Policy + decision docs (10.1, 10.1.1, 10.1.2) — must exist and
   reference master-plan rule numbers.
2. Substrate (driver + manifest + extracted blobs + adapter + ABI)
   — must exist in tree.
3. Findings docs for each sub-task (10.1 through 10.5).

Audio link into Debug.md is a Phase 11 deferral; this contract does
NOT require audio TUs in `build_debug.py`.
"""

from __future__ import annotations

import json
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]


def read(path: str) -> str:
    return (ROOT / path).read_text(encoding="utf-8")


def need(text: str, needle: str, ctx: str) -> None:
    if needle not in text:
        raise AssertionError(f"{ctx}: missing {needle!r}")


def test_policy_docs_present() -> None:
    for p in (
        "docs/audit/audio_driver_decision.md",
        "docs/audit/audio_legal_policy.md",
        "docs/audit/audio_routing.md",
        "docs/audit/audio_split_plan.md",
        "docs/audio_migration_trigger.md",
    ):
        if not (ROOT / p).exists():
            raise AssertionError(f"audio policy doc missing: {p}")


def test_driver_decision_locks_custom() -> None:
    body = read("docs/audit/audio_driver_decision.md")
    need(body, "LOCKED — custom driver retained as default", "driver decision lock")
    need(body, "SGDK-4",                                    "SGDK-4 trigger reference")


def test_legal_policy_adopts_chr_model() -> None:
    body = read("docs/audit/audio_legal_policy.md")
    need(body, "CHR-model rule",   "legal policy headline")
    need(body, "package_check.py", "package check enforcement reference")


def test_audio_routing_gamemode_keyed() -> None:
    body = read("docs/audit/audio_routing.md")
    need(body, "gamemode == 0x01", "FS routing key")
    need(body, "NOT** off the title bitmap",
                                    "explicit rejection of bitmap-keyed routing")


def test_audio_substrate_files_present() -> None:
    for p in (
        "src/audio_driver.asm",
        "src/sgdk_adapter/audio_adapter.c",
        "src/sgdk_adapter/audio_adapter.h",
        "src/abi/audio_abi.h",
        "data/audio/MANIFEST.json",
        "data/audio/songs.c",
        "data/audio/song_scripts.c",
        "data/audio/sfx.c",
        "data/audio/sfx_pcm.c",
        "data/audio/sfx_pcm.h",
        "data/audio/pcm_samples.c",
        "src/data/music_blob.inc",
        "src/data/music_blob.dat",
    ):
        if not (ROOT / p).exists():
            raise AssertionError(f"audio substrate missing: {p}")


def test_audio_manifest_sane() -> None:
    raw = read("data/audio/MANIFEST.json")
    m = json.loads(raw)
    if "nes_rom_sha256" not in m:
        raise AssertionError("audio MANIFEST.json: missing nes_rom_sha256 pin")
    if len(m.get("songs", [])) < 20:
        raise AssertionError(
            f"audio MANIFEST.json: expected at least 20 songs, got {len(m.get('songs', []))}"
        )
    if len(m.get("sfx", [])) < 1:
        raise AssertionError("audio MANIFEST.json: SFX bucket empty")


def test_adapter_abi_exposes_four_calls() -> None:
    api = read("src/abi/audio_abi.h")
    for sym in (
        "audio_xgm_init",
        "audio_music_play",
        "audio_sfx_play",
        "audio_tick_vblank",
    ):
        need(api, sym, "audio_abi entry")


def test_phase10_findings_present() -> None:
    fdir = ROOT / "docs" / "audit" / "drain_findings"
    expected = [
        "phase10_task_10_1.md",
        "phase10_task_10_1_1.md",
        "phase10_task_10_1_2.md",
        "phase10_task_10_2.md",
        "phase10_task_10_3.md",
        "phase10_task_10_4.md",
        "phase10_task_10_5.md",
    ]
    missing = [n for n in expected if not (fdir / n).exists()]
    if missing:
        raise AssertionError(
            "Missing Phase 10 drain findings docs: " + ", ".join(missing)
        )


if __name__ == "__main__":
    test_policy_docs_present()
    test_driver_decision_locks_custom()
    test_legal_policy_adopts_chr_model()
    test_audio_routing_gamemode_keyed()
    test_audio_substrate_files_present()
    test_audio_manifest_sane()
    test_adapter_abi_exposes_four_calls()
    test_phase10_findings_present()
    print(
        "PASS: Phase 10 matrix contract "
        "(5 policy docs + 13 substrate files + 4 adapter entries + 7 findings docs)"
    )
