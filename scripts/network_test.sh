#!/bin/zsh
set -euo pipefail

project_root="$(cd "$(dirname "$0")/.." && pwd)"
godot_bin="${GODOT_BIN:-/Applications/Godot47.app/Contents/MacOS/Godot}"
server_port="${CAR_FIGHT_TEST_PORT:-10380}"
proxy_port=$((server_port + 1))
log_dir="$(mktemp -d "${TMPDIR:-/tmp}/car-fight-network.XXXXXX")"
server_pid=""
proxy_pid=""
client_a_pid=""
client_b_pid=""

cleanup() {
	for process_id in "$client_a_pid" "$client_b_pid" "$proxy_pid" "$server_pid"; do
		if [[ -n "$process_id" ]]; then
			kill "$process_id" >/dev/null 2>&1 || true
		fi
	done
}
trap cleanup EXIT INT TERM

"$godot_bin" --headless --path "$project_root" -- --server --port "$server_port" --ticks 480 >"$log_dir/server.log" 2>&1 &
server_pid=$!
sleep 0.8
"$godot_bin" --headless --path "$project_root" -- --proxy --port "$proxy_port" --to-port "$server_port" --latency 120 >"$log_dir/proxy.log" 2>&1 &
proxy_pid=$!
sleep 0.3
"$godot_bin" --headless --path "$project_root" -- --client --host 127.0.0.1 --port "$proxy_port" --name alpha --script converge --presentation-test --ticks 600 >"$log_dir/client-a.log" 2>&1 &
client_a_pid=$!
sleep 0.2
"$godot_bin" --headless --path "$project_root" -- --client --host 127.0.0.1 --port "$proxy_port" --name bravo --script converge --ticks 600 >"$log_dir/client-b.log" 2>&1 &
client_b_pid=$!

if ! wait "$server_pid"; then
	echo "server failed; logs: $log_dir" >&2
	tail -80 "$log_dir/server.log" >&2
	exit 1
fi
server_pid=""

if ! rg -q 'CLIENT_READY' "$log_dir/client-a.log" || ! rg -q 'CLIENT_READY' "$log_dir/client-b.log"; then
	echo "a client did not complete the ENet handshake; logs: $log_dir" >&2
	tail -60 "$log_dir/client-a.log" >&2
	tail -60 "$log_dir/client-b.log" >&2
	exit 1
fi
if ! rg -q 'RESULT players=2 .*contact=1' "$log_dir/server.log"; then
	echo "authoritative two-car contact was not observed; logs: $log_dir" >&2
	tail -100 "$log_dir/server.log" >&2
	exit 1
fi
if ! rg -q 'RESULT players=2 .*contact=1 escapes=[1-9][0-9]*' "$log_dir/server.log"; then
	echo "colliding cars never triggered the authoritative escape assist; logs: $log_dir" >&2
	tail -100 "$log_dir/server.log" >&2
	exit 1
fi
if rg -q 'SCRIPT ERROR|Parse Error|Invalid call|Invalid get index' "$log_dir"/*.log; then
	echo "runtime script error; logs: $log_dir" >&2
	rg 'SCRIPT ERROR|Parse Error|Invalid call|Invalid get index' "$log_dir"/*.log >&2
	exit 1
fi
correction_lines="$(rg 'CORRECTION .*error=' "$log_dir"/client-*.log || true)"
if [[ -z "$correction_lines" ]]; then
	echo "clients received no same-tick authority probes; logs: $log_dir" >&2
	exit 1
fi
worst_error="$(print -r -- "$correction_lines" | sed -E 's/.*error=([0-9.]+).*/\1/' | sort -n | tail -1)"
if ! awk -v value="$worst_error" 'BEGIN { exit !(value <= 2.0) }'; then
	echo "local prediction correction exceeded 2 units: $worst_error; logs: $log_dir" >&2
	exit 1
fi

result_line="$(rg 'RESULT players=2' "$log_dir/server.log" | tail -1)"
echo "NETWORK_TEST PASS 120ms one-way, worst correction=${worst_error}: $result_line"
echo "logs: $log_dir"
