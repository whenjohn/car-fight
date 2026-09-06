#!/bin/zsh
set -euo pipefail
project_root="$(cd "$(dirname "$0")/.." && pwd)"
godot_bin="${GODOT_BIN:-/Applications/Godot47.app/Contents/MacOS/Godot}"
port="${CAR_FIGHT_ADMISSION_TEST_PORT:-11982}"
transport="${CAR_FIGHT_ADMISSION_TEST_TRANSPORT:-enet}"
log_dir="$(mktemp -d "${TMPDIR:-/tmp}/car-fight-admission.XXXXXX")"
typeset -a pids
cleanup() {
	for pid in "${pids[@]}"; do
		kill "$pid" 2>/dev/null || true
	done
	for pid in "${pids[@]}"; do
		wait "$pid" 2>/dev/null || true
	done
}
trap cleanup EXIT INT TERM
wait_for() {
	local file="$1" pattern="$2" pid="$3"
	for attempt in {1..600}; do
		if rg -q 'ERROR:|SCRIPT ERROR|Parse Error' "$log_dir"/*.log; then
			echo "Admission runtime error; logs: $log_dir" >&2
			rg 'ERROR:|SCRIPT ERROR|Parse Error' "$log_dir"/*.log >&2
			exit 1
		fi
		if rg -q "$pattern" "$file"; then return; fi
		if ! kill -0 "$pid" 2>/dev/null; then
			echo "Admission process exited early; logs: $log_dir" >&2
			exit 1
		fi
		sleep 0.1
	done
	echo "Admission deadline waiting for $pattern; logs: $log_dir" >&2
	exit 1
}
ADMISSION_TEST_MODE=server CAR_FIGHT_SERVER_ADMISSION=1 \
	"$godot_bin" --headless --max-fps 60 --path "$project_root" \
	--script res://tests/fixtures/player_admission_peer.gd \
	-- --server --transport "$transport" --signal-port "$((port + 1))" \
	--no-drone --port "$port" >"$log_dir/server.log" 2>&1 &
pids+=($!)
wait_for "$log_dir/server.log" 'SERVER_READY' "${pids[1]}"
for mode in observe hold late; do
	client_args=(--host 127.0.0.1 --port "$port")
	if [[ "$transport" == "mux" && "$mode" == "hold" ]]; then
		client_args=(--transport webrtc --signal-url "ws://127.0.0.1:$((port + 1))")
	fi
	ADMISSION_TEST_MODE="$mode" CAR_FIGHT_STARTUP_READY=0 CAR_FIGHT_FORWARD_CLOCK_RECOVERY=1 \
		"$godot_bin" --headless --max-fps 60 --path "$project_root" \
		--script res://tests/fixtures/player_admission_peer.gd \
		-- --client "${client_args[@]}" --name "$mode" --script right \
		>"$log_dir/$mode.log" 2>&1 &
	pids+=($!)
	wait_for "$log_dir/$mode.log" 'STARTUP_PLAYABLE' "${pids[-1]}"
	if [[ "$mode" == "hold" ]]; then
		wait_for "$log_dir/observe.log" 'ADMISSION_PEER PASS' "${pids[2]}"
	fi
done
wait_for "$log_dir/hold.log" 'ADMISSION_PEER PASS' "${pids[3]}"
wait_for "$log_dir/late.log" 'ADMISSION_PEER PASS' "${pids[4]}"
if [[ "$(rg -c 'PLAYER_ACTIVATED' "$log_dir/server.log")" != "3" ]]; then
	echo "Expected exactly one activation for each peer; logs: $log_dir" >&2
	exit 1
fi
echo "PLAYER_ADMISSION_NETWORK_TEST PASS transport=$transport hidden=1 physics=excluded late_join=active auto_gate=1 movement=1"
echo "logs: $log_dir"
