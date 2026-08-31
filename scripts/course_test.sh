#!/bin/zsh
set -euo pipefail

project_root="$(cd "$(dirname "$0")/.." && pwd)"
godot_bin="${GODOT_BIN:-/Applications/Godot.app/Contents/MacOS/Godot}"
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

"$godot_bin" --headless --path "$project_root" -- --server --no-drone --port "$server_port" \
	--course-test --ticks 600 >"$log_dir/server.log" 2>&1 &
server_pid=$!
sleep 0.8
"$godot_bin" --headless --path "$project_root" -- --client --host 127.0.0.1 --port "$server_port" \
	--name jumper --script ramp --ticks 680 >"$log_dir/client.log" 2>&1 &
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
if ! print -r -- "$result_line" | rg -q 'grounded=1'; then
	echo "car did not complete the elevated-road drop; logs: $log_dir" >&2
	exit 1
fi
rebound="$(print -r -- "$result_line" | sed -E 's/.*rebound=([0-9.]+).*/\1/')"
tilt="$(print -r -- "$result_line" | sed -E 's/.*rebound=[0-9.]+ tilt=([0-9.]+) maxtilt=.*/\1/')"
max_tilt="$(print -r -- "$result_line" | sed -E 's/.*maxtilt=([0-9.]+).*/\1/')"
if ! awk -v value="$rebound" 'BEGIN { exit !(value >= 0.15 && value <= 3.0) }'; then
	echo "landing rebound was not small and visible: $rebound; logs: $log_dir" >&2
	exit 1
fi
if ! awk -v value="$tilt" 'BEGIN { exit !(value >= 0.5 && value <= 18.0) }'; then
	echo "physical landing jostle was absent or excessive: $tilt degrees; logs: $log_dir" >&2
	exit 1
fi
if ! awk -v value="$max_tilt" 'BEGIN { exit !(value <= 20.0) }'; then
	echo "vehicle failed to self-right after landing: $max_tilt degrees; logs: $log_dir" >&2
	exit 1
fi
if rg -q 'SCRIPT ERROR|Parse Error|Trying to run rollback .*past the history limit' "$log_dir"/*.log; then
	echo "course produced a runtime or rollback-history error; logs: $log_dir" >&2
	rg 'SCRIPT ERROR|Parse Error|Trying to run rollback .*past the history limit' "$log_dir"/*.log >&2
	exit 1
fi

echo "COURSE_TEST PASS: $result_line"
echo "logs: $log_dir"
