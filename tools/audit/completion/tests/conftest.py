"""conftest.py — make the completion modules and sibling test helpers importable.

The tests deliberately import each module directly (`import evidence`)
rather than through a package, matching the tools/debug/test_*_contract.py
precedent in this repo.
"""
from __future__ import annotations

from pathlib import Path
import sys

HERE = Path(__file__).resolve().parent
COMPLETION = HERE.parent

for entry in (str(COMPLETION), str(HERE)):
    if entry not in sys.path:
        sys.path.insert(0, entry)
