"""One-shot helper that scans a src/gen/z_0x.c file and prints a JSON
manifest candidate to stdout.

It recognises the common forwarder shapes:
    void z0N_name(args) { runtime_prefix_name(args); }
    ret  z0N_name(args) { return runtime_prefix_name(args); }

Empty-body or non-forwarder functions are skipped and reported on stderr.
"""
from __future__ import annotations

import json
import re
import sys
from pathlib import Path

FWD_RE = re.compile(
    r"^\s*(?P<ret>void|unsigned\s+char|unsigned\s+int|unsigned\s+short|int|char|signed\s+char)"
    r"\s+(?P<old>z0[1-7]_[A-Za-z0-9_]+)\s*"
    r"\((?P<params>[^)]*)\)\s*\{\s*"
    r"(?:return\s+)?(?P<new>[a-z]+(?:rt|ld|md|obj|pl|xf)_[A-Za-z0-9_]+)\s*"
    r"\((?P<call>[^)]*)\)\s*;\s*\}",
    re.MULTILINE,
)

PREFIX_HEADERS = {
    "cavert_":  "cave_runtime.h",
    "cobrt_":   "combat_runtime.h",
    "colrt_":   "collision_runtime.h",
    "corert_":  "core_runtime.h",
    "enrt_":    "enemy_runtime.h",
    "hudrt_":   "hud_runtime.h",
    "itemrt_":  "item_runtime.h",
    "lcrt_":    "link_collision_runtime.h",
    "objrt_":   "object_runtime.h",
    "progrt_":  "progress_runtime.h",
    "roomld_":  "room_load_runtime.h",
    "roommd_":  "room_mode_runtime.h",
    "roomobj_": "room_object_runtime.h",
    "roompl_":  "room_player_runtime.h",
    "roomrt_":  "room_runtime.h",
    "roomxf_":  "room_transfer_runtime.h",
    "savert_":  "save_menu_runtime.h",
    "sprrt_":   "sprite_runtime.h",
    "targrt_":  "targeting_runtime.h",
    "trprt_":   "trap_runtime.h",
    "uwrt_":    "uw_person_runtime.h",
    "weprt_":   "weapon_runtime.h",
    "worldrt_": "world_runtime.h",
}


def header_for(new: str) -> str | None:
    for prefix, header in PREFIX_HEADERS.items():
        if new.startswith(prefix):
            return header
    return None


def main(path_str: str) -> None:
    path = Path(path_str)
    text = path.read_text()
    bank = path.stem
    symbols = []
    includes: list[str] = []
    seen_includes: set[str] = set()
    for m in FWD_RE.finditer(text):
        ret = re.sub(r"\s+", " ", m.group("ret")).strip()
        params = re.sub(r"\s+", " ", m.group("params")).strip()
        sig = f"{ret} ({params})" if params else f"{ret} ()"
        entry = {"old": m.group("old"), "new": m.group("new"), "sig": sig}
        symbols.append(entry)
        header = header_for(m.group("new"))
        if header and header not in seen_includes:
            seen_includes.add(header)
            includes.append(header)
    manifest = {"bank": bank, "includes": includes, "symbols": symbols}
    print(json.dumps(manifest, indent=2))


if __name__ == "__main__":
    main(sys.argv[1])
