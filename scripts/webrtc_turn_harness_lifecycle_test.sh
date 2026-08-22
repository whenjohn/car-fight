#!/bin/zsh
set -euo pipefail
unsetopt BG_NICE

project_root="$(cd "$(dirname "$0")/.." && pwd)"
test_root="$(mktemp -d "${TMPDIR:-/tmp}/car-fight-harness-lifecycle.XXXXXX")"
base_port="$((22000 + ($$ % 15000)))"
signal_port="$base_port"
web_port="$((base_port + 1))"

cleanup() {
	for pid_file in "$test_root"/*.pid(N); do
		local process_id="$(<"$pid_file")"
		if [[ "$process_id" == <-> ]] && (( process_id > 1 )); then
			kill "$process_id" >/dev/null 2>&1 || true
			wait "$process_id" 2>/dev/null || true
		fi
	done
}
trap cleanup EXIT INT TERM

for signal_name in INT TERM; do
	log="$test_root/harness-$signal_name.log"
	CAR_FIGHT_HARNESS_LIFECYCLE_TEST=1 \
	CAR_FIGHT_SHAPE_LOCAL_SIGNAL_PORT="$signal_port" \
	CAR_FIGHT_SHAPE_WEB_PORT="$web_port" \
		"$project_root/scripts/webrtc_turn_shape_test.sh" latency120 > "$log" 2>&1 &
	harness_pid=$!
	print -r -- "$harness_pid" > "$test_root/harness-$signal_name.pid"
	ready=0
	for _attempt in {1..100}; do
		if rg -q 'HARNESS_LIFECYCLE_READY' "$log"; then
			ready=1
			break
		fi
		if ! kill -0 "$harness_pid" >/dev/null 2>&1; then
			break
		fi
		sleep 0.05
	done
	if (( ready == 0 )); then
		cat "$log" >&2
		echo "harness did not reach lifecycle-ready state for $signal_name" >&2
		exit 1
	fi
	kill -s "$signal_name" "$harness_pid"
	set +e
	wait "$harness_pid"
	exit_status=$?
	set -e
	if [[ "$signal_name" == "INT" && "$exit_status" != "130" ]] \
			|| [[ "$signal_name" == "TERM" && "$exit_status" != "143" ]]; then
		cat "$log" >&2
		echo "harness returned unexpected status $exit_status for $signal_name" >&2
		exit 1
	fi
	unlink "$test_root/harness-$signal_name.pid"

	rebind_log="$test_root/rebind-$signal_name.log"
	node "$project_root/scripts/harness_port_listener.mjs" \
		"$signal_port" "$web_port" "rebind-$signal_name" > "$rebind_log" 2>&1 &
	rebind_pid=$!
	print -r -- "$rebind_pid" > "$test_root/rebind-$signal_name.pid"
	rebound=0
	for _attempt in {1..100}; do
		if rg -q 'HARNESS_PORTS_READY' "$rebind_log"; then
			rebound=1
			break
		fi
		if ! kill -0 "$rebind_pid" >/dev/null 2>&1; then
			break
		fi
		sleep 0.05
	done
	if (( rebound == 0 )); then
		cat "$rebind_log" >&2
		echo "ports did not rebind after $signal_name" >&2
		exit 1
	fi
	kill -TERM "$rebind_pid"
	set +e
	wait "$rebind_pid"
	set -e
	unlink "$test_root/rebind-$signal_name.pid"
done

echo "WEBRTC_TURN_HARNESS_LIFECYCLE PASS signal_port=$signal_port web_port=$web_port interrupts=INT,TERM"
