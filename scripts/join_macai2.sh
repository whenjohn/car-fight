#!/bin/zsh
set -euo pipefail

project_root="$(cd "$(dirname "$0")/.." && pwd)"
exec "$project_root/scripts/join.sh" "${CAR_FIGHT_HOST:-100.113.2.60}" 10080 "${1:-driver}"
