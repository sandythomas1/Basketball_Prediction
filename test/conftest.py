"""
Shared fixtures for the test suite.
"""

import sys
from pathlib import Path

# Ensure src/ is importable in every test module
sys.path.insert(0, str(Path(__file__).parent.parent / "src"))
