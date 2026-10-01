"""Map every NES object type to its Genesis init/update handler.

    python tools/audit/object_dispatch_map.py [--md OUT]

NES side: InitObject_JumpTable and UpdateObject_JumpTable in
reference/aldonunez/Z_07.asm (one .ADDR per object type, from type $00).
Genesis side: enemy_init_fns / enemy_update_fns designated initializers in
src/game/enemies/enemy_loop.c ([0xNN] = fn, and GCC ranges [0xA ... 0xB]).

For each Genesis handler the script finds its C definition under src/ and
reports the body size in statements, so empty or tiny bodies stand out.
Flags:
  MISSING  NES routine is real work, Genesis row is NULL
  TINY     handler body has <= 2 statements (read it: stub or wrapper?)
  NODEF    handler name has no C definition (linked from asm or macro)
"""
from __future__ import annotations

import argparse
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
NES_ASM = ROOT / "reference" / "aldonunez" / "Z_07.asm"
LOOP_C = ROOT / "src" / "game" / "enemies" / "enemy_loop.c"

# NES routines that do nothing (an RTS-only label) need no Genesis handler.
NES_NOOP = {"DoNothing", "ObjectNoop", "InitObjectNoop", "UpdateObjectNoop", "ReturnFromInit"}


def nes_table(label: str) -> list[str]:
    lines = NES_ASM.read_text(encoding="utf-8", errors="replace").splitlines()
    start = next(i for i, l in enumerate(lines) if l.startswith(label + ":"))
    out: list[str] = []
    for l in lines[start + 1:]:
        s = l.split(";")[0].strip()
        if not s:
            continue
        m = re.match(r"\.ADDR\s+(.+)", s)
        if not m:
            break
        out += [a.strip() for a in m.group(1).split(",")]
    return out


def c_table(src: str, name: str) -> dict[int, str]:
    i = src.index(name + "[")
    body = src[src.index("{", i) + 1:]
    depth, end = 1, 0
    for end, ch in enumerate(body):
        depth += ch == "{"
        depth -= ch == "}"
        if depth == 0:
            break
    body = re.sub(r"/\*.*?\*/", "", body[:end], flags=re.S)
    body = re.sub(r"//[^\n]*", "", body)
    out: dict[int, str] = {}
    for m in re.finditer(r"\[\s*(0x[0-9A-Fa-f]+|\d+)\s*(?:\.\.\.\s*(0x[0-9A-Fa-f]+|\d+)\s*)?\]\s*=\s*(\w+)", body):
        a = int(m.group(1), 0)
        b = int(m.group(2), 0) if m.group(2) else a
        for t in range(a, b + 1):
            out[t] = m.group(3)
    return out


def c_defs() -> dict[str, tuple[str, int]]:
    """name -> (file, statement count) for every C function definition."""
    defs: dict[str, tuple[str, int]] = {}
    pat = re.compile(r"^[A-Za-z_][\w \*]*?\b(\w+)\s*\(([^;{}]*)\)\s*\{", re.M)
    for f in (ROOT / "src").rglob("*.c"):
        txt = f.read_text(encoding="utf-8", errors="replace")
        for m in pat.finditer(txt):
            name = m.group(1)
            if name in ("if", "while", "for", "switch", "return"):
                continue
            depth, j = 1, m.end()
            while j < len(txt) and depth:
                depth += txt[j] == "{"
                depth -= txt[j] == "}"
                j += 1
            body = re.sub(r"/\*.*?\*/", "", txt[m.end():j - 1], flags=re.S)
            body = re.sub(r"//[^\n]*", "", body)
            defs.setdefault(name, (str(f.relative_to(ROOT)).replace("\\", "/"),
                                   body.count(";")))
    return defs


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--md", type=Path)
    args = ap.parse_args()
    src = LOOP_C.read_text(encoding="utf-8", errors="replace")
    nes_init, nes_upd = nes_table("InitObject_JumpTable"), nes_table("UpdateObject_JumpTable")
    gen_init, gen_upd = c_table(src, "enemy_init_fns"), c_table(src, "enemy_update_fns")
    defs = c_defs()
    rows, counts = [], {"MISSING": 0, "TINY": 0, "NODEF": 0}
    for t in range(max(len(nes_init), len(nes_upd))):
        for kind, nes, gen in (("init", nes_init, gen_init), ("update", nes_upd, gen_upd)):
            n = nes[t] if t < len(nes) else "-"
            g = gen.get(t)
            flag, where = "", ""
            if g is None:
                if n not in NES_NOOP and n != "-":
                    flag = "MISSING"
            elif g not in defs:
                flag = "NODEF"
            else:
                where, st = defs[g]
                where = f"{where} ({st} stmts)"
                if st <= 2:
                    flag = "TINY"
            if flag:
                counts[flag] += 1
            rows.append(f"| ${t:02X} | {kind} | {n} | {g or '-'} | {where} | {flag} |")
    head = ["| Type | Kind | NES routine | Genesis handler | Definition | Flag |",
            "|---|---|---|---|---|---|"]
    text = "\n".join(head + rows)
    summary = " ".join(f"{k}={v}" for k, v in counts.items())
    if args.md:
        args.md.write_text(text + "\n\n" + summary + "\n", encoding="utf-8")
    print(text)
    print("DISPATCH:", summary)


if __name__ == "__main__":
    main()
