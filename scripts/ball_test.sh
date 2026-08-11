#!/bin/zsh
set -euo pipefail

project_root="$(cd "$(dirname "$0")/.." && pwd)"
godot_bin="${GODOT_BIN:-/Applications/Godot47.app/Contents/MacOS/Godot}"
server_port="${CAR_FIGHT_BALL_TEST_PORT:-10480}"
log_dir="$(mktemp -d "${TMPDIR:-/tmp}/car-fight-ball.XXXXXX")"
server_pid=""
client_pid=""

cleanup() {
	for process_id in "$client_pid" "$server_pid"; do
		if [[ -n "$process_id" ]]; then
			kill "$process_id" >/dev/null 2>&1 || true
		fi
	done
}
trap cleanup EXIT INT TERM

"$godot_bin" --headless --path "$project_root" -- --server --port "$server_port" --ticks 420 >"$log_dir/server.log" 2>&1 &
server_pid=$!
sleep 0.8
"$godot_bin" --headless --path "$project_root" -- --client --host 127.0.0.1 --port "$server_port" \
	--name striker --script ball --presentation-test --ticks 500 >"$log_dir/client.log" 2>&1 &
client_pid=$!

if ! wait "$server_pid"; then
	echo "ball test server failed; logs: $log_dir" >&2
	tail -80 "$log_dir/server.log" >&2
	exit 1
fi
server_pid=""
wait "$client_pid" || true
client_pid=""

if ! rg -q 'CLIENT_READY' "$log_dir/client.log"; then
	echo "ball test client did not connect; logs: $log_dir" >&2
	exit 1
fi
result_line="$(rg 'RESULT players=1 .*ballmax=' "$log_dir/server.log" | tail -1)"
if [[ -z "$result_line" ]]; then
	echo "ball test produced no server result; logs: $log_dir" >&2
	exit 1
fi
ball_speed="$(print -r -- "$result_line" | sed -E 's/.*ballmax=([0-9.]+).*/\1/')"
if ! awk -v value="$ball_speed" 'BEGIN { exit !(value >= 0.75) }'; then
	echo "car did not launch the authoritative ball: max speed $ball_speed; logs: $log_dir" >&2
	exit 1
fi
if rg -q 'SCRIPT ERROR|Parse Error|Trying to run rollback .*past the history limit' "$log_dir"/*.log; then
	echo "ball produced a runtime or rollback-history error; logs: $log_dir" >&2
	rg 'SCRIPT ERROR|Parse Error|Trying to run rollback .*past the history limit' "$log_dir"/*.log >&2
	exit 1
fi

echo "BALL_TEST PASS authoritative max speed=${ball_speed}: $result_line"
echo "logs: $log_dir"
