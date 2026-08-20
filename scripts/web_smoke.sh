#!/bin/zsh
set -euo pipefail
unsetopt BG_NICE

project_root="$(cd "$(dirname "$0")/.." && pwd)"
port="${CAR_FIGHT_WEB_PORT:-8088}"
build_mode="${CAR_FIGHT_WEB_BUILD_MODE:-release}"
server_log="$(mktemp "${TMPDIR:-/tmp}/car-fight-web-server.XXXXXX")"
server_pid=""

cleanup() {
	if [[ -n "$server_pid" ]]; then
		kill "$server_pid" >/dev/null 2>&1 || true
		wait "$server_pid" 2>/dev/null || true
	fi
}
trap cleanup EXIT INT TERM

"$project_root/scripts/web_build.sh" "$build_mode"
CAR_FIGHT_WEB_PORT="$port" "$project_root/scripts/web_serve.sh" \
	>"$server_log" 2>&1 &
server_pid=$!

server_ready=0
for _attempt in {1..100}; do
	if curl -fs -o /dev/null "http://127.0.0.1:$port/"; then
		server_ready=1
		break
	fi
	if ! kill -0 "$server_pid" >/dev/null 2>&1; then
		echo "Web server exited early: $server_log" >&2
		cat "$server_log" >&2
		exit 1
	fi
	sleep 0.05
done
if (( server_ready == 0 )); then
	echo "Web server did not become ready: $server_log" >&2
	cat "$server_log" >&2
	exit 1
fi

node "$project_root/scripts/web_smoke.mjs" "http://127.0.0.1:$port/" \
	"$project_root/build/web-smoke-report.json" \
	"$project_root/build/web-smoke.png"
