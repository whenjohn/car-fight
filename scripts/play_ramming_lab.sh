#!/bin/zsh
set -euo pipefail

project_root="$(cd "$(dirname "$0")/.." && pwd)"
export CAR_FIGHT_RAMMING_LAB=1
export CAR_FIGHT_HIDE_HOTKEY_HINTS="${CAR_FIGHT_HIDE_HOTKEY_HINTS:-1}"
exec "$project_root/scripts/play_monitored.sh" --local "$@"
