"""T-180: orchestration failures cannot be accepted by timing-only evidence."""
from __future__ import annotations

import contextlib
import io
from pathlib import Path
from types import SimpleNamespace
import unittest
from unittest.mock import patch

import lag_gate


def result(code=0):
    return SimpleNamespace(returncode=code, stdout="complete prior timing trace", stderr="")


class LagGateTests(unittest.TestCase):
    def invoke(self, argv, responses):
        output = io.StringIO()
        with patch.object(lag_gate.subprocess, "run", side_effect=responses) as run:
            with contextlib.redirect_stdout(output):
                code = lag_gate.main(argv)
        return code, run.call_args_list, output.getvalue()

    def test_failed_runner_cannot_pass_through_a_successful_scan(self):
        # Second response represents the PASS an old complete trace could give.
        code, calls, output = self.invoke(["case"], [result(1), result(0)])
        self.assertEqual(code, 1)
        self.assertEqual(len(calls), 1)
        self.assertIn("LAG: FAIL", output)
        self.assertNotIn("LAG: PASS", output)

    def test_one_failed_case_prevents_aggregate_acceptance(self):
        code, calls, output = self.invoke(["good", "bad"], [result(), result(9), result()])
        self.assertEqual(code, 1)
        self.assertEqual(len(calls), 2)
        self.assertIn("bad", output)
        self.assertIn("capture/gate failures", output)

    def test_scan_failure_is_propagated(self):
        code, calls, _ = self.invoke(["case"], [result(), result(3)])
        self.assertEqual(code, 3)
        self.assertEqual(len(calls), 2)

    def test_frozen_rom_and_suffix_reach_capture_and_matching_scan(self):
        code, calls, _ = self.invoke(
            ["case", "--rom", "path with spaces/game.md", "--report-suffix", "_agent", "--budget", "0xDA"],
            [result(), result()])
        self.assertEqual(code, 0)
        capture = calls[0].args[0]
        self.assertEqual(Path(capture[capture.index("--rom") + 1]), Path("path with spaces/game.md"))
        self.assertEqual(capture[capture.index("--report-suffix") + 1], "_agent")
        scan = calls[1].args[0]
        self.assertIn("case_agent", scan)
        self.assertEqual(scan[-2:], ["--budget", "0xDA"])

    def test_empty_inventory_cannot_trigger_default_scan(self):
        with patch.object(lag_gate, "BUSY", []):
            code, calls, output = self.invoke([], [])
        self.assertEqual(code, 1)
        self.assertEqual(calls, [])
        self.assertIn("zero requested cases", output)


if __name__ == "__main__":
    unittest.main()
