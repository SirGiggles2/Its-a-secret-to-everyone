"""drain_finalize.py — one-shot integration for drained asm functions.

Given a plan (JSON) describing which asm bodies have been ported to C,
this script performs the FULL integration pass:

  1. Updates tools/gen_wrappers/<bank>_manifest.json
  2. Regenerates src/gen/<bank>.c via emit_gen_wrappers.py
  3. Appends c_<name> entry shims (+ xdefs) to src/c_shims.asm
  4. Rewrites src/zelda_translated/<bank>.asm, replacing drained bodies
     with `jmp c_<name>` trampolines (or deleting dead data/helpers)
  5. (optional) Runs build.bat and reports result

Plan format (JSON):
  {
    "bank": "z_04",
    "entries": [
      {
        "name":   "UpdateBlock",            # asm label
        "target": "enrt_update_block",       # C runtime function
        "sig":    "void (unsigned int slot)",# C signature (for wrappers)
        "kind":   "jmp"                       # "jmp" or "delete"
      },
      {
        "name":   "BlockPushDirections",
        "kind":   "delete"                    # data table, no trampoline
      },
      ...
    ]
  }

Usage:
  python tools/drain_finalize.py --plan drain_plan.json
  python tools/drain_finalize.py --plan drain_plan.json --build

Idempotent: re-running with the same plan is safe (duplicate symbols in
manifest are detected and skipped; duplicate shims likewise).
"""

from __future__ import annotations

import argparse
import json
import re
import subprocess
import sys
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parent.parent
SHIMS = ROOT / "src" / "c_shims.asm"
MANIFEST_DIR = ROOT / "tools" / "gen_wrappers"
GEN_DIR = ROOT / "src" / "gen"
ASM_DIR = ROOT / "src" / "zelda_translated"


# -----------------------------------------------------------------------------
# Shim generation
# -----------------------------------------------------------------------------

SIG_RE = re.compile(r"^\s*(?P<ret>[a-z ]+?)\s*\(\s*(?P<args>.*?)\s*\)\s*$")


def parse_sig(sig: str) -> tuple[str, list[str]]:
    """Return (ret_type, arg_type_list). 'void' args -> []."""
    m = SIG_RE.match(sig)
    if not m:
        raise ValueError(f"bad signature: {sig!r}")
    ret = re.sub(r"\s+", " ", m.group("ret")).strip()
    args = m.group("args").strip()
    if not args or args == "void":
        return ret, []
    out = []
    for part in args.split(","):
        part = part.strip()
        tokens = part.split()
        # drop trailing arg name
        atype = " ".join(tokens[:-1]) if len(tokens) > 1 else part
        out.append(atype.strip())
    return ret, out


def emit_shim(c_name: str, z_name: str, sig: str, arg_regs: list[str] | None = None) -> str:
    """Generate an entry shim body.

    Conventions:
      - void (void): bare jsr + rts
      - void (unsigned int): arg from D2 register (NES X-slot)
      - void (unsigned int, unsigned int): first from stack(4), second from D2
      - unsigned int (unsigned int): carry-returning; sets CCR.C/X from bit 8
        of return value (0x100 = set).

    arg_regs (optional): override default register source per arg, e.g.
      ["D0"] for a single-arg fn that takes its arg in D0 instead of D2.
      Length must match arg count. Used when asm callers pass via D0.
    """
    ret, args = parse_sig(sig)
    pushes: list[str] = []
    arg_count = len(args)
    if arg_regs is None:
        arg_regs = []
    if arg_regs and len(arg_regs) != arg_count:
        raise ValueError(f"arg_regs length {len(arg_regs)} != arg count {arg_count}")

    if arg_count == 0:
        body = [f"    jsr     {z_name}", "    rts"]
    elif arg_count == 1:
        src = arg_regs[0] if arg_regs else "D2"
        # Use D1 as scratch so we never clobber the source register before
        # reading it (e.g. arg_regs=["D0"]).
        body = [
            "    moveq   #0,D1",
            f"    move.w  {src},D1",
            "    move.l  D1,-(SP)",
            f"    jsr     {z_name}",
            "    addq.l  #4,SP",
        ]
        if ret == "unsigned int":
            body += [
                "    btst    #8,D0",
                "    beq.s   ._no_carry_" + c_name,
                "    ori.b   #$11,CCR",
                "    bra.s   ._done_" + c_name,
                "._no_carry_" + c_name + ":",
                "    andi.b  #$EE,CCR",
                "._done_" + c_name + ":",
            ]
        body.append("    rts")
    elif arg_count == 2:
        s1 = arg_regs[0] if arg_regs else "D0"
        s2 = arg_regs[1] if arg_regs else "D2"
        # M68K SysV: args pushed right-to-left → arg2 pushed first (lower
        # on memory after both pushes? no — last push is at lowest addr; so
        # arg1 must be LAST push to land at SP+4 inside callee).
        body = [
            "    moveq   #0,D1",
            f"    move.w  {s2},D1",
            "    move.l  D1,-(SP)",       # arg2 pushed first → SP+8 inside callee
            "    moveq   #0,D1",
            f"    move.w  {s1},D1",
            "    move.l  D1,-(SP)",       # arg1 pushed last  → SP+4 inside callee
            f"    jsr     {z_name}",
            "    addq.l  #8,SP",
            "    rts",
        ]
    else:
        raise ValueError(f"unsupported arg count for shim {c_name}: {arg_count}")

    return f"{c_name}:\n" + "\n".join(body) + "\n"


# -----------------------------------------------------------------------------
# Manifest
# -----------------------------------------------------------------------------


def update_manifest(bank: str, entries: list[dict[str, Any]]) -> int:
    path = MANIFEST_DIR / f"{bank}_manifest.json"
    data = json.loads(path.read_text())
    existing = {s["old"] for s in data.get("symbols", [])}
    added = 0
    for e in entries:
        if e.get("kind") != "jmp":
            continue
        old = f"{bank.replace('_', '')}_{snake(e['name'])}"
        if old in existing:
            continue
        data.setdefault("symbols", []).append(
            {"old": old, "new": e["target"], "sig": e["sig"]}
        )
        existing.add(old)
        added += 1
    path.write_text(json.dumps(data, indent=2) + "\n")
    return added


def snake(name: str) -> str:
    """CamelCase -> camel_case; keep leading 'L_' / digit segments intact."""
    # Preserve existing underscores, insert between lower-upper transitions.
    s = re.sub(r"([a-z0-9])([A-Z])", r"\1_\2", name)
    s = re.sub(r"([A-Z]+)([A-Z][a-z])", r"\1_\2", s)
    return s.lower()


# -----------------------------------------------------------------------------
# Gen forwarders
# -----------------------------------------------------------------------------


def regen_wrappers(bank: str) -> None:
    emit = ROOT / "tools" / "emit_gen_wrappers.py"
    subprocess.run(
        [sys.executable, str(emit), "--bank", bank],
        check=True,
        cwd=ROOT,
    )


# -----------------------------------------------------------------------------
# c_shims.asm
# -----------------------------------------------------------------------------


def update_shims(bank: str, entries: list[dict[str, Any]]) -> tuple[int, int]:
    text = SHIMS.read_text()
    added_xdef = 0
    added_body = 0
    jmp_entries = [e for e in entries if e.get("kind") == "jmp"]

    # ---- xdefs: insert the new block of xdef lines before the first blank
    # line that follows the existing xdef block. Detect the last `xdef`
    # occurrence and append immediately after it.
    xdef_lines = []
    for e in jmp_entries:
        c_name = "c_" + snake(e["name"])
        if re.search(rf"^\s*xdef\s+{re.escape(c_name)}\b", text, re.MULTILINE):
            continue
        xdef_lines.append(f"    xdef    {c_name}")
        added_xdef += 1

    if xdef_lines:
        # Find the last existing xdef and insert after it.
        last = None
        for m in re.finditer(r"^\s*xdef\s+[A-Za-z_]\w*.*$", text, re.MULTILINE):
            last = m
        if last is None:
            raise RuntimeError("no existing xdef found in c_shims.asm")
        insert_at = last.end()
        text = text[:insert_at] + "\n" + "\n".join(xdef_lines) + text[insert_at:]

    # ---- shim bodies: append at EOF (idempotent via symbol check).
    body_blocks = []
    for e in jmp_entries:
        c_name = "c_" + snake(e["name"])
        z_name = f"{bank.replace('_', '')}_{snake(e['name'])}"
        if re.search(rf"^{re.escape(c_name)}:", text, re.MULTILINE):
            continue
        body_blocks.append(emit_shim(c_name, z_name, e["sig"], e.get("arg_regs")))
        added_body += 1

    if body_blocks:
        banner = (
            "\n;==============================================================================\n"
            f"; drain_finalize: {bank} drained entry shims\n"
            ";==============================================================================\n"
        )
        text += banner + "\n".join(body_blocks)

    SHIMS.write_text(text)
    return added_xdef, added_body


# -----------------------------------------------------------------------------
# Asm rewrite
# -----------------------------------------------------------------------------

LABEL_RE = re.compile(r"^([A-Za-z_][A-Za-z0-9_]*):")
LOCAL_PREFIXES = ("_anon_", "_L_", "__far_", "__local_")


def rewrite_asm(bank: str, entries: list[dict[str, Any]]) -> int:
    path = ASM_DIR / f"{bank}.asm"
    src = path.read_text().splitlines()

    # Public-label index
    public_lines: list[tuple[int, str]] = []
    for i, line in enumerate(src):
        m = LABEL_RE.match(line)
        if not m:
            continue
        n = m.group(1)
        if n.startswith(LOCAL_PREFIXES):
            continue
        public_lines.append((i, n))

    ranges: dict[str, tuple[int, int]] = {}
    for j, (idx, name) in enumerate(public_lines):
        end = public_lines[j + 1][0] if j + 1 < len(public_lines) else len(src)
        ranges[name] = (idx, end)

    delete_lines: set[int] = set()
    replace_at: dict[int, list[str]] = {}
    touched = 0

    for e in entries:
        name = e["name"]
        kind = e.get("kind")
        if name not in ranges:
            print(f"WARN: label {name} not found in {path.name}")
            continue
        # If already a trampoline, skip
        a, b = ranges[name]
        body_preview = "\n".join(src[a:min(a + 4, b)])
        if re.search(r"^\s*jmp\s+c_", body_preview, re.MULTILINE) and kind == "jmp":
            # Already drained
            continue

        end = b
        while end > a + 1 and src[end - 1].strip() == "":
            end -= 1
        if end > a + 1 and src[end - 1].strip().lower() == "even":
            end -= 1

        for k in range(a, end):
            delete_lines.add(k)

        if kind == "jmp":
            c_name = "c_" + snake(name)
            replace_at[a] = [f"{name}:", f"    jmp     {c_name}"]
        touched += 1

    out = []
    for i, line in enumerate(src):
        if i in replace_at:
            out.extend(replace_at[i])
            continue
        if i in delete_lines:
            continue
        out.append(line)

    if touched:
        path.write_text("\n".join(out) + "\n")
        print(
            f"{path.name}: {len(src)} -> {len(out)} lines "
            f"({touched} entries processed)"
        )
    return touched


# -----------------------------------------------------------------------------
# Transpiler stub registration (CRITICAL — without this, build.bat reruns
# tools/transpile_6502.py which regenerates the asm and wipes our rewrites).
# -----------------------------------------------------------------------------

TRANSPILER = ROOT / "tools" / "transpile_6502.py"

# Marker comment + insertion anchor per bank. Anchor = the literal text
# immediately preceding the `with open(path, 'w'...` write at the end of
# each `_patch_z??` function. New _stub_func calls are inserted before it.
PATCH_ANCHORS: dict[str, str] = {
    "z_02": "    # --- Batch 38 ---\n    text = _stub_func(text, 'InitDemoSubphasePlayTitleSong'",
    "z_04": "    # Export ROM data tables referenced by C code\n    if 'xdef    PolsVoiceWalkSpeedsX'",
    "z_05": "    # --- Batch 54 ---\n    # Sub4 references _anon_z05_151 defined inside Sub3",
}


def update_transpiler(bank: str, entries: list[dict[str, Any]], plan_tag: str) -> int:
    """Append `_stub_func(text, '<Label>', '<c_name>')` calls to the bank's
    `_patch_z??` function in tools/transpile_6502.py so trampolines survive
    re-transpilation. Idempotent (skips lines already present)."""
    if bank not in PATCH_ANCHORS:
        print(f"  WARNING: no transpiler patch anchor for bank={bank}; "
              f"trampolines will be wiped on next build")
        return 0

    text = TRANSPILER.read_text()
    lines: list[str] = [
        f"\n    # --- {plan_tag} ---",
    ]
    added = 0
    for e in entries:
        if e.get("kind") != "jmp":
            continue
        name = e["name"]
        c_shim = "c_" + snake(name)
        # Idempotency: skip if already present
        marker = f"_stub_func(text, '{name}',"
        if marker in text:
            continue
        lines.append(f"    text = _stub_func(text, '{name}', '{c_shim}')")
        added += 1
    if added == 0:
        return 0

    block = "\n".join(lines) + "\n\n"
    # Find anchor in the bank's _patch function and insert before it.
    func_marker = f"def _patch_{bank.replace('_', '')}(path):"
    func_idx = text.find(func_marker)
    if func_idx < 0:
        # try alternate (e.g. _patch_z04)
        func_marker = f"def _patch_{bank}(path):".replace("z_", "z")
        func_idx = text.find(func_marker)
    if func_idx < 0:
        raise RuntimeError(f"_patch function for {bank} not found in transpiler")
    anchor = PATCH_ANCHORS[bank]
    anchor_idx = text.find(anchor, func_idx)
    if anchor_idx < 0:
        raise RuntimeError(f"transpiler anchor for {bank} not found "
                           f"(does the file structure still match?)")
    text = text[:anchor_idx] + block + text[anchor_idx:]
    TRANSPILER.write_text(text)
    return added


# -----------------------------------------------------------------------------
# Build
# -----------------------------------------------------------------------------


def run_build() -> int:
    r = subprocess.run(
        ["powershell", "-Command", "& cmd.exe /c '.\\build.bat 2>&1'"],
        cwd=ROOT,
        capture_output=True,
        text=True,
    )
    tail = (r.stdout or "").splitlines()[-25:]
    print("\n".join(tail))
    return r.returncode


# -----------------------------------------------------------------------------
# Entry
# -----------------------------------------------------------------------------


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--plan", required=True, help="path to JSON plan file")
    ap.add_argument("--build", action="store_true", help="run build.bat after")
    args = ap.parse_args()

    plan = json.loads(Path(args.plan).read_text())
    bank = plan["bank"]
    entries = plan["entries"]

    print(f"[drain_finalize] bank={bank} entries={len(entries)}")

    added_syms = update_manifest(bank, entries)
    print(f"  manifest: +{added_syms} symbols")

    regen_wrappers(bank)
    print(f"  gen/{bank}.c: regenerated")

    xdef_n, body_n = update_shims(bank, entries)
    print(f"  c_shims.asm: +{xdef_n} xdefs, +{body_n} bodies")

    touched = rewrite_asm(bank, entries)
    print(f"  {bank}.asm: {touched} entries rewritten")

    plan_tag = Path(args.plan).stem
    stubs = update_transpiler(bank, entries, plan_tag)
    print(f"  transpile_6502.py: +{stubs} _stub_func entries")

    if args.build:
        print("\n[drain_finalize] building ...")
        rc = run_build()
        if rc != 0:
            print(f"BUILD FAILED rc={rc}")
            return rc
    return 0


if __name__ == "__main__":
    sys.exit(main())
