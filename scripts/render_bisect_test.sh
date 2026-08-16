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
if [[ -L "$control_root/Pickup.fbx" || ! -f "$control_root/Pickup.fbx" ]]; then
	echo "RENDER_BISECT_TEST FAIL Pickup must be a regular file" >&2
	exit 1
fi
pickup_hash="$(shasum -a 256 "$control_root/Pickup.fbx" | awk '{print $1}')"
if [[ "$pickup_hash" != "21eba6952659dc20916e28aacf8cac98150a7f617a58f4e1acc5b7be56fc4550" ]]; then
	echo "RENDER_BISECT_TEST FAIL Pickup must match the official CC0 source" >&2
	exit 1
fi
if [[ -L "$control_root/garbage-truck.glb" \
		|| ! -f "$control_root/garbage-truck.glb" ]]; then
	echo "RENDER_BISECT_TEST FAIL Kenney Garbage Truck must be a regular file" >&2
	exit 1
fi
garbage_truck_hash="$(shasum -a 256 "$control_root/garbage-truck.glb" | awk '{print $1}')"
if [[ "$garbage_truck_hash" != "6f2943e0ba4c6d86eb69a9243224259d6e0f169f474228439cda0579d49d3509" ]]; then
	echo "RENDER_BISECT_TEST FAIL Garbage Truck must match the Kenney CC0 source" >&2
	exit 1
fi
garbage_texture_hash="$(shasum -a 256 "$control_root/Textures/colormap.png" | awk '{print $1}')"
if [[ "$garbage_texture_hash" != "f3622a03a20c6696065cae9cbe391351be873508af190c2ebd1d420c055787a5" ]]; then
	echo "RENDER_BISECT_TEST FAIL Kenney texture must match the CC0 source" >&2
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
		'"jeep_mesh_data_valid":true' '"jeep_invalid_attribute_values":0' \
		'"jeep_invalid_indices":0' \
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
		'"jeep_mesh_data_valid":true' '"jeep_invalid_attribute_values":0' \
		'"jeep_invalid_indices":0' \
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
		'"jeep_mesh_data_valid":true' '"jeep_invalid_attribute_values":0' \
		'"jeep_invalid_indices":0' \
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

CAR_FIGHT_BISECT_STAGE=stage1-pickup-one-surface \
	CAR_FIGHT_BISECT_TELEMETRY="$test_dir/stage1-pickup-telemetry.jsonl" \
	CAR_FIGHT_BISECT_AUTO_QUIT_SECONDS=2 \
	"$godot_bin" --headless --path "$control_root" \
		> "$test_dir/stage1-pickup-godot.log" 2>&1
if rg -q 'SCRIPT ERROR|Parse Error|Compile Error|ERROR: Failed to load script|Stage 1 could not|One-surface' \
		"$test_dir/stage1-pickup-godot.log"; then
	cat "$test_dir/stage1-pickup-godot.log" >&2
	exit 1
fi
for event in stage1pickup_start stage1pickup_sample stage1pickup_stop; do
	if ! rg -q "\"event\":\"$event\"" "$test_dir/stage1-pickup-telemetry.jsonl"; then
		echo "RENDER_BISECT_TEST FAIL missing Pickup event: $event" >&2
		exit 1
	fi
done
for expected in '"vehicle_model":"Pickup"' '"pickup_mesh_instances":1' \
		'"pickup_shadows":false' '"pickup_material_mode":"flat_override"' \
		'"pickup_material_override":true' '"pickup_geometry_mode":"one_surface"' \
		'"pickup_geometry_counts_preserved":true' '"pickup_mesh_data_valid":true' \
		'"pickup_invalid_attribute_values":0' '"pickup_invalid_indices":0' \
		'"pickup_source_surfaces":7' '"pickup_surfaces":1' \
		'"pickup_source_vertices":1038' '"pickup_vertices":1038' \
		'"pickup_source_indices":1680' '"pickup_indices":1680' \
		'"stage":"stage1-pickup-one-surface"'; do
	if ! rg -q -F "$expected" "$test_dir/stage1-pickup-telemetry.jsonl"; then
		echo "RENDER_BISECT_TEST FAIL Pickup telemetry missing: $expected" >&2
		exit 1
	fi
done

CAR_FIGHT_BISECT_STAGE=stage1-kenney-garbage-truck-one-surface \
	CAR_FIGHT_BISECT_TELEMETRY="$test_dir/stage1-garbage-truck-telemetry.jsonl" \
	CAR_FIGHT_BISECT_AUTO_QUIT_SECONDS=2 \
	"$godot_bin" --headless --path "$control_root" \
		> "$test_dir/stage1-garbage-truck-godot.log" 2>&1
if rg -q 'SCRIPT ERROR|Parse Error|Compile Error|ERROR: Failed to load script|Stage 1 could not|One-surface' \
		"$test_dir/stage1-garbage-truck-godot.log"; then
	cat "$test_dir/stage1-garbage-truck-godot.log" >&2
	exit 1
fi
for event in stage1garbagetruck_start stage1garbagetruck_sample \
		stage1garbagetruck_stop; do
	if ! rg -q "\"event\":\"$event\"" \
			"$test_dir/stage1-garbage-truck-telemetry.jsonl"; then
		echo "RENDER_BISECT_TEST FAIL missing Garbage Truck event: $event" >&2
		exit 1
	fi
done
for expected in '"vehicle_model":"Kenney Garbage Truck"' \
		'"garbage_truck_mesh_instances":1' \
		'"garbage_truck_source_mesh_instances":7' \
		'"garbage_truck_shadows":false' \
		'"garbage_truck_material_mode":"flat_override"' \
		'"garbage_truck_material_override":true' \
		'"garbage_truck_geometry_mode":"one_surface"' \
		'"garbage_truck_geometry_counts_preserved":true' \
		'"garbage_truck_mesh_data_valid":true' \
		'"garbage_truck_invalid_attribute_values":0' \
		'"garbage_truck_invalid_indices":0' \
		'"garbage_truck_source_surfaces":7' '"garbage_truck_surfaces":1' \
		'"garbage_truck_source_vertices":4912' '"garbage_truck_vertices":4912' \
		'"garbage_truck_source_indices":9372' '"garbage_truck_indices":9372' \
		'"stage":"stage1-kenney-garbage-truck-one-surface"'; do
	if ! rg -q -F "$expected" \
			"$test_dir/stage1-garbage-truck-telemetry.jsonl"; then
		echo "RENDER_BISECT_TEST FAIL Garbage Truck telemetry missing: $expected" >&2
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
stage1_pickup_output="$($runner run stage1-pickup-one-surface --dry-run --seconds 12)"
if [[ "$stage1_pickup_output" != *'stage=stage1-pickup-one-surface'* \
		|| "$stage1_pickup_output" != *'--windowed'* \
		|| "$stage1_pickup_output" != *'asset_import_preflight=headless'* ]]; then
	echo "RENDER_BISECT_TEST FAIL incomplete Pickup dry run" >&2
	exit 1
fi
stage1_garbage_truck_output="$($runner run \
	stage1-kenney-garbage-truck-one-surface --dry-run --seconds 12)"
if [[ "$stage1_garbage_truck_output" != \
		*'stage=stage1-kenney-garbage-truck-one-surface'* \
		|| "$stage1_garbage_truck_output" != *'--windowed'* \
		|| "$stage1_garbage_truck_output" != *'asset_import_preflight=headless'* ]]; then
	echo "RENDER_BISECT_TEST FAIL incomplete Garbage Truck dry run" >&2
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
