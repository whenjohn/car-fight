#!/bin/zsh
set -euo pipefail

project_root="$(cd "$(dirname "$0")/.." && pwd)"
godot_bin="${GODOT_BIN:-/Applications/Godot47.app/Contents/MacOS/Godot}"
parse_log="$(mktemp "${TMPDIR:-/tmp}/car-fight-parse.XXXXXX.log")"

"$godot_bin" --headless --path "$project_root" --editor --quit >"$parse_log" 2>&1
if rg -q 'SCRIPT ERROR|Parse Error|Compile Error|ERROR: Failed to load script' "$parse_log"; then
	cat "$parse_log" >&2
	exit 1
fi
"$godot_bin" --headless --path "$project_root" --script res://tests/follow_controller_test.gd
"$godot_bin" --headless --path "$project_root" --script res://tests/asset_smoke_test.gd
"$project_root/scripts/network_test.sh"
git -C "$project_root" diff --check
echo "ALL_TESTS PASS"

