from __future__ import annotations

import importlib.util
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]


def load_module(rel: str):
    path = ROOT / rel
    spec = importlib.util.spec_from_file_location(path.stem, path)
    if spec is None or spec.loader is None:
        raise AssertionError(f"could not load {rel}")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def test_bizhawk_ram_tools_normalize_sgdk_nm_symbols() -> None:
    """SGDK nm reports RAM globals as e0ffNNNN.

    BizHawk's 68K RAM domain needs NNNN, and M68K BUS needs $FF0000 + NNNN.
    Tool launchers must normalize symbols before Lua probes read memory.
    """
    for rel in (
        "RoomRom/tools/launch_uw_live_debug.py",
        "RoomRom/tools/probe_uw_collision_boot.py",
        "RoomRom/tools/probe_uw_west_exit.py",
        "RoomRom/tools/run_uw_walk_reason_probe.py",
        "RoomRom/tools/launch_uw_walkability_overlay.py",
        "tools/probes/run_ph5_uw_t52_special_cases.py",
    ):
        module = load_module(rel)
        if not hasattr(module, "ram_offset"):
            raise AssertionError(f"{rel} missing ram_offset helper")
        assert module.ram_offset(0xE0FF15D6) == 0x15D6
        assert module.ram_offset(0x00FF15D6) == 0x15D6
        assert module.ram_offset(0x000015D6) == 0x15D6


if __name__ == "__main__":
    test_bizhawk_ram_tools_normalize_sgdk_nm_symbols()
    print("PASS: BizHawk RAM symbol contract")
