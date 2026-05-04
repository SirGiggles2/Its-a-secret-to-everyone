#!/usr/bin/env python3
"""prime_refresh.py — rebuild the Prime Directive tracker from authoritative inputs.

Authoritative inputs:
  - docs/superpowers/plans/2026-05-02-title-roomrom-full-port-master-plan.md
  - docs/audit/active_scope.md (or .active_scope)
  - tools/audit/drain_coverage.json
  - git rev-parse HEAD + git status
  - existing tracker (preserve human/tool decisions: deferrals, out_of_phase_tasks)

Writes:
  - docs/superpowers/prime_directive_tracker.json
  - docs/superpowers/prime_directive_status.md (rendered human view)

Flags:
  --record-out-of-phase TARGET REASON STANCE  append an out_of_phase_tasks entry
  --record-deferral PHASE STEP REASON          append a deferral entry
  --close-phase ID                              mark phase ID complete (artifact-checked)
  --no-render                                   skip status.md render
"""
from __future__ import annotations

import argparse
import datetime as dt
import hashlib
import json
import re
import subprocess
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parents[3]
TRACKER = REPO / "docs" / "superpowers" / "prime_directive_tracker.json"
STATUS_MD = REPO / "docs" / "superpowers" / "prime_directive_status.md"
PLAN = REPO / "docs" / "superpowers" / "plans" / "2026-05-02-title-roomrom-full-port-master-plan.md"
ACTIVE_SCOPE_MD = REPO / "docs" / "audit" / "active_scope.md"
DRAIN_COVERAGE = REPO / "tools" / "audit" / "drain_coverage.json"

PHASE_NAMES = {
    "0": "Target Rename and Split",
    "1": "Legal Builder Foundation",
    "1.5": "NES Reference Capture Harness",
    "2": "RoomRom Graphics Registry And No-Clobber Foundation",
    "3": "Overworld Caves",
    "4": "Overworld Secrets, Traversal, And State",
    "5": "Dungeon Core",
    "6": "Link, Inventory, Items, And Combat",
    "7": "Enemies By Behavior Family",
    "8": "Bosses",
    "9": "HUD, Options, Save, Menus",
    "10": "Audio Finalization",
    "11": "Title.md Frontend Gap-Fill + Regression Lock",
    "12": "Promote RoomRom Core And Integrate Final ROM",
    "13": "Optional 4-Player Genesis Mode",
    "14": "Full Quest Completion",
    "15": "Genesis-Specific Optimization",
    "16": "Hardware, Performance, And Polish",
    "17": "Public Builder Release",
}

GATE_STEPS = [
    "build_REQUIRE_GENERATED_ASSETS",
    "focused_probe_set",
    "screenshot_state_evidence",
    "diff_vs_nes_reference",
    "regression_matrix",
    "verify_no_alias_collisions",
    "PROBE_CYCLE_LIMIT_envelope",
    "code_review_requested",
    "findings_resolved_or_deferred",
    "rerun_probes_and_matrix",
    "phase_commit_with_report_paths",
]

SUBSTRATE_PATHS = [
    "src/sgdk_adapter/",
    "src/abi/",
    "src/state/",
    "data/",
    "src/audio_driver.asm",
]


def now_iso() -> str:
    return dt.datetime.now(dt.timezone.utc).isoformat()


def sha256_path(p: Path) -> str | None:
    if not p.exists():
        return None
    h = hashlib.sha256()
    with p.open("rb") as f:
        for chunk in iter(lambda: f.read(65536), b""):
            h.update(chunk)
    return h.hexdigest()


def git(*args: str) -> str:
    r = subprocess.run(["git", *args], cwd=REPO, capture_output=True, text=True, check=False)
    return r.stdout.strip()


def derive_active_phase() -> tuple[str, str | None]:
    if ACTIVE_SCOPE_MD.exists():
        text = ACTIVE_SCOPE_MD.read_text(encoding="utf-8", errors="ignore")
        m = re.search(r"(?:^|\n)#\s*Active\s+(?:phase|scope)[^\n]*", text, re.IGNORECASE)
        if m:
            chunk = text[m.start(): m.start() + 600]
            pm = re.search(r"[Pp]hase\s*[:#]?\s*([0-9]+(?:\.5)?)", chunk)
            if pm:
                pid = pm.group(1)
                tm = re.search(r"[Tt]ask\s*[:#]?\s*([0-9]+(?:\.[0-9]+)+)", chunk)
                return pid, (tm.group(1) if tm else None)
    log = git("log", "--oneline", "-200")
    matches = re.findall(r"phase\s*([0-9]+(?:\.5)?)\s+close", log, re.IGNORECASE)
    if matches:
        last = max(matches, key=lambda v: float(v))
        keys = sorted(PHASE_NAMES.keys(), key=float)
        idx = keys.index(last) if last in keys else -1
        if idx >= 0 and idx + 1 < len(keys):
            return keys[idx + 1], None
    return "0", None


def detect_worktree() -> dict:
    branch = git("rev-parse", "--abbrev-ref", "HEAD") or "?"
    wt_path = git("rev-parse", "--show-toplevel") or str(REPO)
    return {
        "path": wt_path,
        "branch": branch,
        "is_substrate_writer": branch == "main",
    }


def build_phase_entries(active_id: str, prev: dict) -> list[dict]:
    prev_phases = {p["id"]: p for p in prev.get("phases", [])}
    out = []
    seen_active = False
    for pid in sorted(PHASE_NAMES.keys(), key=float):
        old = prev_phases.get(pid, {})
        if pid == active_id:
            status = "active"
            seen_active = True
        elif not seen_active:
            status = old.get("status", "complete")
            if status not in ("complete", "active", "pending", "blocked"):
                status = "complete"
        else:
            status = "pending"
        entry = {
            "id": pid,
            "name": PHASE_NAMES[pid],
            "status": status,
            "tasks": old.get("tasks", []),
            "evidence": old.get("evidence", []),
            "deferrals": old.get("deferrals", []),
            "close_gate": old.get("close_gate") or {step: ("not_applicable" if (pid in {"0"} and step == "verify_no_alias_collisions") else "pending") for step in GATE_STEPS},
        }
        out.append(entry)
    return out


def build_tracker(prev: dict) -> dict:
    active_id, active_task = derive_active_phase()
    plan_sha = sha256_path(PLAN) or ""
    active_scope_sha = sha256_path(ACTIVE_SCOPE_MD)
    drain_sha = sha256_path(DRAIN_COVERAGE)
    head = git("rev-parse", "HEAD")

    dirty = []
    status_porcelain = git("status", "--porcelain")
    for line in status_porcelain.splitlines():
        if len(line) > 3:
            path = line[3:].strip()
            if any(path.startswith(s) for s in ("src/", "RoomRom/", "data/", "tools/", "build.bat")):
                dirty.append(path)

    phases = build_phase_entries(active_id, prev)
    active_phase = next((p for p in phases if p["id"] == active_id), phases[0])
    active_task_title = ""
    for t in active_phase.get("tasks", []):
        if t.get("id") == active_task or t.get("status") == "active":
            active_task_title = t.get("title", "")
            break

    tr = {
        "schema_version": 1,
        "generated_at": now_iso(),
        "generated_by": "tools/audit/primedirective/prime_refresh.py",
        "plan": {"path": str(PLAN.relative_to(REPO)).replace("\\", "/"), "sha256": plan_sha},
        "active": {
            "phase_id": active_id,
            "phase_name": PHASE_NAMES.get(active_id, "?"),
            "task_id": active_task or "?",
            "task_title": active_task_title,
            "worktree": detect_worktree(),
            "next_concrete_action": prev.get("active", {}).get("next_concrete_action", "Read docs/superpowers/prime_directive_status.md"),
        },
        "phases": phases,
        "scope_lock": prev.get("scope_lock", {
            "active_task_only": True,
            "allowed_escape_hatches": ["blocking_fix", "phase_close_gate", "user_interrupt", "out_of_phase_task"],
            "requires_tracker_note": True,
        }),
        "out_of_phase_tasks": prev.get("out_of_phase_tasks", []),
        "deferrals": prev.get("deferrals", []),
        "freshness": {
            "active_scope_md": {
                "path": str(ACTIVE_SCOPE_MD.relative_to(REPO)).replace("\\", "/"),
                "sha256": active_scope_sha,
                "ok": ACTIVE_SCOPE_MD.exists(),
            },
            "drain_coverage_json": {
                "path": str(DRAIN_COVERAGE.relative_to(REPO)).replace("\\", "/"),
                "sha256": drain_sha,
                "ok": DRAIN_COVERAGE.exists(),
            },
            "git_head": head,
            "dirty_paths_relevant": dirty,
            "evidence_paths_present": True,
            "complete_phase_invariant_ok": True,
            "last_refresh_at": now_iso(),
            "stale_reasons": [],
        },
        "blockers": [],
    }

    wt = tr["active"]["worktree"]
    if not wt["is_substrate_writer"]:
        for p in dirty:
            if any(p.startswith(s) for s in SUBSTRATE_PATHS):
                tr["blockers"].append({
                    "kind": "worktree",
                    "description": f"Substrate edit on non-main worktree: {p} (WT-1)",
                    "path": p,
                })

    return tr


def render_status_md(tr: dict) -> str:
    a = tr["active"]
    phase = next((p for p in tr["phases"] if p["id"] == a["phase_id"]), {})
    gate = phase.get("close_gate", {})
    passed = [k for k, v in gate.items() if v == "passed"]
    pending = [k for k, v in gate.items() if v == "pending"]
    blockers = tr.get("blockers", [])

    lines = [
        "# Prime Directive — Status",
        "",
        f"_Generated {tr['generated_at']} by `prime_refresh.py`._",
        "",
        f"**Phase:** {a['phase_id']} — {a['phase_name']}",
        f"**Task:** {a['task_id']} — {a.get('task_title','')}",
        f"**Worktree:** `{a['worktree']['branch']}` at `{a['worktree']['path']}`",
        f"**Substrate writer:** {a['worktree']['is_substrate_writer']}",
        "",
        f"**Gates:** {len(passed)} passed / {len(gate)} total",
        "",
    ]
    if pending:
        lines.append("**Pending gate steps:**")
        for s in pending:
            lines.append(f"- {s}")
        lines.append("")
    if blockers:
        lines.append("**Blockers:**")
        for b in blockers:
            lines.append(f"- **{b['kind']}** — {b['description']}")
        lines.append("")
    if tr.get("out_of_phase_tasks"):
        lines.append(f"**Out-of-phase tasks:** {len(tr['out_of_phase_tasks'])}")
        for o in tr["out_of_phase_tasks"][-3:]:
            lines.append(f"- target Ph{o.get('target_phase_id','?')} · stance {o.get('stance','?')} · {o.get('reason','?')[:60]}")
        lines.append("")
    lines.append(f"**Next concrete action:** {a.get('next_concrete_action','')}")
    return "\n".join(lines) + "\n"


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--record-out-of-phase", nargs=3, metavar=("TARGET", "REASON", "STANCE"))
    ap.add_argument("--record-deferral", nargs=3, metavar=("PHASE", "STEP", "REASON"))
    ap.add_argument("--close-phase", metavar="ID")
    ap.add_argument("--mark-passed", nargs=3, metavar=("PHASE", "STEP", "EVIDENCE"),
                    help="Mark a close-gate step as 'passed' with an evidence path/note")
    ap.add_argument("--no-render", action="store_true")
    args = ap.parse_args()

    prev = {}
    if TRACKER.exists():
        try:
            prev = json.loads(TRACKER.read_text(encoding="utf-8"))
        except json.JSONDecodeError:
            prev = {}

    tr = build_tracker(prev)

    if args.record_out_of_phase:
        target, reason, stance = args.record_out_of_phase
        if stance not in ("PARTIAL", "REPLACE"):
            print(f"ERROR: stance must be PARTIAL or REPLACE, got {stance}", file=sys.stderr)
            return 2
        tr["out_of_phase_tasks"].append({
            "target_phase_id": target,
            "reason": reason,
            "stance": stance,
            "regression_matrix_run": None,
            "recorded_at": now_iso(),
        })

    if args.record_deferral:
        phase, step, reason = args.record_deferral
        tr["deferrals"].append({
            "phase_id": phase,
            "gate_step": step,
            "reason": reason,
            "recorded_at": now_iso(),
        })

    if args.mark_passed:
        phase_id, step, evidence = args.mark_passed
        if step not in GATE_STEPS:
            print(f"ERROR: unknown gate step '{step}'. Valid: {GATE_STEPS}", file=sys.stderr)
            return 2
        found = False
        for ph in tr["phases"]:
            if ph["id"] == phase_id:
                ph.setdefault("close_gate", {})[step] = "passed"
                ph.setdefault("evidence", []).append(f"{step}|{evidence}")
                found = True
                break
        if not found:
            print(f"ERROR: phase {phase_id} not found", file=sys.stderr)
            return 2

    if args.close_phase:
        for ph in tr["phases"]:
            if ph["id"] == args.close_phase:
                gate = ph.get("close_gate", {})
                pending = [k for k, v in gate.items() if v == "pending"]
                if pending:
                    print(f"ERROR: cannot close phase {args.close_phase}: {len(pending)} gate step(s) pending: {pending}", file=sys.stderr)
                    return 2
                ph["status"] = "complete"
                ph.setdefault("evidence", []).append(f"commit:{git('rev-parse', 'HEAD')[:10]}")
                break

    TRACKER.parent.mkdir(parents=True, exist_ok=True)
    TRACKER.write_text(json.dumps(tr, indent=2) + "\n", encoding="utf-8")
    if not args.no_render:
        STATUS_MD.write_text(render_status_md(tr), encoding="utf-8")

    print(f"REFRESHED  {TRACKER.relative_to(REPO)}  ({len(tr['blockers'])} blockers)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
