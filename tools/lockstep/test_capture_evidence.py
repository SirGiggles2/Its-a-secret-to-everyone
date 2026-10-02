"""Failure-path checks for evidence gates; no emulator required."""
from __future__ import annotations

import contextlib
import hashlib
import importlib.util
import io
import json
import struct
import sys
import tempfile
import unittest
from pathlib import Path
from types import SimpleNamespace
from unittest.mock import patch

import capture_evidence
import diff
import lag_scan
import run_lockstep
import screen_sweep


class EvidenceTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name)
        self.case = self.root / "case"
        self.case.mkdir()

    def capture(self, platform, count=4, video=True):
        row = bytearray(2048)
        row[0x12] = 5
        (self.case / f"{platform}.ram").write_bytes(row * count)
        (self.case / f"{platform}.txt").write_text(f"frames={count}\n", encoding="utf-8")
        if video:
            (self.case / f"{platform}.fram").write_bytes(row * count)
            (self.case / f"{platform}.frtick").write_bytes(
                b"".join(struct.pack(">H", t) for t in range(count)))

    def lag(self, names):
        with patch.object(lag_scan, "REPORTS", self.root), patch.object(sys, "argv", ["lag", *names]):
            with contextlib.redirect_stdout(io.StringIO()):
                return lag_scan.main()

    def test_missing_case_and_zero_cases_fail(self):
        self.assertEqual(self.lag(["absent"]), 1)
        self.assertEqual(self.lag([]), 1)

    def test_complete_lag_passes_but_missing_completion_fails(self):
        for platform in ("nes", "gen"):
            self.capture(platform)
        self.assertEqual(self.lag(["case"]), 0)
        (self.case / "gen.txt").write_text("ticks=4\n", encoding="utf-8")
        self.assertEqual(self.lag(["case"]), 1)

    def test_empty_truncated_and_mismatched_video_fail(self):
        for invalid in (b"", b"x", b"x" * 2048):
            with self.subTest(size=len(invalid)):
                for platform in ("nes", "gen"):
                    self.capture(platform)
                (self.case / "gen.fram").write_bytes(invalid)
                self.assertEqual(self.lag(["case"]), 1)

    def test_missing_tick_and_mismatched_completion_fail(self):
        for platform in ("nes", "gen"):
            self.capture(platform)
        (self.case / "gen.frtick").write_bytes(struct.pack(">4H", 0, 1, 1, 3))
        self.assertEqual(self.lag(["case"]), 1)
        self.capture("gen", 3)
        self.assertEqual(self.lag(["case"]), 1)

    def test_declared_fast_transition_padding_is_allowed(self):
        for platform in ("nes", "gen"):
            self.capture(platform)
        row = (self.case / "gen.fram").read_bytes()[:2048]
        (self.case / "gen.fram").write_bytes(row * 3)
        (self.case / "gen.frtick").write_bytes(struct.pack(">3H", 0, 1, 3))
        (self.case / "gen.pad").write_text("2\n", encoding="utf-8")
        self.assertEqual(self.lag(["case"]), 0)

    def test_capture_error_and_wrong_ram_size_rejected(self):
        self.capture("gen")
        (self.case / "gen.err").write_text("timeout", encoding="utf-8")
        with self.assertRaises(ValueError):
            capture_evidence.completed_ticks(self.case, "gen")
        (self.case / "gen.err").unlink()
        (self.case / "gen.ram").write_bytes(b"x")
        with self.assertRaises(ValueError):
            capture_evidence.completed_ticks(self.case, "gen")

    def test_partial_equal_captures_cannot_pass_or_bless(self):
        for platform in ("nes", "gen"):
            self.capture(platform)
        spec = {"name": "case", "script": [[8, ""]]}
        with patch.object(diff.gate, "load_baseline", return_value={}), \
             patch.object(diff.gate, "save_baseline") as save, \
             contextlib.redirect_stdout(io.StringIO()):
            self.assertEqual(diff.main(self.case, spec, True), 1)
            save.assert_not_called()

    def test_gen_runner_failure_cannot_be_accepted(self):
        preset = self.root / "preset.json"
        preset.write_text(json.dumps({"name": "case", "script": [[4, ""]]}), encoding="utf-8")
        def nes_cached(*args):
            out = args[1]
            self.case = out
            self.capture("nes", video=False)
            return "hit"
        def capture(*args):
            self.capture("gen", video=False)
            return 1  # process failed despite apparently complete files
        with patch.object(run_lockstep, "ROOT", self.root), \
             patch.object(run_lockstep, "nes_cached", side_effect=nes_cached), \
             patch.object(run_lockstep, "capture", side_effect=capture), \
             patch.object(run_lockstep.diff, "main") as compare, \
             patch.object(sys, "argv", ["run", str(preset), "--full"]), \
             contextlib.redirect_stdout(io.StringIO()):
            self.assertEqual(run_lockstep.main(), 1)
            compare.assert_not_called()

    def test_screen_missing_or_failed_capture_is_error(self):
        with patch.object(screen_sweep, "REPORTS", self.root):
            self.assertIn("ERROR:", screen_sweep.run_preset("absent", 1)[0])
        with patch.object(screen_sweep, "pick_ticks", return_value=[3]), \
             patch.object(screen_sweep.subprocess, "run", return_value=SimpleNamespace(returncode=1)):
            self.assertIn("ERROR:", screen_sweep.run_preset("case", 1)[0])

    def test_screen_zero_cases_returns_failure(self):
        with patch.object(screen_sweep, "run_preset", return_value=["| case | - | no settled play tick |"]), \
             patch.object(sys, "argv", ["screen", "case"]), \
             contextlib.redirect_stdout(io.StringIO()):
            self.assertEqual(screen_sweep.main(), 1)

    def test_probe_hashes_executed_copy_when_source_changes(self):
        path = Path(__file__).resolve().parents[1] / "debug" / "run_probe.py"
        spec = importlib.util.spec_from_file_location("probe_identity_test", path)
        probe = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(probe)
        rom = self.root / "input.md"
        lua = self.root / "probe.lua"
        rom.write_bytes(b"executed ROM")
        lua.write_text("client.exit()", encoding="utf-8")
        emu = self.root / "emu"
        emu.mkdir()
        (emu / "config.ini").write_text("{}", encoding="utf-8")
        out = self.root / "report"
        def launch(*args):
            rom.write_bytes(b"new concurrent build")
            lua.write_text("changed source", encoding="utf-8")
            return 0
        with patch.object(probe, "EMU", emu / "EmuHawk.exe"), \
             patch.object(probe, "STAGE_ROOT", self.root / "stage"), \
             patch.object(probe.subprocess, "STARTUPINFO", return_value=SimpleNamespace(dwFlags=0, wShowWindow=0), create=True), \
             patch.object(probe.subprocess, "STARTF_USESHOWWINDOW", 1, create=True), \
             patch.object(probe, "short", side_effect=str), \
             patch.object(probe, "run_on_hidden_desktop", side_effect=launch), \
             patch.dict(probe.os.environ, {"CLAUDE_PROBE_VISIBLE": "0"}), \
             patch.object(sys, "argv", ["probe", str(lua), str(out), "--rom", str(rom)]), \
             contextlib.redirect_stdout(io.StringIO()):
            self.assertEqual(probe.main(), 0)
        report = json.loads((out / "launch.json").read_text(encoding="utf-8"))
        self.assertEqual(report["rom_sha256"], hashlib.sha256(b"executed ROM").hexdigest())
        self.assertEqual(report["script_sha256"], hashlib.sha256(b"client.exit()").hexdigest())
        self.assertNotEqual(report["rom_sha256"], probe.sha(rom))
        self.assertEqual(report["rom_sha256"], probe.sha(Path(report["staged_rom"])))


if __name__ == "__main__":
    unittest.main()
