#!/usr/bin/env python3
# Run conservative project diagnostics and return compact output.

from __future__ import annotations

import argparse
import datetime as dt
import json
import re
import shlex
import subprocess
import sys
from dataclasses import dataclass
from pathlib import Path
from typing import Any


DESCRIPTION = """Run conservative project diagnostics.

Default mode lists available checks without running them. Use --check to run a
specific check, or --all when broad safe verification has been explicitly
requested.
"""

EPILOG = """Commands:
  --list              Discover available diagnostics without running them.
  --check NAME        Run one named check, such as test:unit or lint:check.
  --all               Run all conservative checks. Use only after approval for broad verification.
  --json              Return machine-readable output for the selected mode.

Examples:
  .agent/scripts/project-diagnostics.py --list
  .agent/scripts/project-diagnostics.py --check test:unit
  .agent/scripts/project-diagnostics.py --check lint:check --check test:unit
  .agent/scripts/project-diagnostics.py --all
  .agent/scripts/project-diagnostics.py --json --list
"""

SAFE_SCRIPT_NAMES = {
	"attw",
	"check",
	"check:types",
	"lint",
	"lint:check",
	"publint",
	"test:unit",
	"test:unit:run",
	"typecheck",
	"type-check",
	"validate",
}

SKIPPED_SCRIPT_NAMES = {
	"build",
	"dev",
	"e2e",
	"format",
	"lint:fix",
	"preview",
	"publish",
	"release",
	"start",
	"test",
	"test:all",
	"test:e2e",
}

MUTATING_COMMAND_HINTS = ("--fix", "--write", "format", "publish", "release", "deploy", "migrate")
ANSI_PATTERN = re.compile(r"\x1b\[[0-9;]*m")


@dataclass
class Check:
	name: str
	command: list[str]
	reason: str


@dataclass
class Result:
	name: str
	command: list[str]
	status: str
	exit_code: int | None
	log_path: str
	summary: list[str]


def load_package_json(project_dir: Path) -> dict[str, Any]:
	path = project_dir / "package.json"
	if not path.exists():
		return {}

	try:
		return json.loads(path.read_text())
	except json.JSONDecodeError:
		return {}


def detect_package_runner(project_dir: Path) -> list[str] | None:
	if (project_dir / "bun.lock").exists() or (project_dir / "bun.lockb").exists():
		return ["bun", "run"]
	if (project_dir / "pnpm-lock.yaml").exists():
		return ["pnpm", "run"]
	if (project_dir / "yarn.lock").exists():
		return ["yarn"]
	if (project_dir / "package-lock.json").exists() or (project_dir / "package.json").exists():
		return ["npm", "run"]
	return None


def script_is_safe(name: str, command: str) -> bool:
	lower_command = command.lower()
	if name not in SAFE_SCRIPT_NAMES:
		return False
	return not any(hint in lower_command for hint in MUTATING_COMMAND_HINTS)


def script_skip_reason(name: str, command: str) -> str | None:
	lower_command = command.lower()
	if name in SKIPPED_SCRIPT_NAMES:
		return "broad, long-running, or mutating script"
	if any(hint in lower_command for hint in MUTATING_COMMAND_HINTS):
		return "mutating script"
	return None


def discover_checks(project_dir: Path) -> tuple[list[Check], list[str]]:
	checks: list[Check] = []
	skipped: list[str] = []

	validate_script = project_dir / "scripts" / "validate.sh"
	if validate_script.exists():
		checks.append(Check("validate", ["bash", "scripts/validate.sh"], "local validation script"))

	package = load_package_json(project_dir)
	scripts = package.get("scripts", {}) if isinstance(package.get("scripts"), dict) else {}
	runner = detect_package_runner(project_dir)

	for name in sorted(scripts):
		command = str(scripts[name])
		skip_reason = script_skip_reason(name, command)
		if skip_reason:
			skipped.append(f"{name}: {skip_reason}")
			continue

		if runner and script_is_safe(name, command):
			checks.append(Check(name, [*runner, name], "conservative package script"))

	if not checks:
		skipped.append("no conservative diagnostics command found")

	return checks, skipped


def dedupe_checks(checks: list[Check]) -> list[Check]:
	names = {check.name for check in checks}
	duplicates = {
		"test:unit": "test:unit:run",
	}

	return [
		check
		for check in checks
		if duplicates.get(check.name) not in names
	]


def selected_checks(checks: list[Check], requested_names: list[str], run_all: bool) -> tuple[list[Check], list[str]]:
	if run_all:
		return dedupe_checks(checks), []

	by_name = {check.name: check for check in checks}
	selected = []
	errors = []

	for name in requested_names:
		if name in by_name:
			selected.append(by_name[name])
		else:
			errors.append(f"unknown or unsafe check: {name}")

	return selected, errors


def command_label(command: list[str]) -> str:
	return " ".join(shlex.quote(part) for part in command)


def redact(text: str) -> str:
	lines = []
	for line in ANSI_PATTERN.sub("", text).splitlines():
		lower = line.lower()
		if any(token in lower for token in ["api_key", "apikey", "authorization:", "password", "secret", "token="]):
			lines.append("[redacted possible secret]")
		else:
			lines.append(line)
	return "\n".join(lines)


def summarise_output(output: str, limit: int = 8) -> list[str]:
	clean = redact(output).strip()
	if not clean:
		return ["No output."]

	lines = [line for line in clean.splitlines() if line.strip()]
	return lines[-limit:]


def run_check(project_dir: Path, log_dir: Path, check: Check, timeout: int) -> Result:
	started = dt.datetime.now(dt.timezone.utc).strftime("%Y%m%d-%H%M%S")
	log_path = log_dir / f"{started}-{check.name.replace(':', '-')}.log"

	try:
		completed = subprocess.run(
			check.command,
			cwd=project_dir,
			text=True,
			stdout=subprocess.PIPE,
			stderr=subprocess.STDOUT,
			timeout=timeout,
			check=False,
		)
		output = completed.stdout or ""
		log_path.write_text(redact(output))

		status = "passed" if completed.returncode == 0 else "failed"
		return Result(
			name=check.name,
			command=check.command,
			status=status,
			exit_code=completed.returncode,
			log_path=str(log_path.relative_to(project_dir)),
			summary=summarise_output(output),
		)
	except subprocess.TimeoutExpired as error:
		output = error.stdout or ""
		if isinstance(output, bytes):
			output = output.decode(errors="replace")
		log_path.write_text(redact(output))

		return Result(
			name=check.name,
			command=check.command,
			status="timeout",
			exit_code=None,
			log_path=str(log_path.relative_to(project_dir)),
			summary=[f"Timed out after {timeout}s."],
		)
	except FileNotFoundError:
		log_path.write_text("")
		return Result(
			name=check.name,
			command=check.command,
			status="skipped",
			exit_code=None,
			log_path=str(log_path.relative_to(project_dir)),
			summary=[f"Command not found: {check.command[0]}"],
		)


def render_markdown(project_dir: Path, results: list[Result], skipped: list[str]) -> str:
	lines = [
		"# Project diagnostics",
		"",
		f"Project: `{project_dir}`",
		"",
		"| Check | Status | Command | Log |",
		"| --- | --- | --- | --- |",
	]

	for result in results:
		lines.append(
			f"| {result.name} | {result.status} | `{command_label(result.command)}` | `{result.log_path}` |"
		)

	if not results:
		lines.append("| None | skipped |  |  |")

	lines.extend(["", "## Output summary", ""])

	for result in results:
		lines.append(f"### {result.name}")
		lines.extend(f"- {line}" for line in result.summary)
		lines.append("")

	if skipped:
		lines.extend(["## Skipped", ""])
		lines.extend(f"- {item}" for item in skipped)
		lines.append("")

	return "\n".join(lines).rstrip() + "\n"


def render_list_markdown(project_dir: Path, checks: list[Check], skipped: list[str]) -> str:
	lines = [
		"# Project diagnostics",
		"",
		f"Project: `{project_dir}`",
		"",
		"Mode: list only. No checks were run.",
		"",
		"| Check | Command | Description |",
		"| --- | --- | --- |",
	]

	for check in checks:
		lines.append(f"| {check.name} | `{command_label(check.command)}` | {check.reason} |")

	if not checks:
		lines.append("| None |  | No conservative diagnostics command found |")

	if skipped:
		lines.extend(["", "## Skipped", ""])
		lines.extend(f"- {item}" for item in skipped)

	return "\n".join(lines).rstrip() + "\n"


def render_json(project_dir: Path, results: list[Result], skipped: list[str]) -> str:
	payload = {
		"project": str(project_dir),
		"results": [
			{
				"name": result.name,
				"command": result.command,
				"status": result.status,
				"exit_code": result.exit_code,
				"log_path": result.log_path,
				"summary": result.summary,
			}
			for result in results
		],
		"skipped": skipped,
	}
	return json.dumps(payload, indent=2) + "\n"


def render_list_json(project_dir: Path, checks: list[Check], skipped: list[str]) -> str:
	payload = {
		"project": str(project_dir),
		"mode": "list",
		"checks": [
			{
				"name": check.name,
				"command": check.command,
				"description": check.reason,
			}
			for check in checks
		],
		"skipped": skipped,
	}
	return json.dumps(payload, indent=2) + "\n"


def main() -> int:
	parser = argparse.ArgumentParser(
		description=DESCRIPTION,
		epilog=EPILOG,
		formatter_class=argparse.RawDescriptionHelpFormatter,
	)
	parser.add_argument("--project", type=Path, default=Path.cwd(), help="Project directory to inspect. Defaults to the current directory.")
	parser.add_argument("--json", action="store_true", help="Print JSON instead of Markdown for list or run output.")
	parser.add_argument("--timeout", type=int, default=120, help="Timeout per check in seconds. Default: 120.")
	parser.add_argument("--list", action="store_true", help="List available and skipped checks without running anything. This is the default.")
	parser.add_argument("--check", action="append", default=[], metavar="NAME", help="Run one named check. Repeat to run multiple checks.")
	parser.add_argument("--all", action="store_true", help="Run all conservative checks. Use only after approval for broad verification.")
	args = parser.parse_args()

	if args.all and args.check:
		print("Use either --all or --check, not both.", file=sys.stderr)
		return 2

	project_dir = args.project.resolve()
	if not project_dir.is_dir():
		print(f"Project directory not found: {project_dir}", file=sys.stderr)
		return 2

	checks, skipped = discover_checks(project_dir)
	list_only = args.list or (not args.check and not args.all)

	if list_only:
		output = render_list_json(project_dir, checks, skipped) if args.json else render_list_markdown(project_dir, checks, skipped)
		print(output, end="")
		return 0

	checks_to_run, selection_errors = selected_checks(checks, args.check, args.all)
	if selection_errors:
		for error in selection_errors:
			print(error, file=sys.stderr)
		print("Run with --list to see available checks.", file=sys.stderr)
		return 2

	log_dir = project_dir / ".agent" / "diagnostics"
	log_dir.mkdir(parents=True, exist_ok=True)

	results = [run_check(project_dir, log_dir, check, args.timeout) for check in checks_to_run]

	output = render_json(project_dir, results, skipped) if args.json else render_markdown(project_dir, results, skipped)
	print(output, end="")

	if any(result.status in {"failed", "timeout"} for result in results):
		return 1
	return 0


if __name__ == "__main__":
	sys.exit(main())
