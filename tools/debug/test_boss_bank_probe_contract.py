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


def test_boss_bank_writeback_uses_selected_domain_address() -> None:
    probe = read("tools/debug/probe_boss_bank_dispatch.lua")
    need(probe, "local WRITEBACK_ADDR = CTRL_ADDR - 8",
         "writeback diagnostic must follow selected RAM domain addressing")
    need(probe, "ram_w8(WRITEBACK_ADDR, 0xAB)",
         "writeback diagnostic writes through domain-aware address")
    need(probe, "local readback = ram_r8(WRITEBACK_ADDR)",
         "writeback diagnostic reads through domain-aware address")
    reject(probe, "ram_w8(0x73F0, 0xAB)",
           "hard-coded offset breaks M68K BUS diagnostics")
    reject(probe, "local readback = ram_r8(0x73F0)",
           "hard-coded offset breaks M68K BUS diagnostics")


if __name__ == "__main__":
    test_boss_bank_writeback_uses_selected_domain_address()
    print("PASS: Boss bank probe contract")
