"""Automatic NES cut list for asm_equiv: the code reachable from root labels.

Starting at the roots, every global label referenced by an included block
(operands of instructions and of .ADDR/.BYTE/.WORD data) is included, with:
  - fall-through: a block whose last statement is not RTS/RTI/JMP pulls in
    the block after it;
  - branch span: a conditional branch to another global label of the same
    file pulls in every block in between (keeps branches in range);
  - data runs: a data block pulls in the data blocks after it (tables
    are indexed past their end);
  - anonymous labels: a block using ":-" / ":+" pulls in the block
    before / after (the ":" it binds to may sit across a global label);
  - cross-bank trampolines (*_Bank<n> that call SwitchBank) stop unless a
    same-bank branch targets them;
  - stop labels (stubs, or names the spec stops at) are never included; the
    runner auto-stubs them as "unexpected" unless asm_stubs define them.
Blocks are emitted in file order, adjacent blocks merged into one run.
"""
from __future__ import annotations

import re
from pathlib import Path

LABEL = re.compile(r"^([A-Za-z_][A-Za-z0-9_]*):")
IDENT = re.compile(r"(?<![@\w])[A-Za-z_][A-Za-z0-9_]*")   # not @local
TRAMPOLINE = re.compile(r"_Bank\d+$")
BRANCHES = {"BCC", "BCS", "BEQ", "BNE", "BMI", "BPL", "BVC", "BVS"}
ENDS = {"RTS", "RTI", "JMP"}
SKIP_DIRECTIVES = (".SEGMENT", ".IMPORT", ".EXPORT", ".INCLUDE")
DATA = (".ADDR", ".BYTE", ".WORD", ".DBYT", ".LOBYTES", ".HIBYTES", ".INCBIN", ".RES")


# Raw JMP/JSR bytes ("Unknown block" in the disassembly) whose absolute
# target only resolves in the real ROM layout, mapped to the label at that
# address. Evidence: reference/Disassembly by Trax.
RAW_TARGETS = {
    0xEEB8: "Obj_Shove",     # zelda1bank7.txt 1EEB8: LDA $C0,X (Obj_Shove)
}
RAW_JUMP = re.compile(r"^(\s*)\.BYTE \$(4C|20), \$([0-9A-F]{2}), \$([0-9A-F]{2})\s*(;.*)?$")


def patch_raw(line: str) -> str:
    m = RAW_JUMP.match(line)
    if not m:
        return line
    target = RAW_TARGETS.get(int(m.group(4) + m.group(3), 16))
    if target is None:
        return line
    op = "JMP" if m.group(2) == "4C" else "JSR"
    return f"{m.group(1)}{op} {target}    ; raw ${m.group(4)}{m.group(3)} (closure.RAW_TARGETS)"


class Bank:
    def __init__(self, path: Path):
        self.name = path.name
        self.lines = [patch_raw(l) for l in path.read_text(encoding="latin-1").splitlines()]
        self.labels: list[tuple[int, str]] = [
            (k, m.group(1)) for k, l in enumerate(self.lines) if (m := LABEL.match(l))]
        self.index = {name: n for n, (_, name) in enumerate(self.labels)}

    def block(self, n: int) -> tuple[int, int]:
        start = self.labels[n][0]
        end = self.labels[n + 1][0] if n + 1 < len(self.labels) else len(self.lines)
        return start, end

    def is_data(self, n: int) -> bool:
        ops = [op for op, _ in self.statements(n) if not op.startswith(SKIP_DIRECTIVES)]
        return bool(ops) and all(op.startswith(".") for op in ops)

    def statements(self, n: int):
        """(mnemonic or directive, operand text) per statement of block n."""
        a, b = self.block(n)
        for k in range(a, b):
            t = self.lines[k].split(";", 1)[0].strip()
            m = LABEL.match(t)
            if m:
                t = t[m.end():].strip()
            while t.startswith("@") or t.startswith(":"):
                # local / anonymous label prefix ("@Loop:", ":")
                mm = re.match(r"^(@\w+:|:)\s*", t)
                if not mm:
                    break
                t = t[mm.end():]
            if not t:
                continue
            op, _, rest = t.partition(" ")
            yield op.upper(), rest.strip()


def closure(ref: Path, files: list[str], roots: list[str], stop: set[str]):
    """Return [(file, first line, end line)] runs, in file order."""
    banks = {f: Bank(ref / f) for f in files}
    owners: dict[str, list[str]] = {}
    for f in files:
        for _, name in banks[f].labels:
            owners.setdefault(name, []).append(f)

    def resolve(name: str, prefer: str) -> str | None:
        fs = owners.get(name)
        if not fs:
            return None
        return prefer if prefer in fs else fs[0]

    # Cross-bank trampolines (Link_EndMoveAndAnimate_Bank4, ...) lead into
    # whole other subsystems; they stop the walk and trap if reached.
    # A *_Bank<n> label is a trampoline only if it switches banks
    # (IsDarkRoom_Bank4 is plain local code).
    tramp = set()
    for b in banks.values():
        for n, (_, name) in enumerate(b.labels):
            if TRAMPOLINE.search(name):
                lo, hi = b.block(n)
                if any("SwitchBank" in l.split(";", 1)[0] for l in b.lines[lo:hi]):
                    tramp.add(name)
    chosen: dict[str, set[int]] = {f: set() for f in files}
    work: list[tuple[str, int]] = []

    def add(f: str, n: int, branch: bool = False):
        # A same-bank branch must reach its target, trampoline or not.
        name = banks[f].labels[n][1]
        if name in stop or (name in tramp and not branch) or n in chosen[f]:
            return
        chosen[f].add(n)
        work.append((f, n))

    for r in roots:
        f = resolve(r, files[0])
        if f is None:
            raise RuntimeError(f"closure: root {r} not found in {files}")
        add(f, banks[f].index[r])

    while work:
        f, n = work.pop()
        bank = banks[f]
        last, code = None, False
        for op, rest in bank.statements(n):
            if op.startswith(".") and op in SKIP_DIRECTIVES:
                continue
            is_data = op.startswith(".")
            code |= not is_data
            if not is_data:
                last = op           # last instruction (trailing filler data ignored)
            for ident in IDENT.findall(rest):
                if ident in ("A", "X", "Y") or ident in stop:
                    continue
                g = resolve(ident, f)
                if g is None:
                    continue
                m = banks[g].index[ident]
                is_branch = op in BRANCHES and g == f
                add(g, m, is_branch)
                if is_branch:
                    for k in range(min(n, m), max(n, m) + 1):
                        add(f, k, True)
        if code and last not in ENDS and n + 1 < len(bank.labels):
            add(f, n + 1)
        # Tables are indexed past their end into the next table (Dodongo
        # frame images, shot bounce widths): a data block keeps the data
        # blocks that follow it.
        if not code and n + 1 < len(bank.labels) and bank.is_data(n + 1):
            add(f, n + 1)
        # Anonymous labels can cross a global label: ":-" may bind to a ":"
        # in the block before, ":+" to one in the block after.
        a, b = bank.block(n)
        text = "\n".join(l.split(";", 1)[0] for l in bank.lines[a:b])
        if ":-" in text and n > 0:
            add(f, n - 1)
        if ":+" in text and n + 1 < len(bank.labels):
            add(f, n + 1)

    # Bank-local labels defined in more than one chosen bank (e.g. "Exit")
    # are renamed in every bank but the first; references resolve to the
    # referencing bank first, so each bank's text is renamed on its own.
    seen: dict[str, str] = {}
    renames: dict[str, set[str]] = {f: set() for f in files}
    for f in files:
        for n in sorted(chosen[f]):
            name = banks[f].labels[n][1]
            if name in seen and seen[name] != f:
                renames[f].add(name)
            else:
                seen.setdefault(name, f)
    runs = []
    for f in files:
        bank = banks[f]
        cur = None
        for n in sorted(chosen[f]):
            a, b = bank.block(n)
            if cur and cur[2] == a:
                cur[2] = b
            else:
                cur = [f, a, b, renames[f]]
                runs.append(cur)
    return [tuple(r) for r in runs]


def emit(ref: Path, runs) -> list[tuple[str, str]]:
    out = []
    cache: dict[str, list[str]] = {}
    for f, a, b, ren in runs:
        lines = cache.setdefault(f, [patch_raw(l) for l in
                                     (ref / f).read_text(encoding="latin-1").splitlines()])
        body = [l for l in lines[a:b] if not l.lstrip().upper().startswith(SKIP_DIRECTIVES)]
        if ren:
            tag = f.split(".")[0]
            pat = re.compile(r"(?<![@\w])(" + "|".join(map(re.escape, sorted(ren))) + r")\b")
            body = [pat.sub(lambda m: f"{m.group(1)}__{tag}", l.split(";", 1)[0]) for l in body]
        out.append((f"; ---- {f} lines {a + 1}..{b} (closure)", "\n".join(body) + "\n"))
    return out
