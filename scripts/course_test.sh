#!/bin/zsh
set -euo pipefail

project_root="$(cd "$(dirname "$0")/.." && pwd)"
godot_bin="${GODOT_BIN:-/Applications/Godot47.app/Contents/MacOS/Godot}"
server_port="${CAR_FIGHT_COURSE_TEST_PORT:-10580}"
log_dir="$(mktemp -d "${TMPDIR:-/tmp}/car-fight-course.XXXXXX")"
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

"$godot_bin" --headless --path "$project_root" -- --server --port "$server_port" \
	--course-test --ticks 480 >"$log_dir/server.log" 2>&1 &
server_pid=$!
sleep 0.8
"$godot_bin" --headless --path "$project_root" -- --client --host 127.0.0.1 --port "$server_port" \
	--name jumper --script ramp --ticks 560 >"$log_dir/client.log" 2>&1 &
client_pid=$!

if ! wait "$server_pid"; then
	echo "course test server failed; logs: $log_dir" >&2
	tail -80 "$log_dir/server.log" >&2
	exit 1
fi
server_pid=""
wait "$client_pid" || true
client_pid=""

if ! rg -q 'CLIENT_READY' "$log_dir/client.log"; then
	echo "course test client did not connect; logs: $log_dir" >&2
	exit 1
fi
result_line="$(rg 'RESULT players=1 .*maxy=.*landed=' "$log_dir/server.log" | tail -1)"
if [[ -z "$result_line" ]] || ! print -r -- "$result_line" | rg -q 'landed=1'; then
	echo "car did not launch and land on the upper road; logs: $log_dir" >&2
	tail -100 "$log_dir/server.log" >&2
	tail -60 "$log_dir/client.log" >&2
	exit 1
fi
if rg -q 'SCRIPT ERROR|Parse Error|Trying to run rollback .*past the history limit' "$log_dir"/*.log; then
	echo "course produced a runtime or rollback-history error; logs: $log_dir" >&2
	rg 'SCRIPT ERROR|Parse Error|Trying to run rollback .*past the history limit' "$log_dir"/*.log >&2
	exit 1
fi

echo "COURSE_TEST PASS: $result_line"
echo "logs: $log_dir"
