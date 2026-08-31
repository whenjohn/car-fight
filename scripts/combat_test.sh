#!/bin/zsh
set -euo pipefail

project_root="$(cd "$(dirname "$0")/.." && pwd)"
godot_bin="${GODOT_BIN:-/Applications/Godot.app/Contents/MacOS/Godot}"
port="${CAR_FIGHT_COMBAT_PORT:-10580}"
log_dir="$(mktemp -d "${TMPDIR:-/tmp}/car-fight-combat.XXXXXX")"
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

run_case() {
	local case_name="$1"
	local script_name="$2"
	local case_port="$3"
	"$godot_bin" --headless --path "$project_root" -- --server --no-drone --port "$case_port" \
		--ticks 300 >"$log_dir/$case_name-server.log" 2>&1 &
	server_pid=$!
	sleep 0.8
	"$godot_bin" --headless --path "$project_root" -- --client --host 127.0.0.1 \
		--port "$case_port" --name "$case_name" --script "$script_name" --ticks 360 \
		>"$log_dir/$case_name-client.log" 2>&1 &
	client_pid=$!
	wait "$server_pid"
	server_pid=""
	kill "$client_pid" >/dev/null 2>&1 || true
	client_pid=""
}

run_case fire combat "$port"
run_case edit combat-edit "$((port + 1))"
run_case cloak cloak "$((port + 2))"

if ! rg -q 'CLIENT_READY' "$log_dir/fire-client.log"; then
	echo "combat client did not connect; logs: $log_dir" >&2
	exit 1
fi
if ! rg -q 'RESULT players=1 .*shots=[1-9][0-9]* hits=[1-9][0-9]*' "$log_dir/fire-server.log"; then
	echo "automatic zones did not authoritatively shoot and hit targets; logs: $log_dir" >&2
	tail -100 "$log_dir/fire-server.log" >&2
	exit 1
fi
if ! rg -q 'RESULT players=1 .*shots=0 hits=0' "$log_dir/edit-server.log"; then
	echo "coverage editor mode did not suppress automatic combat; logs: $log_dir" >&2
	tail -100 "$log_dir/edit-server.log" >&2
	exit 1
fi
if ! rg -q 'RESULT players=1 .*cloaked=1 shields=0 boosting=0 .*shots=0 hits=0 ballhits=0' "$log_dir/cloak-server.log"; then
	echo "cloak did not stay server-authoritative and move-only; logs: $log_dir" >&2
	tail -100 "$log_dir/cloak-server.log" >&2
	exit 1
fi
if rg -q 'SCRIPT ERROR|Parse Error|Invalid call|Invalid get index' "$log_dir"/*.log; then
	echo "runtime script error; logs: $log_dir" >&2
	rg 'SCRIPT ERROR|Parse Error|Invalid call|Invalid get index' "$log_dir"/*.log >&2
	exit 1
fi

result_line="$(rg 'RESULT players=1' "$log_dir/fire-server.log" | tail -1)"
echo "COMBAT_TEST PASS: $result_line"
echo "logs: $log_dir"
