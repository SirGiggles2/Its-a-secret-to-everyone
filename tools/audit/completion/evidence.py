"""evidence.py — parse and validate evidence blocks (spec §4, §4.1, §8.1).

A cell is GREEN only when every rule here passes. There is no code path
that returns GREEN from anything other than a fully verified block.
"""
from __future__ import annotations

import hashlib
import re
from dataclasses import dataclass, field
from pathlib import Path

import yaml

import signing

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

    # Rule 6 — N/A is allowlisted data, never free prose.
    if block.get("verdict") == "N/A":
        if not str(block.get("reason", "")).strip():
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

    artifact_rel = str(block.get("artifact", ""))
    artifact = root / artifact_rel

    # Rule 1 — artifact must exist.
    if not artifact_rel or not artifact.is_file():
        reasons.append(f"artifact missing: {artifact_rel or '<unset>'}")
        return Result("RED", reasons, drift)

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

    # Rule 2 — artifact hash must match.
    if sha256_file(artifact) != block.get("artifact_sha256"):
        reasons.append(f"artifact hash drift: {artifact_rel}")
        drift.append(artifact_rel)

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

    # Rule 8 — BEHAVIOR must document its accepted deltas.
    if block.get("axis") == "BEHAVIOR" and not str(block.get("tolerance", "")).strip():
        reasons.append(
            "BEHAVIOR cell has no tolerance section — every accepted delta "
            "must be named and explained (spec §4 rule 8)"
        )

    if reasons:
        return Result("RED", reasons, drift)
    return Result("GREEN", reasons, drift)
