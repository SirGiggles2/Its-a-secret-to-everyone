#!/usr/bin/env python3
"""
tools/run_regression_matrix.py
================================
Workstream F — Regression Matrix Runner.

Discovers every probe under builds/reports/, tools/parity/ baselines, and
tools/probes/baselines/, runs each probe's diff against current build output,
and emits builds/reports/regression_matrix.md (and .json for CI).

Exit codes:
    0  All probes green, OR all red probes have a documented expected-failure
       entry in tools/parity/expected_failures.yaml.
    1  One or more unexpected red probes.

Usage:
    python tools/run_regression_matrix.py
    python tools/run_regression_matrix.py --phase 3
    python tools/run_regression_matrix.py --quiet
    python tools/run_regression_matrix.py --out builds/reports/regression_matrix.md
"""

from __future__ import annotations

import argparse
import datetime
import hashlib
import json
import os
import subprocess
import sys
from pathlib import Path
from typing import Optional

# ---------------------------------------------------------------------------
# Repo root
# ---------------------------------------------------------------------------
REPO_ROOT = Path(__file__).resolve().parent.parent

PARITY_DIR = REPO_ROOT / "tools" / "parity"
PROBES_BASELINES_DIR = REPO_ROOT / "tools" / "probes" / "baselines"
REPORTS_DIR = REPO_ROOT / "builds" / "reports"
PARITY_GEN_DIR = REPO_ROOT / "build" / "generated" / "parity"
NES_REF_DIR = REPO_ROOT / "build" / "generated" / "nes_reference"
EXPECTED_FAILURES_PATH = PARITY_DIR / "expected_failures.yaml"

DIFF_PY = PARITY_DIR / "diff.py"

# ---------------------------------------------------------------------------
# YAML minimal loader (mirrors the one in diff.py to avoid a dependency on it)
# ---------------------------------------------------------------------------

def _yaml_load_simple(path: Path) -> dict:
    """Minimal YAML loader for expected_failures.yaml and captures.json."""
    try:
        import yaml  # type: ignore
        with open(path, "r", encoding="utf-8") as f:
            return yaml.safe_load(f)
    except ImportError:
        pass

    with open(path, "r", encoding="utf-8") as f:
        lines = f.readlines()

    def _strip_comment(line):
        result = []
        in_sq = False
        in_dq = False
        for ch in line:
            if ch == "'" and not in_dq:
                in_sq = not in_sq
            elif ch == '"' and not in_sq:
                in_dq = not in_dq
            elif ch == '#' and not in_sq and not in_dq:
                break
            result.append(ch)
        return ''.join(result).rstrip()

    def _coerce(v: str):
        if v in ('true', 'True'):
            return True
        if v in ('false', 'False'):
            return False
        if v in ('null', '~', 'None'):
            return None
        try:
            return int(v)
        except ValueError:
            pass
        try:
            return float(v)
        except ValueError:
            pass
        if (v.startswith('"') and v.endswith('"')) or \
           (v.startswith("'") and v.endswith("'")):
            return v[1:-1]
        return v

    result = {}
    current_list = None
    current_item = None

    for raw in lines:
        line = raw.rstrip('\n').rstrip('\r')
        stripped = _strip_comment(line)
        s = stripped.lstrip()
        if not s or s.startswith('#'):
            continue
        ind = len(stripped) - len(s)
        if ind == 0 and not s.startswith('-') and ':' in s:
            k, _, v = s.partition(':')
            k = k.strip(); v = v.strip()
            if v in ('', '|', '>'):
                current_list = []
                result[k] = current_list
                current_item = None
            else:
                result[k] = _coerce(v)
        elif s.startswith('- '):
            rest = s[2:]
            current_item = {}
            if current_list is not None:
                current_list.append(current_item)
            if rest and ':' in rest:
                k, _, v = rest.partition(':')
                k = k.strip(); v = v.strip()
                if v not in ('>', '|', ''):
                    current_item[k] = _coerce(v)
        elif ind >= 2 and current_item is not None and ':' in s:
            k, _, v = s.partition(':')
            k = k.strip(); v = v.strip()
            if v not in ('>', '|', ''):
                current_item[k] = _coerce(v)

    return result


# ---------------------------------------------------------------------------
# Expected-failure lookup
# ---------------------------------------------------------------------------

def _load_expected_failures() -> list:
    """Return the expected_failures list from tools/parity/expected_failures.yaml."""
    if not EXPECTED_FAILURES_PATH.exists():
        return []
    data = _yaml_load_simple(EXPECTED_FAILURES_PATH)
    return data.get("expected_failures", [])


def _is_expected_failure_probe(probe_id: str, ef_list: list) -> Optional[dict]:
    """
    Check if a whole-probe failure is documented in expected_failures.yaml.
    Probe-level expected failures are recorded with field_path="*" and
    scenario_id matching the probe_id (or a glob pattern covering it).
    """
    import fnmatch
    for ef in ef_list:
        sid_pat = ef.get("scenario_id", "")
        fp_pat = ef.get("field_path", "")
        sid_match = fnmatch.fnmatch(probe_id, sid_pat) or sid_pat == "*"
        fp_match = fp_pat == "*"
        if sid_match and fp_match:
            return ef
    return None


# ---------------------------------------------------------------------------
# Probe discovery
# ---------------------------------------------------------------------------

def discover_parity_probes() -> list[dict]:
    """
    Discover parity-oracle probe pairs under build/generated/parity/.
    Looks for *_nes.json / *_gen.json pairs produced by nes_to_schema.py
    and genesis_probe.lua.

    Returns list of dicts with keys:
        probe_id, method, nes_path, gen_path, target
    """
    probes = []
    if not PARITY_GEN_DIR.exists():
        return probes

    nes_files = sorted(PARITY_GEN_DIR.glob("*_nes.json"))
    for nes_path in nes_files:
        scenario_id = nes_path.stem.removesuffix("_nes")
        gen_path = nes_path.parent / f"{scenario_id}_gen.json"

        # Infer target from scenario_id prefix
        target = _infer_target(scenario_id)

        probes.append({
            "probe_id": scenario_id,
            "method": "parity_oracle",
            "nes_path": nes_path,
            "gen_path": gen_path,
            "target": target,
        })
    return probes


def discover_binary_baseline_probes() -> list[dict]:
    """
    Discover binary baseline probes under tools/probes/baselines/.
    These are .bin files; the matching current-output .bin is expected at
    builds/reports/baselines/<probe_id>.bin (emitted by the phase's probe runner).

    Returns list of dicts with keys:
        probe_id, method, baseline_path, current_path, target
    """
    probes = []
    if not PROBES_BASELINES_DIR.exists():
        return probes

    for baseline in sorted(PROBES_BASELINES_DIR.glob("*.bin")):
        probe_id = baseline.stem
        current_path = REPORTS_DIR / "baselines" / f"{probe_id}.bin"
        target = _infer_target(probe_id)
        probes.append({
            "probe_id": probe_id,
            "method": "binary_baseline",
            "baseline_path": baseline,
            "current_path": current_path,
            "target": target,
        })
    return probes


def discover_screenshot_baseline_probes() -> list[dict]:
    """
    Discover screenshot baseline probes under builds/reports/ or tools/probes/baselines/.
    Looks for .png baseline files; matching current output expected at
    builds/reports/screenshots/<probe_id>.png.

    Returns list of dicts with keys:
        probe_id, method, baseline_path, current_path, target
    """
    probes = []
    # Check both locations
    search_dirs = [PROBES_BASELINES_DIR, REPORTS_DIR]
    seen = set()

    for search_dir in search_dirs:
        if not search_dir.exists():
            continue
        for baseline in sorted(search_dir.glob("*.png")):
            probe_id = baseline.stem
            if probe_id in seen:
                continue
            seen.add(probe_id)
            current_path = REPORTS_DIR / "screenshots" / f"{probe_id}.png"
            target = _infer_target(probe_id)
            probes.append({
                "probe_id": probe_id,
                "method": "screenshot_baseline",
                "baseline_path": baseline,
                "current_path": current_path,
                "target": target,
            })
    return probes


def discover_archived_report_probes() -> list[dict]:
    """
    Discover archived report JSON/txt files under builds/reports/.
    These are legacy per-phase reports; if a *_gen.json exists alongside
    a *_nes.json they are handled by discover_parity_probes() instead.

    Scans for any *_gen.json files not already covered.
    """
    probes = []
    if not REPORTS_DIR.exists():
        return probes

    seen_ids = set()
    for gen_path in sorted(REPORTS_DIR.rglob("*_gen.json")):
        scenario_id = gen_path.stem.removesuffix("_gen")
        if scenario_id in seen_ids:
            continue
        seen_ids.add(scenario_id)
        nes_path = gen_path.parent / f"{scenario_id}_nes.json"
        if not nes_path.exists():
            # No NES counterpart — skip (can't diff)
            continue
        target = _infer_target(scenario_id)
        probes.append({
            "probe_id": scenario_id,
            "method": "parity_oracle",
            "nes_path": nes_path,
            "gen_path": gen_path,
            "target": target,
        })
    return probes


def _infer_target(probe_id: str) -> str:
    """Infer which target ROM this probe belongs to.

    Sole Build Target Amendment 2026-05-08: there is exactly one ROM
    (`Debug.md`). Every probe targets it; the prefix-based dispatch from
    the dual-target era is retired. Function preserved (not deleted) so
    callers that read `probe['target']` keep working.
    """
    return "Debug.md"


# ---------------------------------------------------------------------------
# Phase filtering
# ---------------------------------------------------------------------------

# Map from phase id string to relevant probe_id prefixes/keywords.
_PHASE_PROBE_MAP: dict[str, list[str]] = {
    "1": ["title_", "intro_", "fs_", "file_select_"],
    "2": ["title_", "intro_", "fs_", "file_select_", "ow_room_00"],
    "3": ["cave_", "ow_"],
    "4": ["ow_", "t34_", "t35_"],
    "5": ["uw_", "redux_dungeon_"],
    "6": ["uw_", "cave_", "boss_"],
    "7": ["enemy_"],
    "8": ["boss_"],
    "9": ["save_"],
    "10": ["file_select_", "fs_"],
    "11": ["title_"],
    "12": [],  # all probes
    "13": ["multiplayer_"],
}


def _probe_matches_phase(probe_id: str, phase: str) -> bool:
    """Return True if this probe is relevant to the given phase."""
    if phase not in _PHASE_PROBE_MAP:
        return True  # unknown phase — include all
    prefixes = _PHASE_PROBE_MAP[phase]
    if not prefixes:
        return True  # phase 12 = all
    pid = probe_id.lower()
    return any(pid.startswith(p) for p in prefixes)


# ---------------------------------------------------------------------------
# ROM SHA computation
# ---------------------------------------------------------------------------

def _sha256_file(path: Path, chunk: int = 1 << 20) -> str:
    if not path.exists():
        return "N/A"
    h = hashlib.sha256()
    with open(path, "rb") as f:
        while True:
            buf = f.read(chunk)
            if not buf:
                break
            h.update(buf)
    return h.hexdigest()


def _find_current_rom(target: str) -> Optional[Path]:
    """
    Locate the current build output ROM. Sole Build Target Amendment
    2026-05-08: only `builds/Debug.md` is produced; legacy candidate
    paths are retired with the dual-target era.
    """
    candidates = [
        REPO_ROOT / "builds" / "Debug.md",
    ]
    for c in candidates:
        if c.exists():
            return c
    return None


# ---------------------------------------------------------------------------
# Diff runners
# ---------------------------------------------------------------------------

def run_parity_oracle_diff(probe: dict) -> dict:
    """
    Run tools/parity/diff.py on a (nes, gen) schema pair.
    Returns a result dict with keys: verdict, diff_summary, skip_reason.
    """
    nes_path = probe["nes_path"]
    gen_path = probe.get("gen_path")

    if not nes_path.exists():
        return {
            "verdict": "SKIP",
            "skip_reason": f"NES schema missing: {nes_path}",
            "diff_summary": "",
        }

    if gen_path is None or not gen_path.exists():
        # Check if the ROM itself is missing
        rom = _find_current_rom(probe["target"])
        if rom is None:
            return {
                "verdict": "SKIP",
                "skip_reason": f"SKIP: ROM missing ({probe['target']} not built yet)",
                "diff_summary": "",
            }
        return {
            "verdict": "SKIP",
            "skip_reason": f"Genesis probe output missing: {gen_path}",
            "diff_summary": "",
        }

    try:
        result = subprocess.run(
            [sys.executable, str(DIFF_PY),
             "--nes", str(nes_path),
             "--gen", str(gen_path),
             "--scenario-id", probe["probe_id"]],
            capture_output=True,
            text=True,
            encoding="utf-8",
            errors="replace",
            timeout=30,
        )
        # Parse the JSON output from diff.py
        try:
            diff_json = json.loads(result.stdout)
            diff_result = diff_json.get("result", "FAIL")
            summary = diff_json.get("summary", {})
            diff_summary = (
                f"pass={summary.get('pass', '?')} "
                f"warn={summary.get('warn', '?')} "
                f"fail={summary.get('fail', '?')}"
            )
            if diff_result == "PASS":
                verdict = "GREEN"
            else:
                verdict = "RED"
                # Collect failing field paths for the report
                fail_fields = [
                    d["field_path"]
                    for d in diff_json.get("diffs", [])
                    if not d.get("pass") and "expected_failure" not in d
                ]
                if fail_fields:
                    diff_summary += " | FAIL fields: " + ", ".join(fail_fields[:5])
                    if len(fail_fields) > 5:
                        diff_summary += f" +{len(fail_fields)-5} more"
        except (json.JSONDecodeError, KeyError):
            # diff.py may exit non-zero with non-JSON output on schema error
            diff_summary = result.stdout[:200].strip() or result.stderr[:200].strip()
            verdict = "RED" if result.returncode != 0 else "GREEN"

        return {
            "verdict": verdict,
            "skip_reason": "",
            "diff_summary": diff_summary,
            "diff_exit_code": result.returncode,
        }
    except subprocess.TimeoutExpired:
        return {
            "verdict": "RED",
            "skip_reason": "",
            "diff_summary": "diff.py timed out after 30s",
        }
    except OSError as e:
        return {
            "verdict": "RED",
            "skip_reason": "",
            "diff_summary": f"subprocess error: {e}",
        }


def run_binary_baseline_diff(probe: dict) -> dict:
    """
    Compare a .bin file against its baseline via byte-exact comparison.
    """
    baseline = probe["baseline_path"]
    current = probe["current_path"]

    if not baseline.exists():
        return {
            "verdict": "SKIP",
            "skip_reason": f"Baseline missing: {baseline}",
            "diff_summary": "",
        }

    if not current.exists():
        rom = _find_current_rom(probe["target"])
        if rom is None:
            return {
                "verdict": "SKIP",
                "skip_reason": f"SKIP: ROM missing ({probe['target']} not built yet)",
                "diff_summary": "",
            }
        return {
            "verdict": "SKIP",
            "skip_reason": f"Current probe output missing: {current}",
            "diff_summary": "",
        }

    baseline_data = baseline.read_bytes()
    current_data = current.read_bytes()

    if baseline_data == current_data:
        return {
            "verdict": "GREEN",
            "skip_reason": "",
            "diff_summary": f"byte-exact match ({len(baseline_data)} bytes)",
        }

    # Find first differing byte
    first_diff = -1
    for i, (b, c) in enumerate(zip(baseline_data, current_data)):
        if b != c:
            first_diff = i
            break

    size_note = ""
    if len(baseline_data) != len(current_data):
        size_note = f" | size mismatch: baseline={len(baseline_data)} current={len(current_data)}"

    diff_summary = (
        f"binary mismatch: first diff at byte 0x{first_diff:04x}"
        f" baseline=0x{baseline_data[first_diff]:02x}"
        f" current=0x{current_data[first_diff]:02x}"
        f"{size_note}"
    ) if first_diff >= 0 else f"size mismatch only{size_note}"

    return {
        "verdict": "RED",
        "skip_reason": "",
        "diff_summary": diff_summary,
    }


def run_screenshot_diff(probe: dict) -> dict:
    """
    Compare a .png screenshot against its baseline.
    Uses SHA-256 comparison (byte-exact for static scenes).
    A pixel-L1 comparator would require PIL/Pillow; we flag its absence clearly.
    """
    baseline = probe["baseline_path"]
    current = probe["current_path"]

    if not baseline.exists():
        return {
            "verdict": "SKIP",
            "skip_reason": f"Baseline screenshot missing: {baseline}",
            "diff_summary": "",
        }

    if not current.exists():
        rom = _find_current_rom(probe["target"])
        if rom is None:
            return {
                "verdict": "SKIP",
                "skip_reason": f"SKIP: ROM missing ({probe['target']} not built yet)",
                "diff_summary": "",
            }
        return {
            "verdict": "SKIP",
            "skip_reason": f"Current screenshot missing: {current}",
            "diff_summary": "",
        }

    baseline_sha = _sha256_file(baseline)[:16]
    current_sha = _sha256_file(current)[:16]

    if baseline_sha == current_sha:
        return {
            "verdict": "GREEN",
            "skip_reason": "",
            "diff_summary": f"SHA-256 match (prefix {baseline_sha}...)",
        }

    # Attempt pixel L1 comparison if PIL is available
    try:
        from PIL import Image  # type: ignore
        import struct as _struct
        b_img = Image.open(baseline).convert("RGB")
        c_img = Image.open(current).convert("RGB")
        if b_img.size != c_img.size:
            return {
                "verdict": "RED",
                "skip_reason": "",
                "diff_summary": (
                    f"screenshot size mismatch: baseline={b_img.size} current={c_img.size}"
                ),
            }
        b_px = list(b_img.getdata())
        c_px = list(c_img.getdata())
        l1 = sum(abs(int(a) - int(b)) for ap, cp in zip(b_px, c_px) for a, b in zip(ap, cp))
        threshold = 512
        if l1 <= threshold:
            return {
                "verdict": "GREEN",
                "skip_reason": "",
                "diff_summary": f"pixel L1={l1} <= threshold={threshold} (SHA mismatch but within tolerance)",
            }
        return {
            "verdict": "RED",
            "skip_reason": "",
            "diff_summary": f"pixel L1={l1} > threshold={threshold}",
        }
    except ImportError:
        pass

    return {
        "verdict": "RED",
        "skip_reason": "",
        "diff_summary": (
            f"SHA-256 mismatch: baseline={baseline_sha}... current={current_sha}..."
            " (PIL not available; pixel L1 skipped)"
        ),
    }


# ---------------------------------------------------------------------------
# Run all probes
# ---------------------------------------------------------------------------

def run_probe(probe: dict) -> dict:
    """Dispatch to the correct diff runner based on probe method."""
    method = probe["method"]
    if method == "parity_oracle":
        result = run_parity_oracle_diff(probe)
    elif method == "binary_baseline":
        result = run_binary_baseline_diff(probe)
    elif method == "screenshot_baseline":
        result = run_screenshot_diff(probe)
    else:
        result = {
            "verdict": "SKIP",
            "skip_reason": f"Unknown method: {method}",
            "diff_summary": "",
        }
    result["probe_id"] = probe["probe_id"]
    result["method"] = method
    result["target"] = probe["target"]
    return result


# ---------------------------------------------------------------------------
# Output formatters
# ---------------------------------------------------------------------------

def _rom_sha_line(target: str) -> str:
    rom = _find_current_rom(target)
    if rom is None:
        return f"{target}: ROM not found"
    sha = _sha256_file(rom)[:16]
    return f"{target}: {rom.name} SHA256={sha}..."


def emit_markdown(
    results: list[dict],
    timestamp: str,
    ef_list: list,
    quiet: bool,
) -> str:
    green = [r for r in results if r["verdict"] == "GREEN"]
    red = [r for r in results if r["verdict"] == "RED"]
    skip = [r for r in results if r["verdict"] == "SKIP"]

    # Classify red results
    unexpected_red = []
    expected_red = []
    for r in red:
        ef = _is_expected_failure_probe(r["probe_id"], ef_list)
        if ef:
            r["_ef"] = ef
            expected_red.append(r)
        else:
            unexpected_red.append(r)

    overall = "GREEN" if not unexpected_red else "RED"

    if quiet:
        targets = sorted({r["target"] for r in results})
        target_shas = " | ".join(_rom_sha_line(t) for t in targets)
        return (
            f"regression_matrix {timestamp} | {overall} | "
            f"green={len(green)} red={len(red)} skip={len(skip)} | "
            f"unexpected_red={len(unexpected_red)} | {target_shas}\n"
        )

    lines = []
    lines.append("# Regression Matrix")
    lines.append("")
    lines.append(f"**Run timestamp:** {timestamp}  ")
    lines.append(f"**Overall verdict:** {overall}  ")

    targets = sorted({r["target"] for r in results})
    for t in targets:
        lines.append(f"**{_rom_sha_line(t)}**  ")

    lines.append("")
    lines.append(
        f"**Summary:** {len(green)} GREEN / {len(red)} RED "
        f"({len(expected_red)} expected) / {len(skip)} SKIP  "
    )
    lines.append("")

    if unexpected_red:
        lines.append("## Unexpected Failures (block phase close)")
        lines.append("")
        lines.append("| Probe | Target | Method | Diff Summary |")
        lines.append("|-------|--------|--------|-------------|")
        for r in unexpected_red:
            lines.append(
                f"| `{r['probe_id']}` | {r['target']} | {r['method']} "
                f"| {r.get('diff_summary', '')} |"
            )
        lines.append("")

    if expected_red:
        lines.append("## Expected Failures (documented, do not block)")
        lines.append("")
        lines.append("| Probe | Target | Method | Reason | Owner Phase |")
        lines.append("|-------|--------|--------|--------|-------------|")
        for r in expected_red:
            ef = r.get("_ef", {})
            reason = ef.get("reason", "").replace("\n", " ").strip()[:80]
            lines.append(
                f"| `{r['probe_id']}` | {r['target']} | {r['method']} "
                f"| {reason} | Phase {ef.get('owner_phase', '?')} |"
            )
        lines.append("")

    if green:
        lines.append("## Passing Probes")
        lines.append("")
        lines.append("| Probe | Target | Method | Diff Summary |")
        lines.append("|-------|--------|--------|-------------|")
        for r in green:
            lines.append(
                f"| `{r['probe_id']}` | {r['target']} | {r['method']} "
                f"| {r.get('diff_summary', '')} |"
            )
        lines.append("")

    if skip:
        lines.append("## Skipped Probes")
        lines.append("")
        lines.append("| Probe | Target | Method | Reason |")
        lines.append("|-------|--------|--------|--------|")
        for r in skip:
            lines.append(
                f"| `{r['probe_id']}` | {r['target']} | {r['method']} "
                f"| {r.get('skip_reason', '')} |"
            )
        lines.append("")

    lines.append("---")
    lines.append("")
    lines.append(
        "_Generated by `tools/run_regression_matrix.py`. "
        "Phase close gate step 5 (master plan). "
        "See `tools/regression_matrix_README.md` for usage._"
    )
    lines.append("")
    return "\n".join(lines)


def emit_json(results: list[dict], timestamp: str, ef_list: list) -> str:
    green = [r for r in results if r["verdict"] == "GREEN"]
    red = [r for r in results if r["verdict"] == "RED"]
    skip = [r for r in results if r["verdict"] == "SKIP"]

    unexpected_red = [
        r for r in red
        if not _is_expected_failure_probe(r["probe_id"], ef_list)
    ]

    overall = "GREEN" if not unexpected_red else "RED"

    targets = sorted({r["target"] for r in results})
    target_shas = {t: _rom_sha_line(t) for t in targets}

    output = {
        "schema_version": 1,
        "run_timestamp": timestamp,
        "overall_verdict": overall,
        "target_rom_shas": target_shas,
        "summary": {
            "green": len(green),
            "red": len(red),
            "expected_red": len(red) - len(unexpected_red),
            "unexpected_red": len(unexpected_red),
            "skip": len(skip),
        },
        "probes": [
            {
                "probe_id": r["probe_id"],
                "target": r["target"],
                "method": r["method"],
                "verdict": r["verdict"],
                "diff_summary": r.get("diff_summary", ""),
                "skip_reason": r.get("skip_reason", ""),
            }
            for r in results
        ],
    }
    return json.dumps(output, indent=2)


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

def main() -> int:
    parser = argparse.ArgumentParser(
        description=(
            "Workstream F — Regression Matrix Runner. "
            "Discovers all probes, diffs each against current build, "
            "emits builds/reports/regression_matrix.md."
        )
    )
    parser.add_argument(
        "--phase",
        help="Run only probes relevant to this phase number (e.g. --phase 3).",
    )
    parser.add_argument(
        "--quiet",
        action="store_true",
        help="Emit only a single verdict line instead of the full matrix.",
    )
    parser.add_argument(
        "--out",
        help="Override output path (default: builds/reports/regression_matrix.md).",
    )
    parser.add_argument(
        "--json-out",
        help="Also emit machine-readable JSON to this path.",
    )
    args = parser.parse_args()

    timestamp = datetime.datetime.utcnow().strftime("%Y-%m-%dT%H:%M:%SZ")

    # ── Discover all probes ───────────────────────────────────────────────────
    all_probes: list[dict] = []
    all_probes.extend(discover_parity_probes())
    all_probes.extend(discover_archived_report_probes())
    all_probes.extend(discover_binary_baseline_probes())
    all_probes.extend(discover_screenshot_baseline_probes())

    # Deduplicate by probe_id (parity oracle takes precedence)
    seen: dict[str, dict] = {}
    for p in all_probes:
        pid = p["probe_id"]
        if pid not in seen:
            seen[pid] = p
        elif p["method"] == "parity_oracle" and seen[pid]["method"] != "parity_oracle":
            seen[pid] = p  # promote parity oracle
    probes = list(seen.values())

    # ── Phase filter ─────────────────────────────────────────────────────────
    if args.phase:
        probes = [p for p in probes if _probe_matches_phase(p["probe_id"], args.phase)]

    if not probes:
        msg = "No probes discovered"
        if args.phase:
            msg += f" for phase {args.phase}"
        print(f"INFO: {msg}. Matrix is vacuously GREEN.")
        _ensure_reports_dir()
        out_path = Path(args.out) if args.out else REPORTS_DIR / "regression_matrix.md"
        out_path.write_text(
            f"# Regression Matrix\n\n"
            f"**Run timestamp:** {timestamp}  \n"
            f"**Overall verdict:** GREEN (no probes discovered)  \n\n"
            f"No probe files found. Run Phase 1.5 NES capture harness and Genesis "
            f"probe scripts to populate `build/generated/parity/`.\n",
            encoding="utf-8",
        )
        return 0

    # ── Run probes ────────────────────────────────────────────────────────────
    ef_list = _load_expected_failures()
    results: list[dict] = []

    for probe in probes:
        if not args.quiet:
            print(f"  [{probe['probe_id']}] method={probe['method']} target={probe['target']} ... ", end="", flush=True)
        result = run_probe(probe)
        results.append(result)
        if not args.quiet:
            print(result["verdict"])

    # ── Classify verdicts ─────────────────────────────────────────────────────
    red_results = [r for r in results if r["verdict"] == "RED"]
    unexpected_red = [
        r for r in red_results
        if not _is_expected_failure_probe(r["probe_id"], ef_list)
    ]

    # ── Emit reports ──────────────────────────────────────────────────────────
    _ensure_reports_dir()

    out_path = Path(args.out) if args.out else REPORTS_DIR / "regression_matrix.md"
    md_text = emit_markdown(results, timestamp, ef_list, args.quiet)
    out_path.write_text(md_text, encoding="utf-8")

    if not args.quiet:
        print(f"\nMatrix written: {out_path}")

    if args.json_out:
        json_path = Path(args.json_out)
        json_path.parent.mkdir(parents=True, exist_ok=True)
        json_path.write_text(emit_json(results, timestamp, ef_list), encoding="utf-8")
        if not args.quiet:
            print(f"JSON written:   {json_path}")

    # Also always emit a JSON alongside the MD for CI consumption
    json_companion = out_path.with_suffix(".json")
    json_companion.write_text(emit_json(results, timestamp, ef_list), encoding="utf-8")

    # ── Final verdict ─────────────────────────────────────────────────────────
    green = sum(1 for r in results if r["verdict"] == "GREEN")
    red = len(red_results)
    skip = sum(1 for r in results if r["verdict"] == "SKIP")

    verdict_line = (
        f"Regression matrix: {timestamp} | "
        f"GREEN={green} RED={red} SKIP={skip} | "
        f"unexpected_red={len(unexpected_red)} | "
        f"OVERALL={'GREEN' if not unexpected_red else 'RED'}"
    )
    print(verdict_line)

    if args.quiet:
        out_path.write_text(verdict_line + "\n", encoding="utf-8")

    if unexpected_red:
        print("\nUNEXPECTED RED probes (block phase close):", file=sys.stderr)
        for r in unexpected_red:
            print(f"  {r['probe_id']}: {r.get('diff_summary', '')}", file=sys.stderr)
        return 1

    return 0


def _ensure_reports_dir():
    REPORTS_DIR.mkdir(parents=True, exist_ok=True)


if __name__ == "__main__":
    sys.exit(main())
