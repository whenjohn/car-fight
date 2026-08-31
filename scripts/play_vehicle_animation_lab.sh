#!/bin/zsh
set -euo pipefail

project_root="$(cd "$(dirname "$0")/.." && pwd)"
godot_bin="${GODOT_BIN:-/Applications/Godot.app/Contents/MacOS/Godot}"

if [[ ! -x "$godot_bin" ]]; then
	echo "Godot not found: $godot_bin" >&2
	exit 2
fi

exec "$godot_bin" --path "$project_root" --windowed \
	--resolution 1100x720 res://tools/VehicleAnimationLab.tscn

