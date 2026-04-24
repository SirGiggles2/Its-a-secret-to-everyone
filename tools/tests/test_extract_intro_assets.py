import subprocess
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]
TOOL = REPO / "tools" / "extract_intro_assets.py"

def test_tool_runs_with_help():
    result = subprocess.run([sys.executable, str(TOOL), "--help"],
                            stdin=subprocess.DEVNULL,
                            stdout=subprocess.PIPE, stderr=subprocess.PIPE,
                            text=True)
    assert result.returncode == 0
    assert "extract" in result.stdout.lower()

def test_tool_rejects_missing_ref_dir():
    result = subprocess.run([sys.executable, str(TOOL),
                             "--ref-dir", "/nonexistent/path/does/not/exist"],
                            stdin=subprocess.DEVNULL,
                            stdout=subprocess.PIPE, stderr=subprocess.PIPE,
                            text=True)
    assert result.returncode != 0
