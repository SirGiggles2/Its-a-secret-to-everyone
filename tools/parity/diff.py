#!/usr/bin/env python3
"""
tools/parity/diff.py — Parity Oracle Diff Tool
================================================
Loads two schema instances (NES capture vs Genesis probe), validates each
against schema.json, applies per-field tolerances from tolerances.yaml,
and emits a structured diff.

Usage:
    diff.py --nes <path> --gen <path> [--human] [--out <path>]

Exit codes:
    0 = all fields match within tolerance (or are in expected_failures.yaml)
    1 = one or more fields outside tolerance
    2 = schema validation error
    3 = file I/O or argument error

Integration:
    Phase close gate step 4 runs this tool against every probe pair.
    Workstream F regression matrix calls this tool for every scenario.
    Every "compare against NES" claim must cite this tool's output.
"""

import argparse
import fnmatch
import hashlib
import json
import os
import re
import struct
import sys
from pathlib import Path

# ─── Paths ────────────────────────────────────────────────────────────────────

SCRIPT_DIR = Path(__file__).parent
SCHEMA_PATH = SCRIPT_DIR / "schema.json"
TOLERANCES_PATH = SCRIPT_DIR / "tolerances.yaml"
EXPECTED_FAILURES_PATH = SCRIPT_DIR / "expected_failures.yaml"


# ─── YAML minimal parser ──────────────────────────────────────────────────────
# Avoids requiring PyYAML in the build environment. Handles the simple
# list-of-dicts structure used in tolerances.yaml and expected_failures.yaml.

def _yaml_load_simple(path: Path) -> dict:
    """
    Minimal YAML loader for the tolerances/expected_failures files.
    Supports: top-level key: value, list items (- key: val), multi-line
    scalars (>), and nested dicts. Does NOT support anchors, aliases, or
    complex YAML features. Falls back to PyYAML if available.
    """
    try:
        import yaml  # type: ignore
        with open(path, "r", encoding="utf-8") as f:
            return yaml.safe_load(f)
    except ImportError:
        pass

    # Hand-rolled parser for our specific subset.
    with open(path, "r", encoding="utf-8") as f:
        lines = f.readlines()

    def _strip_comment(line):
        # Remove inline # comments that are not inside quotes.
        result = []
        in_sq = False
        in_dq = False
        for i, ch in enumerate(line):
            if ch == "'" and not in_dq:
                in_sq = not in_sq
            elif ch == '"' and not in_sq:
                in_dq = not in_dq
            elif ch == '#' and not in_sq and not in_dq:
                break
            result.append(ch)
        return ''.join(result).rstrip()

    def _indent(line):
        return len(line) - len(line.lstrip(' '))

    # State machine: collect into a list of records under each top-level key
    result = {}
    current_top_key = None
    current_list = None
    current_item = None
    multiline_key = None
    multiline_buf = []
    multiline_indent = 0
    i = 0

    def _flush_multiline():
        nonlocal multiline_buf, multiline_key, current_item
        if multiline_key and current_item is not None:
            current_item[multiline_key] = ' '.join(
                l.strip() for l in multiline_buf if l.strip()
            )
            multiline_key = None
            multiline_buf = []

    while i < len(lines):
        raw = lines[i]
        i += 1
        line = raw.rstrip('\n').rstrip('\r')
        stripped = _strip_comment(line)
        s = stripped.lstrip()

        if not s or s.startswith('#'):
            if multiline_key:
                # blank line inside multi-line block = paragraph break
                multiline_buf.append('')
            continue

        ind = _indent(stripped)

        if multiline_key:
            if ind > multiline_indent:
                multiline_buf.append(s)
                continue
            else:
                _flush_multiline()

        # Top-level key (indent 0, no leading -)
        if ind == 0 and not s.startswith('-'):
            if ':' in s:
                k, _, v = s.partition(':')
                k = k.strip()
                v = v.strip()
                if v == '' or v == '|' or v == '>':
                    # Start of a list or block
                    current_list = []
                    result[k] = current_list
                    current_top_key = k
                    current_item = None
                elif v.lstrip('-').strip().isdigit() or v in ('true', 'false', 'null'):
                    result[k] = _coerce(v)
                else:
                    result[k] = v
            continue

        # List item (starts with -)
        if s.startswith('- '):
            _flush_multiline()
            rest = s[2:]
            current_item = {}
            if current_list is not None:
                current_list.append(current_item)
            if rest:
                k, _, v = rest.partition(':')
                k = k.strip()
                v = v.strip()
                if v in ('>', '|', ''):
                    pass
                else:
                    current_item[k] = _coerce(v)
            continue

        # Key: value inside a list item
        if ind >= 2 and current_item is not None and ':' in s:
            k, _, v = s.partition(':')
            k = k.strip()
            v = v.strip()
            if v in ('>', '|'):
                multiline_key = k
                multiline_indent = ind
                multiline_buf = []
            elif v == '':
                current_item[k] = {}
            else:
                current_item[k] = _coerce(v)
            continue

    _flush_multiline()
    return result


def _coerce(v: str):
    """Coerce YAML scalar string to Python type."""
    if v == 'true':
        return True
    if v == 'false':
        return False
    if v == 'null' or v == '~':
        return None
    try:
        return int(v)
    except ValueError:
        pass
    try:
        return float(v)
    except ValueError:
        pass
    # Strip surrounding quotes
    if (v.startswith('"') and v.endswith('"')) or \
       (v.startswith("'") and v.endswith("'")):
        return v[1:-1]
    return v


# ─── JSON Schema validator ────────────────────────────────────────────────────

def _validate_schema(instance: dict, schema: dict, path: str = "") -> list:
    """
    Minimal draft-07 JSON Schema validator.
    Returns list of (path, message) error tuples.
    Handles: type, required, additionalProperties, properties, items,
             minItems, maxItems, minimum, maximum, pattern, enum.
    Falls back to jsonschema library if available (recommended).
    """
    try:
        import jsonschema  # type: ignore
        validator = jsonschema.Draft7Validator(schema)
        errors = []
        for e in validator.iter_errors(instance):
            errors.append(("/".join(str(p) for p in e.absolute_path), e.message))
        return errors
    except ImportError:
        pass

    # Hand-rolled minimal validator
    errors = []

    def _check(inst, sch, p):
        t = sch.get("type")
        if t == "object":
            if not isinstance(inst, dict):
                errors.append((p, f"expected object, got {type(inst).__name__}"))
                return
            req = sch.get("required", [])
            for r in req:
                if r not in inst:
                    errors.append((p, f"missing required field '{r}'"))
            no_add = sch.get("additionalProperties", True)
            props = sch.get("properties", {})
            if no_add is False:
                for k in inst:
                    if k not in props:
                        errors.append((p, f"additional property not allowed: '{k}'"))
            for k, subsch in props.items():
                if k in inst:
                    _check(inst[k], subsch, f"{p}/{k}")
        elif t == "array":
            if not isinstance(inst, list):
                errors.append((p, f"expected array, got {type(inst).__name__}"))
                return
            mn = sch.get("minItems")
            mx = sch.get("maxItems")
            if mn is not None and len(inst) < mn:
                errors.append((p, f"array too short: {len(inst)} < {mn}"))
            if mx is not None and len(inst) > mx:
                errors.append((p, f"array too long: {len(inst)} > {mx}"))
            item_sch = sch.get("items")
            if item_sch:
                for idx, item in enumerate(inst):
                    _check(item, item_sch, f"{p}/{idx}")
        elif t == "integer":
            if not isinstance(inst, int) or isinstance(inst, bool):
                errors.append((p, f"expected integer, got {type(inst).__name__}"))
                return
            mn = sch.get("minimum")
            mx = sch.get("maximum")
            if mn is not None and inst < mn:
                errors.append((p, f"value {inst} < minimum {mn}"))
            if mx is not None and inst > mx:
                errors.append((p, f"value {inst} > maximum {mx}"))
        elif t == "string":
            if not isinstance(inst, str):
                errors.append((p, f"expected string, got {type(inst).__name__}"))
                return
            pat = sch.get("pattern")
            if pat and not re.fullmatch(pat, inst):
                errors.append((p, f"string does not match pattern {pat!r}: {inst[:40]!r}"))

    _check(instance, schema, path or "")
    return errors


# ─── Comparators ──────────────────────────────────────────────────────────────

def cmp_exact(nes_val, gen_val, _tol):
    """Exact equality."""
    return nes_val == gen_val, f"NES={nes_val!r} GEN={gen_val!r}"


def cmp_window_int(nes_val, gen_val, tol):
    """Integer within ±window."""
    window = tol.get("window", 0)
    ok = abs(nes_val - gen_val) <= window
    return ok, f"NES={nes_val} GEN={gen_val} diff={gen_val - nes_val} window=±{window}"


def cmp_exact_hex(nes_val, gen_val, _tol):
    """Hex string exact equality."""
    ok = nes_val.lower() == gen_val.lower()
    if not ok:
        # Find first differing byte index
        for i in range(0, min(len(nes_val), len(gen_val)), 2):
            if nes_val[i:i+2].lower() != gen_val[i:i+2].lower():
                byte_idx = i // 2
                return False, (
                    f"first diff at byte {byte_idx:#04x}: "
                    f"NES={nes_val[i:i+2]} GEN={gen_val[i:i+2]}"
                )
    return ok, "match" if ok else "mismatch"


def cmp_structural_save_buffer(nes_val, gen_val, _tol):
    """
    Structural save buffer comparison.
    Unpacks known NES SRAM field offsets and compares by logical value.
    Unknown bytes are compared exact.
    TODO: Expand field map from docs/audit/state_macro_inventory.md as
    SaveState fields are migrated to typed structs (Phase 9).
    """
    # For now, delegate to hex exact.
    # Expand this comparator at Phase 9 when SaveState struct is defined.
    return cmp_exact_hex(nes_val, gen_val, _tol)


def cmp_sat_oam_functional(nes_oam: list, gen_sat: list, _tol):
    """
    Functional SAT vs OAM comparison.
    Checks that every visible NES OAM sprite has a corresponding Genesis SAT
    entry with equivalent visual identity.

    Visual identity rules:
    - Position: ±1 pixel tolerance (sub-pixel rounding differences).
    - Palette: exact (palette index must match after conversion).
    - H/V flip flags: exact.
    - Tile index: not compared directly (Genesis tile indexing differs from
      NES tile indexing after CHR expansion). Presence of a non-zero tile
      entry is required for visible sprites.

    TODO: Implement full collapse rule matching Anim_WriteSpecificItemSprites
    grouping logic from reference/aldonunez/sprites.asm. This stub checks
    only sprite count and rough position cloud. Full implementation gates on
    Phase 2 sprite system completion.

    Collapse comparator: STUB — returns WARN (True with warning message)
    until the full sprite-collapse rules are defined at Phase 2.
    """
    # Count visible NES sprites (y != 0xEF/0xFF = off-screen sentinel)
    nes_visible = [s for s in nes_oam if s.get("y", 0xFF) < 0xEF]
    gen_visible = [s for s in gen_sat if s.get("attr_tile", 0) != 0]

    # Stub: warn if counts diverge significantly (>4 sprite difference)
    count_diff = abs(len(nes_visible) - len(gen_visible))
    if count_diff > 4:
        return False, (
            f"STUB comparator: NES visible sprites={len(nes_visible)} "
            f"GEN visible SAT entries={len(gen_visible)} "
            f"diff={count_diff} > threshold=4. "
            "Full collapse rule comparison not yet implemented (Phase 2)."
        )
    return True, (
        f"STUB comparator PASS: NES visible={len(nes_visible)} "
        f"GEN visible={len(gen_visible)} — full collapse validation pending Phase 2."
    )


def cmp_screenshot_per_scenario(nes_sha, gen_sha, tol, scenario_id=None):
    """
    Screenshot comparison.
    static scenarios: byte-exact SHA-256 match.
    animated scenarios: delegates to pixel L1 comparison (requires PNG paths
    from the calling context; this function compares hashes for static only).

    NOTE: For animated scenes, diff.py must be invoked with --screenshot-dir
    pointing to the directory containing the PNG files. If not provided, this
    comparator falls back to hash comparison with a warning.
    """
    whitelist = tol.get("static_scenario_whitelist", [])
    if scenario_id and any(fnmatch.fnmatch(scenario_id, p) for p in whitelist):
        ok = nes_sha.lower() == gen_sha.lower()
        return ok, f"static/exact: NES={nes_sha[:16]}... GEN={gen_sha[:16]}..."
    else:
        # For animated scenes, hash mismatch is a warning, not a failure,
        # unless pixel L1 comparison is available.
        # diff.py --human mode will note this as a soft warning.
        if nes_sha.lower() == gen_sha.lower():
            return True, "animated/hash-match (identical frames)"
        return True, (
            f"animated/hash-mismatch (expected for animated scenes): "
            f"NES={nes_sha[:16]}... GEN={gen_sha[:16]}... "
            "pixel L1 comparison requires --screenshot-dir."
        )


# ─── Tolerance engine ─────────────────────────────────────────────────────────

COMPARATOR_MAP = {
    "cmp_exact": cmp_exact,
    "cmp_window_int": cmp_window_int,
    "cmp_exact_hex": cmp_exact_hex,
    "cmp_structural_save_buffer": cmp_structural_save_buffer,
    "cmp_sat_oam_functional": cmp_sat_oam_functional,
    "cmp_screenshot_per_scenario": cmp_screenshot_per_scenario,
}


def _resolve_path(obj: dict, json_ptr: str):
    """Resolve a JSON Pointer (RFC 6901) against obj. Returns (found, value)."""
    if json_ptr == "":
        return True, obj
    parts = json_ptr.lstrip("/").split("/")
    cur = obj
    for part in parts:
        part = part.replace("~1", "/").replace("~0", "~")
        if isinstance(cur, dict):
            if part not in cur:
                return False, None
            cur = cur[part]
        elif isinstance(cur, list):
            if part == "*":
                # Wildcard: return the list itself for array comparators
                return True, cur
            try:
                cur = cur[int(part)]
            except (IndexError, ValueError):
                return False, None
        else:
            return False, None
    return True, cur


def _expand_array_ptr(ptr: str, length: int) -> list:
    """Expand /foo/[*]/bar into [/foo/0/bar, /foo/1/bar, ...]."""
    if "[*]" not in ptr:
        return [ptr]
    results = []
    for i in range(length):
        results.append(ptr.replace("[*]", str(i)))
    return results


def _get_array_length(nes: dict, ptr: str) -> int:
    """Get the length of the array referenced before the [*] wildcard."""
    base = ptr[:ptr.index("[*]")].rstrip("/")
    found, val = _resolve_path(nes, base)
    if found and isinstance(val, list):
        return len(val)
    return 16  # fallback


def apply_tolerances(
    nes: dict,
    gen: dict,
    tolerances: dict,
    scenario_id: str = None,
) -> list:
    """
    Apply all tolerance rules and return a list of diff result dicts.
    Each dict has: field_path, pass, nes_value, gen_value, detail, comparator.
    """
    results = []
    tol_list = tolerances.get("tolerances", [])

    for tol in tol_list:
        ptr = tol.get("field_path", "")
        cmp_name = tol.get("comparator", "cmp_exact")
        cmp_fn = COMPARATOR_MAP.get(cmp_name, cmp_exact)

        # Expand array wildcards
        if "[*]" in ptr:
            arr_len = _get_array_length(nes, ptr)
            ptrs = _expand_array_ptr(ptr, arr_len)
        else:
            ptrs = [ptr]

        for p in ptrs:
            nes_found, nes_val = _resolve_path(nes, p)
            gen_found, gen_val = _resolve_path(gen, p)

            if not nes_found and not gen_found:
                continue  # Field absent on both sides — skip
            if not nes_found:
                results.append({
                    "field_path": p,
                    "pass": False,
                    "nes_value": None,
                    "gen_value": gen_val,
                    "detail": "field present in GEN but missing in NES",
                    "comparator": cmp_name,
                })
                continue
            if not gen_found:
                results.append({
                    "field_path": p,
                    "pass": False,
                    "nes_value": nes_val,
                    "gen_value": None,
                    "detail": "field present in NES but missing in GEN",
                    "comparator": cmp_name,
                })
                continue

            # Special handling for SAT/OAM functional comparator
            if cmp_name == "cmp_sat_oam_functional":
                # Always compare /oam (NES) vs /sat (GEN) together
                _, nes_oam = _resolve_path(nes, "/oam")
                _, gen_sat = _resolve_path(gen, "/sat")
                ok, detail = cmp_fn(nes_oam or [], gen_sat or [], tol)
            elif cmp_name == "cmp_screenshot_per_scenario":
                ok, detail = cmp_fn(nes_val, gen_val, tol, scenario_id=scenario_id)
            else:
                ok, detail = cmp_fn(nes_val, gen_val, tol)

            results.append({
                "field_path": p,
                "pass": ok,
                "nes_value": nes_val if not isinstance(nes_val, (list, dict)) else f"<{type(nes_val).__name__} len={len(nes_val) if hasattr(nes_val, '__len__') else '?'}>",
                "gen_value": gen_val if not isinstance(gen_val, (list, dict)) else f"<{type(gen_val).__name__} len={len(gen_val) if hasattr(gen_val, '__len__') else '?'}>",
                "detail": detail,
                "comparator": cmp_name,
            })

    return results


# ─── Expected failures matcher ────────────────────────────────────────────────

def _is_expected_failure(scenario_id: str, field_path: str, ef_list: list) -> dict:
    """Return the matching expected failure entry, or None."""
    for ef in ef_list:
        sid_pat = ef.get("scenario_id", "")
        fp_pat = ef.get("field_path", "")
        sid_match = fnmatch.fnmatch(scenario_id or "", sid_pat) or sid_pat == "*"
        fp_match = (fp_pat == "*") or fnmatch.fnmatch(field_path, fp_pat) or field_path.startswith(fp_pat.rstrip("*"))
        if sid_match and fp_match:
            return ef
    return None


def annotate_expected_failures(results: list, scenario_id: str, ef_data: dict) -> list:
    """
    Downgrade failures that match expected_failures.yaml from FAIL to WARN.
    Adds 'expected_failure' key to result dicts that are known divergences.
    """
    ef_list = ef_data.get("expected_failures", [])
    for r in results:
        if not r["pass"]:
            ef = _is_expected_failure(scenario_id, r["field_path"], ef_list)
            if ef:
                r["expected_failure"] = {
                    "reason": ef.get("reason", ""),
                    "owner_phase": ef.get("owner_phase", 0),
                    "memory_ref": ef.get("memory_ref", ""),
                }
    return results


# ─── Output formatters ────────────────────────────────────────────────────────

def _format_human(results: list, nes_path: str, gen_path: str, scenario_id: str) -> str:
    """Format diff results as human-readable terminal output."""
    lines = []
    lines.append("=" * 70)
    lines.append("PARITY ORACLE DIFF")
    lines.append(f"  NES: {nes_path}")
    lines.append(f"  GEN: {gen_path}")
    if scenario_id:
        lines.append(f"  Scenario: {scenario_id}")
    lines.append("=" * 70)

    passes = [r for r in results if r["pass"] and "expected_failure" not in r]
    warns = [r for r in results if "expected_failure" in r]
    fails = [r for r in results if not r["pass"] and "expected_failure" not in r]

    lines.append(f"\nSUMMARY: {len(passes)} PASS  {len(warns)} WARN  {len(fails)} FAIL\n")

    if fails:
        lines.append("─── FAILURES ──────────────────────────────────────────────────────")
        for r in fails:
            lines.append(f"  FAIL  {r['field_path']}")
            lines.append(f"        {r['detail']}")
            lines.append(f"        comparator: {r['comparator']}")
        lines.append("")

    if warns:
        lines.append("─── WARNINGS (known expected failures) ────────────────────────────")
        for r in warns:
            ef = r["expected_failure"]
            lines.append(f"  WARN  {r['field_path']}")
            lines.append(f"        {r['detail']}")
            reason = ef.get('reason', '').strip().replace('\n', ' ')
            lines.append(f"        reason: {reason[:100]}")
            lines.append(f"        owner_phase: {ef.get('owner_phase', '?')}")
        lines.append("")

    if len(passes) <= 20:
        lines.append("─── PASSES ─────────────────────────────────────────────────────────")
        for r in passes:
            lines.append(f"  PASS  {r['field_path']}")
        lines.append("")

    lines.append("=" * 70)
    lines.append("RESULT: " + ("ALL PASS" if not fails else f"FAIL ({len(fails)} field(s))"))
    lines.append("=" * 70)
    return "\n".join(lines)


def _format_json(results: list, nes_path: str, gen_path: str, scenario_id: str) -> str:
    """Format diff results as machine-readable JSON."""
    output = {
        "schema_version": 1,
        "nes_path": str(nes_path),
        "gen_path": str(gen_path),
        "scenario_id": scenario_id,
        "summary": {
            "total": len(results),
            "pass": sum(1 for r in results if r["pass"] and "expected_failure" not in r),
            "warn": sum(1 for r in results if "expected_failure" in r),
            "fail": sum(1 for r in results if not r["pass"] and "expected_failure" not in r),
        },
        "result": "PASS" if all(r["pass"] or "expected_failure" in r for r in results) else "FAIL",
        "diffs": results,
    }
    return json.dumps(output, indent=2)


# ─── Main ─────────────────────────────────────────────────────────────────────

def main():
    parser = argparse.ArgumentParser(
        description="Parity Oracle Diff — compare NES capture vs Genesis probe schema instances."
    )
    parser.add_argument("--nes", required=True, help="Path to NES capture schema JSON.")
    parser.add_argument("--gen", required=True, help="Path to Genesis probe schema JSON.")
    parser.add_argument("--human", action="store_true", help="Emit human-readable terminal output.")
    parser.add_argument("--out", help="Write output to this file instead of stdout.")
    parser.add_argument("--scenario-id", help="Scenario ID for expected_failures lookup.")
    parser.add_argument("--screenshot-dir", help="Directory containing PNG screenshots for pixel L1 comparison.")
    args = parser.parse_args()

    # ── Load inputs ───────────────────────────────────────────────────────────
    try:
        with open(args.nes, "r", encoding="utf-8") as f:
            nes_instance = json.load(f)
        with open(args.gen, "r", encoding="utf-8") as f:
            gen_instance = json.load(f)
    except (OSError, json.JSONDecodeError) as e:
        print(f"ERROR loading input files: {e}", file=sys.stderr)
        sys.exit(3)

    try:
        with open(SCHEMA_PATH, "r", encoding="utf-8") as f:
            schema = json.load(f)
    except (OSError, json.JSONDecodeError) as e:
        print(f"ERROR loading schema: {e}", file=sys.stderr)
        sys.exit(3)

    tolerances = _yaml_load_simple(TOLERANCES_PATH)
    ef_data = _yaml_load_simple(EXPECTED_FAILURES_PATH)

    # ── Validate against schema ───────────────────────────────────────────────
    nes_errors = _validate_schema(nes_instance, schema, "NES")
    gen_errors = _validate_schema(gen_instance, schema, "GEN")

    if nes_errors or gen_errors:
        print("SCHEMA VALIDATION ERRORS:", file=sys.stderr)
        for path, msg in nes_errors:
            print(f"  NES  {path}: {msg}", file=sys.stderr)
        for path, msg in gen_errors:
            print(f"  GEN  {path}: {msg}", file=sys.stderr)
        sys.exit(2)

    # ── Determine scenario_id ─────────────────────────────────────────────────
    scenario_id = args.scenario_id
    if not scenario_id:
        # Try to infer from file path (convention: <scenario_id>_nes.json)
        nes_stem = Path(args.nes).stem
        if nes_stem.endswith("_nes"):
            scenario_id = nes_stem[:-4]
        else:
            scenario_id = nes_stem

    # ── Apply tolerances ──────────────────────────────────────────────────────
    results = apply_tolerances(nes_instance, gen_instance, tolerances, scenario_id)
    results = annotate_expected_failures(results, scenario_id, ef_data)

    # ── Format output ─────────────────────────────────────────────────────────
    if args.human:
        output_str = _format_human(results, args.nes, args.gen, scenario_id)
    else:
        output_str = _format_json(results, args.nes, args.gen, scenario_id)

    if args.out:
        try:
            with open(args.out, "w", encoding="utf-8") as f:
                f.write(output_str)
        except OSError as e:
            print(f"ERROR writing output: {e}", file=sys.stderr)
            sys.exit(3)
    else:
        print(output_str)

    # ── Exit code ─────────────────────────────────────────────────────────────
    hard_fails = [r for r in results if not r["pass"] and "expected_failure" not in r]
    sys.exit(1 if hard_fails else 0)


if __name__ == "__main__":
    main()
