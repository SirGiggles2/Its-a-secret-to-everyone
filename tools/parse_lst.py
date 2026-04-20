#!/usr/bin/env python3
"""
Parse builds/whatif.lst and emit tools/cycle_profile_buckets.json.

For each target bucket symbol:
  - resolve the label to its instruction address (entry_addr)
  - scan the whole listing for `jsr SYM` / `bsr SYM` call sites
  - record each call site's return address (addr of next instruction)

Output JSON is consumed by tools/cycle_probe.lua.

Invariants about the .lst format (vasm-style):
  - Address lines:   `02:00000422 48E7FFFE        \t   450:     movem.l ...`
  - Label-only lines: `                            \t   449: VBlankISR:`
  - Label maps to address of the next instruction line in the same section.
  - jsr/bsr instructions' return address is the address of the next
    instruction line (works across .s/.w/.l variants and local labels).
"""

import json
import re
import sys
from pathlib import Path

# Hand-curated bucket list from the plan. Keep in sync with cycle_probe.lua.
# Tier values are informational; all tiers get hooks.
TARGET_SYMBOLS = [
    # T1 — must hook
    ("VBlankISR",                            "T1"),
    ("IsrNmi",                               "T1"),
    ("UpdateMode",                           "T1"),
    # T2 — recommended
    ("TransferCurTileBuf",                   "T2"),
    ("music_tick",                           "T2"),
    # T3 — deeper buckets
    ("UpdatePlayer",                         "T3"),
    ("UpdateObject",                         "T3"),
    ("CheckMonsterCollisions",               "T3"),
    ("MoveObject",                           "T3"),
    # T4 — walker-AI callees (primary suspects for /mathproblem cost)
    ("Walker_Move",                          "T4"),
    ("Walker_CheckTileCollision",            "T4"),
    ("UpdateMoblin",                         "T4"),
    ("UpdateArrowOrBoomerang",               "T4"),
    ("AnimateAndDrawObjectWalking",          "T4"),
    ("AddQSpeedToPositionFraction",          "T4"),
    ("SubQSpeedFromPositionFraction",        "T4"),
    ("TryNextDir",                           "T4"),
    ("GetCollidableTile",                    "T4"),
    # Deriveds (subtract from parents)
    ("_oam_dma_flush",                       "derived"),
    ("_ags_flush",                           "derived"),
    ("_ags_prearm",                          "derived"),
    ("DriveAudio",                           "derived"),
]

# Symbols reached via vector table / tail-jmp (no jsr/bsr call sites).
# For these, we need a single explicit exit hook (the rte/rts). Limited
# to interrupt handlers because normal functions with no call sites are
# typically tail-jmp targets with multi-exit paths.
INTERRUPT_HANDLERS = {"VBlankISR"}

ADDR_LINE = re.compile(
    r'^(\d\d):([0-9A-Fa-f]{8})\s+[0-9A-Fa-f ]+?\s*\t\s*(\d+):\s?(.*)$'
)
# Label lines have empty address column. The listing left-pads the
# address area with spaces before the TAB + line-number column.
NOCODE_LINE = re.compile(r'^\s{20,}\t\s*(\d+):\s?(.*)$')

LABEL_RE = re.compile(r'^([A-Za-z_][\w]*):\s*(?:;.*)?$')
# Capture both jsr and bsr. Match the callee exactly (word-boundary).
CALL_RE = re.compile(r'^\s*(jsr|bsr)(?:\.[swl])?\s+([A-Za-z_][\w]*)\b')
SOURCE_RE = re.compile(r'^Source:\s*"(.+)"\s*$')
RTE_RE = re.compile(r'^\s*rte\b')
RTS_RE = re.compile(r'^\s*rts\b')


def parse(lst_path: Path):
    """Stream the .lst and return (insts, labels).

    insts: list of dicts with keys section, addr, content, src, src_line, idx
    labels: dict name -> (section, addr)
    """
    insts = []
    pending_labels = []
    cur_source = ""
    labels = {}

    with lst_path.open("r", encoding="utf-8", errors="replace") as fh:
        for raw in fh:
            line = raw.rstrip("\r\n")

            m = SOURCE_RE.match(line)
            if m:
                cur_source = m.group(1)
                continue

            m = ADDR_LINE.match(line)
            if m:
                section = m.group(1)
                addr = int(m.group(2), 16)
                src_line = int(m.group(3))
                content = m.group(4)
                # Flush pending labels to this address.
                for label in pending_labels:
                    if label not in labels:
                        labels[label] = (section, addr)
                pending_labels = []
                insts.append({
                    "section": section,
                    "addr": addr,
                    "content": content,
                    "src": cur_source,
                    "src_line": src_line,
                    "idx": len(insts),
                })
                continue

            m = NOCODE_LINE.match(line)
            if m:
                content = m.group(2)
                # Is this a label-only line?
                lm = LABEL_RE.match(content)
                if lm:
                    pending_labels.append(lm.group(1))
                continue

    return insts, labels


def build_bucket_config(insts, labels):
    """For each TARGET symbol, gather entry + call sites."""
    # Index instructions by section for fast next-inst lookup.
    inst_by_idx = insts  # already sequential
    sym_set = {name for name, _ in TARGET_SYMBOLS}

    buckets = []
    missing = []

    for name, tier in TARGET_SYMBOLS:
        entry = labels.get(name)
        if entry is None:
            missing.append(name)
            continue
        entry_section, entry_addr = entry

        call_sites = []
        for i, inst in enumerate(inst_by_idx):
            m = CALL_RE.match(inst["content"])
            if not m:
                continue
            if m.group(2) != name:
                continue
            # Return address = address of next instruction in same section,
            # or fall back to call_addr + length(hex bytes).
            ret_addr = None
            for j in range(i + 1, len(inst_by_idx)):
                nxt = inst_by_idx[j]
                if nxt["section"] == inst["section"]:
                    ret_addr = nxt["addr"]
                    break
            if ret_addr is None:
                # End of section; skip this call site (no hookable return).
                continue
            call_sites.append({
                "caller_src": inst["src"],
                "caller_line": inst["src_line"],
                "call_addr": inst["addr"],
                "return_addr": ret_addr,
                "mnemonic": m.group(1),
            })

        # Interrupt handlers (reached via vector table) have no call sites
        # — hook their single rte as the exit. Normal functions with no
        # call sites are tail-jmp targets with ambiguous exits; skip them.
        exit_addr = None
        exit_kind = None
        entry_idx = None
        for i, inst in enumerate(inst_by_idx):
            if (inst["section"] == entry_section
                    and inst["addr"] == entry_addr):
                entry_idx = i
                break
        if entry_idx is not None and not call_sites and name in INTERRUPT_HANDLERS:
            for j in range(entry_idx, min(entry_idx + 200,
                                          len(inst_by_idx))):
                nxt = inst_by_idx[j]
                if nxt["section"] != entry_section:
                    break
                if RTE_RE.match(nxt["content"]):
                    exit_addr = nxt["addr"]
                    exit_kind = "rte"
                    break

        # Static instruction count — from entry_idx up to first rts/rte
        # or first jmp-out at column zero. Used by the reporter to
        # convert call-count into approximate cycle cost.
        static_insts = 0
        if entry_idx is not None:
            for j in range(entry_idx, min(entry_idx + 1000,
                                          len(inst_by_idx))):
                nxt = inst_by_idx[j]
                if nxt["section"] != entry_section:
                    break
                static_insts += 1
                if (RTE_RE.match(nxt["content"])
                        or RTS_RE.match(nxt["content"])):
                    break

        buckets.append({
            "name": name,
            "tier": tier,
            "entry_addr": entry_addr,
            "entry_section": entry_section,
            "call_sites": call_sites,
            "exit_addr": exit_addr,
            "exit_kind": exit_kind,
            "static_insts": static_insts,
        })

    return buckets, missing


def emit_lua(cfg):
    """Emit a Lua module that assigns global `cycle_profile_buckets`.

    Consumed by tools/cycle_probe.lua via dofile() (BizHawk-friendly
    pattern; require() is unreliable there — see boot_sequence.lua).
    """
    lines = []
    lines.append("-- Generated by tools/parse_lst.py. Do not edit by hand.")
    lines.append(f"-- Source: {cfg['lst_file']}")
    lines.append("cycle_profile_buckets = {")
    for b in cfg["buckets"]:
        lines.append(f"  {{")
        lines.append(f"    name = {lua_str(b['name'])},")
        lines.append(f"    tier = {lua_str(b['tier'])},")
        lines.append(f"    entry_addr = 0x{b['entry_addr']:08X},")
        lines.append(f"    static_insts = {b['static_insts']},")
        if b["exit_addr"] is not None:
            lines.append(f"    exit_addr = 0x{b['exit_addr']:08X},")
            lines.append(f"    exit_kind = {lua_str(b['exit_kind'])},")
        lines.append(f"    call_sites = {{")
        for cs in b["call_sites"]:
            lines.append(
                f"      {{ call_addr = 0x{cs['call_addr']:08X}, "
                f"return_addr = 0x{cs['return_addr']:08X}, "
                f"caller_src = {lua_str(cs['caller_src'])}, "
                f"caller_line = {cs['caller_line']}, "
                f"mnemonic = {lua_str(cs['mnemonic'])} }},"
            )
        lines.append(f"    }},")
        lines.append(f"  }},")
    lines.append("}")
    if cfg["missing_symbols"]:
        lines.append(
            "cycle_profile_missing = { "
            + ", ".join(lua_str(s) for s in cfg["missing_symbols"])
            + " }"
        )
    else:
        lines.append("cycle_profile_missing = {}")
    lines.append("")
    return "\n".join(lines)


def lua_str(s):
    escaped = s.replace("\\", "\\\\").replace('"', '\\"')
    return f'"{escaped}"'


def main():
    if len(sys.argv) < 2:
        lst = Path("builds/whatif.lst")
    else:
        lst = Path(sys.argv[1])
    if not lst.exists():
        print(f"error: {lst} not found", file=sys.stderr)
        sys.exit(1)

    json_path = Path("tools/cycle_profile_buckets.json")
    lua_path = Path("tools/cycle_profile_buckets.lua")
    if len(sys.argv) >= 3:
        json_path = Path(sys.argv[2])
        lua_path = json_path.with_suffix(".lua")

    insts, labels = parse(lst)
    buckets, missing = build_bucket_config(insts, labels)

    cfg = {
        "lst_file": str(lst),
        "buckets": buckets,
        "missing_symbols": missing,
    }
    json_path.write_text(json.dumps(cfg, indent=2), encoding="utf-8")
    lua_path.write_text(emit_lua(cfg), encoding="utf-8")

    # Human-readable summary to stdout.
    print(f"Parsed {len(insts)} instructions, {len(labels)} labels from {lst}")
    print(f"Wrote {json_path}")
    print(f"Wrote {lua_path}")
    print()
    print(f"{'Bucket':<30} {'Tier':<8} {'Entry':<10}  {'Calls':>5}  "
          f"{'Insts':>5}  {'Exit':<16}")
    print("-" * 90)
    for b in buckets:
        exit_str = ""
        if b["exit_addr"] is not None:
            exit_str = f"${b['exit_addr']:08X} ({b['exit_kind']})"
        elif not b["call_sites"]:
            exit_str = "— blind (tail-jmp)"
        print(f"{b['name']:<30} {b['tier']:<8} "
              f"${b['entry_addr']:08X}  {len(b['call_sites']):>5}  "
              f"{b['static_insts']:>5}  {exit_str}")
    if missing:
        print()
        print(f"WARNING: {len(missing)} symbols not found: {missing}")


if __name__ == "__main__":
    main()
