#!/bin/zsh
set -euo pipefail

project_root="$(cd "$(dirname "$0")/.." && pwd)"
export CAR_FIGHT_PROJECT_ROOT="$project_root"
exec "$project_root/scripts/play_monitored.sh" --offline \
	--name "${CAR_FIGHT_NAME:-sunlit-aerial}"
