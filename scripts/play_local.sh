#!/bin/zsh
set -euo pipefail

project_root="$(cd "$(dirname "$0")/.." && pwd)"
exec "$project_root/scripts/play_monitored.sh" --local --name "${CAR_FIGHT_NAME:-local}"
