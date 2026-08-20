#!/bin/zsh
set -euo pipefail
unsetopt BG_NICE

project_root="$(cd "$(dirname "$0")/.." && pwd)"
godot_bin="${GODOT_BIN:-/Applications/Godot47.app/Contents/MacOS/Godot}"
web_port="${CAR_FIGHT_WEB_NETWORK_PORT:-18088}"
enet_port="${CAR_FIGHT_MUX_ENET_PORT:-12380}"
signal_port="${CAR_FIGHT_MUX_SIGNAL_PORT:-12381}"
log_dir="$(mktemp -d "${TMPDIR:-/tmp}/car-fight-web-network.XXXXXX")"
web_pid=""
server_pid=""
native_pid=""

cleanup() {
	for process_id in "$native_pid" "$server_pid" "$web_pid"; do
		if [[ "$process_id" == <-> ]] && (( process_id > 1 )); then
			kill "$process_id" >/dev/null 2>&1 || true
		fi
	done
	wait 2>/dev/null || true
}
trap cleanup EXIT INT TERM

"$project_root/scripts/web_network_build.sh" release
CAR_FIGHT_WEB_PORT="$web_port" CAR_FIGHT_WEB_OUTPUT="$project_root/build/web-network" \
	"$project_root/scripts/web_serve.sh" >"$log_dir/web-server.log" 2>&1 &
web_pid=$!
for _attempt in {1..100}; do
	if curl -fs -o /dev/null "http://127.0.0.1:$web_port/"; then
		break
	fi
	sleep 0.05
done
curl -fs -o /dev/null "http://127.0.0.1:$web_port/"

"$godot_bin" --headless --path "$project_root" -- --server --transport mux \
	--port "$enet_port" --signal-port "$signal_port" --no-drone \
	>"$log_dir/server.log" 2>&1 &
server_pid=$!
sleep 0.8
"$godot_bin" --headless --path "$project_root" -- --client --transport enet \
	--host 127.0.0.1 --port "$enet_port" --name native-survivor --script right \
	>"$log_dir/native.log" 2>&1 &
native_pid=$!
sleep 0.8

browser_url="http://127.0.0.1:$web_port/?signal=ws%3A%2F%2F127.0.0.1%3A$signal_port&name=browser&webrtcTelemetry=1"
node "$project_root/scripts/web_network_smoke.mjs" "$browser_url" \
	"$log_dir/browser-report.json" "$log_dir/browser.png" \
	| tee "$log_dir/browser.log"

sleep 1
first_two_line="$(rg -n 'CLIENT_TICK .*players=2 world=[^|]+\|[^ ]+' "$log_dir/native.log" \
	| head -1 | cut -d: -f1 || true)"
one_line="$(rg -n 'CLIENT_TICK .*players=1 world=[^| ]+ ' "$log_dir/native.log" \
	| cut -d: -f1 | awk -v after="${first_two_line:-0}" '$1 > after {print; exit}' || true)"
last_two_line="$(rg -n 'CLIENT_TICK .*players=2 world=[^|]+\|[^ ]+' "$log_dir/native.log" \
	| tail -1 | cut -d: -f1 || true)"
if [[ -z "$first_two_line" || -z "$one_line" || -z "$last_two_line" ]] \
		|| (( first_two_line >= one_line || one_line >= last_two_line )); then
	echo "Native ENet survivor did not observe shared-world leave/rejoin; logs: $log_dir" >&2
	exit 1
fi
if [[ "$(rg -c 'peer_connected id=.*transport=webrtc' "$log_dir/server.log" || true)" -lt 2 ]]; then
	echo "Mux server did not admit both browser generations; logs: $log_dir" >&2
	exit 1
fi
if rg -q 'SCRIPT ERROR|Parse Error|Invalid call|Invalid get index|Node not found|Failed to get path from RPC' \
		"$log_dir"/*.log; then
	echo "Mixed browser/native run emitted a runtime error; logs: $log_dir" >&2
	rg 'SCRIPT ERROR|Parse Error|Invalid call|Invalid get index|Node not found|Failed to get path from RPC' \
		"$log_dir"/*.log >&2
	exit 1
fi
stale_count="$(rg -c 'Skipping stale rollback origin' "$log_dir/server.log" || true)"
if (( stale_count > 4 )); then
	echo "Browser refresh produced a stale-history warning flood ($stale_count); logs: $log_dir" >&2
	exit 1
fi

echo "WEB_NETWORK_TEST PASS"
echo "logs: $log_dir"
