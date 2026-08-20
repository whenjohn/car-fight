#!/bin/zsh
set -euo pipefail

project_root="$(cd "$(dirname "$0")/.." && pwd)"
godot_bin="${GODOT_BIN:-/Applications/Godot47.app/Contents/MacOS/Godot}"
port="${1:-10080}"
transport="${CAR_FIGHT_TRANSPORT:-mux}"
signal_port="${CAR_FIGHT_SIGNAL_PORT:-10181}"

exec "$godot_bin" --headless --path "$project_root" -- --server \
	--transport "$transport" --port "$port" --signal-port "$signal_port"
