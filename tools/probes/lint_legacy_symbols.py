"""Warning-only lint for legacy shim and transpile symbols.

At S0: prints a warning summary; never fails the build.
At S1+: same families graduate to hard failure per spec Section 8.1.

Exemptions:
  - src/abi/legacy_bridge.h   (transitional declarations only)
  - src/zelda_translated/     (legacy bank source — these define the symbols)
  - src/gen/z_*.c             (transpile adapters)
  - src/nes_io.asm, src/c_shims.asm, src/genesis_shell.asm (definitions)
"""

from __future__ import annotations

import re
import sys
from dataclasses import dataclass
from pathlib import Path

from _common import REPO_ROOT, SRC, relative_to_repo


PATTERNS: list[tuple[str, re.Pattern]] = [
    ("_ppu_*",  re.compile(r"\b_ppu_[A-Za-z0-9_]+")),
    ("_oam_*",  re.compile(r"\b_oam_[A-Za-z0-9_]+")),
    ("_apu_*",  re.compile(r"\b_apu_[A-Za-z0-9_]+")),
    ("_ctrl_*", re.compile(r"\b_ctrl_[A-Za-z0-9_]+")),
    ("_mmc1_*", re.compile(r"\b_mmc1_[A-Za-z0-9_]+")),
    ("z00_*..z07_*", re.compile(r"\bz0[0-7]_[A-Za-z0-9_]+")),
]

EXEMPT_PATH_PREFIXES = (
    "src/zelda_translated/",
    "src/gen/",
    "src/abi/legacy_bridge.h",
)
EXEMPT_PATH_EXACT = {
    "src/nes_io.asm",
    "src/c_shims.asm",
    "src/genesis_shell.asm",
}


@dataclass
class Finding:
    path: str
    lineno: int
    symbol: str


def is_exempt(rel: str) -> bool:
    rel_norm = rel.replace("\\", "/")
    if rel_norm in EXEMPT_PATH_EXACT:
        return True
    return any(rel_norm.startswith(p) for p in EXEMPT_PATH_PREFIXES)


def lint_text(rel: str, text: str) -> list[Finding]:
    if is_exempt(rel):
        return []
    out: list[Finding] = []
    for lineno, line in enumerate(text.splitlines(), start=1):
        for _family, pat in PATTERNS:
            for m in pat.finditer(line):
                out.append(Finding(path=rel, lineno=lineno, symbol=m.group(0)))
    return out


def main() -> int:
    findings: list[Finding] = []
    for path in sorted(SRC.rglob("*")):
        if not path.is_file():
            continue
        if path.suffix not in (".c", ".h", ".asm", ".inc"):
            continue
        try:
            text = path.read_text(encoding="utf-8", errors="replace")
        except OSError:
            continue
        findings.extend(lint_text(relative_to_repo(path), text))

    if findings:
        print(f"[lint_legacy_symbols] WARNING: {len(findings)} legacy callers found (S0 warn-only):", file=sys.stderr)
        for f in findings[:50]:
            print(f"  {f.path}:{f.lineno}  {f.symbol}", file=sys.stderr)
        if len(findings) > 50:
            print(f"  ... and {len(findings) - 50} more", file=sys.stderr)
    else:
        print("[lint_legacy_symbols] no legacy callers in non-exempt files.")
    # Warn-only at S0; always exit 0.
    return 0


if __name__ == "__main__":
    sys.exit(main())
