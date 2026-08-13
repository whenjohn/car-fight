#!/bin/zsh
set -euo pipefail

project_root="$(cd "$(dirname "$0")/.." && pwd)"
godot_bin="${GODOT_BIN:-/Applications/Godot47.app/Contents/MacOS/Godot}"
server_port="${CAR_FIGHT_GATE_TEST_PORT:-10980}"
log_dir="$(mktemp -d "${TMPDIR:-/tmp}/car-fight-gate.XXXXXX")"
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

"$godot_bin" --headless --path "$project_root" -- --server --no-drone --port "$server_port" \
	--gate-test --ticks 480 >"$log_dir/server.log" 2>&1 &
server_pid=$!
sleep 0.8
"$godot_bin" --headless --path "$project_root" -- --client --host 127.0.0.1 --port "$server_port" \
	--name gate-driver --script gate-loop --gate-test --ticks 540 >"$log_dir/client.log" 2>&1 &
client_pid=$!

if ! wait "$server_pid"; then
	echo "gate test server failed; logs: $log_dir" >&2
	tail -80 "$log_dir/server.log" >&2
	exit 1
fi
server_pid=""
wait "$client_pid" || true
client_pid=""

result_line="$(rg 'RESULT players=1 .*gatetransitions=' "$log_dir/server.log" | tail -1)"
if [[ -z "$result_line" ]] || ! print -r -- "$result_line" \
		| rg -q 'coursemaps=0 courseoff=0 gatetransitions=2'; then
	echo "jump gates did not complete a safe arena-course-arena round trip; logs: $log_dir" >&2
	tail -100 "$log_dir/server.log" >&2
	tail -60 "$log_dir/client.log" >&2
	exit 1
fi
if ! rg -q 'CLIENT_TICK .*map=1' "$log_dir/client.log"; then
	echo "client never reconciled into the driving-course map; logs: $log_dir" >&2
	exit 1
fi
if rg -q 'SCRIPT ERROR|Parse Error|Trying to run rollback .*past the history limit' "$log_dir"/*.log; then
	echo "gate produced a runtime or rollback-history error; logs: $log_dir" >&2
	rg 'SCRIPT ERROR|Parse Error|Trying to run rollback .*past the history limit' "$log_dir"/*.log >&2
	exit 1
fi

echo "GATE_TEST PASS: $result_line"
echo "logs: $log_dir"
