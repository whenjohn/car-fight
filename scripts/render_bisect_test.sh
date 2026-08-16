#!/bin/zsh
set -euo pipefail

project_root="$(cd "$(dirname "$0")/.." && pwd)"
control_root="$project_root/render_bisect"
runner="$project_root/scripts/render_bisect.sh"
godot_bin="${GODOT_BIN:-/Applications/Godot47.app/Contents/MacOS/Godot}"
test_dir="$(mktemp -d "${TMPDIR:-/tmp}/car-fight-render-control.XXXXXX")"
trap 'rm -rf "$test_dir"' EXIT

if rg -n -i 'g2|netfox|res://assets|res://player' "$control_root"; then
	echo "RENDER_BISECT_TEST FAIL forbidden dependency in clean project" >&2
	exit 1
fi
for section in '[autoload]' '[input]' '[display]'; do
	if rg -n -F "$section" "$control_root/project.godot"; then
		echo "RENDER_BISECT_TEST FAIL forbidden project section: $section" >&2
		exit 1
	fi
done
if rg -n 'ext_resource.*path="res://(?!Main\.gd)' "$control_root/Main.tscn" -P; then
	echo "RENDER_BISECT_TEST FAIL non-control resource referenced" >&2
	exit 1
fi
if [[ -L "$control_root/CarFightJeep.fbx" \
		|| ! -f "$control_root/CarFightJeep.fbx" ]]; then
	echo "RENDER_BISECT_TEST FAIL Stage 1 Jeep must be a regular file" >&2
	exit 1
fi
if ! cmp -s "$control_root/CarFightJeep.fbx" \
		"$project_root/assets/ground_vehicle/Jeep.fbx"; then
	echo "RENDER_BISECT_TEST FAIL Stage 1 Jeep must match the car-fight source bytes" >&2
	exit 1
fi

"$godot_bin" --headless --path "$control_root" --editor --quit \
	> "$test_dir/import-preflight.log" 2>&1
if rg -q 'SCRIPT ERROR|Parse Error|Compile Error|ERROR: Failed to load script|Import failed' \
		"$test_dir/import-preflight.log"; then
	cat "$test_dir/import-preflight.log" >&2
	exit 1
fi

CAR_FIGHT_BISECT_TELEMETRY="$test_dir/telemetry.jsonl" \
	CAR_FIGHT_BISECT_AUTO_QUIT_SECONDS=2 \
	"$godot_bin" --headless --path "$control_root" \
		> "$test_dir/godot.log" 2>&1
if rg -q 'SCRIPT ERROR|Parse Error|Compile Error|ERROR: Failed to load script' \
		"$test_dir/godot.log"; then
	cat "$test_dir/godot.log" >&2
	exit 1
fi
for event in stage0_start stage0_sample stage0_stop; do
	if ! rg -q "\"event\":\"$event\"" "$test_dir/telemetry.jsonl"; then
		echo "RENDER_BISECT_TEST FAIL missing telemetry event: $event" >&2
		exit 1
	fi
done

CAR_FIGHT_BISECT_STAGE=stage1-jeep \
	CAR_FIGHT_BISECT_TELEMETRY="$test_dir/stage1-telemetry.jsonl" \
	CAR_FIGHT_BISECT_AUTO_QUIT_SECONDS=2 \
	"$godot_bin" --headless --path "$control_root" \
		> "$test_dir/stage1-godot.log" 2>&1
if rg -q 'SCRIPT ERROR|Parse Error|Compile Error|ERROR: Failed to load script|Stage 1 could not' \
		"$test_dir/stage1-godot.log"; then
	cat "$test_dir/stage1-godot.log" >&2
	exit 1
fi
for event in stage1_start stage1_sample stage1_stop; do
	if ! rg -q "\"event\":\"$event\"" "$test_dir/stage1-telemetry.jsonl"; then
		echo "RENDER_BISECT_TEST FAIL missing Stage 1 telemetry event: $event" >&2
		exit 1
	fi
done
for expected in '"jeep_mesh_instances":1' '"jeep_shadows":false' \
		'"jeep_material_mode":"embedded"' '"jeep_material_override":false' \
		'"jeep_geometry_mode":"source_surfaces"' '"jeep_surfaces":8' \
		'"stage":"stage1-jeep"'; do
	if ! rg -q -F "$expected" "$test_dir/stage1-telemetry.jsonl"; then
		echo "RENDER_BISECT_TEST FAIL Stage 1 telemetry missing: $expected" >&2
		exit 1
	fi
done

CAR_FIGHT_BISECT_STAGE=stage1-jeep-flat \
	CAR_FIGHT_BISECT_TELEMETRY="$test_dir/stage1-flat-telemetry.jsonl" \
	CAR_FIGHT_BISECT_AUTO_QUIT_SECONDS=2 \
	"$godot_bin" --headless --path "$control_root" \
		> "$test_dir/stage1-flat-godot.log" 2>&1
if rg -q 'SCRIPT ERROR|Parse Error|Compile Error|ERROR: Failed to load script|Stage 1 could not' \
		"$test_dir/stage1-flat-godot.log"; then
	cat "$test_dir/stage1-flat-godot.log" >&2
	exit 1
fi
for event in stage1flat_start stage1flat_sample stage1flat_stop; do
	if ! rg -q "\"event\":\"$event\"" "$test_dir/stage1-flat-telemetry.jsonl"; then
		echo "RENDER_BISECT_TEST FAIL missing flat Jeep telemetry event: $event" >&2
		exit 1
	fi
done
for expected in '"jeep_mesh_instances":1' '"jeep_shadows":false' \
		'"jeep_material_mode":"flat_override"' '"jeep_material_override":true' \
		'"jeep_geometry_mode":"source_surfaces"' '"jeep_surfaces":8' \
		'"stage":"stage1-jeep-flat"'; do
	if ! rg -q -F "$expected" "$test_dir/stage1-flat-telemetry.jsonl"; then
		echo "RENDER_BISECT_TEST FAIL flat Jeep telemetry missing: $expected" >&2
		exit 1
	fi
done

CAR_FIGHT_BISECT_STAGE=stage1-jeep-one-surface \
	CAR_FIGHT_BISECT_TELEMETRY="$test_dir/stage1-one-telemetry.jsonl" \
	CAR_FIGHT_BISECT_AUTO_QUIT_SECONDS=2 \
	"$godot_bin" --headless --path "$control_root" \
		> "$test_dir/stage1-one-godot.log" 2>&1
if rg -q 'SCRIPT ERROR|Parse Error|Compile Error|ERROR: Failed to load script|Stage 1 could not|One-surface Jeep' \
		"$test_dir/stage1-one-godot.log"; then
	cat "$test_dir/stage1-one-godot.log" >&2
	exit 1
fi
for event in stage1one_start stage1one_sample stage1one_stop; do
	if ! rg -q "\"event\":\"$event\"" "$test_dir/stage1-one-telemetry.jsonl"; then
		echo "RENDER_BISECT_TEST FAIL missing one-surface Jeep event: $event" >&2
		exit 1
	fi
done
for expected in '"jeep_mesh_instances":1' '"jeep_shadows":false' \
		'"jeep_material_mode":"flat_override"' '"jeep_material_override":true' \
		'"jeep_geometry_mode":"one_surface"' '"jeep_geometry_counts_preserved":true' \
		'"jeep_source_surfaces":8' '"jeep_surfaces":1' \
		'"jeep_source_vertices":1323' '"jeep_vertices":1323' \
		'"jeep_source_indices":2118' '"jeep_indices":2118' \
		'"stage":"stage1-jeep-one-surface"'; do
	if ! rg -q -F "$expected" "$test_dir/stage1-one-telemetry.jsonl"; then
		echo "RENDER_BISECT_TEST FAIL one-surface Jeep telemetry missing: $expected" >&2
		exit 1
	fi
done

dry_output="$($runner run stage0-control --dry-run --seconds 12)"
for expected in '--rendering-driver opengl3' '--windowed' \
		"--path $control_root" 'fullscreen_entry=manual' \
		'post_fullscreen_watch_seconds=360'; do
	if [[ "$dry_output" != *"$expected"* ]]; then
		echo "RENDER_BISECT_TEST FAIL dry run missing: $expected" >&2
		exit 1
	fi
done
stage1_output="$($runner run stage1-jeep --dry-run --seconds 12)"
if [[ "$stage1_output" != *'stage=stage1-jeep'* \
		|| "$stage1_output" != *'--windowed'* \
		|| "$stage1_output" != *'asset_import_preflight=headless'* ]]; then
	echo "RENDER_BISECT_TEST FAIL incomplete Stage 1 dry run" >&2
	exit 1
fi
stage1_flat_output="$($runner run stage1-jeep-flat --dry-run --seconds 12)"
if [[ "$stage1_flat_output" != *'stage=stage1-jeep-flat'* \
		|| "$stage1_flat_output" != *'--windowed'* \
		|| "$stage1_flat_output" != *'asset_import_preflight=headless'* ]]; then
	echo "RENDER_BISECT_TEST FAIL incomplete flat Jeep dry run" >&2
	exit 1
fi
stage1_one_output="$($runner run stage1-jeep-one-surface --dry-run --seconds 12)"
if [[ "$stage1_one_output" != *'stage=stage1-jeep-one-surface'* \
		|| "$stage1_one_output" != *'--windowed'* \
		|| "$stage1_one_output" != *'asset_import_preflight=headless'* ]]; then
	echo "RENDER_BISECT_TEST FAIL incomplete one-surface Jeep dry run" >&2
	exit 1
fi
fullscreen_output="$($runner run stage0-control --dry-run --startup-fullscreen --seconds 12)"
for expected in '--fullscreen' 'fullscreen_entry=startup'; do
	if [[ "$fullscreen_output" != *"$expected"* ]]; then
		echo "RENDER_BISECT_TEST FAIL startup fullscreen missing: $expected" >&2
		exit 1
	fi
done
if [[ "$fullscreen_output" == *'--windowed'* ]]; then
	echo "RENDER_BISECT_TEST FAIL startup fullscreen remained windowed" >&2
	exit 1
fi
if "$runner" run stage0-control --seconds 12 >/dev/null 2>&1; then
	echo "RENDER_BISECT_TEST FAIL risk acknowledgement was optional" >&2
	exit 1
fi
if rg -q 'EPOCHSECONDS' "$runner"; then
	echo "RENDER_BISECT_TEST FAIL launcher uses unavailable zsh clock" >&2
	exit 1
fi
for required_state in display-precursor not-fullscreen; do
	if ! rg -q "state=\"$required_state\"" "$runner"; then
		echo "RENDER_BISECT_TEST FAIL missing state: $required_state" >&2
		exit 1
	fi
done

echo "RENDER_BISECT_TEST PASS clean_project=1 rendered=0"
