#!/bin/zsh
set -euo pipefail

project_root="$(cd "$(dirname "$0")/.." && pwd)"
godot_bin="${GODOT_BIN:-/Applications/Godot47.app/Contents/MacOS/Godot}"
log_dir="$(mktemp -d "${TMPDIR:-/tmp}/car-fight-fast-check.XXXXXX")"

cleanup() {
	rm -rf "$log_dir"
}
trap cleanup EXIT INT TERM

if [[ ! -x "$godot_bin" ]]; then
	echo "Godot not found: $godot_bin" >&2
	exit 2
fi

# A fresh netfox checkout registers plugin globals during its first editor
# pass. Godot can return zero while that pass still prints transient parse
# errors, so only a clean second pass proves the imported project is ready.
for pass in first verify; do
	log_file="$log_dir/import-$pass.log"
	if ! "$godot_bin" --headless --path "$project_root" --editor --quit \
			>"$log_file" 2>&1; then
		echo "Godot $pass import failed: $log_file" >&2
		tail -120 "$log_file" >&2
		exit 1
	fi
done

parse_pattern='SCRIPT ERROR|Parse Error|Compile Error|ERROR: Failed to load script'
if rg -q "$parse_pattern" "$log_dir/import-verify.log"; then
	echo "Godot verification import reported script errors:" >&2
	rg "$parse_pattern" "$log_dir/import-verify.log" >&2
	exit 1
fi

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
echo "FAST_CHECK PASS import=2 shell=ok node=ok uid=ok diff=ok"
