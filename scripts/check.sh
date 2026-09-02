#!/bin/zsh
set -euo pipefail

project_root="$(cd "$(dirname "$0")/.." && pwd)"
log_dir="$(mktemp -d "${TMPDIR:-/tmp}/car-fight-fast-check.XXXXXX")"

cleanup() {
	rm -rf "$log_dir"
}
trap cleanup EXIT INT TERM

CAR_FIGHT_IMPORT_QUIET=1 "$project_root/scripts/godot_import_check.sh"

for script in "$project_root"/scripts/*.sh; do
	syntax_log="$log_dir/zsh-syntax.log"
	if ! /bin/zsh -n "$script" >"$syntax_log" 2>&1; then
		echo "Shell syntax check failed: ${script#$project_root/}" >&2
		cat "$syntax_log" >&2
		exit 1
	fi
done

for script in "$project_root"/scripts/*.mjs; do
	syntax_log="$log_dir/node-syntax.log"
	if ! node --check "$script" >"$syntax_log" 2>&1; then
		echo "Node syntax check failed: ${script#$project_root/}" >&2
		cat "$syntax_log" >&2
		exit 1
	fi
done

CAR_FIGHT_MANIFEST_QUIET=1 "$project_root/scripts/test_manifest_check.sh"

orphan_uids=()
while IFS= read -r uid_file; do
	resource_file="${uid_file%.uid}"
	if [[ ! -e "$resource_file" ]]; then
		orphan_uids+=("${uid_file#$project_root/}")
	fi
done < <(find "$project_root" -type f -name '*.uid' \
	-not -path "$project_root/.git/*" -not -path "$project_root/.godot/*" | sort)

if (( ${#orphan_uids[@]} > 0 )); then
	echo "Orphan Godot UID sidecars:" >&2
	printf '  %s\n' "${orphan_uids[@]}" >&2
	exit 1
fi

git -C "$project_root" diff --check
git -C "$project_root" diff --cached --check
echo "FAST_CHECK PASS import=2 shell=ok node=ok tests=listed uid=ok diff=ok"
