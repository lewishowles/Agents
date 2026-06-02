#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
REPO_DIR=$(cd "$SCRIPT_DIR/.." && pwd)
MANIFEST="$REPO_DIR/external-skills.json"

source "$REPO_DIR/scripts/lib/colours.sh"

usage() {
	printf 'Usage: %s\n' "$(basename "$0")"
}

if [ "${1:-}" = "--help" ]; then
	usage
	exit 0
fi

if ! command -v jq &>/dev/null; then
	printf '%s✗%s sync-external-skills requires jq. Install it with: brew install jq\n' "$RED" "$RESET_COLOUR" >&2
	exit 1
fi

if ! command -v curl &>/dev/null; then
	printf '%s✗%s sync-external-skills requires curl.\n' "$RED" "$RESET_COLOUR" >&2
	exit 1
fi

if [ ! -f "$MANIFEST" ]; then
	printf '%s✗%s External skills manifest not found: %s\n' "$RED" "$RESET_COLOUR" "$MANIFEST" >&2
	exit 1
fi

vet_skill_file() {
	local file="$1"
	local slug="$2"
	local warnings=0

	# Destructive shell commands
	if grep -qE '\b(rm\s+-rf|sudo\s|chmod\s+[0-7]*7[0-7]*)\b' "$file" 2>/dev/null; then
		printf '  %s⚠%s %s: contains potentially destructive shell commands (rm -rf / sudo / chmod 7xx)\n' "$YELLOW" "$RESET_COLOUR" "$slug" >&2
		warnings=$((warnings + 1))
	fi

	# Network calls to non-GitHub hosts in script blocks
	if grep -qE '^\s*(curl|wget|fetch)\s+.*https?://(?!raw\.githubusercontent\.com|api\.github\.com)' "$file" 2>/dev/null; then
		printf '  %s⚠%s %s: contains network calls to external hosts\n' "$YELLOW" "$RESET_COLOUR" "$slug" >&2
		warnings=$((warnings + 1))
	fi

	# Secret/credential exfiltration patterns
	if grep -qiE '(AWS_SECRET|api_key|GITHUB_TOKEN|password|private_key)\s*=' "$file" 2>/dev/null; then
		printf '  %s⚠%s %s: references credential-like variable names\n' "$YELLOW" "$RESET_COLOUR" "$slug" >&2
		warnings=$((warnings + 1))
	fi

	if [ "$warnings" -gt 0 ]; then
		printf '  Review %s before use.\n' "$file" >&2
	fi
}

sync_skill() {
	local slug="$1"
	local name="$2"
	local source="$3"
	local skill_url="$4"
	local references_api_url="$5"
	local commit_api_url="$6"
	local license="$7"
	local target_dir="$REPO_DIR/skills/$slug"
	local skill_file="$target_dir/SKILL.md"
	local sync_file="$target_dir/SYNC.md"
	local temp_file
	local references_file
	local references_count="0"
	local total_references="0"
	local upstream_sha="unresolved"
	local current_sha=""
	local synced_at

	echo ""
	printf '→ Syncing external skill %s%s%s\n' "$PURPLE" "$slug" "$RESET_COLOUR"
	echo ""

	if [ -n "$commit_api_url" ]; then
		printf '  Resolving upstream revision\n'
		upstream_sha=$(curl -fsSL "$commit_api_url" | jq -r '.sha // "unresolved"' 2>/dev/null || printf 'unresolved')
	fi

	if [ -f "$sync_file" ]; then
		current_sha=$(awk -F'|' '/Upstream SHA/ { gsub(/^[ \t]+|[ \t]+$/, "", $3); print $3; exit }' "$sync_file")
	fi

	if [ "$upstream_sha" != "unresolved" ] && [ "$current_sha" = "$upstream_sha" ] && [ -f "$skill_file" ]; then
		printf '  %s↪%s already up to date (%s)\n' "$PURPLE" "$RESET_COLOUR" "$upstream_sha"
		echo ""
		return
	fi

	temp_file=$(mktemp)
	printf '  Fetching SKILL.md\n'
	curl -fsSL "$skill_url" -o "$temp_file"

	vet_skill_file "$temp_file" "$slug"

	synced_at=$(date -u '+%Y-%m-%dT%H:%M:%SZ')

	mkdir -p "$target_dir"
	cp "$temp_file" "$skill_file"

	if [ -n "$references_api_url" ]; then
		references_file=$(mktemp)
		printf '  Fetching reference index\n'
		curl -fsSL "$references_api_url" -o "$references_file"
		mkdir -p "$target_dir/references"

		total_references=$(jq '[.[] | select(.type == "file")] | length' "$references_file")
		printf '  Fetching %s reference files\n' "$total_references"

		while IFS=$'\t' read -r reference_name reference_url; do
			curl -fsSL "$reference_url" -o "$target_dir/references/$reference_name"
			references_count=$((references_count + 1))
		done < <(jq -r '.[] | select(.type == "file") | [.name, .download_url] | @tsv' "$references_file")

		rm "$references_file"
	fi

	cat > "$sync_file" <<EOF
# ${name}

Managed by \`scripts/sync-external-skills.sh\`. Do not edit \`SKILL.md\` directly.

| Field | Value |
|-------|-------|
| Source | ${source} |
| Skill URL | ${skill_url} |
| References URL | ${references_api_url:-none} |
| References synced | ${references_count} |
| Upstream SHA | ${upstream_sha} |
| Licence | ${license} |
| Synced at | ${synced_at} |
EOF

	rm "$temp_file"
	printf '%s✓%s synced external skill %s%s%s\n' "$GREEN" "$RESET_COLOUR" "$PURPLE" "$slug" "$RESET_COLOUR"
	echo ""
}

count=$(jq 'length' "$MANIFEST")

for index in $(seq 0 $((count - 1))); do
	slug=$(jq -r ".[$index].slug" "$MANIFEST")
	name=$(jq -r ".[$index].name" "$MANIFEST")
	source=$(jq -r ".[$index].source" "$MANIFEST")
	skill_url=$(jq -r ".[$index].skill_url" "$MANIFEST")
	references_api_url=$(jq -r ".[$index].references_api_url // \"\"" "$MANIFEST")
	commit_api_url=$(jq -r ".[$index].commit_api_url // \"\"" "$MANIFEST")
	license=$(jq -r ".[$index].license // \"unknown\"" "$MANIFEST")

	sync_skill "$slug" "$name" "$source" "$skill_url" "$references_api_url" "$commit_api_url" "$license"
done
