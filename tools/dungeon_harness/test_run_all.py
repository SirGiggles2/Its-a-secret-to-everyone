"""Focused checks against false-positive harness verdicts; no emulator needed."""
import importlib.util
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

spec = importlib.util.spec_from_file_location('runner', Path(__file__).with_name('run_all.py'))
runner = importlib.util.module_from_spec(spec)
spec.loader.exec_module(runner)


class ResultContractTests(unittest.TestCase):
    def setUp(self):
        self.context = dict(run_id='new-run', rom_sha256='current-rom', level=1,
                            quest=1, scope='entry', expected_room=0x73)
        self.entry = dict(self.context, verdict='ENTRY_ONLY',
                          entry=dict(room=0x73, level=1, quest=1, frame_delta=60))

    def test_entry_pass_is_not_completion(self):
        self.assertEqual(runner.validate_report(self.entry, self.context), 'ENTRY_ONLY')
        completion = dict(self.context, scope='completion')
        with self.assertRaises(ValueError):
            runner.validate_report(dict(self.entry, scope='completion'), completion)

    def test_prior_run_or_other_rom_cannot_pass(self):
        for field in ('run_id', 'rom_sha256'):
            with self.subTest(field=field), self.assertRaises(ValueError):
                runner.validate_report(dict(self.entry, **{field: 'old'}), self.context)

    def test_completion_requires_all_events(self):
        context = dict(self.context, scope='completion')
        report = dict(context, verdict='PASS', events=dict(entered=True, boss_killed=True))
        with self.assertRaises(ValueError):
            runner.validate_report(report, context)
        report['events']['reward_collected'] = True
        self.assertEqual(runner.validate_report(report, context), 'PASS')

    def test_missing_state_is_error_even_in_dry_run(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            row = dict(save_state='missing.State', probe='legacy.lua')
            with patch.object(runner, 'HARNESS', root), self.assertRaises(ValueError):
                runner.prepare_row(row, False, 'current-rom')


if __name__ == '__main__':
    unittest.main()
