#!/bin/zsh
set -euo pipefail

project_root="$(cd "$(dirname "$0")/.." && pwd)"
godot_bin="${GODOT_BIN:-/Applications/Godot47.app/Contents/MacOS/Godot}"
host="${1:-${CAR_FIGHT_HOST:-100.113.2.60}}"
port="${2:-10080}"
player_name="${3:-driver}"
session_label="${CAR_FIGHT_SESSION_LABEL:-$(git -C "$project_root" branch --show-current)}"

exec "$godot_bin" --path "$project_root" -- --client --host "$host" --port "$port" --name "$player_name" --session-label "$session_label"
