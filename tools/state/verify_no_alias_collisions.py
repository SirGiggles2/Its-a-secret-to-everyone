#!/usr/bin/env python3
"""
verify_no_alias_collisions.py — Workstream G: Alias Collision Gate

Scans every src/state/*.h file for RAM() and OBJ() macro definitions,
then fails with exit code 1 if any two distinct macro names map to the
same numeric NES RAM offset (same-kind pairs: RAM-RAM or OBJ-OBJ).

Required green in the phase close gate per master plan Task 2.0.

Per docs/audit/state_contract.md, alias collisions are resolved
incrementally as each subsystem is promoted to typed structs (per-phase
migration order). Use --scope to enforce hard-fail only for collisions
that involve a currently-promoted subsystem; collisions outside scope
are reported as INFO and do not fail the build.

Usage:
    python tools/state/verify_no_alias_collisions.py [--repo-root PATH]
                                                     [--scope SUB[,SUB...]]
                                                     [--strict-all]

Exit codes:
    0 — no in-scope alias collisions (out-of-scope collisions may exist
        and are reported as INFO when --scope is set)
    1 — one or more in-scope alias collisions found

Examples:
    # Phase close gate for Phase 2 (graphics registry):
    python tools/state/verify_no_alias_collisions.py \
        --scope vram_map,palette

    # Phase 7 (enemies) close gate:
    python tools/state/verify_no_alias_collisions.py --scope enemy

    # Bulk strict mode (current default if --scope omitted):
    python tools/state/verify_no_alias_collisions.py
"""

import argparse
import sys
from pathlib import Path

# Re-use scanner from audit script (same directory)
_HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(_HERE))

from audit_macro_shims import scan_all, find_collisions  # noqa: E402


def _parse_scope(scope_arg: str | None) -> set[str] | None:
    """Parse comma-separated scope list. None = strict-all (legacy default)."""
    if scope_arg is None:
        return None
    return {s.strip() for s in scope_arg.split(",") if s.strip()}


def _subsys_match(entry_subsys: str, scope: set[str]) -> bool:
    """
    MacroEntry.subsystem is the file stem (e.g. 'enemy_state'); user passes
    the short subsystem name (e.g. 'enemy'). Match either form: exact, with
    '_state' suffix stripped from the entry, or scope item with '_state'
    suffix added. Case-insensitive for safety.
    """
    e = entry_subsys.lower()
    e_short = e[:-6] if e.endswith("_state") else e
    for s in scope:
        s_lo = s.lower()
        if s_lo == e or s_lo == e_short or f"{s_lo}_state" == e:
            return True
    return False


def _classify(collision, scope: set[str] | None) -> str:
    """
    Return 'in_scope' if either side is in the promotion scope (hard fail),
    else 'out_of_scope' (info only).
    If scope is None, every collision is in_scope (strict-all mode).
    """
    if scope is None:
        return "in_scope"
    a, b = collision
    if _subsys_match(a.subsystem, scope) or _subsys_match(b.subsystem, scope):
        return "in_scope"
    return "out_of_scope"


def main() -> int:
    parser = argparse.ArgumentParser(
        description=__doc__.split("\n\n")[0],
        formatter_class=argparse.RawDescriptionHelpFormatter,
    )
    parser.add_argument(
        "--repo-root",
        default=None,
        help="Repository root (default: two levels up from this script's directory)",
    )
    parser.add_argument(
        "--scope",
        default=None,
        help=(
            "Comma-separated subsystem names to enforce (e.g. 'vram_map,palette'). "
            "Collisions involving these subsystems are hard-fail; others are INFO. "
            "Omit (or use --strict-all) for legacy strict-all behavior."
        ),
    )
    parser.add_argument(
        "--strict-all",
        action="store_true",
        help="Force strict-all mode (every collision is hard-fail). Overrides --scope.",
    )
    args = parser.parse_args()

    if args.repo_root:
        repo_root = Path(args.repo_root).resolve()
    else:
        repo_root = Path(__file__).resolve().parent.parent.parent

    state_dir = repo_root / "src" / "state"

    if not state_dir.is_dir():
        print(f"ERROR: state dir not found: {state_dir}", file=sys.stderr)
        return 1

    scope = None if args.strict_all else _parse_scope(args.scope)

    entries = scan_all(state_dir)
    collisions = find_collisions(entries)

    if not collisions:
        print("OK: no alias collisions found.")
        return 0

    in_scope: list = []
    out_of_scope: list = []
    for c in collisions:
        if _classify(c, scope) == "in_scope":
            in_scope.append(c)
        else:
            out_of_scope.append(c)

    # Header summary
    if scope is None:
        print(f"Strict-all mode: {len(collisions)} alias collision(s) found in src/state/*.h\n")
    else:
        scope_str = ",".join(sorted(scope))
        print(
            f"Scoped mode: scope={{{scope_str}}}; "
            f"{len(in_scope)} in-scope (hard fail), "
            f"{len(out_of_scope)} out-of-scope (info only).\n"
        )

    def _print_table(title: str, group: list, hard_fail: bool):
        if not group:
            return
        marker = "FAIL" if hard_fail else "INFO"
        print(f"--- {marker}: {title} ({len(group)} collision(s)) ---")
        print(f"{'Offset':<8}  {'Kind':<4}  {'Name A':<40}  {'Location A':<30}  "
              f"{'Name B':<40}  {'Location B'}")
        print("-" * 160)
        for a, b in group:
            offset_str = f"0x{a.resolved_offset:04X}"
            loc_a = f"{a.filename}:{a.lineno}"
            loc_b = f"{b.filename}:{b.lineno}"
            print(f"{offset_str:<8}  {a.kind:<4}  {a.name:<40}  {loc_a:<30}  "
                  f"{b.name:<40}  {loc_b}")
        print()

    _print_table("in-scope alias collisions", in_scope, hard_fail=True)
    _print_table("out-of-scope alias collisions (deferred per state_contract.md)",
                 out_of_scope, hard_fail=False)

    if in_scope:
        print(f"FAIL: {len(in_scope)} in-scope collision(s) must be resolved.")
        print(
            "  Each NES RAM byte gets exactly one canonical struct field name. "
            "See docs/audit/state_contract.md."
        )
        return 1

    if out_of_scope:
        print(
            f"OK (scoped): no in-scope collisions; {len(out_of_scope)} out-of-scope "
            "collision(s) deferred to their owning subsystem's promotion phase."
        )
    return 0


if __name__ == "__main__":
    sys.exit(main())
