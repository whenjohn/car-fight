#!/bin/zsh
set -euo pipefail

project_root="$(cd "$(dirname "$0")/.." && pwd)"
output_dir="${CAR_FIGHT_WEB_OUTPUT:-$project_root/build/web}"
port="${CAR_FIGHT_WEB_PORT:-8088}"

if [[ ! -f "$output_dir/index.html" ]]; then
	echo "Web build missing; run ./scripts/web_build.sh first" >&2
	exit 1
fi
exec python3 "$project_root/scripts/web_serve.py" "$port" "$output_dir"
