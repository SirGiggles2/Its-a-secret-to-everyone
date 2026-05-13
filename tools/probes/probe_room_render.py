#!/usr/bin/env python3
"""Retired S3.A2 overworld room render probe.

This historical probe depended on a removed debug-only build path. It tried
to compile deleted OW entry code and link against artifacts that the current
Debug build no longer emits. Keeping that behavior active makes bug hunts
look like runtime failures when the real issue is obsolete tooling.
"""

from __future__ import annotations

import sys


MESSAGE = """\
[probe_room_render] retired

The old S3.A2 room-render probe cannot run against the current Debug-only
build layout. Use the current room tooling instead:

  python tools/room_checklist.py recapture-gen
  python tools/compare_room77_parity.py --room-id 0x77
  python tools/run_regression_matrix.py
"""


def main() -> int:
    print(MESSAGE, file=sys.stderr)
    return 2


if __name__ == "__main__":
    raise SystemExit(main())
