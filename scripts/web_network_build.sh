#!/bin/zsh
set -euo pipefail

project_root="$(cd "$(dirname "$0")/.." && pwd)"
CAR_FIGHT_WEB_PRESET="Web Network" \
	CAR_FIGHT_WEB_OUTPUT="${CAR_FIGHT_WEB_OUTPUT:-$project_root/build/web-network}" \
	"$project_root/scripts/web_build.sh" "${1:-release}"
