#!/usr/bin/env python3
"""asm_equiv.py - run original NES routines (6502) against their C ports.

Each spec in specs.py names NES routines cut verbatim from
reference/aldonunez/*.asm (label ranges), the C function that ports them
and a random-input generator. The 6502 side is assembled with ca65/ld65
and executed in py65; the C side is compiled with the host gcc into a
shared library. Both start from the same NES memory and share identical
callee stubs, so a difference is a port defect (or a documented,
spec-listed intentional divergence), not a callee difference.

Compared per case: NES RAM $0000-$07FF (except this harness's 6502 stack
$01C0-$01FF) and WRAM $6000-$7FFF byte for byte, the ordered callee log,
the returned A register when the spec says so, and any call into a callee
the spec did not expect (auto-stubbed on both sides, reported as a FAIL).

Requires: ca65 + ld65 (cc65), py65 (pip), host gcc + nm.
Usage:  python tools/audit/asm_equiv/asm_equiv.py [SPEC ...] [--cases N] [--seed S] [--list]
Exit 1 on any mismatch, unexpected call, or missing tool.
"""
from __future__ import annotations

import argparse
import ctypes
import random
import re
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
REF = ROOT / "reference" / "aldonunez"
HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))

MEM = 0x8000
H_LOG_IDX, H_CALL_IDX, H_UNEXP, H_LOG_BUF = 0x5000, 0x5001, 0x5004, 0x5100
STACK_LO = 0x1C0        # the harness enters with SP $FF; chains stay above
COMPARE = [r for r in (range(0x0000, STACK_LO), range(0x200, 0x800), range(0x6000, 0x8000))]

CORE_ASM = r"""
H_LOG_IDX  = $5000
H_CALL_IDX = $5001
H_TMPX     = $5002
H_TMPY     = $5003
H_UNEXP    = $5004
H_LOG_BUF  = $5100

Trap:
    NOP
SwitchBank:
    RTS
LogA:
    STY H_TMPY
    LDY H_LOG_IDX
    STA H_LOG_BUF, Y
    INC H_LOG_IDX
    LDY H_TMPY
    RTS
Unexpected:
    LDY H_UNEXP
    BNE :+
    STA H_UNEXP
:
    RTS
"""

LD_CFG = """MEMORY { ROM: start = $8000, size = $8000, fill = yes; }
SEGMENTS { CODE: load = ROM, type = ro; }
"""


def ref_lines(fname: str) -> list[str]:
    return (REF / fname).read_text(encoding="latin-1").splitlines()


def cut_range(fname: str, start: str, end: str) -> tuple[int, int]:
    lines = ref_lines(fname)
    i = next(k for k, l in enumerate(lines) if l.startswith(start))
    j = next(k for k in range(i + 1, len(lines)) if lines[k].startswith(end))
    return i, j


def merged_cuts(asm) -> list[tuple[str, str]]:
    """(header, text) per cut. Plain cuts (no prefix/suffix) of one file that
    overlap are merged into their union, so specs can compose shared cut
    lists without duplicate labels."""
    plain: list[list] = []          # [fname, i, j]
    out: list = []                  # (header, text) or a plain-cut ref
    for f, a, b, *extra in asm:
        pre, post = (extra + ["", ""])[:2] if extra else ("", "")
        i, j = cut_range(f, a, b)
        if pre or post:
            text = "\n".join(ref_lines(f)[i:j]) + "\n"
            out.append((f"; ---- {f} {a} .. {b}", pre + text + post))
            continue
        for c in plain:
            if c[0] == f and i < c[2] and c[1] < j:
                c[1], c[2] = min(c[1], i), max(c[2], j)
                break
        else:
            c = [f, i, j]
            plain.append(c)
            out.append(c)
    # A merge can make two earlier plain cuts overlap; fold until stable.
    changed = True
    while changed:
        changed = False
        for x in plain:
            for y in plain:
                if x is not y and x[0] == y[0] and x[1] < y[2] and y[1] < x[2] and x[1] <= y[1]:
                    x[2] = max(x[2], y[2])
                    plain.remove(y)
                    out.remove(y)
                    changed = True
                    break
            if changed:
                break
    res = []
    for c in out:
        if isinstance(c, list):
            lines = ref_lines(c[0])
            res.append((f"; ---- {c[0]} lines {c[1] + 1}..{c[2]}",
                        "\n".join(lines[c[1]:c[2]]) + "\n"))
        else:
            res.append(c)
    return res


def asm_source(spec, auto: list[str]) -> str:
    src = ['.INCLUDE "Variables.inc"', '.INCLUDE "CommonVars.inc"']
    src += [f'.INCLUDE "{inc}"' for inc in spec.get("incs", [])]
    src += ['.SEGMENT "CODE"', CORE_ASM, spec.get("asm_stubs", "")]
    for k, name in enumerate(auto, start=1):
        src.append(f"{name}:\n    LDA #${k:02X}\n    JMP Unexpected")
    for header, text in merged_cuts(spec.get("asm", [])):
        src.append(f"{header}\n{text}")
    if spec.get("closure"):
        src += [f"{h}\n{t}" for h, t in closure_cuts(spec)]
    return "\n".join(src)


def closure_cuts(spec) -> list[tuple[str, str]]:
    """Automatic cut list (closure.py) from spec["closure"]:
    {"files": [...], "roots": [...], "stop": [...]}; roots default to the
    entry, stubs (CORE_ASM, asm_stubs) always stop the walk."""
    import closure
    cfg = spec["closure"]
    stubs = CORE_ASM + spec.get("asm_stubs", "")
    stop = set(cfg.get("stop", ())) | set(re.findall(r"^([A-Za-z_]\w*):", stubs, re.M))
    roots = cfg.get("roots") or [spec["entry"]]
    runs = closure.closure(REF, cfg["files"], [r for r in roots if r not in stop], stop)
    return closure.emit(REF, runs)


_DATA_LABELS: set[str] | None = None


def data_labels() -> set[str]:
    """Labels in reference/aldonunez whose first statement is data."""
    global _DATA_LABELS
    if _DATA_LABELS is None:
        _DATA_LABELS = set()
        for f in REF.glob("*.asm"):
            pending = []
            for line in f.read_text(encoding="latin-1").splitlines():
                t = line.split(";", 1)[0].strip()
                if not t:
                    continue
                m = re.match(r"^([A-Za-z_]\w*):\s*(.*)$", t)
                if m:
                    pending.append(m.group(1))
                    t = m.group(2)
                    if not t:
                        continue
                if pending:
                    if re.match(r"\.(BYTE|WORD|ADDR|DBYT|RES)\b", t, re.I):
                        _DATA_LABELS.update(pending)
                    pending = []
    return _DATA_LABELS


def build_6502(spec, td: Path) -> tuple[bytes, dict[str, int], list[str]]:
    auto: list[str] = []
    for _ in range(4):
        (td / "eq.s").write_text(asm_source(spec, auto), encoding="latin-1")
        (td / "eq.cfg").write_text(LD_CFG)
        subprocess.run(["ca65", "-g", "--auto-import", "-I", str(REF),
                        "--bin-include-dir", str(REF), "-o",
                        str(td / "eq.o"), str(td / "eq.s")], check=True)
        r = subprocess.run(["ld65", "-C", str(td / "eq.cfg"), "-o", str(td / "eq.bin"),
                            "-Ln", str(td / "eq.lbl"), str(td / "eq.o")],
                           capture_output=True, text=True)
        missing = re.findall(r"Unresolved external '(\w+)'", r.stderr)
        if r.returncode == 0:
            break
        if not missing:
            raise RuntimeError(r.stderr)
        auto += [m for m in missing if m not in auto]
    data = [n for n in auto if n in data_labels() and n not in spec.get("data_unreached", ())]
    if data:
        # A data table auto-stubbed as code feeds the NES side garbage;
        # the spec must cut the table in.
        raise RuntimeError(f"{spec['name']}: data labels not in the cut: {','.join(data)}")
    labels = {}
    for line in (td / "eq.lbl").read_text().splitlines():
        p = line.split()
        if len(p) == 3 and p[0] == "al":
            labels[p[2].lstrip(".")] = int(p[1], 16)
    return (td / "eq.bin").read_bytes(), labels, auto


def build_c(spec, td: Path) -> tuple[ctypes.CDLL, list[str]]:
    sys.path.insert(0, str(ROOT / "tools" / "debug"))
    argv, sys.argv = sys.argv, [sys.argv[0]]
    import build_debug as b  # noqa: E402
    sys.argv = argv
    flags = [f for f in b.CFLAGS if f not in ("-m68000", "-ffixed-a4", "-O3")]
    flags += ["-DROOMROM_BUILD", "-O1", "-fPIC", "-w", "-Dalways_inline=noinline"]
    incs = [f"-I{HERE.parent / 'host_sgdk_stub'}"] + b.include_args()
    srcs = list(spec["c_sources"]) + [str(HERE / "harness_core.c")]
    srcs += [str(HERE / s) for s in spec.get("c_stub_files", [])]
    if spec.get("c_stubs"):
        (td / "spec_stubs.c").write_text(
            "extern unsigned char g_mem[];\nvoid eq_log_byte(unsigned char v);\n" + spec["c_stubs"])
        srcs.append(str(td / "spec_stubs.c"))
    objs = []
    for k, s in enumerate(srcs):
        o = td / f"c{k}.o"
        subprocess.run(["gcc", "-c"] + flags + incs + [s, "-o", str(o)], cwd=ROOT, check=True)
        objs.append(o)
    # Stub files win over the game TU that owns the same function: those
    # definitions are weakened (the TU's other functions stay real).
    n_game = len(spec["c_sources"])
    stub_defs = set()
    for o in objs[n_game:]:
        stub_defs |= {p[2] for p in (l.split() for l in subprocess.run(
            ["nm", str(o)], capture_output=True, text=True).stdout.splitlines())
            if len(p) == 3 and p[1] == "T"}
    for o in objs[:n_game]:
        own = {p[2] for p in (l.split() for l in subprocess.run(
            ["nm", str(o)], capture_output=True, text=True).stdout.splitlines())
            if len(p) == 3 and p[1] == "T"}
        shadow = sorted(own & stub_defs)
        if shadow:
            subprocess.run(["objcopy"] + [f"-W{x}" for x in shadow] + [str(o)], check=True)
    defined, undef = set(), set()
    for o in objs:
        for line in subprocess.run(["nm", str(o)], capture_output=True, text=True).stdout.splitlines():
            p = line.split()
            if len(p) == 3 and p[1] in "TDRBCVW":
                defined.add(p[2])
            elif len(p) == 2 and p[0] == "U":
                undef.add(p[1])
    missing = sorted(u for u in undef - defined if not u.startswith("_GLOBAL_OFFSET"))
    stub = ["void eq_unexpected(unsigned char id);"]
    for k, m in enumerate(missing, start=1):
        stub.append(f"unsigned long {m}(void) {{ eq_unexpected({min(k, 255)}); return 0; }}")
    (td / "missing.c").write_text("\n".join(stub) + "\n")
    subprocess.run(["gcc", "-c", "-fPIC", "-w", str(td / "missing.c"), "-o", str(td / "missing.o")],
                   check=True)
    so = td / f"eq_{spec['name']}.so"
    subprocess.run(["gcc", "-shared", "-o", str(so)] + [str(o) for o in objs] +
                   [str(td / "missing.o")], check=True)
    return ctypes.CDLL(str(so)), missing


class Nes:
    def __init__(self, rom: bytes, labels: dict[str, int]):
        from py65.devices.mpu6502 import MPU
        self.MPU, self.rom, self.labels = MPU, rom, labels

    def run(self, mem: bytearray, entry: str, a: int, x: int, y: int,
            carry: int = 0, trace: list | None = None,
            watch: dict[int, str] | None = None, hit: set | None = None
            ) -> tuple[bytearray, int, int]:
        mpu = self.MPU()
        m = bytearray(0x10000)
        m[0:MEM] = mem
        m[0x8000:0x10000] = self.rom
        mpu.memory = m
        trap = self.labels["Trap"]
        ret = trap - 1
        mpu.sp = 0xFF
        m[0x1FF], m[0x1FE] = (ret >> 8) & 0xFF, ret & 0xFF
        mpu.sp = 0xFD
        mpu.pc, mpu.a, mpu.x, mpu.y = self.labels[entry], a, x, y
        if carry:
            mpu.p |= mpu.CARRY
        names = {v: k for k, v in self.labels.items()} if trace is not None else None
        for _ in range(200000):
            if names is not None and mpu.pc in names and not names[mpu.pc].startswith("@"):
                trace.append(f"{names[mpu.pc]}(x={mpu.x:02X},y={mpu.y:02X},a={mpu.a:02X})")
            if mpu.pc == trap:
                return bytearray(m[0:MEM]), mpu.a, mpu.p & mpu.CARRY
            if watch and mpu.pc in watch:
                hit.add(watch[mpu.pc])
            mpu.step()
        raise NoReturn(trace[-16:] if trace else [])


class NoReturn(Exception):
    """The 6502 side did not return within the step budget."""


def base_mem(r: random.Random) -> bytearray:
    mem = bytearray(r.getrandbits(8) for _ in range(MEM))
    for a in range(0x5000, 0x6000):
        mem[a] = 0
    for k in range(16):                       # per-call preset results
        mem[0x5200 + k] = r.choice([0xF4, 0x8D, 0x98, 0x99, 0x8C, 0x26, 0x00, r.randrange(256)])
        mem[0x5300 + k] = r.randrange(256) if r.random() < 0.8 else 0
        mem[0x5400 + k] = r.randrange(256)
    return mem


def diff(spec, k: int, nes: bytearray, c: bytearray, ignore: set[int]) -> list[str]:
    errs = []
    for rng in COMPARE:
        for a in rng:
            if nes[a] != c[a] and a not in ignore:
                errs.append(f"{spec['name']} case {k}: ${a:04X} NES {nes[a]:02X} C {c[a]:02X}")
    ln, lc = nes[H_LOG_IDX], c[H_LOG_IDX]
    if nes[H_LOG_BUF:H_LOG_BUF + ln] != c[H_LOG_BUF:H_LOG_BUF + lc]:
        errs.append(f"{spec['name']} case {k}: log NES {nes[H_LOG_BUF:H_LOG_BUF+ln].hex()} "
                    f"C {c[H_LOG_BUF:H_LOG_BUF+lc].hex()}")
    return errs


def run_spec(spec, cases: int, seed: int, verbose: bool) -> tuple[bool, str]:
    r = random.Random(f"{seed}:{spec['name']}")
    with tempfile.TemporaryDirectory() as tdn:
        td = Path(tdn)
        rom, labels, auto6502 = build_6502(spec, td)
        lib, autoc = build_c(spec, td)
        nes = Nes(rom, labels)
        gmem = (ctypes.c_ubyte * MEM).in_dll(lib, "g_mem")
        errs: list[str] = []
        active = 0
        skipped = 0
        # ignore_if_run: {label: cells} ignored only in cases where the NES
        # side executed that label (e.g. TableJump's pointer scratch).
        cond = spec.get("ignore_if_run", {})
        watch = {labels[l]: l for l in cond if l in labels}
        for k in range(cases):
            case = spec["gen"](r, base_mem(r))
            mem = case["mem"]
            hit: set = set()
            try:
                n, a_out, c_out = nes.run(mem, spec["entry"], case.get("a", 0),
                                          case.get("x", 0), case.get("y", 0),
                                          case.get("carry", 0), watch=watch, hit=hit)
            except NoReturn:
                if spec.get("skip_no_return"):
                    skipped += 1        # documented NES hang, see the spec
                    continue
                tr: list[str] = []
                try:
                    nes.run(mem, spec["entry"], case.get("a", 0), case.get("x", 0),
                            case.get("y", 0), case.get("carry", 0), trace=tr)
                except NoReturn as nr:
                    tr = nr.args[0]
                errs.append(f"{spec['name']} case {k}: NES no return; last labels "
                            + " ".join(tr))
                if len(errs) > 30:
                    break
                continue
            ctypes.memmove(gmem, bytes(mem), MEM)
            ret = spec["call"](lib, case)
            c = bytearray(gmem)
            if "post" in spec:
                spec["post"](case, n, c)
            ignore = set(spec.get("ignore", ())) | set(case.get("ignore", ()))
            for l in hit:
                ignore |= set(cond[l])
            e = diff(spec, k, n, c, ignore)
            if n[H_UNEXP]:
                e.append(f"{spec['name']} case {k}: NES called unexpected "
                         f"{auto6502[n[H_UNEXP] - 1]}")
            if c[H_UNEXP]:
                e.append(f"{spec['name']} case {k}: C called unexpected "
                         f"{autoc[min(c[H_UNEXP], len(autoc)) - 1]}")
            if spec.get("ret") == "A" and (ret & 0xFF) != a_out:
                e.append(f"{spec['name']} case {k}: return NES A {a_out:02X} C {ret & 0xFF:02X}")
            if spec.get("ret") == "C" and spec["carry_of"](ret) != c_out:
                e.append(f"{spec['name']} case {k}: return NES carry {c_out} C {ret:#x}")
            if e and verbose and not errs:
                e.append(f"  inputs a={case.get('a',0):02X} x={case.get('x',0):02X} "
                         f"y={case.get('y',0):02X} note={case.get('note','')}")
            errs += e
            if spec.get("active") and spec["active"](case, n):
                active += 1
            if len(errs) > 30:
                break
        head = (f"{spec['name']}: {k + 1} cases, {active} active"
                f"{f', {skipped} skipped (NES hangs: ' + spec['skip_no_return'] + ')' if skipped else ''}"
                f"{'' if not auto6502 else ', 6502 auto-stubs ' + ','.join(auto6502)}")
        if errs:
            return False, head + "\n" + "\n".join(errs[:30]) + f"\nFAIL: {len(errs)} differences"
        return True, head + "\nPASS"


def debug_case(spec, k: int, seed: int, cells: list[int]) -> None:
    """Rebuild case k of a spec and print the given cells before/after."""
    r = random.Random(f"{seed}:{spec['name']}")
    for _ in range(k + 1):
        case = spec["gen"](r, base_mem(r))
    with tempfile.TemporaryDirectory() as tdn:
        td = Path(tdn)
        rom, labels, _ = build_6502(spec, td)
        lib, _ = build_c(spec, td)
        mem = case["mem"]
        tr: list[str] = []
        n, a_out, c_out = Nes(rom, labels).run(mem, spec["entry"], case.get("a", 0),
                                              case.get("x", 0), case.get("y", 0),
                                              case.get("carry", 0), trace=tr)
        print("NES trace: " + " ".join(tr[:400]))
        gmem = (ctypes.c_ubyte * MEM).in_dll(lib, "g_mem")
        ctypes.memmove(gmem, bytes(mem), MEM)
        ret = spec["call"](lib, case)
        c = bytearray(gmem)
        print(f"case {k}: a={case.get('a',0):02X} x={case.get('x',0):02X} y={case.get('y',0):02X} "
              f"NES A={a_out:02X} C={c_out} Cret={ret:#x}")
        for a in cells:
            print(f"  ${a:04X} in {mem[a]:02X}  NES {n[a]:02X}  C {c[a]:02X}"
                  f"{'  <<' if n[a] != c[a] else ''}")


def main() -> int:
    import specs
    ap = argparse.ArgumentParser()
    ap.add_argument("names", nargs="*")
    ap.add_argument("--cases", type=int, default=2000)
    ap.add_argument("--seed", type=int, default=56)
    ap.add_argument("--list", action="store_true")
    ap.add_argument("-v", "--verbose", action="store_true")
    ap.add_argument("--debug", type=int, help="case index to dump (one spec)")
    ap.add_argument("--cells", default="", help="hex addresses for --debug, comma-separated")
    a = ap.parse_args()
    if a.list:
        for s in specs.SPECS:
            print(f"{s['name']:28s} {s.get('doc', '')}")
        return 0
    for tool in ("ca65", "ld65", "gcc", "nm"):
        if not shutil.which(tool):
            print(f"FAIL: {tool} not found (cc65 / host gcc required)")
            return 1
    try:
        import py65  # noqa: F401
    except ImportError:
        print("FAIL: py65 not installed (pip install py65)")
        return 1
    chosen = [s for s in specs.SPECS if not a.names or s["name"] in a.names]
    if a.names and len(chosen) != len(set(a.names)):
        print("FAIL: unknown spec name"); return 1
    if a.debug is not None:
        cells = [int(x, 16) for x in a.cells.split(",") if x]
        debug_case(chosen[0], a.debug, a.seed, cells)
        return 0
    ok_all = True
    for s in chosen:
        if len(chosen) > 1:
            # One process per spec: a crash in drained C (segfault on a
            # generated input) is reported for that spec, the sweep goes on.
            argv = [sys.executable, __file__, s["name"], "--cases", str(a.cases),
                    "--seed", str(a.seed)] + (["-v"] if a.verbose else [])
            r = subprocess.run(argv, capture_output=True, text=True)
            out = "\n".join(l for l in r.stdout.splitlines() if l not in ("ALL PASS", "FAILURES"))
            if r.returncode < 0:
                out += f"\n{s['name']}: ERROR crashed (signal {-r.returncode})"
            print(out, flush=True)
            ok_all &= r.returncode == 0
            continue
        try:
            ok, text = run_spec(s, a.cases, a.seed, a.verbose)
        except Exception as e:      # build failure: report, keep sweeping
            ok, text = False, f"{s['name']}: ERROR {type(e).__name__}: {e}"
        print(text)
        ok_all &= ok
    print("ALL PASS" if ok_all else "FAILURES")
    return 0 if ok_all else 1


if __name__ == "__main__":
    sys.exit(main())
