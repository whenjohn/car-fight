#!/bin/zsh
set -euo pipefail

project_root="$(cd "$(dirname "$0")/.." && pwd)"
godot_bin="${GODOT_BIN:-/Applications/Godot47.app/Contents/MacOS/Godot}"
port="${1:-10080}"

exec "$godot_bin" --headless --path "$project_root" -- --server --port "$port"

