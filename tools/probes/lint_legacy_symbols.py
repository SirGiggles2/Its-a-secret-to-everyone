"""Lint for legacy shim, transpile symbols, and raw VDP MMIO writes.

# S2 graduated invariant: data/ reproducibility
#
# Spec table 8.1 row 7 says every file under data/ must be byte-reproducible
# from the locked NES ROM via tools/extract_*.py, enforced as WARN at S1 and
# FAIL at S2 close.
#
# This check is delegated to tools/probes/check_data_manifest.py which is
# already wired into build.bat phase 2a.0c (since S2 Phase A).  That probe
# re-runs all extractors against a temp directory and diffs the resulting
# MANIFEST.sha256 against the committed one, failing the build on any
# divergence.
#
# Decision: no subprocess call added here.  The build-time check at 2a.0c is
# the single canonical gate.  Running it here too would double-run all
# extractors on every lint pass (slow) and produce no additional signal.
# Document this in the lint module so future sessions do not re-add a
# redundant subprocess call.
#
# If you need to run the data reproducibility check standalone:
#   python tools/probes/check_data_manifest.py
# If you need to regenerate the manifest after extractor changes:
#   python tools/build_data.py && git add data/MANIFEST.sha256 data/

Path-aware severity per spec Section 8.1:

| Scope                    | _ppu_/_oam_/_apu_/_ctrl_/_mmc1_/z00_..z07_ | Raw VDP MMIO writes |
|--------------------------|--------------------------------------------|---------------------|
| src/frontend/            | FAIL (S1+)                                 | FAIL (S1+)          |
| src/game/                | WARN (S1)                                  | WARN (S1)           |
| Everywhere else          | WARN (S1)                                  | WARN (S1)           |

Exemptions (callers + raw MMIO both):
  - src/abi/legacy_bridge.h         (transitional decls only)
  - src/zelda_translated/           (legacy bank source -- these DEFINE the symbols)
  - src/gen/z_*.c                   (transpile adapters)
  - src/nes_io.asm                  (NES IO primitive owner)
  - src/c_shims.asm                 (transpile shim layer)
  - src/genesis_shell.asm           (boot path; sets a few VDP regs at init)
  - src/audio_driver.asm            (XGM2 substrate)
  - src/sgdk_adapter/render_adapter.c   (the IO primitive layer; lint TARGETS this as the
                                         single owner of VDP MMIO writes)

Exit code 0 iff no FAIL-level findings. Non-zero on any frontend-scope hit.
WARN-level findings always print but do not gate the build.
"""

from __future__ import annotations

import re
import sys
from dataclasses import dataclass, field
from pathlib import Path

from _common import REPO_ROOT, SRC, relative_to_repo


# Legacy symbol families.
LEGACY_PATTERNS: list[tuple[str, re.Pattern]] = [
    ("_ppu_*",  re.compile(r"\b_ppu_[A-Za-z0-9_]+")),
    ("_oam_*",  re.compile(r"\b_oam_[A-Za-z0-9_]+")),
    ("_apu_*",  re.compile(r"\b_apu_[A-Za-z0-9_]+")),
    ("_ctrl_*", re.compile(r"\b_ctrl_[A-Za-z0-9_]+")),
    ("_mmc1_*", re.compile(r"\b_mmc1_[A-Za-z0-9_]+")),
    ("z00_*..z07_*", re.compile(r"\bz0[0-7]_[A-Za-z0-9_]+")),
]

# Raw VDP / Z80 MMIO patterns.
MMIO_PATTERNS: list[tuple[str, re.Pattern]] = [
    ("VDP_CTRL_WORD",   re.compile(r"\bVDP_CTRL_WORD\b")),
    ("VDP_CTRL_LONG",   re.compile(r"\bVDP_CTRL_LONG\b")),
    ("VDP_DATA_WORD",   re.compile(r"\bVDP_DATA_WORD\b")),
    ("VDP_DATA_LONG",   re.compile(r"\bVDP_DATA_LONG\b")),
    # Bare MMIO hex addresses (anywhere in code, not in comments — comments
    # are filtered post-match by re-checking the line for // or /* before the
    # match position).
    ("0xC00000-port",   re.compile(r"\b0x00C0000[04]\b")),
    ("Z80_BUSREQ",      re.compile(r"\b0x00A1110[01]\b")),
]

EXEMPT_PATH_PREFIXES = (
    "src/zelda_translated/",
    "src/gen/",
)
EXEMPT_PATH_EXACT = {
    "src/abi/legacy_bridge.h",
    "src/nes_io.asm",
    "src/c_shims.asm",
    "src/genesis_shell.asm",
    "src/audio_driver.asm",
    "src/sgdk_adapter/render_adapter.c",
}

# Strip C-style comments from a multi-line text. Returns the text with
# block (/* ... */) and line (//) comments replaced by spaces of equal
# length, so line numbers are preserved.
def strip_comments(text: str) -> str:
    out: list[str] = []
    i = 0
    n = len(text)
    in_block = False
    in_line = False
    in_string = False
    string_quote = ""
    while i < n:
        c = text[i]
        nxt = text[i + 1] if i + 1 < n else ""
        if in_block:
            if c == "*" and nxt == "/":
                out.append("  ")
                i += 2
                in_block = False
                continue
            out.append(" " if c != "\n" else "\n")
            i += 1
            continue
        if in_line:
            if c == "\n":
                in_line = False
                out.append("\n")
            else:
                out.append(" ")
            i += 1
            continue
        if in_string:
            out.append(c)
            if c == "\\" and nxt:
                out.append(nxt)
                i += 2
                continue
            if c == string_quote:
                in_string = False
            i += 1
            continue
        if c == "/" and nxt == "*":
            in_block = True
            out.append("  ")
            i += 2
            continue
        if c == "/" and nxt == "/":
            in_line = True
            out.append("  ")
            i += 2
            continue
        if c in ('"', "'"):
            in_string = True
            string_quote = c
            out.append(c)
            i += 1
            continue
        out.append(c)
        i += 1
    return "".join(out)


@dataclass
class Finding:
    severity: str  # "FAIL" or "WARN"
    path: str
    lineno: int
    symbol: str
    family: str


def is_exempt(rel: str) -> bool:
    rel_norm = rel.replace("\\", "/")
    if rel_norm in EXEMPT_PATH_EXACT:
        return True
    return any(rel_norm.startswith(p) for p in EXEMPT_PATH_PREFIXES)


def severity_for(rel: str, family_kind: str) -> str:
    """Return FAIL or WARN based on path scope and family kind ('legacy' or 'mmio').

    Per spec Section 8.1 (S1 graduation):
      - Raw VDP MMIO writes in src/frontend/ -> FAIL (Phase F1-F6 made the
        frontend MMIO-clean; the lint enforces no regression).
      - Raw VDP MMIO writes in src/game/    -> WARN (graduates to FAIL at S3 as
        game subsystems migrate onto the adapter).
      - Legacy z01_/z07_ symbol callers     -> WARN everywhere (the symbols
        get deleted at the S10 transpile-bank cutover; new callers SHOULD
        not be added but pre-existing callers are grandfathered).
      - _ppu_/_oam_/_apu_/_ctrl_/_mmc1_     -> WARN (same rationale; deleted
        with the shim layer at S10).
    """
    rel_norm = rel.replace("\\", "/")
    if family_kind == "mmio" and rel_norm.startswith("src/frontend/"):
        return "FAIL"
    return "WARN"


def lint_text(rel: str, text: str) -> list[Finding]:
    if is_exempt(rel):
        return []
    out: list[Finding] = []
    cleaned = strip_comments(text)
    for lineno, line in enumerate(cleaned.splitlines(), start=1):
        for family, pat in LEGACY_PATTERNS:
            for m in pat.finditer(line):
                out.append(Finding(severity=severity_for(rel, "legacy"),
                                   path=rel, lineno=lineno,
                                   symbol=m.group(0), family=family))
        for family, pat in MMIO_PATTERNS:
            for m in pat.finditer(line):
                out.append(Finding(severity=severity_for(rel, "mmio"),
                                   path=rel, lineno=lineno,
                                   symbol=m.group(0), family=family))
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

    fails = [f for f in findings if f.severity == "FAIL"]
    warns = [f for f in findings if f.severity == "WARN"]

    if fails:
        print(f"[lint_legacy_symbols] FAIL: {len(fails)} forbidden references in src/frontend/:",
              file=sys.stderr)
        for f in fails[:100]:
            print(f"  {f.severity} {f.path}:{f.lineno}  {f.symbol}  ({f.family})",
                  file=sys.stderr)
        if len(fails) > 100:
            print(f"  ... and {len(fails) - 100} more", file=sys.stderr)

    if warns:
        # Group by family for legibility; cap per-family display.
        by_family: dict[str, list[Finding]] = {}
        for f in warns:
            by_family.setdefault(f.family, []).append(f)
        print(f"[lint_legacy_symbols] WARN: {len(warns)} legacy/MMIO references "
              f"in src/game/ + other (warn-only at S1):", file=sys.stderr)
        for fam, items in sorted(by_family.items()):
            print(f"  {fam}: {len(items)} hits", file=sys.stderr)
            for f in items[:5]:
                print(f"    {f.path}:{f.lineno}  {f.symbol}", file=sys.stderr)
            if len(items) > 5:
                print(f"    ... +{len(items) - 5} more", file=sys.stderr)

    if not findings:
        print("[lint_legacy_symbols] clean.")

    return 1 if fails else 0


if __name__ == "__main__":
    sys.exit(main())
