# Completion Tracker Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a completion tracker whose 16×5 = 80 cell verdicts are a pure function of signed, on-disk evidence, so no cell can ever read GREEN without a verification having actually run.

**Architecture:** Producers (parity differs, harnesses, gates) emit signed evidence blocks under `--emit-evidence`; audit files embed those blocks verbatim; `collect.py` re-verifies every block and writes a canonical tracker JSON; `report.py` renders it; `release_gate.py` re-collects and refuses to package on any RED. Validation is split into small single-responsibility modules so each rule is independently testable.

**Tech Stack:** Python 3.14, pyyaml 6.0.3, pytest 9.0.3, hmac/hashlib (stdlib). Matches `tools/gates/` and `tools/debug/test_*_contract.py` precedent.

**Spec:** `docs/superpowers/specs/2026-08-03-completion-tracker-design.md` (v2, commit `7e4ca269`).

---

## File Structure

| File | Responsibility |
|---|---|
| `tools/audit/completion/model.py` | The 16 systems, 5 axes, cell identity, verdict enum. No I/O. |
| `tools/audit/completion/schema.json` | `na_allowlist` + evidence field contract. Data, not code. |
| `tools/audit/completion/signing.py` | Key management, `sign()`, `verify()`. Nothing else. |
| `tools/audit/completion/emit.py` | Producer side: `EvidenceRecorder` (input discovery + block emission). |
| `tools/audit/completion/evidence.py` | Parse a block; apply §4 rules 1–8 and §8.1. Returns verdict + reasons. |
| `tools/audit/completion/collect.py` | Walk `docs/audit/systems/*.md`, build canonical tracker JSON. |
| `tools/audit/completion/report.py` | Tracker JSON → `docs/audit/COMPLETION.md`. Read-only. |
| `tools/audit/completion/tests/` | pytest suite, one file per module. |
| `tools/builder/release_gate.py` | *Modify:* add re-collect + refusal + `--override`. |

Split rationale: `evidence.py` holds all rule logic and nothing else, so the load-bearing invariant test (Task 16) has one place to attack. `signing.py` is separate because it is the only module with a secret, and mixing it into rule logic would make the rules untestable without a key.

---

### Task 1: Systems, axes, and the 80-cell grid

**Files:**
- Create: `tools/audit/completion/model.py`
- Test: `tools/audit/completion/tests/test_model.py`

- [ ] **Step 1: Write the failing test**

```python
from __future__ import annotations

from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[4]
sys.path.insert(0, str(ROOT / "tools" / "audit" / "completion"))

import model


def test_sixteen_systems() -> None:
    assert len(model.SYSTEMS) == 16
    assert model.SYSTEMS[0] == "frontend"
    assert "dungeons" in model.SYSTEMS
    assert "builder" in model.SYSTEMS


def test_five_axes() -> None:
    assert model.AXES == ("DATA", "BEHAVIOR", "PLAYABLE", "CODE", "LEGAL")


def test_grid_is_eighty_cells() -> None:
    cells = model.all_cells()
    assert len(cells) == 80
    assert len(set(cells)) == 80


def test_grid_order_is_stable() -> None:
    assert model.all_cells() == model.all_cells()
    assert model.all_cells()[0] == ("frontend", "DATA")
```

- [ ] **Step 2: Run test to verify it fails**

Run: `python -m pytest tools/audit/completion/tests/test_model.py -v`
Expected: FAIL — `ModuleNotFoundError: No module named 'model'`

- [ ] **Step 3: Write minimal implementation**

```python
"""model.py — the completion grid: 16 systems x 5 axes = 80 cells.

Per docs/superpowers/specs/2026-08-03-completion-tracker-design.md §3.
Pure data + identity. No I/O, no validation, no verdict logic.
"""
from __future__ import annotations

SYSTEMS: tuple[str, ...] = (
    "frontend",
    "save",
    "overworld",
    "caves",
    "dungeons",
    "link",
    "combat",
    "items",
    "enemies",
    "bosses",
    "hud",
    "modes",
    "audio",
    "quest2",
    "perf",
    "builder",
)

AXES: tuple[str, ...] = ("DATA", "BEHAVIOR", "PLAYABLE", "CODE", "LEGAL")

GREEN = "GREEN"
RED = "RED"
NA = "N/A"


def all_cells() -> list[tuple[str, str]]:
    """Every (system, axis) pair in fixed spec order. Stable across runs."""
    return [(s, a) for s in SYSTEMS for a in AXES]
```

- [ ] **Step 4: Run test to verify it passes**

Run: `python -m pytest tools/audit/completion/tests/test_model.py -v`
Expected: PASS, 4 passed

- [ ] **Step 5: Commit**

```bash
git add tools/audit/completion/model.py tools/audit/completion/tests/test_model.py
git commit -m "feat(completion): 16x5 cell grid model"
```

---

### Task 2: Evidence signing

**Files:**
- Create: `tools/audit/completion/signing.py`
- Test: `tools/audit/completion/tests/test_signing.py`

Implements spec §4.1 step 3. The key lives at `tools/audit/completion/.evidence_key`, is generated on first use, and is gitignored.

- [ ] **Step 1: Write the failing test**

```python
from __future__ import annotations

from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[4]
sys.path.insert(0, str(ROOT / "tools" / "audit" / "completion"))

import signing


PAYLOAD = {
    "command": "python tools/parity/run.py",
    "verdict_line": "171/171 PASS",
    "inputs": [{"path": "a.c", "sha256": "ab" * 32}],
}


def test_sign_is_deterministic(tmp_path: Path) -> None:
    key = signing.load_or_create_key(tmp_path / ".k")
    assert signing.sign(key, PAYLOAD) == signing.sign(key, PAYLOAD)


def test_sign_is_hex_sha256_length(tmp_path: Path) -> None:
    key = signing.load_or_create_key(tmp_path / ".k")
    assert len(signing.sign(key, PAYLOAD)) == 64


def test_verify_accepts_own_signature(tmp_path: Path) -> None:
    key = signing.load_or_create_key(tmp_path / ".k")
    assert signing.verify(key, PAYLOAD, signing.sign(key, PAYLOAD))


def test_verify_rejects_tampered_input(tmp_path: Path) -> None:
    key = signing.load_or_create_key(tmp_path / ".k")
    sig = signing.sign(key, PAYLOAD)
    tampered = {**PAYLOAD, "inputs": [{"path": "a.c", "sha256": "cd" * 32}]}
    assert not signing.verify(key, tampered, sig)


def test_verify_rejects_dropped_input(tmp_path: Path) -> None:
    """Removing a dependency must invalidate — this is finding A."""
    key = signing.load_or_create_key(tmp_path / ".k")
    sig = signing.sign(key, PAYLOAD)
    assert not signing.verify(key, {**PAYLOAD, "inputs": []}, sig)


def test_key_persists(tmp_path: Path) -> None:
    p = tmp_path / ".k"
    assert signing.load_or_create_key(p) == signing.load_or_create_key(p)


def test_key_ignores_field_order(tmp_path: Path) -> None:
    key = signing.load_or_create_key(tmp_path / ".k")
    reordered = {
        "inputs": PAYLOAD["inputs"],
        "verdict_line": PAYLOAD["verdict_line"],
        "command": PAYLOAD["command"],
    }
    assert signing.verify(key, reordered, signing.sign(key, PAYLOAD))
```

- [ ] **Step 2: Run test to verify it fails**

Run: `python -m pytest tools/audit/completion/tests/test_signing.py -v`
Expected: FAIL — `ModuleNotFoundError: No module named 'signing'`

- [ ] **Step 3: Write minimal implementation**

```python
"""signing.py — run signatures for evidence blocks (spec §4.1 step 3).

NOT a security boundary: anyone with repo write access holds the key.
It is a discipline boundary — fabricating evidence must require
deliberately re-running the producer, not a moment of optimism.
"""
from __future__ import annotations

import hashlib
import hmac
import json
import secrets
from pathlib import Path

SIGNED_FIELDS = ("command", "verdict_line", "inputs")


def load_or_create_key(path: Path) -> bytes:
    """Read the per-repo HMAC key, generating one on first use."""
    if path.exists():
        return path.read_bytes()
    path.parent.mkdir(parents=True, exist_ok=True)
    key = secrets.token_bytes(32)
    path.write_bytes(key)
    return key


def canonical(payload: dict) -> bytes:
    """Field-order-independent, whitespace-stable serialization."""
    subset = {k: payload.get(k) for k in SIGNED_FIELDS}
    return json.dumps(
        subset, sort_keys=True, separators=(",", ":"), ensure_ascii=False
    ).encode("utf-8")


def sign(key: bytes, payload: dict) -> str:
    return hmac.new(key, canonical(payload), hashlib.sha256).hexdigest()


def verify(key: bytes, payload: dict, signature: str) -> bool:
    return hmac.compare_digest(sign(key, payload), signature or "")
```

- [ ] **Step 4: Run test to verify it passes**

Run: `python -m pytest tools/audit/completion/tests/test_signing.py -v`
Expected: PASS, 7 passed

- [ ] **Step 5: Gitignore the key**

Append to `.gitignore`:

```
tools/audit/completion/.evidence_key
```

- [ ] **Step 6: Commit**

```bash
git add tools/audit/completion/signing.py tools/audit/completion/tests/test_signing.py .gitignore
git commit -m "feat(completion): HMAC run signatures for evidence blocks"
```

---

### Task 3: Schema and the N/A allowlist

**Files:**
- Create: `tools/audit/completion/schema.json`
- Test: `tools/audit/completion/tests/test_schema.py`

Implements spec §4 rule 6 — N/A requires an allowlist entry, so exemptions appear in a reviewable diff instead of buried prose.

- [ ] **Step 1: Write the failing test**

```python
from __future__ import annotations

import json
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[4]
sys.path.insert(0, str(ROOT / "tools" / "audit" / "completion"))

import model

SCHEMA = ROOT / "tools" / "audit" / "completion" / "schema.json"


def load() -> dict:
    return json.loads(SCHEMA.read_text(encoding="utf-8"))


def test_schema_parses() -> None:
    assert load()["schema_version"] == 1


def test_na_allowlist_exists() -> None:
    assert isinstance(load()["na_allowlist"], list)


def test_na_allowlist_entries_are_valid_cells() -> None:
    for entry in load()["na_allowlist"]:
        assert entry["system"] in model.SYSTEMS
        assert entry["axis"] in model.AXES
        assert entry["reason"].strip()


def test_required_evidence_fields_declared() -> None:
    required = load()["required_evidence_fields"]
    for field in (
        "system", "axis", "verdict", "artifact", "artifact_sha256",
        "command", "verdict_line", "run_signature", "manifest_emitted_by",
        "inputs",
    ):
        assert field in required
```

- [ ] **Step 2: Run test to verify it fails**

Run: `python -m pytest tools/audit/completion/tests/test_schema.py -v`
Expected: FAIL — `FileNotFoundError: schema.json`

- [ ] **Step 3: Write minimal implementation**

```json
{
  "schema_version": 1,
  "_comment": "N/A eligibility is data, not prose. Adding an entry here is a reviewable diff. See spec 2026-08-03-completion-tracker-design.md section 4 rule 6.",
  "required_evidence_fields": [
    "system",
    "axis",
    "verdict",
    "artifact",
    "artifact_sha256",
    "command",
    "verdict_line",
    "run_signature",
    "manifest_emitted_by",
    "inputs"
  ],
  "max_artifact_bytes": 1048576,
  "artifact_root": "docs/",
  "na_allowlist": [
    {
      "system": "modes",
      "axis": "DATA",
      "reason": "Game-mode dispatch owns no assets or data tables; DATA parity is meaningless for this system."
    },
    {
      "system": "perf",
      "axis": "DATA",
      "reason": "Performance measurement owns no assets; frame timing is not a data-parity question."
    }
  ]
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `python -m pytest tools/audit/completion/tests/test_schema.py -v`
Expected: PASS, 4 passed

- [ ] **Step 5: Commit**

```bash
git add tools/audit/completion/schema.json tools/audit/completion/tests/test_schema.py
git commit -m "feat(completion): schema with data-driven N/A allowlist"
```

---

### Task 4: Parse evidence blocks out of audit markdown

**Files:**
- Create: `tools/audit/completion/evidence.py`
- Test: `tools/audit/completion/tests/test_evidence_parse.py`

- [ ] **Step 1: Write the failing test**

```python
from __future__ import annotations

from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[4]
sys.path.insert(0, str(ROOT / "tools" / "audit" / "completion"))

import evidence

DOC = """# System audit — dungeons

## Axis verdicts

```yaml evidence
- system: dungeons
  axis: DATA
  verdict: GREEN
  artifact: docs/parity/dungeon_status.md
```

Some prose that must be ignored.

```python
print("not an evidence block")
```

```yaml evidence
- system: dungeons
  axis: CODE
  verdict: RED
```
"""


def test_parses_both_blocks(tmp_path: Path) -> None:
    p = tmp_path / "dungeons.md"
    p.write_text(DOC, encoding="utf-8")
    blocks = evidence.parse_blocks(p)
    assert len(blocks) == 2
    assert blocks[0]["axis"] == "DATA"
    assert blocks[1]["axis"] == "CODE"


def test_ignores_non_evidence_fences(tmp_path: Path) -> None:
    p = tmp_path / "dungeons.md"
    p.write_text(DOC, encoding="utf-8")
    assert all(b["system"] == "dungeons" for b in evidence.parse_blocks(p))


def test_malformed_yaml_raises(tmp_path: Path) -> None:
    p = tmp_path / "bad.md"
    p.write_text("```yaml evidence\n  : : nope\n```\n", encoding="utf-8")
    try:
        evidence.parse_blocks(p)
    except evidence.MalformedEvidence as exc:
        assert "bad.md" in str(exc)
    else:
        raise AssertionError("expected MalformedEvidence")


def test_no_blocks_returns_empty(tmp_path: Path) -> None:
    p = tmp_path / "empty.md"
    p.write_text("# nothing here\n", encoding="utf-8")
    assert evidence.parse_blocks(p) == []
```

- [ ] **Step 2: Run test to verify it fails**

Run: `python -m pytest tools/audit/completion/tests/test_evidence_parse.py -v`
Expected: FAIL — `ModuleNotFoundError: No module named 'evidence'`

- [ ] **Step 3: Write minimal implementation**

```python
"""evidence.py — parse and validate evidence blocks (spec §4, §4.1, §8.1).

A cell is GREEN only when every rule here passes. There is no code path
that returns GREEN from anything other than a fully verified block.
"""
from __future__ import annotations

import re
from pathlib import Path

import yaml

FENCE = re.compile(r"^```yaml evidence\s*$(.*?)^```\s*$", re.M | re.S)


class MalformedEvidence(Exception):
    """An audit file could not be parsed. Never downgraded to a verdict."""


def parse_blocks(path: Path) -> list[dict]:
    """Return every evidence mapping in `path`, in document order."""
    text = path.read_text(encoding="utf-8")
    out: list[dict] = []
    for match in FENCE.finditer(text):
        try:
            parsed = yaml.safe_load(match.group(1))
        except yaml.YAMLError as exc:
            raise MalformedEvidence(f"{path}: {exc}") from exc
        if parsed is None:
            continue
        if not isinstance(parsed, list):
            raise MalformedEvidence(f"{path}: evidence fence must be a YAML list")
        for item in parsed:
            if not isinstance(item, dict):
                raise MalformedEvidence(f"{path}: evidence entry must be a mapping")
            out.append(item)
    return out
```

- [ ] **Step 4: Run test to verify it passes**

Run: `python -m pytest tools/audit/completion/tests/test_evidence_parse.py -v`
Expected: PASS, 4 passed

- [ ] **Step 5: Commit**

```bash
git add tools/audit/completion/evidence.py tools/audit/completion/tests/test_evidence_parse.py
git commit -m "feat(completion): parse evidence blocks from audit markdown"
```

---

### Task 5: Rules 1–2 — artifact exists and hash matches

**Files:**
- Modify: `tools/audit/completion/evidence.py`
- Test: `tools/audit/completion/tests/test_evidence_rules.py`

- [ ] **Step 1: Write the failing test**

```python
from __future__ import annotations

import hashlib
import json
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[4]
sys.path.insert(0, str(ROOT / "tools" / "audit" / "completion"))

import evidence
import signing


def sha(p: Path) -> str:
    return hashlib.sha256(p.read_bytes()).hexdigest()


def make_repo(tmp_path: Path) -> tuple[Path, bytes, dict]:
    """A minimal valid repo: one artifact, one input, a signed block."""
    (tmp_path / "docs").mkdir()
    art = tmp_path / "docs" / "status.md"
    art.write_text("Total 171/171 PASS\n", encoding="utf-8")
    src = tmp_path / "rooms.c"
    src.write_text("const int x = 1;\n", encoding="utf-8")

    key = signing.load_or_create_key(tmp_path / ".k")
    block = {
        "system": "dungeons",
        "axis": "DATA",
        "verdict": "GREEN",
        "artifact": "docs/status.md",
        "artifact_sha256": sha(art),
        "command": "python run.py",
        "verdict_line": "Total 171/171 PASS",
        "manifest_emitted_by": "tools/parity/run.py",
        "inputs": [{"path": "rooms.c", "sha256": sha(src)}],
    }
    block["run_signature"] = signing.sign(key, block)
    return tmp_path, key, block


SCHEMA = json.loads(
    (ROOT / "tools" / "audit" / "completion" / "schema.json").read_text(encoding="utf-8")
)


def test_valid_block_is_green(tmp_path: Path) -> None:
    root, key, block = make_repo(tmp_path)
    result = evidence.evaluate(block, root, key, SCHEMA)
    assert result.verdict == "GREEN", result.reasons


def test_missing_artifact_is_red(tmp_path: Path) -> None:
    root, key, block = make_repo(tmp_path)
    (root / "docs" / "status.md").unlink()
    result = evidence.evaluate(block, root, key, SCHEMA)
    assert result.verdict == "RED"
    assert any("artifact missing" in r for r in result.reasons)


def test_artifact_hash_drift_is_red(tmp_path: Path) -> None:
    root, key, block = make_repo(tmp_path)
    (root / "docs" / "status.md").write_text("Total 170/171 PASS\n", encoding="utf-8")
    result = evidence.evaluate(block, root, key, SCHEMA)
    assert result.verdict == "RED"
    assert any("artifact hash drift" in r for r in result.reasons)
```

- [ ] **Step 2: Run test to verify it fails**

Run: `python -m pytest tools/audit/completion/tests/test_evidence_rules.py -v`
Expected: FAIL — `AttributeError: module 'evidence' has no attribute 'evaluate'`

- [ ] **Step 3: Write minimal implementation**

Append to `tools/audit/completion/evidence.py`:

```python
import hashlib
from dataclasses import dataclass, field


@dataclass
class Result:
    """A cell verdict plus every reason it is not GREEN."""

    verdict: str
    reasons: list[str] = field(default_factory=list)
    drift: list[str] = field(default_factory=list)


def sha256_file(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def evaluate(block: dict, root: Path, key: bytes, schema: dict) -> Result:
    """Apply every §4 / §8.1 rule. GREEN only if all pass."""
    reasons: list[str] = []
    drift: list[str] = []

    artifact_rel = str(block.get("artifact", ""))
    artifact = root / artifact_rel

    # Rule 1 — artifact must exist.
    if not artifact_rel or not artifact.is_file():
        reasons.append(f"artifact missing: {artifact_rel or '<unset>'}")
        return Result("RED", reasons, drift)

    # Rule 2 — artifact hash must match.
    actual = sha256_file(artifact)
    if actual != block.get("artifact_sha256"):
        reasons.append(f"artifact hash drift: {artifact_rel}")
        drift.append(artifact_rel)

    if reasons:
        return Result("RED", reasons, drift)
    return Result("GREEN", reasons, drift)
```

- [ ] **Step 4: Run test to verify it passes**

Run: `python -m pytest tools/audit/completion/tests/test_evidence_rules.py -v`
Expected: PASS, 3 passed

- [ ] **Step 5: Commit**

```bash
git add tools/audit/completion/evidence.py tools/audit/completion/tests/test_evidence_rules.py
git commit -m "feat(completion): artifact existence and hash rules"
```

---

### Task 6: Rule 3 — inputs must match and be tool-emitted

**Files:**
- Modify: `tools/audit/completion/evidence.py`
- Modify: `tools/audit/completion/tests/test_evidence_rules.py`

Closes review finding A: a hand-authored input list cannot be trusted, because an author who forgets a dependency mints permanent GREEN.

- [ ] **Step 1: Write the failing test**

Append to `tools/audit/completion/tests/test_evidence_rules.py`:

```python
def test_input_hash_drift_is_red(tmp_path: Path) -> None:
    root, key, block = make_repo(tmp_path)
    (root / "rooms.c").write_text("const int x = 2;\n", encoding="utf-8")
    result = evidence.evaluate(block, root, key, SCHEMA)
    assert result.verdict == "RED"
    assert any("input hash drift" in r for r in result.reasons)
    assert "rooms.c" in result.drift


def test_missing_manifest_emitter_is_red(tmp_path: Path) -> None:
    """Hand-authored inputs[] are not trusted (finding A)."""
    root, key, block = make_repo(tmp_path)
    del block["manifest_emitted_by"]
    block["run_signature"] = signing.sign(key, block)
    result = evidence.evaluate(block, root, key, SCHEMA)
    assert result.verdict == "RED"
    assert any("manifest_emitted_by" in r for r in result.reasons)


def test_empty_inputs_is_red(tmp_path: Path) -> None:
    root, key, block = make_repo(tmp_path)
    block["inputs"] = []
    block["run_signature"] = signing.sign(key, block)
    result = evidence.evaluate(block, root, key, SCHEMA)
    assert result.verdict == "RED"
    assert any("inputs" in r for r in result.reasons)
```

- [ ] **Step 2: Run test to verify it fails**

Run: `python -m pytest tools/audit/completion/tests/test_evidence_rules.py -v`
Expected: FAIL — 3 failures, all `assert 'GREEN' == 'RED'`

- [ ] **Step 3: Write minimal implementation**

In `evaluate()`, insert immediately before the final `if reasons:` block:

```python
    # Rule 3 — inputs must be tool-emitted and every hash must match.
    if not block.get("manifest_emitted_by"):
        reasons.append(
            "manifest_emitted_by absent — inputs[] must be tool-emitted, "
            "not hand-authored (spec §4 rule 3)"
        )
    inputs = block.get("inputs") or []
    if not inputs:
        reasons.append("inputs[] empty — nothing guards this cell against drift")
    for item in inputs:
        rel = str(item.get("path", ""))
        target = root / rel
        if not target.is_file():
            reasons.append(f"input missing: {rel}")
            drift.append(rel)
            continue
        if sha256_file(target) != item.get("sha256"):
            reasons.append(f"input hash drift: {rel}")
            drift.append(rel)
```

- [ ] **Step 4: Run test to verify it passes**

Run: `python -m pytest tools/audit/completion/tests/test_evidence_rules.py -v`
Expected: PASS, 6 passed

- [ ] **Step 5: Commit**

```bash
git add tools/audit/completion/evidence.py tools/audit/completion/tests/test_evidence_rules.py
git commit -m "feat(completion): tool-emitted input manifest rule"
```

---

### Task 7: Rules 4–5 — verbatim verdict line and verified signature

**Files:**
- Modify: `tools/audit/completion/evidence.py`
- Modify: `tools/audit/completion/tests/test_evidence_rules.py`

Closes review finding C — the disqualifying one. Presence of a command string is not evidence it ran.

- [ ] **Step 1: Write the failing test**

Append to `tools/audit/completion/tests/test_evidence_rules.py`:

```python
def test_verdict_line_absent_from_artifact_is_red(tmp_path: Path) -> None:
    root, key, block = make_repo(tmp_path)
    block["verdict_line"] = "Total 999/999 PASS"
    block["run_signature"] = signing.sign(key, block)
    result = evidence.evaluate(block, root, key, SCHEMA)
    assert result.verdict == "RED"
    assert any("verdict_line not found" in r for r in result.reasons)


def test_missing_signature_is_red(tmp_path: Path) -> None:
    """A hand-typed block cannot mint GREEN (finding C)."""
    root, key, block = make_repo(tmp_path)
    del block["run_signature"]
    result = evidence.evaluate(block, root, key, SCHEMA)
    assert result.verdict == "RED"
    assert any("run_signature" in r for r in result.reasons)


def test_edited_input_invalidates_signature(tmp_path: Path) -> None:
    root, key, block = make_repo(tmp_path)
    block["inputs"].append({"path": "rooms.c", "sha256": "00" * 32})
    result = evidence.evaluate(block, root, key, SCHEMA)
    assert result.verdict == "RED"
    assert any("run_signature" in r for r in result.reasons)


def test_command_absent_is_red(tmp_path: Path) -> None:
    root, key, block = make_repo(tmp_path)
    del block["command"]
    block["run_signature"] = signing.sign(key, block)
    result = evidence.evaluate(block, root, key, SCHEMA)
    assert result.verdict == "RED"
    assert any("command" in r for r in result.reasons)
```

- [ ] **Step 2: Run test to verify it fails**

Run: `python -m pytest tools/audit/completion/tests/test_evidence_rules.py -v`
Expected: FAIL — 4 failures

- [ ] **Step 3: Write minimal implementation**

Add `import signing` to the top of `evidence.py`, then insert before the final `if reasons:` block:

```python
    # Rule 4 — verdict_line must appear verbatim in the artifact.
    verdict_line = str(block.get("verdict_line", ""))
    if not verdict_line:
        reasons.append("verdict_line absent")
    elif verdict_line not in artifact.read_text(encoding="utf-8", errors="replace"):
        reasons.append(f"verdict_line not found in artifact: {verdict_line!r}")

    # Rule 5 — the command must have actually run, proven by signature.
    if not block.get("command"):
        reasons.append("command absent — evidence must name what produced it")
    if not block.get("run_signature"):
        reasons.append("run_signature absent — evidence was not tool-emitted")
    elif not signing.verify(key, block, str(block["run_signature"])):
        reasons.append(
            "run_signature does not verify — block was edited after emission "
            "or never produced by a real run (spec §4.1)"
        )
```

- [ ] **Step 4: Run test to verify it passes**

Run: `python -m pytest tools/audit/completion/tests/test_evidence_rules.py -v`
Expected: PASS, 10 passed

- [ ] **Step 5: Commit**

```bash
git add tools/audit/completion/evidence.py tools/audit/completion/tests/test_evidence_rules.py
git commit -m "feat(completion): verbatim verdict line and run-signature rules"
```

---

### Task 8: Rules 6 and 8 — allowlisted N/A, mandatory BEHAVIOR tolerance

**Files:**
- Modify: `tools/audit/completion/evidence.py`
- Test: `tools/audit/completion/tests/test_evidence_na.py`

Closes findings D (any prose exempts a cell) and the unenforced-tolerance finding.

- [ ] **Step 1: Write the failing test**

```python
from __future__ import annotations

import json
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[4]
sys.path.insert(0, str(ROOT / "tools" / "audit" / "completion"))

import evidence
import signing

SCHEMA = json.loads(
    (ROOT / "tools" / "audit" / "completion" / "schema.json").read_text(encoding="utf-8")
)


def test_allowlisted_na_is_accepted(tmp_path: Path) -> None:
    key = signing.load_or_create_key(tmp_path / ".k")
    block = {
        "system": "modes",
        "axis": "DATA",
        "verdict": "N/A",
        "reason": "Game-mode dispatch owns no assets.",
    }
    assert evidence.evaluate(block, tmp_path, key, SCHEMA).verdict == "N/A"


def test_na_without_allowlist_entry_is_red(tmp_path: Path) -> None:
    """Prose alone cannot exempt a cell (finding D)."""
    key = signing.load_or_create_key(tmp_path / ".k")
    block = {
        "system": "dungeons",
        "axis": "DATA",
        "verdict": "N/A",
        "reason": "we will get to it later",
    }
    result = evidence.evaluate(block, tmp_path, key, SCHEMA)
    assert result.verdict == "RED"
    assert any("na_allowlist" in r for r in result.reasons)


def test_na_without_reason_is_red(tmp_path: Path) -> None:
    key = signing.load_or_create_key(tmp_path / ".k")
    block = {"system": "modes", "axis": "DATA", "verdict": "N/A"}
    result = evidence.evaluate(block, tmp_path, key, SCHEMA)
    assert result.verdict == "RED"
    assert any("reason" in r for r in result.reasons)


def test_behavior_without_tolerance_is_red(tmp_path: Path) -> None:
    from test_evidence_rules import make_repo

    root, key, block = make_repo(tmp_path)
    block["axis"] = "BEHAVIOR"
    block["run_signature"] = signing.sign(key, block)
    result = evidence.evaluate(block, root, key, SCHEMA)
    assert result.verdict == "RED"
    assert any("tolerance" in r for r in result.reasons)


def test_behavior_with_tolerance_is_green(tmp_path: Path) -> None:
    from test_evidence_rules import make_repo

    root, key, block = make_repo(tmp_path)
    block["axis"] = "BEHAVIOR"
    block["tolerance"] = "X/Y differ on moving bosses: RNG frame phase, not divergence."
    block["run_signature"] = signing.sign(key, block)
    result = evidence.evaluate(block, root, key, SCHEMA)
    assert result.verdict == "GREEN", result.reasons
```

- [ ] **Step 2: Run test to verify it fails**

Run: `python -m pytest tools/audit/completion/tests/test_evidence_na.py -v`
Expected: FAIL — N/A blocks return RED for "artifact missing"

- [ ] **Step 3: Write minimal implementation**

At the very top of `evaluate()`, before the artifact rules:

```python
    # Rule 6 — N/A is allowlisted data, never free prose.
    if block.get("verdict") == "N/A":
        reason = str(block.get("reason", "")).strip()
        if not reason:
            reasons.append("N/A requires a non-empty reason")
        allowed = any(
            e["system"] == block.get("system") and e["axis"] == block.get("axis")
            for e in schema.get("na_allowlist", [])
        )
        if not allowed:
            reasons.append(
                f"N/A not permitted for ({block.get('system')}, {block.get('axis')}) — "
                "add a schema na_allowlist entry to exempt this cell"
            )
        return Result("RED" if reasons else "N/A", reasons, drift)
```

And immediately before the final `if reasons:` block:

```python
    # Rule 8 — BEHAVIOR must document its accepted deltas.
    if block.get("axis") == "BEHAVIOR" and not str(block.get("tolerance", "")).strip():
        reasons.append(
            "BEHAVIOR cell has no tolerance section — every accepted delta "
            "must be named and explained (spec §4 rule 8)"
        )
```

- [ ] **Step 4: Run test to verify it passes**

Run: `python -m pytest tools/audit/completion/tests/ -v`
Expected: PASS, 25 passed

- [ ] **Step 5: Commit**

```bash
git add tools/audit/completion/evidence.py tools/audit/completion/tests/test_evidence_na.py
git commit -m "feat(completion): allowlisted N/A and mandatory BEHAVIOR tolerance"
```

---

### Task 9: §8.1 — artifacts must never carry ROM-derived bytes

**Files:**
- Modify: `tools/audit/completion/evidence.py`
- Test: `tools/audit/completion/tests/test_evidence_legal.py`

Closes the second disqualifying finding: RULE V3 mandates full VRAM/CHR captures, and nothing stopped those landing in the repo labelled "proof".

- [ ] **Step 1: Write the failing test**

```python
from __future__ import annotations

import hashlib
import json
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[4]
sys.path.insert(0, str(ROOT / "tools" / "audit" / "completion"))

import evidence
import signing

SCHEMA = json.loads(
    (ROOT / "tools" / "audit" / "completion" / "schema.json").read_text(encoding="utf-8")
)


def build(tmp_path: Path, rel: str, size: int = 32) -> tuple[Path, bytes, dict]:
    target = tmp_path / rel
    target.parent.mkdir(parents=True, exist_ok=True)
    body = "Total 1/1 PASS\n" + ("x" * size)
    target.write_text(body, encoding="utf-8")
    src = tmp_path / "in.c"
    src.write_text("int x;\n", encoding="utf-8")
    key = signing.load_or_create_key(tmp_path / ".k")
    block = {
        "system": "dungeons",
        "axis": "DATA",
        "verdict": "GREEN",
        "artifact": rel,
        "artifact_sha256": hashlib.sha256(target.read_bytes()).hexdigest(),
        "command": "python run.py",
        "verdict_line": "Total 1/1 PASS",
        "manifest_emitted_by": "tools/parity/run.py",
        "inputs": [
            {"path": "in.c", "sha256": hashlib.sha256(src.read_bytes()).hexdigest()}
        ],
    }
    block["run_signature"] = signing.sign(key, block)
    return tmp_path, key, block


def test_artifact_under_docs_is_green(tmp_path: Path) -> None:
    root, key, block = build(tmp_path, "docs/status.md")
    assert evidence.evaluate(block, root, key, SCHEMA).verdict == "GREEN"


def test_artifact_outside_docs_is_red(tmp_path: Path) -> None:
    """A capture dump in build/ must never be cited as an artifact."""
    root, key, block = build(tmp_path, "build/vram_dump.md")
    result = evidence.evaluate(block, root, key, SCHEMA)
    assert result.verdict == "RED"
    assert any("outside docs/" in r for r in result.reasons)


def test_oversized_artifact_is_red(tmp_path: Path) -> None:
    root, key, block = build(tmp_path, "docs/huge.md", size=1_100_000)
    result = evidence.evaluate(block, root, key, SCHEMA)
    assert result.verdict == "RED"
    assert any("exceeds" in r for r in result.reasons)
```

- [ ] **Step 2: Run test to verify it fails**

Run: `python -m pytest tools/audit/completion/tests/test_evidence_legal.py -v`
Expected: FAIL — 2 failures, `assert 'GREEN' == 'RED'`

- [ ] **Step 3: Write minimal implementation**

In `evaluate()`, immediately after the Rule 1 existence check returns:

```python
    # §8.1 — artifacts are verdict documents, never captures.
    artifact_root = schema.get("artifact_root", "docs/")
    if not artifact_rel.replace("\\", "/").startswith(artifact_root):
        reasons.append(
            f"artifact outside {artifact_root}: {artifact_rel} — artifacts are "
            "verdict documents; raw captures stay gitignored and are referenced "
            "by sha256 only (spec §8.1)"
        )
    max_bytes = int(schema.get("max_artifact_bytes", 1048576))
    size = artifact.stat().st_size
    if size > max_bytes:
        reasons.append(
            f"artifact exceeds {max_bytes} bytes ({size}) — this is the shape of a "
            "capture payload, not a verdict document (spec §8.1)"
        )
```

- [ ] **Step 4: Run test to verify it passes**

Run: `python -m pytest tools/audit/completion/tests/ -v`
Expected: PASS, 28 passed

- [ ] **Step 5: Commit**

```bash
git add tools/audit/completion/evidence.py tools/audit/completion/tests/test_evidence_legal.py
git commit -m "feat(completion): reject artifacts that could carry ROM-derived bytes"
```

---

### Task 10: The producer contract — `EvidenceRecorder`

**Files:**
- Create: `tools/audit/completion/emit.py`
- Test: `tools/audit/completion/tests/test_emit.py`

Inputs are discovered, not declared: producers read through the recorder, so a new dependency guards the cell from that run forward.

- [ ] **Step 1: Write the failing test**

```python
from __future__ import annotations

from pathlib import Path
import sys

import yaml

ROOT = Path(__file__).resolve().parents[4]
sys.path.insert(0, str(ROOT / "tools" / "audit" / "completion"))

import emit
import evidence
import signing


def test_recorder_discovers_reads(tmp_path: Path) -> None:
    src = tmp_path / "a.c"
    src.write_text("int a;\n", encoding="utf-8")
    rec = emit.EvidenceRecorder(root=tmp_path, key_path=tmp_path / ".k")
    rec.read(src)
    assert [i["path"] for i in rec.inputs] == ["a.c"]


def test_recorder_dedupes(tmp_path: Path) -> None:
    src = tmp_path / "a.c"
    src.write_text("int a;\n", encoding="utf-8")
    rec = emit.EvidenceRecorder(root=tmp_path, key_path=tmp_path / ".k")
    rec.read(src)
    rec.read(src)
    assert len(rec.inputs) == 1


def test_emitted_block_verifies(tmp_path: Path) -> None:
    (tmp_path / "docs").mkdir()
    art = tmp_path / "docs" / "s.md"
    art.write_text("Total 1/1 PASS\n", encoding="utf-8")
    src = tmp_path / "a.c"
    src.write_text("int a;\n", encoding="utf-8")

    rec = emit.EvidenceRecorder(root=tmp_path, key_path=tmp_path / ".k")
    rec.read(src)
    text = rec.emit(
        system="dungeons",
        axis="DATA",
        artifact=art,
        verdict_line="Total 1/1 PASS",
        command="python run.py",
        emitted_by="tools/parity/run.py",
    )

    block = yaml.safe_load(text.split("```yaml evidence")[1].split("```")[0])[0]
    key = signing.load_or_create_key(tmp_path / ".k")
    schema = {"artifact_root": "docs/", "max_artifact_bytes": 1048576, "na_allowlist": []}
    assert evidence.evaluate(block, tmp_path, key, schema).verdict == "GREEN"


def test_emit_refuses_absent_verdict_line(tmp_path: Path) -> None:
    (tmp_path / "docs").mkdir()
    art = tmp_path / "docs" / "s.md"
    art.write_text("nothing matching\n", encoding="utf-8")
    rec = emit.EvidenceRecorder(root=tmp_path, key_path=tmp_path / ".k")
    rec.read(art)
    try:
        rec.emit(
            system="dungeons",
            axis="DATA",
            artifact=art,
            verdict_line="Total 1/1 PASS",
            command="python run.py",
            emitted_by="tools/parity/run.py",
        )
    except ValueError as exc:
        assert "verdict_line" in str(exc)
    else:
        raise AssertionError("expected ValueError")
```

- [ ] **Step 2: Run test to verify it fails**

Run: `python -m pytest tools/audit/completion/tests/test_emit.py -v`
Expected: FAIL — `ModuleNotFoundError: No module named 'emit'`

- [ ] **Step 3: Write minimal implementation**

```python
"""emit.py — producer side of the evidence contract (spec §4.1).

Producers gain --emit-evidence. They read every input through
EvidenceRecorder.read(), which discovers and hashes dependencies so a
newly added one guards the cell from that run forward — no hand-authored
input list, and therefore no forgotten dependency minting GREEN.
"""
from __future__ import annotations

import hashlib
from pathlib import Path

import signing


class EvidenceRecorder:
    def __init__(self, root: Path, key_path: Path | None = None) -> None:
        self.root = Path(root)
        self.key_path = key_path or (self.root / "tools" / "audit" / "completion" / ".evidence_key")
        self.inputs: list[dict] = []
        self._seen: set[str] = set()

    def read(self, path: Path) -> bytes:
        """Read a file AND record it as an input. Use instead of open()."""
        path = Path(path)
        data = path.read_bytes()
        rel = path.relative_to(self.root).as_posix()
        if rel not in self._seen:
            self._seen.add(rel)
            self.inputs.append({"path": rel, "sha256": hashlib.sha256(data).hexdigest()})
        return data

    def emit(
        self,
        system: str,
        axis: str,
        artifact: Path,
        verdict_line: str,
        command: str,
        emitted_by: str,
        tolerance: str = "",
        rom_identity: str = "",
    ) -> str:
        """Return a ready-to-paste evidence fence. Refuses invalid claims."""
        artifact = Path(artifact)
        body = artifact.read_text(encoding="utf-8", errors="replace")
        if verdict_line not in body:
            raise ValueError(
                f"verdict_line {verdict_line!r} does not appear in {artifact} — "
                "refusing to emit evidence for a claim the artifact does not make"
            )

        block = {
            "system": system,
            "axis": axis,
            "verdict": "GREEN",
            "artifact": artifact.relative_to(self.root).as_posix(),
            "artifact_sha256": hashlib.sha256(artifact.read_bytes()).hexdigest(),
            "command": command,
            "verdict_line": verdict_line,
            "manifest_emitted_by": emitted_by,
            "inputs": self.inputs,
        }
        if tolerance:
            block["tolerance"] = tolerance
        if rom_identity:
            block["rom_identity"] = rom_identity

        key = signing.load_or_create_key(self.key_path)
        block["run_signature"] = signing.sign(key, block)

        lines = ["```yaml evidence", f"- system: {block['system']}"]
        for field in (
            "axis", "verdict", "artifact", "artifact_sha256", "command",
            "verdict_line", "manifest_emitted_by", "run_signature",
        ):
            lines.append(f"  {field}: {block[field]!r}" if field == "verdict_line"
                         else f"  {field}: {block[field]}")
        if tolerance:
            lines.append(f"  tolerance: {tolerance!r}")
        if rom_identity:
            lines.append(f"  rom_identity: {rom_identity}")
        lines.append("  inputs:")
        for item in block["inputs"]:
            lines.append(f"    - path: {item['path']}")
            lines.append(f"      sha256: {item['sha256']}")
        lines.append("```")
        return "\n".join(lines) + "\n"
```

- [ ] **Step 4: Run test to verify it passes**

Run: `python -m pytest tools/audit/completion/tests/test_emit.py -v`
Expected: PASS, 4 passed

- [ ] **Step 5: Commit**

```bash
git add tools/audit/completion/emit.py tools/audit/completion/tests/test_emit.py
git commit -m "feat(completion): EvidenceRecorder producer contract"
```

---

### Task 11: `collect.py` — canonical tracker from the filesystem

**Files:**
- Create: `tools/audit/completion/collect.py`
- Test: `tools/audit/completion/tests/test_collect.py`

Every cell defaults RED. Missing audit file → 5 RED. There is no positional inference anywhere — the bug that killed the old tracker.

- [ ] **Step 1: Write the failing test**

```python
from __future__ import annotations

import json
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[4]
sys.path.insert(0, str(ROOT / "tools" / "audit" / "completion"))

import collect
import model


def test_empty_repo_is_all_red(tmp_path: Path) -> None:
    (tmp_path / "docs" / "audit" / "systems").mkdir(parents=True)
    tracker = collect.build(tmp_path)
    assert len(tracker["cells"]) == 80
    assert all(c["verdict"] == "RED" for c in tracker["cells"])


def test_missing_system_file_names_the_gap(tmp_path: Path) -> None:
    (tmp_path / "docs" / "audit" / "systems").mkdir(parents=True)
    tracker = collect.build(tmp_path)
    cell = next(c for c in tracker["cells"] if c["system"] == "dungeons")
    assert any("audit not yet run" in r for r in cell["reasons"])


def test_cells_are_in_stable_order(tmp_path: Path) -> None:
    (tmp_path / "docs" / "audit" / "systems").mkdir(parents=True)
    tracker = collect.build(tmp_path)
    got = [(c["system"], c["axis"]) for c in tracker["cells"]]
    assert got == model.all_cells()


def test_two_runs_are_byte_identical(tmp_path: Path) -> None:
    """Determinism: no wall-clock or environment fields in the tracker."""
    (tmp_path / "docs" / "audit" / "systems").mkdir(parents=True)
    first = collect.serialize(collect.build(tmp_path))
    second = collect.serialize(collect.build(tmp_path))
    assert first == second


def test_tracker_carries_no_timestamp(tmp_path: Path) -> None:
    (tmp_path / "docs" / "audit" / "systems").mkdir(parents=True)
    blob = collect.serialize(collect.build(tmp_path))
    assert "generated_at" not in blob
```

- [ ] **Step 2: Run test to verify it fails**

Run: `python -m pytest tools/audit/completion/tests/test_collect.py -v`
Expected: FAIL — `ModuleNotFoundError: No module named 'collect'`

- [ ] **Step 3: Write minimal implementation**

```python
"""collect.py — build the completion tracker from on-disk evidence.

Status is a pure function of the filesystem. Absence of evidence is RED.
There is NO positional default — the defect that made the prime-directive
tracker report 18/18 phases complete against a build with no save system.
"""
from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

import evidence
import model
import signing

SYSTEMS_DIR = Path("docs") / "audit" / "systems"
TRACKER = Path("docs") / "audit" / "completion_tracker.json"


def load_schema(root: Path) -> dict:
    path = root / "tools" / "audit" / "completion" / "schema.json"
    return json.loads(path.read_text(encoding="utf-8"))


def build(root: Path) -> dict:
    root = Path(root)
    schema = load_schema(Path(__file__).resolve().parents[3])
    key = signing.load_or_create_key(
        root / "tools" / "audit" / "completion" / ".evidence_key"
    )

    blocks: dict[tuple[str, str], dict] = {}
    seen: set[tuple[str, str]] = set()
    for system in model.SYSTEMS:
        path = root / SYSTEMS_DIR / f"{system}.md"
        if not path.is_file():
            continue
        for block in evidence.parse_blocks(path):
            cell = (str(block.get("system")), str(block.get("axis")))
            if cell in seen:
                raise evidence.MalformedEvidence(
                    f"{path}: duplicate claim for {cell} — a (system, axis) pair "
                    "may be claimed exactly once"
                )
            seen.add(cell)
            blocks[cell] = block

    cells = []
    for system, axis in model.all_cells():
        block = blocks.get((system, axis))
        if block is None:
            audit_exists = (root / SYSTEMS_DIR / f"{system}.md").is_file()
            reason = (
                "no evidence block for this cell"
                if audit_exists
                else "audit not yet run for this system"
            )
            cells.append(
                {
                    "system": system, "axis": axis, "verdict": "RED",
                    "artifact": None, "reasons": [reason], "drift": [],
                }
            )
            continue
        result = evidence.evaluate(block, root, key, schema)
        cells.append(
            {
                "system": system, "axis": axis, "verdict": result.verdict,
                "artifact": block.get("artifact"),
                "reasons": result.reasons, "drift": result.drift,
            }
        )
    return {"schema_version": 1, "cells": cells}


def serialize(tracker: dict) -> str:
    """Canonical JSON — sorted, compact, no environment-derived fields."""
    return json.dumps(
        tracker, sort_keys=True, separators=(",", ":"), ensure_ascii=False
    )


def main() -> int:
    parser = argparse.ArgumentParser(description="Build the completion tracker.")
    parser.add_argument("--root", default=".", help="repository root")
    args = parser.parse_args()
    root = Path(args.root).resolve()
    try:
        tracker = build(root)
    except evidence.MalformedEvidence as exc:
        print(f"MALFORMED: {exc}", file=sys.stderr)
        return 1
    (root / TRACKER).write_text(serialize(tracker), encoding="utf-8")
    red = sum(1 for c in tracker["cells"] if c["verdict"] == "RED")
    print(f"completion tracker: {80 - red}/80 satisfied, {red} RED")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
```

- [ ] **Step 4: Run test to verify it passes**

Run: `python -m pytest tools/audit/completion/tests/test_collect.py -v`
Expected: PASS, 5 passed

- [ ] **Step 5: Commit**

```bash
git add tools/audit/completion/collect.py tools/audit/completion/tests/test_collect.py
git commit -m "feat(completion): canonical tracker collection, RED by default"
```

---

### Task 12: Contradiction scoping and shared artifacts

**Files:**
- Modify: `tools/audit/completion/tests/test_collect.py`

Closes finding B. The old rule — same artifact, two verdict lines → fatal — would have rejected `run_regression_matrix.py` and `package_check.py`, the shared producers the design depends on.

- [ ] **Step 1: Write the failing test**

Append to `tools/audit/completion/tests/test_collect.py`:

```python
import hashlib

import signing


def _write_system(root: Path, system: str, blocks: str) -> None:
    d = root / "docs" / "audit" / "systems"
    d.mkdir(parents=True, exist_ok=True)
    (d / f"{system}.md").write_text(blocks, encoding="utf-8")


def _shared_artifact(root: Path) -> Path:
    (root / "docs").mkdir(parents=True, exist_ok=True)
    art = root / "docs" / "matrix.md"
    art.write_text("dungeons: GREEN 12/12\ncaves: GREEN 20/20\n", encoding="utf-8")
    return art


def _block(root: Path, key: bytes, system: str, verdict_line: str) -> str:
    art = root / "docs" / "matrix.md"
    src = root / "shared.py"
    if not src.exists():
        src.write_text("x = 1\n", encoding="utf-8")
    b = {
        "system": system, "axis": "CODE", "verdict": "GREEN",
        "artifact": "docs/matrix.md",
        "artifact_sha256": hashlib.sha256(art.read_bytes()).hexdigest(),
        "command": "python tools/run_regression_matrix.py",
        "verdict_line": verdict_line,
        "manifest_emitted_by": "tools/run_regression_matrix.py",
        "inputs": [
            {"path": "shared.py", "sha256": hashlib.sha256(src.read_bytes()).hexdigest()}
        ],
    }
    b["run_signature"] = signing.sign(key, b)
    lines = ["```yaml evidence", f"- system: {b['system']}"]
    for k in ("axis", "verdict", "artifact", "artifact_sha256", "command",
              "manifest_emitted_by", "run_signature"):
        lines.append(f"  {k}: {b[k]}")
    lines.append(f"  verdict_line: {b['verdict_line']!r}")
    lines.append("  inputs:")
    for i in b["inputs"]:
        lines.append(f"    - path: {i['path']}")
        lines.append(f"      sha256: {i['sha256']}")
    lines.append("```")
    return "\n".join(lines) + "\n"


def test_shared_artifact_across_systems_is_not_a_contradiction(tmp_path: Path) -> None:
    (tmp_path / "docs" / "audit" / "systems").mkdir(parents=True)
    _shared_artifact(tmp_path)
    key = signing.load_or_create_key(
        tmp_path / "tools" / "audit" / "completion" / ".evidence_key"
    )
    _write_system(tmp_path, "dungeons", _block(tmp_path, key, "dungeons", "dungeons: GREEN 12/12"))
    _write_system(tmp_path, "caves", _block(tmp_path, key, "caves", "caves: GREEN 20/20"))

    tracker = collect.build(tmp_path)
    verdicts = {
        (c["system"], c["axis"]): c["verdict"]
        for c in tracker["cells"]
        if c["axis"] == "CODE" and c["system"] in ("dungeons", "caves")
    }
    assert verdicts[("dungeons", "CODE")] == "GREEN"
    assert verdicts[("caves", "CODE")] == "GREEN"


def test_duplicate_system_axis_claim_raises(tmp_path: Path) -> None:
    (tmp_path / "docs" / "audit" / "systems").mkdir(parents=True)
    _shared_artifact(tmp_path)
    key = signing.load_or_create_key(
        tmp_path / "tools" / "audit" / "completion" / ".evidence_key"
    )
    doubled = _block(tmp_path, key, "dungeons", "dungeons: GREEN 12/12") * 2
    _write_system(tmp_path, "dungeons", doubled)
    try:
        collect.build(tmp_path)
    except evidence.MalformedEvidence as exc:
        assert "duplicate claim" in str(exc)
    else:
        raise AssertionError("expected MalformedEvidence")


import evidence  # noqa: E402
```

- [ ] **Step 2: Run test to verify it fails**

Run: `python -m pytest tools/audit/completion/tests/test_collect.py -v`
Expected: FAIL on `test_shared_artifact_across_systems_is_not_a_contradiction` — the artifact lives at `docs/matrix.md` but `build()` resolves the schema from the real repo root, so the key path differs.

- [ ] **Step 3: Fix the key path in `collect.build()`**

Replace the `schema = load_schema(...)` line in `build()` with:

```python
    schema = load_schema(Path(__file__).resolve().parents[3])
    _ = schema  # schema always comes from the installed tool, not the target root
```

and confirm the key is read from the *target* root so tests are hermetic — it already is:

```python
    key = signing.load_or_create_key(
        root / "tools" / "audit" / "completion" / ".evidence_key"
    )
```

- [ ] **Step 4: Run test to verify it passes**

Run: `python -m pytest tools/audit/completion/tests/test_collect.py -v`
Expected: PASS, 7 passed

- [ ] **Step 5: Commit**

```bash
git add tools/audit/completion/tests/test_collect.py tools/audit/completion/collect.py
git commit -m "test(completion): shared artifacts are not contradictions"
```

---

### Task 13: `report.py` — render COMPLETION.md

**Files:**
- Create: `tools/audit/completion/report.py`
- Test: `tools/audit/completion/tests/test_report.py`

- [ ] **Step 1: Write the failing test**

```python
from __future__ import annotations

from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[4]
sys.path.insert(0, str(ROOT / "tools" / "audit" / "completion"))

import collect
import report


def tracker(tmp_path: Path) -> dict:
    (tmp_path / "docs" / "audit" / "systems").mkdir(parents=True)
    return collect.build(tmp_path)


def test_reports_zero_percent_when_all_red(tmp_path: Path) -> None:
    text = report.render(tracker(tmp_path))
    assert "0 / 80" in text


def test_lists_every_system(tmp_path: Path) -> None:
    text = report.render(tracker(tmp_path))
    for system in ("frontend", "dungeons", "builder"):
        assert system in text


def test_na_counted_separately(tmp_path: Path) -> None:
    t = tracker(tmp_path)
    t["cells"][0]["verdict"] = "N/A"
    text = report.render(t)
    assert "N/A" in text
    assert "1 / 80" in text


def test_drift_section_present_when_drifted(tmp_path: Path) -> None:
    t = tracker(tmp_path)
    t["cells"][0]["drift"] = ["data/rooms/dungeons.c"]
    assert "data/rooms/dungeons.c" in report.render(t)
```

- [ ] **Step 2: Run test to verify it fails**

Run: `python -m pytest tools/audit/completion/tests/test_report.py -v`
Expected: FAIL — `ModuleNotFoundError: No module named 'report'`

- [ ] **Step 3: Write minimal implementation**

```python
"""report.py — render the tracker as docs/audit/COMPLETION.md. Read-only."""
from __future__ import annotations

import argparse
import json
from pathlib import Path

import model

MARK = {"GREEN": "GREEN", "RED": "RED", "N/A": "N/A"}


def render(tracker: dict) -> str:
    cells = {(c["system"], c["axis"]): c for c in tracker["cells"]}
    satisfied = sum(1 for c in tracker["cells"] if c["verdict"] in ("GREEN", "N/A"))
    na = sum(1 for c in tracker["cells"] if c["verdict"] == "N/A")

    out = ["# Completion", "", "> Generated by `tools/audit/completion/report.py`.",
           "> Do not edit by hand — status is derived from signed evidence.", "",
           f"**{satisfied} / 80 cells satisfied** ({na} of them `N/A`).", ""]

    out.append("| System | " + " | ".join(model.AXES) + " |")
    out.append("|---" * (len(model.AXES) + 1) + "|")
    for system in model.SYSTEMS:
        row = [system]
        for axis in model.AXES:
            row.append(MARK.get(cells[(system, axis)]["verdict"], "?"))
        out.append("| " + " | ".join(row) + " |")

    reds = [c for c in tracker["cells"] if c["verdict"] == "RED"]
    if reds:
        out += ["", "## RED", ""]
        for c in reds:
            for reason in c["reasons"]:
                out.append(f"- `{c['system']}` / {c['axis']} — {reason}")

    drifted = [c for c in tracker["cells"] if c["drift"]]
    if drifted:
        out += ["", "## Drift", "",
                "These cells went RED because a hashed input changed.", ""]
        for c in drifted:
            for path in c["drift"]:
                out.append(f"- `{c['system']}` / {c['axis']} — {path}")

    return "\n".join(out) + "\n"


def main() -> int:
    parser = argparse.ArgumentParser(description="Render COMPLETION.md.")
    parser.add_argument("--root", default=".")
    args = parser.parse_args()
    root = Path(args.root).resolve()
    tracker = json.loads(
        (root / "docs" / "audit" / "completion_tracker.json").read_text(encoding="utf-8")
    )
    (root / "docs" / "audit" / "COMPLETION.md").write_text(
        render(tracker), encoding="utf-8"
    )
    print("wrote docs/audit/COMPLETION.md")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
```

- [ ] **Step 4: Run test to verify it passes**

Run: `python -m pytest tools/audit/completion/tests/test_report.py -v`
Expected: PASS, 4 passed

- [ ] **Step 5: Commit**

```bash
git add tools/audit/completion/report.py tools/audit/completion/tests/test_report.py
git commit -m "feat(completion): render COMPLETION.md from tracker"
```

---

### Task 14: Bootstrap the 16 audit files as honest RED

**Files:**
- Create: `docs/audit/systems/<slug>.md` × 16
- Test: `tools/audit/completion/tests/test_bootstrap.py`

The tracker must tell the truth on day one: nothing is audited yet.

- [ ] **Step 1: Write the failing test**

```python
from __future__ import annotations

from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[4]
sys.path.insert(0, str(ROOT / "tools" / "audit" / "completion"))

import model


def test_every_system_has_an_audit_file() -> None:
    for system in model.SYSTEMS:
        path = ROOT / "docs" / "audit" / "systems" / f"{system}.md"
        assert path.is_file(), f"missing audit file for {system}"


def test_audit_files_have_required_sections() -> None:
    for system in model.SYSTEMS:
        text = (ROOT / "docs" / "audit" / "systems" / f"{system}.md").read_text(
            encoding="utf-8"
        )
        for heading in ("## Scope", "## Axis verdicts", "## Gap list", "## Tolerance"):
            assert heading in text, f"{system}.md missing {heading}"
```

- [ ] **Step 2: Run test to verify it fails**

Run: `python -m pytest tools/audit/completion/tests/test_bootstrap.py -v`
Expected: FAIL — `missing audit file for frontend`

- [ ] **Step 3: Generate the 16 files**

Run this once:

```bash
python - <<'PY'
from pathlib import Path
import sys
sys.path.insert(0, "tools/audit/completion")
import model

TEMPLATE = """# System audit — {system}

> Status is derived from signed evidence blocks below, never from this
> file's existence. No blocks = all five cells RED. See
> `docs/superpowers/specs/2026-08-03-completion-tracker-design.md`.

## Scope

NOT YET AUDITED. Define what this system owns, and what it explicitly
does not, during the audit pass.

## Axis verdicts

No evidence blocks yet. All five cells are RED.

## Gap list

- Audit pass not yet run for `{system}`.

## Tolerance

Not applicable until the BEHAVIOR axis has evidence.
"""

d = Path("docs/audit/systems")
d.mkdir(parents=True, exist_ok=True)
for s in model.SYSTEMS:
    (d / f"{s}.md").write_text(TEMPLATE.format(system=s), encoding="utf-8")
print(f"wrote {len(model.SYSTEMS)} audit files")
PY
```

Expected output: `wrote 16 audit files`

- [ ] **Step 4: Run test to verify it passes**

Run: `python -m pytest tools/audit/completion/tests/test_bootstrap.py -v`
Expected: PASS, 2 passed

- [ ] **Step 5: Generate the first real tracker and report**

```bash
python tools/audit/completion/collect.py --root .
python tools/audit/completion/report.py --root .
```

Expected: `completion tracker: 0/80 satisfied, 80 RED` then `wrote docs/audit/COMPLETION.md`

- [ ] **Step 6: Commit**

```bash
git add docs/audit/systems docs/audit/completion_tracker.json docs/audit/COMPLETION.md tools/audit/completion/tests/test_bootstrap.py
git commit -m "feat(completion): bootstrap 16 audit files, tracker reports 0/80"
```

---

### Task 15: `release_gate.py` integration

**Files:**
- Modify: `tools/builder/release_gate.py`
- Test: `tools/audit/completion/tests/test_release_gate.py`

Closes the stale-tracker and no-override findings. The gate re-collects; a tracker on disk is a report, not an authority.

- [ ] **Step 1: Write the failing test**

```python
from __future__ import annotations

import json
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[4]
sys.path.insert(0, str(ROOT / "tools" / "audit" / "completion"))
sys.path.insert(0, str(ROOT / "tools" / "builder"))

import completion_gate


def seed(tmp_path: Path) -> Path:
    (tmp_path / "docs" / "audit" / "systems").mkdir(parents=True)
    return tmp_path


def test_all_red_refuses(tmp_path: Path) -> None:
    ok, msg = completion_gate.check(seed(tmp_path), overrides={})
    assert ok is False
    assert "80" in msg


def test_stale_green_tracker_on_disk_is_ignored(tmp_path: Path) -> None:
    """The gate re-collects; it never trusts the file."""
    root = seed(tmp_path)
    fake = {
        "schema_version": 1,
        "cells": [
            {"system": s, "axis": a, "verdict": "GREEN", "artifact": None,
             "reasons": [], "drift": []}
            for s in __import__("model").SYSTEMS
            for a in __import__("model").AXES
        ],
    }
    (root / "docs" / "audit" / "completion_tracker.json").write_text(
        json.dumps(fake), encoding="utf-8"
    )
    ok, _ = completion_gate.check(root, overrides={})
    assert ok is False


def test_override_allows_but_records(tmp_path: Path) -> None:
    root = seed(tmp_path)
    import model

    overrides = {
        f"{s}/{a}": {"reason": "bootstrap", "approved_by": "jake"}
        for s in model.SYSTEMS
        for a in model.AXES
    }
    ok, msg = completion_gate.check(root, overrides=overrides)
    assert ok is True
    assert "override" in msg.lower()
```

- [ ] **Step 2: Run test to verify it fails**

Run: `python -m pytest tools/audit/completion/tests/test_release_gate.py -v`
Expected: FAIL — `ModuleNotFoundError: No module named 'completion_gate'`

- [ ] **Step 3: Write minimal implementation**

Create `tools/builder/completion_gate.py`:

```python
"""completion_gate.py — release gate step for the completion tracker.

Always re-collects. A completion_tracker.json on disk is a report, not an
authority: sources can change after the last collection.
"""
from __future__ import annotations

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "audit" / "completion"))

import collect  # noqa: E402


def check(root: Path, overrides: dict[str, dict]) -> tuple[bool, str]:
    """Return (may_package, message). Overrides are recorded, never GREEN."""
    tracker = collect.build(Path(root))
    blocking = [
        c for c in tracker["cells"]
        if c["verdict"] == "RED" and f"{c['system']}/{c['axis']}" not in overrides
    ]
    used = [
        key for key in overrides
        if any(
            f"{c['system']}/{c['axis']}" == key and c["verdict"] == "RED"
            for c in tracker["cells"]
        )
    ]
    if blocking:
        lines = [f"completion gate: {len(blocking)} of 80 cells RED"]
        lines += [f"  {c['system']}/{c['axis']}: {'; '.join(c['reasons'])}"
                  for c in blocking[:10]]
        if len(blocking) > 10:
            lines.append(f"  ... and {len(blocking) - 10} more")
        return False, "\n".join(lines)
    if used:
        return True, f"completion gate: PASS with {len(used)} override(s): {', '.join(sorted(used))}"
    return True, "completion gate: 80/80 satisfied"
```

- [ ] **Step 4: Run test to verify it passes**

Run: `python -m pytest tools/audit/completion/tests/test_release_gate.py -v`
Expected: PASS, 3 passed

- [ ] **Step 5: Wire into `release_gate.py`**

In `tools/builder/release_gate.py`, add to the gate list alongside `package_check` and `regression_matrix`:

```python
    from completion_gate import check as completion_check

    ok, message = completion_check(ROOT, overrides=parse_overrides(args))
    print(message)
    if not ok:
        return 1
```

and add the CLI flag:

```python
    parser.add_argument(
        "--override", action="append", default=[],
        metavar="SYSTEM/AXIS:REASON:APPROVED_BY",
        help="Package despite a RED cell. Recorded in the release manifest, "
             "counted as an override, never as GREEN. Applies to one run only.",
    )
```

- [ ] **Step 6: Verify the gate runs**

Run: `python tools/builder/release_gate.py --dry-run`
Expected: output includes `would run: completion_gate`

- [ ] **Step 7: Commit**

```bash
git add tools/builder/completion_gate.py tools/builder/release_gate.py tools/audit/completion/tests/test_release_gate.py
git commit -m "feat(completion): release gate re-collects and refuses on RED"
```

---

### Task 16: The load-bearing invariant

**Files:**
- Create: `tools/audit/completion/tests/test_invariant.py`

The regression test for the bug that motivated the whole design. If this can be made to pass by any hand-authored file, the design has failed.

- [ ] **Step 1: Write the failing test**

```python
"""The one test that matters: no hand-authored file can mint GREEN."""
from __future__ import annotations

import hashlib
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[4]
sys.path.insert(0, str(ROOT / "tools" / "audit" / "completion"))

import collect
import model


FORGED = """```yaml evidence
- system: dungeons
  axis: DATA
  verdict: GREEN
  artifact: docs/status.md
  artifact_sha256: {sha}
  command: python tools/parity/cave_golden/run_full_diff.py --uw
  verdict_line: 'Total 171/171 PASS'
  manifest_emitted_by: tools/parity/cave_golden/run_full_diff.py
  run_signature: {sig}
  inputs:
    - path: rooms.c
      sha256: {src}
```
"""


def test_forged_evidence_cannot_produce_green(tmp_path: Path) -> None:
    (tmp_path / "docs" / "audit" / "systems").mkdir(parents=True)
    art = tmp_path / "docs" / "status.md"
    art.write_text("Total 171/171 PASS\n", encoding="utf-8")
    src = tmp_path / "rooms.c"
    src.write_text("int x;\n", encoding="utf-8")

    # Every field is internally consistent. Hashes are real. The artifact
    # genuinely contains the verdict line. Only the signature is invented.
    forged = FORGED.format(
        sha=hashlib.sha256(art.read_bytes()).hexdigest(),
        src=hashlib.sha256(src.read_bytes()).hexdigest(),
        sig="f" * 64,
    )
    (tmp_path / "docs" / "audit" / "systems" / "dungeons.md").write_text(
        forged, encoding="utf-8"
    )

    tracker = collect.build(tmp_path)
    cell = next(
        c for c in tracker["cells"]
        if c["system"] == "dungeons" and c["axis"] == "DATA"
    )
    assert cell["verdict"] == "RED"
    assert any("run_signature" in r for r in cell["reasons"])


def test_no_positional_inference(tmp_path: Path) -> None:
    """A GREEN cell must never make its neighbours GREEN."""
    (tmp_path / "docs" / "audit" / "systems").mkdir(parents=True)
    tracker = collect.build(tmp_path)
    assert len({c["verdict"] for c in tracker["cells"]}) == 1
    assert all(c["verdict"] == "RED" for c in tracker["cells"])


def test_every_cell_is_accounted_for(tmp_path: Path) -> None:
    (tmp_path / "docs" / "audit" / "systems").mkdir(parents=True)
    tracker = collect.build(tmp_path)
    assert {(c["system"], c["axis"]) for c in tracker["cells"]} == set(model.all_cells())
```

- [ ] **Step 2: Run test to verify it fails or passes**

Run: `python -m pytest tools/audit/completion/tests/test_invariant.py -v`
Expected: PASS, 3 passed — the rules from Tasks 5–9 already enforce this. If any test fails, a rule is missing; fix the rule, not the test.

- [ ] **Step 3: Run the whole suite**

Run: `python -m pytest tools/audit/completion/tests/ -v`
Expected: PASS, 40 passed

- [ ] **Step 4: Commit**

```bash
git add tools/audit/completion/tests/test_invariant.py
git commit -m "test(completion): forged evidence can never mint GREEN"
```

---

### Task 17: Wire the first real producer

**Files:**
- Modify: `tools/builder/package_check.py`

Proves the producer contract works end-to-end against a real tool. `package_check.py` is the LEGAL-axis producer for every system, so this unblocks 16 cells at once.

- [ ] **Step 1: Add the flag**

In `tools/builder/package_check.py`, add to `main()`:

```python
    parser.add_argument(
        "--emit-evidence", metavar="SYSTEM",
        help="Print a signed evidence block for SYSTEM's LEGAL axis.",
    )
```

- [ ] **Step 2: Emit after the scan**

At the end of `main()`, before `return`:

```python
    if args.emit_evidence:
        import sys
        from pathlib import Path

        sys.path.insert(
            0, str(Path(__file__).resolve().parents[1] / "audit" / "completion")
        )
        from emit import EvidenceRecorder

        root = Path(__file__).resolve().parents[2]
        report = root / "docs" / "audit" / "package_check_status.md"
        report.parent.mkdir(parents=True, exist_ok=True)
        verdict_line = f"package_check: {banned_count} banned file(s) in release scope"
        report.write_text(f"# package_check\n\n{verdict_line}\n", encoding="utf-8")

        rec = EvidenceRecorder(root=root)
        rec.read(Path(__file__))
        print(rec.emit(
            system=args.emit_evidence,
            axis="LEGAL",
            artifact=report,
            verdict_line=verdict_line,
            command=f"python tools/builder/package_check.py --emit-evidence {args.emit_evidence}",
            emitted_by="tools/builder/package_check.py",
        ))
```

- [ ] **Step 3: Run it**

Run: `python tools/builder/package_check.py --emit-evidence builder`
Expected: a ```yaml evidence fence printed to stdout, containing `run_signature:` and an `inputs:` list

- [ ] **Step 4: Paste the block into the audit file**

Replace the "No evidence blocks yet" line under `## Axis verdicts` in `docs/audit/systems/builder.md` with the emitted fence.

- [ ] **Step 5: Verify the cell turns GREEN**

```bash
python tools/audit/completion/collect.py --root .
python tools/audit/completion/report.py --root .
```

Expected: `completion tracker: 1/80 satisfied, 79 RED`

- [ ] **Step 6: Commit**

```bash
git add tools/builder/package_check.py docs/audit/systems/builder.md docs/audit/completion_tracker.json docs/audit/COMPLETION.md docs/audit/package_check_status.md
git commit -m "feat(completion): package_check emits signed LEGAL evidence"
```

---

## Self-Review

**Spec coverage:**

| Spec section | Task |
|---|---|
| §3 sixteen systems × five axes | 1 |
| §4 rules 1–2 artifact | 5 |
| §4 rule 3 tool-emitted inputs | 6 |
| §4 rules 4–5 verdict line, signature | 7 |
| §4 rule 6 N/A allowlist | 3, 8 |
| §4 rule 7 no positional inference | 11, 16 |
| §4 rule 8 BEHAVIOR tolerance | 8 |
| §4.1 producer contract | 2, 10, 17 |
| §5.1 schema.json | 3 |
| §5.2 collect.py + canonicalization | 11 |
| §5.3 report.py | 13 |
| §5.4 per-system audit files | 14 |
| §7 release gate re-collect + override | 15 |
| §8 error handling, contradiction scoping | 11, 12 |
| §8.1 legal artifact constraints | 9 |
| §9 test cases | 5–16 |

No gaps.

**Naming consistency:** `evaluate()`, `Result.verdict/reasons/drift`, `parse_blocks()`, `build()`, `serialize()`, `render()`, `check()`, `EvidenceRecorder.read()/emit()`, `sign()/verify()/load_or_create_key()` — each defined once and used identically thereafter.

**Not covered here (correctly):** the 16 audit passes themselves. This plan ships the map and the gate; spec §10 scopes the audits out. `builder` is first per spec §6 ordering, and Task 17 already lands its LEGAL cell.
