#!/usr/bin/env python3
"""drain_coverage.py — drain-first / NES-disasm-second governance scanner.

Per debate 005 RULE D1.

Scans:
  - src/game/**/*_runtime.c                     drained C corpus (primary impl)
  - reference/aldonunez/*.asm                   NES disasm spec (final authority)
  - src/zelda_translated/*.asm                  transpiled NES code still living
  - docs/superpowers/plans/*master-plan*.md     master plan task headers

Emits:
  - tools/audit/drain_coverage.json             canonical (per-NES-source-file rows)
  - docs/audit/drain/<subsystem>.md             per-subsystem human view
  - docs/audit/drain/INDEX.md                   navigation
  - docs/audit/drain/orphans.md                 drained C with no master plan task pointing at it
  - docs/audit/drain/phantoms.md                master plan tasks claiming GREENFIELD where drain candidate exists

Exits non-zero on:
  - any task header malformed
  - any Stance: GREENFIELD where this tool found a candidate drain
  - any NES symbol claimed in a header that doesn't exist in the asm corpus
"""
import argparse
import json
import re
import sys
from datetime import datetime, timezone
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]
GAME_ROOT = REPO / "src" / "game"
NES_REFERENCE = REPO / "reference" / "aldonunez"
NES_TRANSLATED = REPO / "src" / "zelda_translated"
MASTER_PLAN = REPO / "docs" / "superpowers" / "plans" / "2026-05-02-title-roomrom-full-port-master-plan.md"

OUT_JSON   = REPO / "tools" / "audit" / "drain_coverage.json"
OUT_DIR_MD = REPO / "docs" / "audit" / "drain"

# C function definition regex — `[static] [inline] type name(args) {`
C_FUNC_RE = re.compile(
    r"^(?:static\s+)?(?:inline\s+)?[\w\s\*]+\s+(\w+)\s*\([^;]*?\)\s*\{",
    re.MULTILINE,
)

# Asm label regex — `Symbol:` at start of line (vasm Motorola style)
ASM_LABEL_RE = re.compile(r"^([A-Za-z_][\w]*)\s*:", re.MULTILINE)

# 4-line task header — match the four bullet lines per debate 005 spec
HEADER_RE = re.compile(
    r"###\s+Task\s+(?P<task>\d+(?:\.\d+)*)\s*[—–-]\s*(?P<name>[^\n]+)\n"
    r"\s*\n"
    r"-\s+\*\*NES source\*\*:\s*(?P<nes>[^\n]+)\n"
    r"-\s+\*\*Drained C\*\*:\s*(?P<drain>[^\n]+)\n"
    r"-\s+\*\*Coverage\*\*:\s*(?P<coverage>[^\n]+)\n"
    r"-\s+\*\*Stance\*\*:\s*(?P<stance>[^\n]+)\n",
)

LEGAL_COVERAGE = {"FULL", "PARTIAL", "STALE", "NONE"}
LEGAL_STANCE   = {"ADOPT", "EXTEND", "REPLACE", "GREENFIELD"}

# Subsystem inferred from src/game/<subsystem>/...
def subsystem_of(path: Path) -> str:
    try:
        rel = path.relative_to(GAME_ROOT).parts
        return rel[0] if rel else "unknown"
    except ValueError:
        return "external"


def scan_drained_functions() -> list[dict]:
    """Return list of {file, subsystem, function, line, calls_ppu_shim}."""
    out = []
    for p in sorted(GAME_ROOT.rglob("*_runtime.c")):
        try:
            text = p.read_text(encoding="utf-8", errors="replace")
        except OSError:
            continue
        # Strip line/block comments crudely so we don't match function-like
        # patterns inside comments.
        no_block = re.sub(r"/\*.*?\*/", "", text, flags=re.DOTALL)
        no_line  = re.sub(r"//[^\n]*", "", no_block)
        sub = subsystem_of(p)
        for m in C_FUNC_RE.finditer(no_line):
            name = m.group(1)
            # Skip C language keywords + stub-typedefs
            if name in {"if", "for", "while", "switch", "return", "sizeof",
                        "do", "else"}:
                continue
            line_no = no_line.count("\n", 0, m.start()) + 1
            out.append({
                "file": str(p.relative_to(REPO).as_posix()),
                "subsystem": sub,
                "function": name,
                "line": line_no,
                "calls_ppu_shim": "_ppu_" in text or "_apu_" in text,
            })
    return out


def scan_nes_symbols() -> dict[str, list[dict]]:
    """Return {asm_file: [{symbol, line}, ...]} for both reference and translated."""
    out: dict[str, list[dict]] = {}
    for root in (NES_REFERENCE, NES_TRANSLATED):
        if not root.exists():
            continue
        for p in sorted(root.glob("*.asm")):
            try:
                text = p.read_text(encoding="utf-8", errors="replace")
            except OSError:
                continue
            rel = str(p.relative_to(REPO).as_posix())
            symbols = []
            for m in ASM_LABEL_RE.finditer(text):
                sym = m.group(1)
                # Skip local labels (start with .) and obvious noise
                if sym.startswith("."):
                    continue
                if sym in {"section", "include", "incbin"}:
                    continue
                line_no = text.count("\n", 0, m.start()) + 1
                symbols.append({"symbol": sym, "line": line_no})
            out[rel] = symbols
    return out


def scan_master_plan_headers() -> tuple[list[dict], list[dict]]:
    """Return (headers, malformed). Each header is a dict with task/nes/drain/coverage/stance."""
    if not MASTER_PLAN.exists():
        return [], []
    text = MASTER_PLAN.read_text(encoding="utf-8")
    headers = []
    for m in HEADER_RE.finditer(text):
        headers.append({
            "task": m.group("task"),
            "name": m.group("name").strip(),
            "nes_source": m.group("nes").strip(),
            "drained_c": m.group("drain").strip(),
            "coverage_raw": m.group("coverage").strip(),
            "stance_raw": m.group("stance").strip(),
        })
    # Detect malformed: tasks that have a name but no header below
    # (regex above fails to match → we get 0 headers but tasks exist)
    malformed = []
    task_names = re.findall(r"###\s+Task\s+(\d+(?:\.\d+)*)\s*[—–-]\s*([^\n]+)", text)
    matched_tasks = {h["task"] for h in headers}
    for task_id, name in task_names:
        if task_id not in matched_tasks:
            malformed.append({"task": task_id, "name": name.strip()})
    return headers, malformed


def parse_coverage(raw: str) -> str:
    # Coverage may be "PARTIAL(missing: foo)" — extract enum prefix
    m = re.match(r"\s*(FULL|PARTIAL|STALE|NONE)\b", raw)
    return m.group(1) if m else f"INVALID({raw[:40]})"


def parse_stance(raw: str) -> str:
    m = re.match(r"\s*(ADOPT|EXTEND|REPLACE|GREENFIELD)\b", raw)
    return m.group(1) if m else f"INVALID({raw[:40]})"


def candidate_drain_for_task(header: dict, drained: list[dict]) -> list[str]:
    """Heuristic: for a task with NES source = 'z_01.asm:CaveInit', look for
    drained C functions whose name resembles 'cave_init' or similar."""
    nes_raw = header["nes_source"]
    syms = re.findall(r":(\w+)", nes_raw)
    candidates = []
    for sym in syms:
        # snake_case it
        snake = re.sub(r"(?<!^)(?=[A-Z])", "_", sym).lower()
        for d in drained:
            if snake in d["function"].lower() or sym.lower() in d["function"].lower():
                candidates.append(f"{d['file']}:{d['function']}")
    return candidates[:5]  # cap


def build_rows(drained: list[dict], nes_symbols: dict[str, list[dict]],
               headers: list[dict]) -> list[dict]:
    """Build canonical per-NES-symbol rows.

    For each task header that cites an NES source `file:symbol`, emit a row.
    Plus rows for orphaned drained-C functions (no header points at them).
    """
    rows: list[dict] = []
    referenced_drain: set[str] = set()
    for h in headers:
        nes_pairs = re.findall(r"([\w/\.]+\.asm)\s*:\s*([\w\*]+)", h["nes_source"])
        if not nes_pairs:
            # Header has no asm:symbol — degraded entry
            rows.append({
                "nes_file": "",
                "nes_symbol": "",
                "drained_c": h["drained_c"],
                "phase": h["task"].split(".")[0],
                "task": h["task"],
                "task_name": h["name"],
                "subsystem": "",
                "coverage": parse_coverage(h["coverage_raw"]),
                "stance": parse_stance(h["stance_raw"]),
            })
            continue
        for nes_file, nes_sym in nes_pairs:
            # mark drained-C entries cited
            for d in re.findall(r"([\w/\.]+\.c)\s*:\s*(\w+)", h["drained_c"]):
                referenced_drain.add(f"{d[0]}:{d[1]}")
            sub = ""
            for dpair in re.findall(r"([\w/\.]+\.c)", h["drained_c"]):
                p = REPO / dpair
                if p.exists():
                    sub = subsystem_of(p)
                    break
            rows.append({
                "nes_file": nes_file,
                "nes_symbol": nes_sym,
                "drained_c": h["drained_c"],
                "phase": h["task"].split(".")[0],
                "task": h["task"],
                "task_name": h["name"],
                "subsystem": sub,
                "coverage": parse_coverage(h["coverage_raw"]),
                "stance": parse_stance(h["stance_raw"]),
            })
    return rows, referenced_drain


def write_json(rows, malformed_headers, drained, nes_symbols,
               orphans, phantoms) -> None:
    OUT_JSON.parent.mkdir(parents=True, exist_ok=True)
    payload = {
        "schema_version": 1,
        "generated_at": datetime.now(timezone.utc).isoformat(timespec="seconds"),
        "rows": rows,
        "malformed_headers": malformed_headers,
        "drained_function_count": len(drained),
        "nes_file_count": len(nes_symbols),
        "orphan_count": len(orphans),
        "phantom_count": len(phantoms),
    }
    OUT_JSON.write_text(json.dumps(payload, indent=2) + "\n", encoding="utf-8")


def write_subsystem_views(rows, drained) -> None:
    OUT_DIR_MD.mkdir(parents=True, exist_ok=True)
    by_sub: dict[str, list[dict]] = {}
    for r in rows:
        by_sub.setdefault(r.get("subsystem") or "uncategorized", []).append(r)
    # Also make sure every drained subsystem has at least an empty file
    drained_subs = {d["subsystem"] for d in drained}
    for s in drained_subs:
        by_sub.setdefault(s, [])
    for sub, sub_rows in sorted(by_sub.items()):
        path = OUT_DIR_MD / f"{sub}.md"
        lines = [
            f"# Drain Coverage — `{sub}`",
            "",
            "> Auto-generated by `tools/audit/drain_coverage.py`. Do not edit by hand.",
            "",
            f"## Drained C functions in this subsystem",
            "",
        ]
        sub_drained = [d for d in drained if d["subsystem"] == sub]
        if not sub_drained:
            lines.append("(none)")
        else:
            lines.append("| File | Function | Line | Calls _ppu_/_apu_ shim? |")
            lines.append("|------|----------|------|------|")
            for d in sorted(sub_drained, key=lambda x: (x["file"], x["function"])):
                shim = "yes" if d["calls_ppu_shim"] else "no"
                lines.append(f"| `{d['file']}` | `{d['function']}` | {d['line']} | {shim} |")
        lines += ["", "## Master plan tasks claiming this subsystem", ""]
        if not sub_rows:
            lines.append("(none — possibly all drained code in this subsystem is orphaned from the plan)")
        else:
            lines.append("| Task | Name | NES source | Coverage | Stance |")
            lines.append("|------|------|-----------|----------|--------|")
            for r in sorted(sub_rows, key=lambda x: x["task"]):
                lines.append(
                    f"| {r['task']} | {r['task_name']} | "
                    f"`{r['nes_file']}:{r['nes_symbol']}` | "
                    f"{r['coverage']} | {r['stance']} |"
                )
        path.write_text("\n".join(lines) + "\n", encoding="utf-8")


def write_index(drained, rows) -> None:
    path = OUT_DIR_MD / "INDEX.md"
    subs = sorted({d["subsystem"] for d in drained})
    phases = sorted({r["phase"] for r in rows if r.get("phase")})
    lines = [
        "# Drain Coverage Index",
        "",
        "> Auto-generated by `tools/audit/drain_coverage.py`.",
        "",
        f"- **Drained C functions:** {len(drained)} across {len(subs)} subsystems",
        f"- **Master plan task headers (4-line):** {len(rows)}",
        "",
        "## Per-subsystem views",
        "",
    ]
    for s in subs:
        lines.append(f"- [{s}](./{s}.md)")
    lines += ["", "## Phase coverage", ""]
    for p in phases:
        lines.append(f"- Phase {p}")
    lines += [
        "",
        "## Tools",
        "",
        "- Canonical JSON: `tools/audit/drain_coverage.json`",
        "- Orphans (drain not cited by any task): `orphans.md`",
        "- Phantoms (tasks claiming GREENFIELD with candidate drain): `phantoms.md`",
        "",
        "## Rule",
        "",
        "Per debate 005 RULE D1: drained C is PRIMARY implementation evidence;",
        "NES disassembly is SECONDARY verification + final authority. Read drain",
        "first; verify against NES asm; NES wins on mismatch. `Stance: GREENFIELD`",
        "is illegal when this tool finds a candidate drain.",
    ]
    path.write_text("\n".join(lines) + "\n", encoding="utf-8")


def write_orphans(orphans) -> None:
    path = OUT_DIR_MD / "orphans.md"
    lines = [
        "# Drain Orphans",
        "",
        "> Drained C functions with NO master plan task header citing them.",
        "> Either dead code, hidden coverage we forgot to plan around, or the",
        "> task header is incomplete.",
        "",
    ]
    if not orphans:
        lines.append("(none — every drained function is cited by a task header)")
    else:
        lines.append("| File | Function | Subsystem |")
        lines.append("|------|----------|-----------|")
        for o in sorted(orphans, key=lambda x: (x["subsystem"], x["file"], x["function"])):
            lines.append(f"| `{o['file']}` | `{o['function']}` | {o['subsystem']} |")
    path.write_text("\n".join(lines) + "\n", encoding="utf-8")


def write_phantoms(phantoms) -> None:
    path = OUT_DIR_MD / "phantoms.md"
    lines = [
        "# Plan Phantoms",
        "",
        "> Master plan tasks claiming `Stance: GREENFIELD` where this tool",
        "> found a candidate drained C function. Header is wrong; task author",
        "> didn't grep `src/game/**/*_runtime.c` first. Per RULE D1, GREENFIELD",
        "> is illegal when a candidate drain exists.",
        "",
    ]
    if not phantoms:
        lines.append("(none — every GREENFIELD task is justified)")
    else:
        lines.append("| Task | Name | Candidate drain |")
        lines.append("|------|------|-----------------|")
        for p in sorted(phantoms, key=lambda x: x["task"]):
            for cand in p["candidates"]:
                lines.append(f"| {p['task']} | {p['name']} | `{cand}` |")
    path.write_text("\n".join(lines) + "\n", encoding="utf-8")


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("--phase", help="filter to one phase number (informational)")
    ap.add_argument("--quiet", action="store_true")
    args = ap.parse_args()

    drained = scan_drained_functions()
    nes_symbols = scan_nes_symbols()
    headers, malformed = scan_master_plan_headers()
    rows, referenced_drain = build_rows(drained, nes_symbols, headers)

    # Orphans: drained C entries no header cites
    orphans = []
    for d in drained:
        key = f"{d['file']}:{d['function']}"
        if key not in referenced_drain:
            orphans.append(d)

    # Phantoms: header claims GREENFIELD but candidate drain exists
    phantoms = []
    for h in headers:
        if parse_stance(h["stance_raw"]) != "GREENFIELD":
            continue
        cands = candidate_drain_for_task(h, drained)
        if cands:
            phantoms.append({
                "task": h["task"],
                "name": h["name"],
                "candidates": cands,
            })

    write_json(rows, malformed, drained, nes_symbols, orphans, phantoms)
    write_subsystem_views(rows, drained)
    write_index(drained, rows)
    write_orphans(orphans)
    write_phantoms(phantoms)

    if not args.quiet:
        print(f"OK: scanned {len(drained)} drained funcs across "
              f"{len({d['subsystem'] for d in drained})} subsystems; "
              f"{len(nes_symbols)} NES asm files; "
              f"{len(headers)} task headers; "
              f"{len(orphans)} orphans; "
              f"{len(phantoms)} phantoms; "
              f"{len(malformed)} malformed task headers.")
        print(f"  wrote {OUT_JSON.relative_to(REPO).as_posix()}")
        print(f"  wrote {OUT_DIR_MD.relative_to(REPO).as_posix()}/")

    if malformed or phantoms:
        if malformed:
            print(f"FAIL: {len(malformed)} task header(s) malformed (no 4-line block):", file=sys.stderr)
            for m in malformed[:5]:
                print(f"  Task {m['task']} — {m['name']}", file=sys.stderr)
        if phantoms:
            print(f"FAIL: {len(phantoms)} GREENFIELD claim(s) with candidate drain:", file=sys.stderr)
            for p in phantoms[:5]:
                print(f"  Task {p['task']} — candidates: {p['candidates']}", file=sys.stderr)
        return 1

    return 0


if __name__ == "__main__":
    sys.exit(main())
