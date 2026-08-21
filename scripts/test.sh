#!/bin/zsh
set -euo pipefail

project_root="$(cd "$(dirname "$0")/.." && pwd)"
godot_bin="${GODOT_BIN:-/Applications/Godot47.app/Contents/MacOS/Godot}"
parse_log="$(mktemp "${TMPDIR:-/tmp}/car-fight-parse.XXXXXX")"

"$godot_bin" --headless --path "$project_root" --editor --quit >"$parse_log" 2>&1
if rg -q 'SCRIPT ERROR|Parse Error|Compile Error|ERROR: Failed to load script' "$parse_log"; then
	cat "$parse_log" >&2
	exit 1
fi
"$godot_bin" --headless --path "$project_root" --script res://tests/follow_controller_test.gd
"$godot_bin" --headless --path "$project_root" --script res://tests/tractor_controller_test.gd
"$godot_bin" --headless --path "$project_root" --script res://tests/impact_controller_test.gd
"$godot_bin" --headless --path "$project_root" --script res://tests/asset_smoke_test.gd
"$godot_bin" --headless --path "$project_root" --script res://tests/boost_afterimage_test.gd
"$godot_bin" --headless --path "$project_root" --script res://tests/coverage_config_test.gd
"$godot_bin" --headless --path "$project_root" --script res://tests/area_weapon_test.gd
"$godot_bin" --headless --path "$project_root" --script res://tests/homing_missile_test.gd
"$godot_bin" --headless --path "$project_root" --script res://tests/arena_layout_test.gd
"$godot_bin" --headless --path "$project_root" --script res://tests/driving_course_test.gd
"$godot_bin" --headless --path "$project_root" --script res://tests/crash_telemetry_test.gd
"$godot_bin" --headless --path "$project_root" --script res://tests/window_safety_policy_test.gd
"$godot_bin" --headless --path "$project_root" --script res://tests/arena_ball_test.gd
"$godot_bin" --headless --path "$project_root" --script res://tests/dots_test.gd
"$godot_bin" --headless --path "$project_root" --script res://tests/troop_delivery_test.gd
"$godot_bin" --headless --path "$project_root" --script res://tests/elevated_course_test.gd
"$project_root/scripts/offline_test.sh"
"$project_root/scripts/network_test.sh"
"$project_root/scripts/mixed_transport_test.sh"
"$project_root/scripts/join_transient_test.sh"
"$project_root/scripts/reconnect_test.sh"
"$project_root/scripts/ball_test.sh"
"$project_root/scripts/tractor_test.sh"
"$project_root/scripts/course_test.sh"
"$project_root/scripts/reverse_test.sh"
"$project_root/scripts/gate_test.sh"
"$project_root/scripts/combat_test.sh"
"$project_root/scripts/rc_orb_test.sh"
"$project_root/scripts/shield_test.sh"
"$project_root/scripts/det_test.sh"
git -C "$project_root" diff --check
echo "ALL_TESTS PASS"
