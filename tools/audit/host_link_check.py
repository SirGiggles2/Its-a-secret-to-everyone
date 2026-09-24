#!/usr/bin/env python3
"""Host-gcc pre-check for the Debug.md C sources (no SGDK toolchain needed).

Compiles every C TU listed in tools/debug/build_debug.py with the host gcc
(syntax + implicit-declaration errors), then checks the object set for
duplicate global definitions and unresolved symbols. It does NOT replace
Debug.bat: m68k inline asm, codegen, link layout and runtime are unchecked.
Expected unresolved: SGDK library, vasm-assembled .asm symbols, and the
render_adapter.c exports (its m68k inline asm cannot assemble on the host).

Usage:  python tools/audit/host_link_check.py [--baseline FILE] [--write FILE]
  --write FILE     save the unresolved-symbol list
  --baseline FILE  fail if unresolved symbols appear that are not in FILE
Exit 1 on compile errors, duplicate definitions, or new unresolved symbols.
"""
from __future__ import annotations
import argparse, collections, subprocess, sys, tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "tools" / "debug"))
sys.argv, _argv = [sys.argv[0]], sys.argv
import build_debug as b  # noqa: E402
sys.argv = _argv

HOST_ASM_TU = {"src/sgdk_adapter/render_adapter.c"}


def sources() -> list[str]:
    out = set()
    for name in dir(b):
        v = getattr(b, name)
        if isinstance(v, list) and v and isinstance(v[0], tuple) and str(v[0][0]).endswith(".c"):
            out.update(str(s) for s, _ in v)
    return sorted(out)


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--baseline", type=Path)
    ap.add_argument("--write", type=Path)
    a = ap.parse_args()
    flags = [f for f in b.CFLAGS if f not in ("-m68000", "-ffixed-a4", "-O3")]
    flags += ['-Dasm(x)=__asm__("r12")', "-O0", "-fno-common", "-w",
              "-Werror=implicit-function-declaration"]
    defs, und = collections.defaultdict(list), collections.defaultdict(list)
    errors = 0
    with tempfile.TemporaryDirectory() as td:
        for i, src in enumerate(sources()):
            obj = f"{td}/{i}.o"
            r = subprocess.run(["gcc", "-c"] + flags + b.include_args() + [src, "-o", obj],
                               cwd=ROOT, capture_output=True, text=True)
            if r.returncode:
                if src in HOST_ASM_TU:
                    continue
                errors += 1
                print(f"COMPILE FAIL {src}")
                for line in [l for l in r.stderr.splitlines() if "error" in l][:5]:
                    print("   ", line[:220])
                continue
            for line in subprocess.run(["nm", obj], capture_output=True, text=True).stdout.splitlines():
                p = line.split()
                if len(p) == 3 and p[1] in "TDRB":
                    defs[p[2]].append(src)
                elif len(p) == 2 and p[0] == "U":
                    und[p[1]].append(src)
    dups = {k: v for k, v in defs.items() if len(v) > 1}
    unresolved = sorted(k for k in und if k not in defs and not k.startswith("_GLOBAL_OFFSET")
                        and k != "__stack_chk_fail")
    print(f"TUs {len(sources())}  compile errors {errors}  duplicate defs {len(dups)}  unresolved {len(unresolved)}")
    for k, v in sorted(dups.items()):
        print(f"  DUP {k}: {v}")
    if a.write:
        a.write.write_text("\n".join(unresolved) + "\n")
    new = []
    if a.baseline and a.baseline.exists():
        base = set(a.baseline.read_text().split())
        new = [k for k in unresolved if k not in base]
        for k in new:
            print(f"  NEW UNRESOLVED {k}: {und[k][:3]}")
    return 1 if (errors or dups or new) else 0


if __name__ == "__main__":
    sys.exit(main())
