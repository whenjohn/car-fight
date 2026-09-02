#!/bin/zsh
set -euo pipefail

project_root="$(cd "$(dirname "$0")/.." && pwd)"
godot_bin="${GODOT_BIN:-/Applications/Godot47.app/Contents/MacOS/Godot}"
output_dir="${CAR_FIGHT_WEB_OUTPUT:-$project_root/build/web}"
preset="${CAR_FIGHT_WEB_PRESET:-Web Offline}"
mode="${1:-debug}"

if [[ "$mode" != "debug" && "$mode" != "release" ]]; then
	echo "usage: $0 [debug|release]" >&2
	exit 2
fi
if [[ ! -x "$godot_bin" ]]; then
	echo "Godot not found: $godot_bin" >&2
	exit 2
fi

mkdir -p "$output_dir"
export_log="$(mktemp "${TMPDIR:-/tmp}/car-fight-web-export.XXXXXX")"

CAR_FIGHT_IMPORT_QUIET=1 "$project_root/scripts/godot_import_check.sh"

export_flag="--export-debug"
if [[ "$mode" == "release" ]]; then
	export_flag="--export-release"
fi
"$godot_bin" --headless --path "$project_root" "$export_flag" \
	"$preset" "$output_dir/index.html" >"$export_log" 2>&1 || {
		echo "Web export failed: $export_log" >&2
		tail -120 "$export_log" >&2
		exit 1
	}

for required in index.html index.js index.wasm index.side.wasm index.pck godot_rapier.wasm; do
	if [[ ! -f "$output_dir/$required" ]]; then
		echo "Web export omitted $required; export log: $export_log" >&2
		exit 1
	fi
done
echo "WEB_BUILD PASS mode=$mode preset=$preset output=$output_dir"
echo "export log: $export_log"
