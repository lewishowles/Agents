#!/usr/bin/env python3
# Runs the renamed workspace generator for compatibility with existing commands.

import subprocess
import sys
from pathlib import Path


SCRIPT = Path(__file__).resolve().with_name("init-workspace.py")


def main() -> int:
	print("init-capabilities.py is deprecated; use init-workspace.py.", file=sys.stderr)
	return subprocess.call([str(SCRIPT), *sys.argv[1:]])


if __name__ == "__main__":
	sys.exit(main())
