#!/usr/bin/env python3
# Run conservative project diagnostics and return compact output.
#
# Shim: execs the globally-installed project-checks CLI. The real
# implementation lives in dev-tools' project-checks package.

from __future__ import annotations

import os
import sys

COMMAND = "project-checks"


def main() -> int:
	try:
		os.execvp(COMMAND, [COMMAND, *sys.argv[1:]])
	except FileNotFoundError:
		print(
			f"error: '{COMMAND}' not found on PATH. Install it: "
			"uv tool install --from ~/Dev/Repositories/Packages/dev-tools/packages/project-checks project-checks",
			file=sys.stderr,
		)
		return 1


if __name__ == "__main__":
	raise SystemExit(main())
