#!/bin/zsh
set -euo pipefail

project_root="$(cd "$(dirname "$0")/.." && pwd)"
port="${CAR_FIGHT_PORT:-10080}"
log_file="${TMPDIR:-/tmp}/car-fight-local-server.log"
server_pid=""

cleanup() {
	if [[ -n "$server_pid" ]]; then
		kill "$server_pid" >/dev/null 2>&1 || true
	fi
}
trap cleanup EXIT INT TERM

"$project_root/scripts/serve.sh" "$port" >"$log_file" 2>&1 &
server_pid=$!
sleep 0.8
echo "server log: $log_file"
"$project_root/scripts/join.sh" 127.0.0.1 "$port" "local"

