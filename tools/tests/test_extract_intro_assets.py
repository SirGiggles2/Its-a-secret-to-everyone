import sys
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]
TOOL = REPO / "tools" / "extract_intro_assets.py"

def test_tool_exists():
    """Test that the tool file exists."""
    assert TOOL.exists(), f"Tool not found at {TOOL}"

def test_tool_is_executable():
    """Test that the tool file is readable as Python."""
    assert TOOL.is_file()
    # Verify it contains a main function
    content = TOOL.read_text()
    assert "def main()" in content
    assert "if __name__" in content
