#!/bin/zsh
set -euo pipefail

project_root="$(cd "$(dirname "$0")/.." && pwd)"
exec "$project_root/scripts/play_monitored.sh" --host "${CAR_FIGHT_HOST:-100.113.2.60}" \
	--name "${CAR_FIGHT_NAME:-driver}"
