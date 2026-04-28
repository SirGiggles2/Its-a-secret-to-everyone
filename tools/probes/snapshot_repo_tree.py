# tools/probes/snapshot_repo_tree.py
"""Generate docs/audit/repo_tree.txt — sorted file list under src/."""

from __future__ import annotations

import sys

from _common import REPO_ROOT, SRC, write_audit, relative_to_repo


def main() -> int:
    lines: list[str] = ["# Repository source tree snapshot", ""]
    lines.append(f"Root: `{relative_to_repo(REPO_ROOT)}/`")
    lines.append("")
    lines.append("```")

    paths = sorted(p for p in SRC.rglob("*") if p.is_file())
    for path in paths:
        lines.append(relative_to_repo(path))

    lines.append("```")
    lines.append("")
    lines.append(f"Total files: {len(paths)}")

    out = write_audit("repo_tree.txt", "\n".join(lines) + "\n")
    print(f"wrote {out}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
