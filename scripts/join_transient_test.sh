#!/bin/zsh
# Deterministic positive control for the stale late-join rollback flood.
set -euo pipefail

project_root="$(cd "$(dirname "$0")/.." && pwd)"
godot_bin="${GODOT_BIN:-/Applications/Godot.app/Contents/MacOS/Godot}"
server_port="${CAR_FIGHT_JOIN_TEST_PORT:-10980}"
proxy_port=$((server_port + 1))
log_dir="$(mktemp -d "${TMPDIR:-/tmp}/car-fight-join-transient.XXXXXX")"
server_pid=""
proxy_pid=""
client_pid=""

cleanup() {
	for process_id in "$client_pid" "$proxy_pid" "$server_pid"; do
		if [[ -n "$process_id" ]]; then
			kill "$process_id" >/dev/null 2>&1 || true
		fi
	done
}
trap cleanup EXIT INT TERM

"$godot_bin" --headless --path "$project_root" -- \
	--server --no-drone --port "$server_port" --ticks 900 \
	>"$log_dir/server.log" 2>&1 &
server_pid=$!
sleep 0.8
"$godot_bin" --headless --path "$project_root" -- \
	--proxy --port "$proxy_port" --to-port "$server_port" --latency 120 \
	>"$log_dir/proxy.log" 2>&1 &
proxy_pid=$!
sleep 0.3
CAR_FIGHT_JOIN_STALL_MS=1500 CAR_FIGHT_JOIN_STALL_AFTER_MS=500 \
	"$godot_bin" --headless --path "$project_root" -- \
	--client --host 127.0.0.1 --port "$proxy_port" --name joiner --ticks 600 \
	>"$log_dir/client.log" 2>&1 &
client_pid=$!

if ! wait "$server_pid"; then
	echo "join-transient server failed; logs: $log_dir" >&2
	tail -80 "$log_dir/server.log" >&2
	exit 1
fi
server_pid=""
wait "$client_pid" || true
client_pid=""

begins="$(rg -c 'JOINSTALL begin' "$log_dir/client.log" || true)"
ends="$(rg -c 'JOINSTALL end' "$log_dir/client.log" || true)"
detected="$(rg -c 'Game stalled for' "$log_dir/client.log" || true)"
if [[ "${begins:-0}" -ne 1 || "${ends:-0}" -ne 1 || "${detected:-0}" -lt 1 ]]; then
	echo "join-transient positive control failed begin=${begins:-0} end=${ends:-0} detected=${detected:-0}; logs: $log_dir" >&2
	exit 1
fi

recoveries="$(rg -c '^WARNING: .*Skipping stale rollback origin' "$log_dir/client.log" || true)"
if [[ "${recoveries:-0}" -lt 1 || "${recoveries:-0}" -gt 2 ]]; then
	echo "stale-origin recovery was absent or unbounded (${recoveries:-0}); logs: $log_dir" >&2
	exit 1
fi
requests="$(rg -c '^\[netfox-recovery\] request .*reason=stale_authority_tick' \
	"$log_dir/client.log" || true)"
applied="$(rg -c '^\[netfox-recovery\] applied ' "$log_dir/client.log" || true)"
if [[ "${requests:-0}" -lt 1 || "${requests:-0}" -gt 2 || "${applied:-0}" -lt 1 ]]; then
	echo "reliable authority recovery failed requests=${requests:-0} applied=${applied:-0}; logs: $log_dir" >&2
	rg 'netfox-recovery|Skipping stale rollback' "$log_dir"/*.log >&2 || true
	exit 1
fi
if rg -q 'Trying to run rollback .*past the history limit|rejecting because older than' \
		"$log_dir"/*.log; then
	echo "join-transient produced an impossible rollback or stale-packet flood; logs: $log_dir" >&2
	rg 'Trying to run rollback .*past the history limit|rejecting because older than' \
		"$log_dir"/*.log >&2
	exit 1
fi
if ! rg -q 'CLIENT_TICK tick=5[0-9][0-9]' "$log_dir/client.log"; then
	echo "client did not remain healthy through tick 500 after recovery; logs: $log_dir" >&2
	tail -100 "$log_dir/client.log" >&2
	exit 1
fi
if rg -q 'SCRIPT ERROR|Parse Error|Failed to load script' "$log_dir"/*.log; then
	echo "join-transient produced a runtime error; logs: $log_dir" >&2
	rg 'SCRIPT ERROR|Parse Error|Failed to load script' "$log_dir"/*.log >&2
	exit 1
fi

echo "JOIN_TRANSIENT_TEST PASS recoveries=${recoveries:-0} reliable_requests=${requests:-0} applied=${applied:-0} post_stall_tick=500"
echo "logs: $log_dir"
