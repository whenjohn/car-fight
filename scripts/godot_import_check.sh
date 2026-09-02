#!/bin/zsh
set -euo pipefail

project_root="$(cd "$(dirname "$0")/.." && pwd)"
godot_bin="${GODOT_BIN:-/Applications/Godot47.app/Contents/MacOS/Godot}"
log_dir="$(mktemp -d "${TMPDIR:-/tmp}/car-fight-import-check.XXXXXX")"
parse_pattern='SCRIPT ERROR|Parse Error|Compile Error|ERROR: Failed to load script'

if [[ ! -x "$godot_bin" ]]; then
	echo "Godot not found: $godot_bin" >&2
	exit 2
fi

for pass in first verify; do
	log_file="$log_dir/import-$pass.log"
	if ! "$godot_bin" --headless --path "$project_root" --editor --quit \
			>"$log_file" 2>&1; then
		echo "Godot $pass import failed; logs retained at $log_dir" >&2
		tail -120 "$log_file" >&2
		exit 1
	fi
done

# A fresh netfox checkout can register plugin globals during the first pass.
# Godot may also return zero while printing parse errors, so only the second
# pass is the acceptance signal.
if /usr/bin/grep -Eq "$parse_pattern" "$log_dir/import-verify.log"; then
	echo "Godot verification import reported script errors; logs retained at $log_dir" >&2
	/usr/bin/grep -E "$parse_pattern" "$log_dir/import-verify.log" >&2
	exit 1
fi

rm -rf "$log_dir"
if [[ "${CAR_FIGHT_IMPORT_QUIET:-0}" != "1" ]]; then
	echo "GODOT_IMPORT_CHECK PASS passes=2"
fi
