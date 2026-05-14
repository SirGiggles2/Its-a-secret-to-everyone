"""Phase 17.1 — Public package include/exclude gate.

Enforces the Phase 10.1.1 CHR-model legal policy
(docs/audit/audio_legal_policy.md): public release tarball ships
builder source + manifest + adapter code, NEVER ships generated
Nintendo-derived assets (extracted CHR / songs / SFX / room blobs)
unless they were generated from a user-supplied ROM at the user's
local build time.

Usage:
    python tools/builder/package_check.py
        — scan the working tree, report which files would be
          included vs excluded if a release tarball were built now.
    python tools/builder/package_check.py --tarball <path>
        — open an existing tarball and reject if any banned file is
          present.

Exit codes:
    0  No banned files in release scope.
    1  Banned files present (lists which ones; suggests fix).
"""

from __future__ import annotations

import argparse
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]


# Generated Nintendo-derived assets — MUST NOT ship in public package.
# Extension-based plus path-based rules; path-based wins on conflict.
BANNED_PATHS = (
    # Audio extraction output (Phase 10.2): songs / SFX / PCM / music blob.
    "data/audio/songs.c",
    "data/audio/song_scripts.c",
    "data/audio/sfx.c",
    "data/audio/sfx_pcm.c",
    "data/audio/sfx_pcm.h",
    "data/audio/pcm_samples.c",
    "src/data/music_blob.dat",
    "src/data/music_blob.inc",
    # CHR extraction output (Phase 1 builder + Phase 12.2 atlas-data classification).
    # data/chr/* + data/rooms/* + RoomRom/data/* are extractor outputs.
)

# Path-prefix excludes — any file whose POSIX path starts with one
# of these MUST NOT ship in public package.
BANNED_PREFIXES = (
    "data/chr/",
    "data/rooms/",
    "data/redux/",
    "RoomRom/data/",
    # CHR atlas data — Phase 12.2 atlas sub-audit classified as
    # generated-asset (13 of 15 atlas .c files).
    "RoomRom/src/atlas/bg_overworld_chr.",
    "RoomRom/src/atlas/bg_underworld_chr.",
    "RoomRom/src/atlas/boss_chr.",
    "RoomRom/src/atlas/bosses_chr.",
    "RoomRom/src/atlas/enemies_chr.",
    "RoomRom/src/atlas/enemy_chr.",
    "RoomRom/src/atlas/fileselect_chr.",
    "RoomRom/src/atlas/hud_chr.",
    "RoomRom/src/atlas/items_chr.",
    "RoomRom/src/atlas/items_chr_x4.",
    "RoomRom/src/atlas/link_chr.",
    "RoomRom/src/atlas/npc_chr.",
    "RoomRom/src/atlas/title_chr.",
    # NES ROM files (user supplies own).
    "roms/",
)

# Extension blacklist — ROM files of any name MUST NOT ship.
BANNED_EXTENSIONS = (
    ".nes",
    ".sfc",  # if SNES-derivative ever ships
    ".smc",
)

# Always allow these (override prefix-bans).
ALLOWLIST = (
    "data/audio/MANIFEST.json",  # manifest is metadata, not data
)


def is_banned(rel: str) -> tuple[bool, str]:
    """Return (banned, reason)."""
    rel_posix = rel.replace("\\", "/")

    for allow in ALLOWLIST:
        if rel_posix == allow:
            return (False, "allowlist")

    for banned in BANNED_PATHS:
        if rel_posix == banned:
            return (True, f"banned generated asset: {banned}")

    for prefix in BANNED_PREFIXES:
        if rel_posix.startswith(prefix):
            return (True, f"banned prefix: {prefix}")

    for ext in BANNED_EXTENSIONS:
        if rel_posix.endswith(ext):
            return (True, f"banned extension: {ext}")

    return (False, "ok")


def scan_tree() -> int:
    """Scan working tree; report would-ship vs banned counts."""
    banned: list[str] = []
    shipped: list[str] = []

    for path in ROOT.rglob("*"):
        if not path.is_file():
            continue
        rel = str(path.relative_to(ROOT))
        # Skip hidden + build + .git
        rel_posix = rel.replace("\\", "/")
        if rel_posix.startswith(".git/") or rel_posix.startswith(".claude/") \
                or rel_posix.startswith("build/") or rel_posix.startswith("builds/"):
            continue
        is_b, reason = is_banned(rel)
        if is_b:
            banned.append(f"{rel}  ({reason})")
        else:
            shipped.append(rel)

    print(f"Files in scan: {len(banned) + len(shipped)}")
    print(f"  would ship: {len(shipped)}")
    print(f"  would block: {len(banned)}")
    if banned:
        print()
        print("Banned files (would NOT ship in public package):")
        for f in sorted(banned)[:30]:
            print(f"  - {f}")
        if len(banned) > 30:
            print(f"  ... ({len(banned) - 30} more)")
    return 0


def check_tarball(path: Path) -> int:
    """Open tarball; reject if any banned file is present."""
    import tarfile
    if not path.exists():
        print(f"ERROR: tarball not found: {path}", file=sys.stderr)
        return 1

    bad = []
    with tarfile.open(path, "r:*") as tf:
        for member in tf:
            if not member.isfile():
                continue
            is_b, reason = is_banned(member.name)
            if is_b:
                bad.append(f"{member.name}  ({reason})")

    if bad:
        print(f"REJECTED: {path.name} contains {len(bad)} banned files:")
        for b in bad:
            print(f"  - {b}")
        return 1
    print(f"OK: {path.name} clean for public release")
    return 0


def main() -> int:
    ap = argparse.ArgumentParser(prog="package_check.py")
    ap.add_argument("--tarball", type=Path,
                    help="check existing tarball instead of working tree")
    args = ap.parse_args()

    if args.tarball:
        return check_tarball(args.tarball)
    return scan_tree()


if __name__ == "__main__":
    sys.exit(main())
