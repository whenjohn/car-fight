#!/bin/zsh
set -euo pipefail

project_root="$(cd "$(dirname "$0")/.." && pwd)"
export CAR_FIGHT_PROJECT_ROOT="$project_root"
export GODOT_BIN="/Applications/Godot.app/Contents/MacOS/Godot"
export CAR_FIGHT_RENDERING_DRIVER=vulkan
export CAR_FIGHT_LIGHTING_STYLE=4
export CAR_FIGHT_START_MAP=city
exec "$project_root/scripts/play_monitored.sh" --offline \
	--name "${CAR_FIGHT_NAME:-forwardplus-46}"
