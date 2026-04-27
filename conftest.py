"""Pytest configuration and fixtures."""
import sys
from pathlib import Path

# Add tools/ to sys.path so tests can import from tools.extract_intro_assets
repo_root = Path(__file__).parent
sys.path.insert(0, str(repo_root))
