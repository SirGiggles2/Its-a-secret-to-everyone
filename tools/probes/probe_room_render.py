#!/usr/bin/env python3
"""S3.A2 — Overworld room render parity probe.

Builds a debug Genesis ROM with -DOW_DEBUG_ENTRY, captures Genesis VDP state
and NES PPU state via BizHawk, normalizes both, diffs the 32x22 play area.

Usage:
    python tools/probes/probe_room_render.py [--room-id N]

    --room-id  Room id in hex (0x...) or decimal (default: 0x77 = 119).
               NOTE: the Genesis debug build is hardcoded to room 0x77 in
               src/frontend/fs/fs_handoff.c. If a different room id is given,
               the Genesis side will still render room 0x77.

Exit codes:
    0  All 32x22 play-area cells match.
    1  One or more cells differ.
    2  Invocation / environment error.
"""

from __future__ import annotations

import argparse
import os
import subprocess
import sys
import tempfile
import time
from pathlib import Path

# ---------------------------------------------------------------------------
# Repo-relative paths
# ---------------------------------------------------------------------------
_THIS = Path(__file__).resolve()
REPO_ROOT = _THIS.parents[2]
TOOLS_PROBES = _THIS.parent

# ---------------------------------------------------------------------------
# Build toolchain constants (mirrors build.bat layout)
# ---------------------------------------------------------------------------
M68K_BIN = REPO_ROOT / "build" / "toolchain" / "sgdk_bin" / "bin"
M68K_GCC = M68K_BIN / "gcc.exe"
M68K_LD  = M68K_BIN / "ld.exe"
LD_SCRIPT = REPO_ROOT / "build" / "genesis.ld"
OBJ_DIR   = REPO_ROOT / "builds" / "obj"

# Output ELF for the debug build (does NOT overwrite the main ROM)
DEBUG_ELF = REPO_ROOT / "builds" / "whatif_ow_debug.elf"

# Common compile flags (taken verbatim from build.bat)
_COMMON_CFLAGS = [
    "-m68000",
    "-ffreestanding",
    "-nostdlib",
    "-nostartfiles",
    "-ffixed-a4",
    "-fno-builtin",
    "-fomit-frame-pointer",
    "-fno-PIC",
    "-fno-common",
    "-O2",
]

# Include paths (mirrors the large -I list in build.bat)
_INCLUDE_DIRS = [
    REPO_ROOT / "src",
    REPO_ROOT / "src" / "state",
    REPO_ROOT / "src" / "core",
    REPO_ROOT / "src" / "abi",
    REPO_ROOT / "src" / "frontend",
    REPO_ROOT / "src" / "frontend" / "intro",
    REPO_ROOT / "src" / "frontend" / "fs",
    REPO_ROOT / "src" / "game" / "enemies",
    REPO_ROOT / "src" / "game" / "combat",
    REPO_ROOT / "src" / "game" / "room",
    REPO_ROOT / "src" / "game" / "cave",
    REPO_ROOT / "src" / "game" / "hud",
    REPO_ROOT / "src" / "game" / "items",
    REPO_ROOT / "src" / "game" / "world",
    REPO_ROOT / "sgdk" / "inc",
]

# Zelda 1 USA NES ROM SHA256 (locked by the project spec)
NES_ROM_SHA256 = "b3ed9f5dc5b2b73e5e9b19c8ea2c8cffe5c396a11d9e9e7f6bf38fcb2b22d5c9"

# BizHawk env var (from project memory skill_bizhawk_script.md)
BIZHAWK_ROOT_ENV = "CODEX_BIZHAWK_ROOT"

# Dump wait timeout (seconds)
DUMP_TIMEOUT = 120


# ---------------------------------------------------------------------------
# Step 1: Build debug Genesis ROM
# ---------------------------------------------------------------------------

def _compile(src: Path, obj: Path, extra_flags: list[str] | None = None) -> None:
    """Compile a single C file to an ELF object."""
    cmd = [
        str(M68K_GCC),
        "-B", str(M68K_BIN) + "\\",
    ] + _COMMON_CFLAGS + [
        f"-I{d}" for d in _INCLUDE_DIRS
    ] + (extra_flags or []) + [
        "-c", str(src),
        "-o", str(obj),
    ]
    result = subprocess.run(cmd, capture_output=True, text=True)
    if result.returncode != 0:
        print(f"[build] FAIL compiling {src.name}:", file=sys.stderr)
        print(result.stderr, file=sys.stderr)
        raise RuntimeError(f"Compile failed: {src}")


def build_debug_rom() -> Path:
    """Compile debug variants of fs_handoff.c and ow_room_debug.c, then link
    with all existing .o files to produce builds/whatif_ow_debug.elf.

    Returns the path to the debug ELF.
    """
    if not M68K_GCC.is_file():
        raise RuntimeError(
            f"m68k-elf-gcc not found at {M68K_GCC}\n"
            "Ensure build\\toolchain\\sgdk_bin\\bin\\ exists (run build.bat once first)."
        )

    OBJ_DIR.mkdir(parents=True, exist_ok=True)

    # Compile the two debug-variant objects into separate paths so we don't
    # overwrite the normal build objects.
    debug_fs_handoff_obj = OBJ_DIR / "fs_handoff_dbg.o"
    debug_ow_room_obj    = OBJ_DIR / "ow_room_debug_dbg.o"

    print("[build] Compiling fs_handoff.c with -DOW_DEBUG_ENTRY ...")
    _compile(
        REPO_ROOT / "src" / "frontend" / "fs" / "fs_handoff.c",
        debug_fs_handoff_obj,
        extra_flags=["-DOW_DEBUG_ENTRY"],
    )

    print("[build] Compiling ow_room_debug.c ...")
    _compile(
        REPO_ROOT / "src" / "game" / "room" / "ow_room_debug.c",
        debug_ow_room_obj,
    )

    # Collect all normal .o files from the response file that the last full
    # build wrote, substituting the two debug objects in place of their
    # non-debug counterparts.
    ld_resp = OBJ_DIR / "link_objs.rsp"
    if not ld_resp.is_file():
        raise RuntimeError(
            f"{ld_resp} not found.\n"
            "Run build.bat once to produce the full object set before running this probe."
        )

    obj_lines = ld_resp.read_text(encoding="utf-8").splitlines()
    # Each line is a quoted forward-slash path like "/full/path/to/foo.o"
    # Strip quotes and convert to Path objects.
    obj_paths: list[str] = []
    substituted_fs_handoff = False
    substituted_ow_room_debug = False
    for line in obj_lines:
        stripped = line.strip().strip('"')
        if not stripped:
            continue
        p = Path(stripped)
        if p.name == "fs_handoff.o":
            obj_paths.append(str(debug_fs_handoff_obj).replace("\\", "/"))
            substituted_fs_handoff = True
        elif p.name == "ow_room_debug.o":
            obj_paths.append(str(debug_ow_room_obj).replace("\\", "/"))
            substituted_ow_room_debug = True
        else:
            obj_paths.append(str(p))

    # If the normal objects weren't in the rsp (e.g. fresh setup), add debug objs.
    if not substituted_fs_handoff:
        obj_paths.append(str(debug_fs_handoff_obj).replace("\\", "/"))
    if not substituted_ow_room_debug:
        obj_paths.append(str(debug_ow_room_obj).replace("\\", "/"))

    # Write a debug-specific response file.
    debug_rsp = OBJ_DIR / "link_objs_dbg.rsp"
    debug_rsp.write_text(
        "\n".join(f'"{p}"' for p in obj_paths) + "\n",
        encoding="utf-8",
    )

    # The ASM root object (builds/whatif.o) is always the first positional arg.
    asm_obj = REPO_ROOT / "builds" / "whatif.o"
    if not asm_obj.is_file():
        raise RuntimeError(
            f"{asm_obj} not found.\n"
            "Run build.bat once to assemble genesis_shell.asm first."
        )

    print(f"[build] Linking debug ELF -> {DEBUG_ELF.name} ...")
    link_cmd = [
        str(M68K_LD),
        "-T", str(LD_SCRIPT),
        "-o", str(DEBUG_ELF),
        str(asm_obj),
        f"@{debug_rsp}",
        "-L", str(REPO_ROOT / "sgdk" / "lib"),
        "-lmd",
        "-lgcc",
    ]
    result = subprocess.run(link_cmd, capture_output=True, text=True)
    if result.returncode != 0:
        print("[build] FAIL linking debug ELF:", file=sys.stderr)
        print(result.stderr, file=sys.stderr)
        raise RuntimeError("Link failed")

    print(f"[build] Debug ELF ready: {DEBUG_ELF}")
    return DEBUG_ELF


# ---------------------------------------------------------------------------
# Step 2: BizHawk launch helpers
# ---------------------------------------------------------------------------

def _get_bizhawk_dir() -> Path:
    """Return BizHawk install directory from CODEX_BIZHAWK_ROOT env var.

    Falls back to a few known locations used in build.bat.
    """
    raw = os.environ.get(BIZHAWK_ROOT_ENV)
    if raw:
        p = Path(raw)
        if (p / "EmuHawk.exe").is_file():
            return p
        # Env var set but path invalid — still report what we found.
        raise RuntimeError(
            f"{BIZHAWK_ROOT_ENV}={raw} does not contain EmuHawk.exe"
        )

    # Fallback scan (same candidates as build.bat)
    candidates = [
        Path(r"C:\Users\Jake Diggity\Documents\GitHub\VDP rebirth tools and asms\BizHawk-2.11-win-x64"),
        Path(r"C:\BizHawk"),
        Path(os.environ.get("LOCALAPPDATA", "")) / "BizHawk",
        Path(os.environ.get("USERPROFILE", "")) / "BizHawk",
    ]
    for c in candidates:
        if (c / "EmuHawk.exe").is_file():
            return c

    raise RuntimeError(
        f"BizHawk not found. Set {BIZHAWK_ROOT_ENV} to the BizHawk install directory."
    )


def _wait_for_file(path: Path, timeout: int = DUMP_TIMEOUT) -> None:
    """Poll until path exists and its size stabilises (write complete)."""
    deadline = time.monotonic() + timeout
    while time.monotonic() < deadline:
        if path.is_file() and path.stat().st_size > 0:
            # Wait for size to stabilise across two polls.
            size1 = path.stat().st_size
            time.sleep(0.3)
            size2 = path.stat().st_size
            if size1 == size2:
                return
        time.sleep(0.5)
    raise TimeoutError(
        f"Timed out waiting for {path} (waited {timeout}s).\n"
        "BizHawk may have crashed or the ROM didn't render in time."
    )


def _launch_bizhawk(bizhawk_dir: Path, rom_path: Path, lua_script: Path) -> subprocess.Popen:
    """Launch BizHawk as a background process."""
    emuhawk = bizhawk_dir / "EmuHawk.exe"
    cmd = [
        "cmd.exe", "/c",
        f'cd /d "{bizhawk_dir}" && '
        f'"{emuhawk}" --lua="{lua_script}" "{rom_path}"'
    ]
    return subprocess.Popen(
        " ".join(cmd),
        shell=True,
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
    )


def _write_gen_lua(lua_path: Path, dump_out: Path, frame_target: int = 120) -> None:
    lua_path.write_text(
        f'FRAME_TARGET = {frame_target}\n'
        f'DUMP_OUT = "{str(dump_out).replace(chr(92), chr(92)*2)}"\n'
        f'dofile("{str(TOOLS_PROBES / "bizhawk_capture_gen.lua").replace(chr(92), "/")}")\n',
        encoding="utf-8",
    )


def _write_nes_lua(lua_path: Path, dump_out: Path, room_id: int = 0x77) -> None:
    capture_script = TOOLS_PROBES / "nes_ow_room_capture.lua"
    lua_path.write_text(
        f'DUMP_OUT = "{str(dump_out).replace(chr(92), chr(92)*2)}"\n'
        f'TARGET_ROOM = {room_id}\n'
        f'dofile("{str(capture_script).replace(chr(92), "/")}")\n',
        encoding="utf-8",
    )


# ---------------------------------------------------------------------------
# Step 3: Custom diff — only compare the 32x22 overworld play area
# ---------------------------------------------------------------------------

def diff_overworld_bg(nes_schema: dict, gen_schema: dict) -> int:
    """Diff the 32x22 overworld play area between NES and Genesis schemas.

    Mapping:
        NES  : col 0..31, row 0..21  (rows 22-23 are status bar)
        Genesis: col 0..31, row 2..23 (rows 0-1 are HUD area)

    Returns the total number of mismatching cells (0 = pass).
    """
    COLS = 32
    ROWS = 22  # play area height

    total_diffs = 0

    for field in ("bg_tile", "bg_palette", "bg_priority"):
        nes_f = nes_schema.get(field, {})
        gen_f = gen_schema.get(field, {})
        diffs: list[tuple[int, int, object, object]] = []

        for row in range(ROWS):
            for col in range(COLS):
                nes_key = f"{col},{row}"
                gen_key = f"{col},{row + 2}"  # Genesis row offset +2 for HUD
                nv = nes_f.get(nes_key)
                gv = gen_f.get(gen_key)
                if nv != gv:
                    diffs.append((col, row, nv, gv))

        if diffs:
            total_diffs += len(diffs)
            print(f"[{field}] {len(diffs)} cells differ (play area 32x{ROWS}):")
            for col, row, nv, gv in diffs[:20]:
                print(f"  ({col},{row}): NES={nv}  GEN={gv}")
            if len(diffs) > 20:
                print(f"  ... +{len(diffs) - 20} more")
        else:
            print(f"[{field}] match ({COLS * ROWS} cells)")

    print()
    print(f"TOTAL play-area differences: {total_diffs}")
    print("VERDICT:", "PASS" if total_diffs == 0 else "FAIL")
    return total_diffs


# ---------------------------------------------------------------------------
# Main entry point
# ---------------------------------------------------------------------------

def main() -> int:
    parser = argparse.ArgumentParser(
        description="S3.A2 overworld room render parity probe."
    )
    parser.add_argument(
        "--room-id",
        default="0x77",
        help="Room id in hex (0x..) or decimal (default: 0x77). "
             "NOTE: the debug build is hardcoded to room 0x77.",
    )
    args = parser.parse_args()

    # Parse room id
    try:
        room_id = int(args.room_id, 0) if isinstance(args.room_id, str) else int(args.room_id)
    except ValueError:
        print(f"ERROR: invalid --room-id value: {args.room_id!r}", file=sys.stderr)
        return 2

    if room_id != 0x77:
        print(
            f"WARNING: --room-id=0x{room_id:02X} requested, but the debug build "
            f"is hardcoded to room 0x77 (see fs_handoff.c:OW_DEBUG_ENTRY branch).\n"
            f"         The Genesis capture will show room 0x77 regardless.",
            file=sys.stderr,
        )

    # Locate BizHawk early so we fail fast before a long build.
    try:
        bizhawk_dir = _get_bizhawk_dir()
    except RuntimeError as e:
        print(f"ERROR: {e}", file=sys.stderr)
        return 2

    print(f"[env] BizHawk: {bizhawk_dir}")
    print(f"[env] Room ID: 0x{room_id:02X}")

    # Locate NES reference ROM
    sys.path.insert(0, str(TOOLS_PROBES))
    from locate_reference_rom import resolve_rom, RomNotFoundError, RomHashMismatchError
    try:
        nes_rom_path = resolve_rom(NES_ROM_SHA256)
    except RomNotFoundError as e:
        print(f"ERROR: {e}", file=sys.stderr)
        return 2
    except RomHashMismatchError as e:
        print(f"WARNING: {e}", file=sys.stderr)
        # Allow mismatch but continue — common during dev with different ROM editions.
        import os as _os
        nes_rom_path = Path(_os.environ.get("ZELDA_NES_ROM", ""))
        if not nes_rom_path.is_file():
            return 2

    print(f"[env] NES ROM: {nes_rom_path}")

    # -----------------------------------------------------------------
    # 1. Build debug Genesis ROM
    # -----------------------------------------------------------------
    print("\n--- Step 1: Build debug Genesis ROM ---")
    try:
        debug_elf = build_debug_rom()
    except RuntimeError as e:
        print(f"ERROR (build): {e}", file=sys.stderr)
        return 1

    # -----------------------------------------------------------------
    # 2. Genesis capture
    # -----------------------------------------------------------------
    print("\n--- Step 2: Genesis VDP capture ---")
    tmp_dir = Path(tempfile.gettempdir())
    gen_dump = tmp_dir / f"gen_room_{room_id:02x}.bin"
    gen_dump.unlink(missing_ok=True)

    gen_lua = tmp_dir / "gen_probe_room.lua"
    _write_gen_lua(gen_lua, gen_dump, frame_target=120)

    print(f"[gen] Launching BizHawk (Genesis) with debug ROM ...")
    print(f"[gen] Lua: {gen_lua}")
    print(f"[gen] Dump: {gen_dump}")
    _launch_bizhawk(bizhawk_dir, debug_elf, gen_lua)

    try:
        _wait_for_file(gen_dump, DUMP_TIMEOUT)
    except TimeoutError as e:
        print(f"ERROR: {e}", file=sys.stderr)
        return 1
    print(f"[gen] Dump ready ({gen_dump.stat().st_size} bytes)")

    # -----------------------------------------------------------------
    # 3. NES capture
    # -----------------------------------------------------------------
    print("\n--- Step 3: NES PPU capture ---")
    nes_dump = tmp_dir / f"nes_room_{room_id:02x}.bin"
    nes_dump.unlink(missing_ok=True)

    nes_lua = tmp_dir / "nes_probe_room.lua"
    _write_nes_lua(nes_lua, nes_dump, room_id=room_id)

    print(f"[nes] Launching BizHawk (NES) ...")
    print(f"[nes] Lua: {nes_lua}")
    print(f"[nes] Dump: {nes_dump}")
    _launch_bizhawk(bizhawk_dir, nes_rom_path, nes_lua)

    try:
        _wait_for_file(nes_dump, DUMP_TIMEOUT)
    except TimeoutError as e:
        print(f"ERROR: {e}", file=sys.stderr)
        return 1
    print(f"[nes] Dump ready ({nes_dump.stat().st_size} bytes)")

    # -----------------------------------------------------------------
    # 4. Normalize both dumps
    # -----------------------------------------------------------------
    print("\n--- Step 4: Normalize ---")
    from normalize_gen import normalize as norm_gen
    from normalize_nes import normalize as norm_nes

    gen_schema = norm_gen(gen_dump)
    nes_schema = norm_nes(nes_dump)

    print(f"[norm] Genesis: platform={gen_schema['platform']} frame={gen_schema['frame']}")
    print(f"[norm] NES:     platform={nes_schema['platform']} frame={nes_schema['frame']}")

    # Log NES GameMode to confirm we captured overworld state
    nes_stat = nes_schema.get("state", {}).get("raw", [])
    if nes_stat:
        game_mode_val = nes_stat[0] if len(nes_stat) > 0 else "?"
        room_num_val  = nes_stat[1] if len(nes_stat) > 1 else "?"
        print(f"[norm] NES GameMode=0x{game_mode_val:02X}  RoomNum=0x{room_num_val:02X}"
              if isinstance(game_mode_val, int) else
              f"[norm] NES STAT raw: {nes_stat}")

    # -----------------------------------------------------------------
    # 5. Diff — only play area (32x22)
    # -----------------------------------------------------------------
    print("\n--- Step 5: Diff (32x22 play area) ---")
    total_diffs = diff_overworld_bg(nes_schema, gen_schema)

    return 0 if total_diffs == 0 else 1


if __name__ == "__main__":
    sys.exit(main())
