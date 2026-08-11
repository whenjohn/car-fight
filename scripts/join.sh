#!/bin/zsh
set -euo pipefail

project_root="$(cd "$(dirname "$0")/.." && pwd)"
godot_bin="${GODOT_BIN:-/Applications/Godot47.app/Contents/MacOS/Godot}"
host="${1:-127.0.0.1}"
port="${2:-10080}"
player_name="${3:-driver}"

exec "$godot_bin" --path "$project_root" -- --client --host "$host" --port "$port" --name "$player_name"

