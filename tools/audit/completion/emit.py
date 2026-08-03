"""emit.py — producer side of the evidence contract (spec §4.1).

Producers gain --emit-evidence. They read every input through
EvidenceRecorder.read(), which discovers and hashes dependencies so a
newly added one guards the cell from that run forward — no hand-authored
input list, and therefore no forgotten dependency minting GREEN.
"""
from __future__ import annotations

import hashlib
from pathlib import Path

import yaml

import signing

# Field order in the emitted fence. Readability only — verification is
# order-independent (signing.canonical sorts keys).
FIELD_ORDER = (
    "system",
    "axis",
    "verdict",
    "artifact",
    "artifact_sha256",
    "command",
    "verdict_line",
    "manifest_emitted_by",
    "run_signature",
    "tolerance",
    "rom_identity",
    "inputs",
)


class EvidenceRecorder:
    def __init__(self, root: Path, key_path: Path | None = None) -> None:
        self.root = Path(root)
        self.key_path = key_path or (
            self.root / "tools" / "audit" / "completion" / ".evidence_key"
        )
        self.inputs: list[dict] = []
        self._seen: set[str] = set()

    def read(self, path: Path) -> bytes:
        """Read a file AND record it as an input. Use instead of open()."""
        path = Path(path)
        data = path.read_bytes()
        rel = path.relative_to(self.root).as_posix()
        if rel not in self._seen:
            self._seen.add(rel)
            self.inputs.append(
                {"path": rel, "sha256": hashlib.sha256(data).hexdigest()}
            )
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

        ordered = {k: block[k] for k in FIELD_ORDER if k in block}
        # safe_dump handles quoting/escaping, so a verdict line containing a
        # colon, quote, or leading '%' round-trips instead of corrupting the
        # fence. Hand-formatting this was a latent parse bug.
        dumped = yaml.safe_dump(
            [ordered], sort_keys=False, default_flow_style=False, allow_unicode=True
        )
        return f"```yaml evidence\n{dumped}```\n"
