#!/usr/bin/env python3
# Create or preview AGENT_CAPABILITIES.md from local repo facts.
#
# This is an intentionally boring orientation generator:
# - show the repo shape
# - show exact package scripts
# - show generated/build outputs
# - show detected generators
# - show conservative command safety guidance
#
# Keep behavioural rules in AGENTS.md.
# Keep current status/plans in PROGRESS.md.

import argparse
import json
import sys
from dataclasses import dataclass
from pathlib import Path
from typing import Any, Dict, List, Optional, Union

DEFAULT_PROJECT_DIR = Path.cwd()
MANIFEST_NAME = "AGENT_CAPABILITIES.md"

CONFIG_NAMES = [
	".agent-capabilities.json",
	"agent-capabilities.json",
]

UNKNOWN = "Not detected"
NOT_DETECTED = "Not detected"

PACKAGE_MANAGERS = [
	("bun.lockb", "Bun", "bun run"),
	("bun.lock", "Bun", "bun run"),
	("pnpm-lock.yaml", "pnpm", "pnpm run"),
	("yarn.lock", "Yarn", "yarn"),
	("package-lock.json", "npm", "npm run"),
]

COMMON_SOURCE_DIRS = [
	"src",
	"app",
	"lib",
	"packages",
	"bin",
	"scripts",
	"support",
]

COMMON_CONFIG_FILES = [
	"package.json",
	"vite.config.ts",
	"vite.config.js",
	"vitest.config.ts",
	"vitest.config.js",
	"cypress.config.ts",
	"cypress.config.js",
	"playwright.config.ts",
	"playwright.config.js",
	"test/playwright-ct.config.ts",
	"test/playwright-ct.config.js",
	"tsconfig.json",
	"jsconfig.json",
	"tailwind.config.js",
	"tailwind.config.ts",
	"eslint.config.js",
	"eslint.config.mjs",
	"prettier.config.js",
	"prettier.config.mjs",
	"pyproject.toml",
	"Cargo.toml",
	"Package.swift",
	".boilersuit",
]

COMMON_DOC_FILES = [
	"README.md",
	"AGENTS.md",
	"PROGRESS.md",
	"CHANGELOG.md",
	"docs",
]

COMMON_GENERATED_PATHS = [
	"dist",
	"dist-docs",
	"build",
	"coverage",
	".coverage",
	"test-results",
	"playwright-report",
	".next",
	".nuxt",
	".vite",
	".turbo",
]

DEFAULT_TREE_EXCLUDES = [
	".git",
	".hg",
	".svn",
	".DS_Store",
	"node_modules",
	"dist",
	"dist-docs",
	"build",
	"coverage",
	".coverage",
	"test-results",
	"playwright-report",
	"default.profraw",
	".next",
	".nuxt",
	".vite",
	".turbo",
	".cache",
	"vendor",
]

BOILERSUIT_DIR_NAME = ".boilersuit"

SAFE_SCRIPT_HINTS = [
	"lint",
	"check",
	"typecheck",
	"test:unit",
	"test:component",
	"test:ct",
	"format:check",
]

EXPENSIVE_SCRIPT_HINTS = [
	"build",
	"test",
	"test:all",
	"test:e2e",
	"e2e",
	"coverage",
	"preview",
	"dev",
	"serve",
	"storybook",
]

MUTATING_SCRIPT_HINTS = [
	"format",
	"fix",
	"lint:fix",
	"generate",
	"generator",
	"scaffold",
	"create",
	"update",
	"prepare",
	"postinstall",
]

FORBIDDEN_SCRIPT_HINTS = [
	"publish",
	"release",
	"deploy",
	"migration",
	"migrate",
	"db:",
	"prisma",
]

GENERATOR_FIELD_KEYS = [
	"fields",
	"field",
	"prompts",
	"prompt",
	"args",
	"arguments",
	"inputs",
	"variables",
]


@dataclass
class PackageManager:
	name: str
	run_prefix: str
	source: str


@dataclass
class Generator:
	name: str
	command: str
	notes: str = ""


@dataclass
class PreservedManifestValues:
	package_manager: str = ""
	common_check_rows: List[str] = None

	def __post_init__(self) -> None:
		if self.common_check_rows is None:
			self.common_check_rows = []


def read_json(path: Path) -> Dict[str, Any]:
	try:
		return json.loads(path.read_text())
	except json.JSONDecodeError as error:
		raise SystemExit(f"Invalid JSON in {path}: {error}") from error


def try_read_json(path: Path) -> Optional[Union[Dict[str, Any], List[Any]]]:
	try:
		return json.loads(path.read_text())
	except (json.JSONDecodeError, OSError, UnicodeDecodeError):
		return None


def package_json(project_dir: Path) -> Dict[str, Any]:
	path = project_dir / "package.json"
	if not path.exists():
		return {}
	return read_json(path)


def load_config(project_dir: Path) -> Dict[str, Any]:
	for name in CONFIG_NAMES:
		path = project_dir / name
		if path.exists():
			return read_json(path)
	return {}


def config_list(config: Dict[str, Any], key: str) -> List[str]:
	value = config.get(key, [])
	if not isinstance(value, list):
		return []
	return [str(item) for item in value if str(item).strip()]


def is_placeholder_value(value: str) -> bool:
	normalised = value.strip().strip("`").lower()
	return normalised in {"", "[command]", "[unknown]", "unknown", "not detected"}


def preserved_values(project_dir: Path) -> PreservedManifestValues:
	path = project_dir / MANIFEST_NAME
	if not path.exists():
		return PreservedManifestValues()

	values = PreservedManifestValues()
	in_common_checks = False

	for raw_line in path.read_text().splitlines():
		line = raw_line.strip()

		if line.startswith("## "):
			in_common_checks = line in {"## Common checks", "## Diagnostics and checks"}
			continue

		if line.startswith("- Package manager: "):
			package_manager = line.removeprefix("- Package manager: ").strip()
			if not is_placeholder_value(package_manager):
				values.package_manager = package_manager
			continue

		if not in_common_checks or not line.startswith("|"):
			continue

		cells = [cell.strip() for cell in line.strip("|").split("|")]
		if len(cells) < 2 or cells[0] in {"Purpose", "---"}:
			continue

		purpose = cells[0]
		command = cells[1]
		if is_placeholder_value(command):
			continue

		values.common_check_rows.append(f"| {purpose} | {command} (Preserved from existing) |")

	return values


def existing_names(project_dir: Path, names: List[str]) -> List[str]:
	return [name for name in names if (project_dir / name).exists()]


def detect_package_manager(project_dir: Path, package: Dict[str, Any]) -> PackageManager:
	for filename, name, run_prefix in PACKAGE_MANAGERS:
		if (project_dir / filename).exists():
			return PackageManager(name=name, run_prefix=run_prefix, source=filename)

	manager = package.get("packageManager")
	if isinstance(manager, str) and manager:
		name, _, _version = manager.partition("@")
		lower_name = name.lower()

		if lower_name == "bun":
			return PackageManager(name="Bun", run_prefix="bun run", source="package.json")
		if lower_name == "pnpm":
			return PackageManager(name="pnpm", run_prefix="pnpm run", source="package.json")
		if lower_name == "yarn":
			return PackageManager(name="Yarn", run_prefix="yarn", source="package.json")
		if lower_name == "npm":
			return PackageManager(name="npm", run_prefix="npm run", source="package.json")

	return PackageManager(name=UNKNOWN, run_prefix="package-manager run", source=UNKNOWN)


def detect_runtime_requirements(project_dir: Path, package: Dict[str, Any], manager: PackageManager) -> str:
	requirements = []

	node = package.get("engines", {}).get("node")
	if node:
		requirements.append(f"Node {node}")

	package_manager = package.get("packageManager")
	if isinstance(package_manager, str) and package_manager:
		requirements.append(package_manager)
	elif manager.name != UNKNOWN:
		requirements.append(manager.name)

	if (project_dir / "Package.swift").exists():
		requirements.append("Swift")
	if (project_dir / "pyproject.toml").exists():
		requirements.append("Python")
	if (project_dir / "Cargo.toml").exists():
		requirements.append("Rust")

	return "; ".join(requirements) if requirements else NOT_DETECTED


def detect_primary_stack(project_dir: Path, package: Dict[str, Any]) -> str:
	dependencies = {}
	dependencies.update(package.get("dependencies", {}))
	dependencies.update(package.get("devDependencies", {}))
	dependencies.update(package.get("peerDependencies", {}))

	if "vue" in dependencies:
		return "Vue"
	if "react" in dependencies:
		return "React"
	if "svelte" in dependencies:
		return "Svelte"
	if "next" in dependencies:
		return "Next.js"
	if (project_dir / "Package.swift").exists():
		return "Swift"
	if (project_dir / "pyproject.toml").exists():
		return "Python"
	if (project_dir / "Cargo.toml").exists():
		return "Rust"

	return UNKNOWN


def detect_test_paths(project_dir: Path) -> List[str]:
	paths = []

	for name in ["tests", "test", "__tests__"]:
		if (project_dir / name).exists():
			paths.append(name)

	for pattern in ["*.test.*", "*.spec.*"]:
		for candidate in project_dir.glob(pattern):
			if candidate.is_file():
				paths.append(candidate.name)

	return sorted(set(paths))


def detect_progress_files(project_dir: Path) -> List[str]:
	return existing_names(
		project_dir,
		[
			"PROGRESS.md",
			".claude/PROGRESS.md",
			".agents/PROGRESS.md",
		],
	)


def script_run_command(script_name: str, manager: PackageManager) -> str:
	if manager.name == UNKNOWN:
		return f"<package-manager> run {script_name}"
	return f"{manager.run_prefix} {script_name}"


def detect_local_services(scripts: Dict[str, str], manager: PackageManager) -> List[str]:
	services = []

	for name in ["dev", "serve", "preview", "storybook"]:
		if name in scripts:
			services.append(f"`{script_run_command(name, manager)}`")

	return services


def detect_package_script_generators(scripts: Dict[str, str], manager: PackageManager) -> List[Generator]:
	generator_names = [
		name
		for name in scripts
		if any(token in name.lower() for token in ["generate", "generator", "scaffold", "create"])
	]

	return [
		Generator(
			name=name,
			command=script_run_command(name, manager),
			notes="Detected from package script name.",
		)
		for name in sorted(generator_names)
	]


def boilersuit_generator_candidates(boilersuit_dir: Path) -> List[Path]:
	generators_dir = boilersuit_dir / "generators"
	if generators_dir.exists() and generators_dir.is_dir():
		return sorted(generators_dir.iterdir(), key=lambda item: item.name.lower())

	return sorted(boilersuit_dir.iterdir(), key=lambda item: item.name.lower())


def field_name_from_value(value: Any) -> str:
	if isinstance(value, str):
		return value

	if not isinstance(value, dict):
		return ""

	for key in ["token", "name", "key", "id", "field", "argument", "variable"]:
		candidate = value.get(key)
		if isinstance(candidate, str) and candidate.strip():
			return candidate.strip()

	return ""


def field_names_from_json(data: Any) -> List[str]:
	names = []

	if isinstance(data, list):
		for item in data:
			name = field_name_from_value(item)
			if name:
				names.append(name)
		return names

	if not isinstance(data, dict):
		return []

	for key in GENERATOR_FIELD_KEYS:
		value = data.get(key)
		if value is None:
			continue

		if isinstance(value, dict):
			for field_key, field_value in value.items():
				if isinstance(field_value, dict):
					name = field_name_from_value({"name": field_key, **field_value})
				else:
					name = str(field_key)
				if name:
					names.append(name)
			continue

		if isinstance(value, list):
			for item in value:
				name = field_name_from_value(item)
				if name:
					names.append(name)
			continue

		name = field_name_from_value(value)
		if name:
			names.append(name)

	return names


def detect_boilersuit_fields(generator_path: Path) -> List[str]:
	json_candidates = []

	if generator_path.is_file() and generator_path.suffix == ".json":
		json_candidates.append(generator_path)

	if generator_path.is_dir():
		for name in [
			"generator.json",
			"boilersuit.json",
			"template.json",
			"schema.json",
			"fields.json",
			"prompts.json",
		]:
			candidate = generator_path / name
			if candidate.exists() and candidate.is_file():
				json_candidates.append(candidate)

		json_candidates.extend(
			child for child in sorted(generator_path.glob("*.json"), key=lambda item: item.name.lower())
			if child not in json_candidates
		)

	field_names = []

	for candidate in json_candidates:
		data = try_read_json(candidate)
		field_names.extend(field_names_from_json(data))

	unique_names = []
	for name in field_names:
		if name not in unique_names:
			unique_names.append(name)

	return unique_names


def generator_notes(relative_path: Path, fields: List[str]) -> str:
	if fields:
		field_text = ", ".join(f"`{field}`" for field in fields)
		return f"Detected from `{relative_path}`. Fields: {field_text}."

	return f"Detected from `{relative_path}`. Run with `--json` to inspect required fields."


def detect_boilersuit_generators(project_dir: Path) -> List[Generator]:
	boilersuit_dir = project_dir / BOILERSUIT_DIR_NAME
	if not boilersuit_dir.exists() or not boilersuit_dir.is_dir():
		return []

	generators = []

	for child in boilersuit_generator_candidates(boilersuit_dir):
		if child.name.startswith("."):
			continue

		if child.name in ["config", "generators", "index", "templates"]:
			continue

		relative_path = child.relative_to(project_dir)

		if child.is_dir():
			fields = detect_boilersuit_fields(child)
			generators.append(
				Generator(
					name=child.name,
					command=f'boilersuit generate "{child.name}" --json',
					notes=generator_notes(relative_path, fields),
				)
			)
			continue

		if child.is_file() and child.suffix in [".json", ".js", ".ts", ".mjs", ".cjs"]:
			name = child.stem
			if name in ["index", "config", "boilersuit"]:
				continue

			fields = detect_boilersuit_fields(child)
			generators.append(
				Generator(
					name=name,
					command=f'boilersuit generate "{name}" --json',
					notes=generator_notes(relative_path, fields),
				)
			)

	return generators


def script_matches(text: str, hints: List[str]) -> bool:
	return any(hint in text for hint in hints)


def classify_script(name: str, command: str = "") -> str:
	lower_name = name.lower()
	lower_command = command.lower()
	text = f"{lower_name} {lower_command}"

	if script_matches(text, FORBIDDEN_SCRIPT_HINTS):
		return "Forbidden unless explicit"

	if any(token in text for token in ["--fix", " --write", "write ", "format "]):
		return "Ask first: mutating"

	if script_matches(text, MUTATING_SCRIPT_HINTS):
		return "Ask first: mutating"

	if lower_name.startswith("check:"):
		return "Usually safe"

	if lower_name in ["attw", "publint"]:
		return "Usually safe"

	if script_matches(text, EXPENSIVE_SCRIPT_HINTS):
		return "Ask first: broad/long-running"

	if script_matches(text, SAFE_SCRIPT_HINTS):
		return "Usually safe"

	return "Unclassified"


def common_check_rows(scripts: Dict[str, str], manager: PackageManager) -> List[str]:
	checks = [
		("Lint", ["lint:check", "lint"]),
		("Unit tests", ["test:unit", "test:unit:run", "test"]),
		("Component tests", ["test:component", "test:ct", "test:component:cypress"]),
		("End-to-end tests", ["test:e2e", "e2e"]),
		("Docs build", ["build:docs", "docs:build"]),
		("Build", ["build"]),
	]

	rows = []

	for purpose, candidates in checks:
		command = NOT_DETECTED

		for candidate in candidates:
			if candidate in scripts:
				command = f"`{script_run_command(candidate, manager)}`"
				break

		rows.append(f"| {purpose} | {command} |")

	return rows


def package_script_rows(scripts: Dict[str, str], manager: PackageManager) -> List[str]:
	if not scripts:
		return ["| None detected |  |  |"]

	rows = []

	for name in sorted(scripts):
		command = scripts[name].replace("\n", " ")
		run_command = script_run_command(name, manager)
		classification = classify_script(name, command)

		rows.append(
			f"| `{name}` | `{command}` | `{run_command}` | {classification} |"
		)

	return rows


def tree_label(path: Path) -> str:
	return path.name + ("/" if path.is_dir() else "")


def visible_children(path: Path, excludes: set[str]) -> List[Path]:
	children = []

	try:
		for child in path.iterdir():
			if child.name in excludes:
				continue
			if child.name.startswith(".") and child.name not in [".github", ".vscode"]:
				continue
			children.append(child)
	except PermissionError:
		return []

	return sorted(children, key=lambda item: (not item.is_dir(), item.name.lower()))


def render_tree(project_dir: Path, depth: int, excludes: List[str]) -> List[str]:
	exclude_set = set(excludes)
	lines = ["."]

	def walk(path: Path, prefix: str, current_depth: int) -> None:
		if current_depth >= depth:
			return

		children = visible_children(path, exclude_set)
		for index, child in enumerate(children):
			is_last = index == len(children) - 1
			branch = "└── " if is_last else "├── "
			lines.append(f"{prefix}{branch}{tree_label(child)}")

			if child.is_dir():
				extension = "    " if is_last else "│   "
				walk(child, prefix + extension, current_depth + 1)

	walk(project_dir, "", 0)
	return lines


def bullet_values(heading: str, values: List[str]) -> List[str]:
	if values:
		return [f"- {heading}: {', '.join(f'`{value}`' for value in values)}"]
	return [f"- {heading}: {UNKNOWN}"]


def render_generator_table(generators: List[Generator]) -> List[str]:
	if not generators:
		return ["| None detected |  |  |"]

	rows = []
	for generator in generators:
		notes = generator.notes or ""
		rows.append(f"| {generator.name} | `{generator.command}` | {notes} |")
	return rows


def render_manifest(project_dir: Path, tree_depth: int, tree_excludes: List[str]) -> str:
	package = package_json(project_dir)
	scripts = package.get("scripts", {})
	config = load_config(project_dir)
	preserved = preserved_values(project_dir)

	manager = detect_package_manager(project_dir, package)
	stack = detect_primary_stack(project_dir, package)
	runtime = detect_runtime_requirements(project_dir, package, manager)

	config_tree_excludes = config_list(config, "treeExclude")
	config_generated_paths = config_list(config, "generatedPaths")

	source_dirs = existing_names(project_dir, COMMON_SOURCE_DIRS)
	config_paths = existing_names(project_dir, COMMON_CONFIG_FILES)
	doc_paths = existing_names(project_dir, COMMON_DOC_FILES)
	test_paths = detect_test_paths(project_dir)
	generated_paths = sorted(
		set(existing_names(project_dir, COMMON_GENERATED_PATHS) + existing_names(project_dir, config_generated_paths))
	)
	progress_files = detect_progress_files(project_dir)
	local_services = detect_local_services(scripts, manager)

	tree_excludes = sorted(set(tree_excludes + config_tree_excludes + generated_paths))

	detected_generators = [
		*detect_boilersuit_generators(project_dir),
		*detect_package_script_generators(scripts, manager),
	]

	lines = [
		"# Project capabilities",
		"",
		"Factual repo orientation for agents. Behavioural rules live in `AGENTS.md`. Current status and plans live in `PROGRESS.md`.",
		"",
		"## Repo summary",
		"",
		f"- Primary stack: {stack}",
		f"- Package manager: {preserved.package_manager}"
			if preserved.package_manager
			else f"- Package manager: {manager.name if manager.name != UNKNOWN else UNKNOWN}"
				+ (f" (detected from `{manager.source}`)" if manager.source != UNKNOWN else ""),
		f"- Script runner: `{manager.run_prefix} <script>`" if manager.name != UNKNOWN else "- Script runner: Not detected",
		f"- Runtime requirements: {runtime}",
		*bullet_values("Progress files", progress_files),
		*bullet_values("Agent rules", existing_names(project_dir, ["AGENTS.md"])),
		"",
		"## File tree",
		"",
		f"Generated with depth {tree_depth}.",
		f"Excluded: {', '.join(f'`{item}`' for item in tree_excludes)}.",
		"",
		"```txt",
		*render_tree(project_dir, tree_depth, tree_excludes),
		"```",
		"",
		"## Important paths",
		"",
		*bullet_values("Main source directories", source_dirs),
		*bullet_values("Configuration paths", config_paths),
		*bullet_values("Test paths", test_paths),
		*bullet_values("Documentation paths", doc_paths),
		"",
		"## Package scripts",
		"",
		"Run scripts with:",
		"",
		"```sh",
		f"{manager.run_prefix} <script>" if manager.name != UNKNOWN else "<package-manager> run <script>",
		"```",
		"",
		"| Script | package.json command | Run command | Safety |",
		"| --- | --- | --- | --- |",
		*package_script_rows(scripts, manager),
		"",
		"## Common checks",
		"",
		"Prefer the narrowest command that verifies the changed area. Classifications are conservative; inspect the script before running if behaviour is unclear.",
		"",
		"Some test runners support passing a changed file path after the script command. Inspect the script/config before running a broad suite.",
		"",
		"Broad test commands can produce large output. When only the failure summary is needed, capture output to a temp file or use shell-safe truncation such as `command 2>&1 | tail -20`, taking care not to hide the original exit status.",
		"",
		"| Purpose | Command |",
		"| --- | --- |",
		*common_check_rows(scripts, manager),
		*preserved.common_check_rows,
		"",
		"## Local services",
		"",
	]

	if local_services:
		lines.extend(f"- {service}" for service in local_services)
	else:
		lines.append("- None detected.")

	lines.extend(
		[
			"",
			"## Generated or build output",
			"",
		]
	)

	if generated_paths:
		lines.extend(f"- `{path}`" for path in generated_paths)
	else:
		lines.append("- None detected.")

	lines.extend(
		[
			"",
			"Do not edit generated output directly unless the user explicitly asks for that exact action.",
			"",
			"## Generators",
			"",
			"Detected generators come from `.boilersuit`.",
			"",
			"| Name | Command | Notes |",
			"| --- | --- | --- |",
			*render_generator_table(detected_generators),
			"",
			"## Command safety",
			"",
			"Ask before running:",
			"",
			"- Dependency installation commands.",
			"- Broad builds.",
			"- Full test suites.",
			"- End-to-end tests.",
			"- Long-running dev servers.",
			"- Commands that modify many files.",
			"- Database, deploy, publish, release, or migration commands.",
			"",
			"Forbidden unless explicitly requested:",
			"",
			"- `git commit`",
			"- `git tag`",
			"- `git push`",
			"- merge or rebase commands",
			"- deploy, publish, or release commands",
			"- destructive file operations",
			"- production or remote mutation commands",
			"",
			"## Fallback",
			"",
			"If this file is incomplete, inspect these in order:",
			"",
			"1. `AGENTS.md`",
			"2. `PROGRESS.md`",
			"3. `package.json`",
			"4. nearby README/docs files",
			"",
			"Ask before guessing about expensive, destructive, remote, or history-changing commands.",
			"",
		]
	)

	return "\n".join(lines)


def confirm_write(path: Path, force: bool) -> None:
	if not path.exists() or force:
		return

	if not sys.stdin.isatty():
		raise SystemExit(f"{path} already exists. Re-run with --force to replace it.")

	response = input(f"{path} already exists. Replace it? (y/n): ")
	if response.strip().lower() != "y":
		raise SystemExit("Skipped.")


def main() -> None:
	parser = argparse.ArgumentParser(description="Preview or write AGENT_CAPABILITIES.md for a project.")
	parser.add_argument("--project-dir", type=Path, default=DEFAULT_PROJECT_DIR, help="Project directory to inspect.")
	parser.add_argument("--write", action="store_true", help="Write AGENT_CAPABILITIES.md instead of printing a preview.")
	parser.add_argument("--force", action="store_true", help="Replace an existing AGENT_CAPABILITIES.md without prompting.")
	parser.add_argument("--tree-depth", type=int, default=3, help="Maximum tree depth to include.")
	parser.add_argument(
		"--tree-exclude",
		action="append",
		default=[],
		help="Additional file or directory name to exclude from the tree. Can be used more than once.",
	)
	args = parser.parse_args()

	project_dir = args.project_dir.resolve()
	if not project_dir.is_dir():
		raise SystemExit(f"Project directory not found: {project_dir}")

	if args.tree_depth < 1:
		raise SystemExit("--tree-depth must be 1 or greater.")

	tree_excludes = sorted(set(DEFAULT_TREE_EXCLUDES + args.tree_exclude))
	target = project_dir / MANIFEST_NAME

	body = render_manifest(
		project_dir=project_dir,
		tree_depth=args.tree_depth,
		tree_excludes=tree_excludes,
	)

	if not args.write:
		print(body, end="")
		return

	confirm_write(target, args.force)
	target.write_text(body)
	print(f"Wrote {target}")


if __name__ == "__main__":
	main()
