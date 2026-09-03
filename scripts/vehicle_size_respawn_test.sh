#!/bin/zsh
set -euo pipefail

project_root="$(cd "$(dirname "$0")/.." && pwd)"
godot_bin="${GODOT_BIN:-/Applications/Godot47.app/Contents/MacOS/Godot}"
server_port="${CAR_FIGHT_SIZE_TEST_PORT:-10490}"
log_dir="$(mktemp -d "${TMPDIR:-/tmp}/car-fight-vehicle-size.XXXXXX")"
server_pid=""
client_pid=""
observer_pid=""

cleanup() {
	for process_id in "$observer_pid" "$client_pid" "$server_pid"; do
		if [[ "$process_id" == <-> ]] && (( process_id > 1 )); then
			kill "$process_id" >/dev/null 2>&1 || true
		fi
	done
}
trap cleanup EXIT INT TERM

"$godot_bin" --headless --path "$project_root" -- \
	--server --no-drone --no-ball --port "$server_port" --ticks 420 \
	>"$log_dir/server.log" 2>&1 &
server_pid=$!
sleep 0.8
"$godot_bin" --headless --path "$project_root" -- \
	--client --host 127.0.0.1 --port "$server_port" --name size-tuner \
	--script size-respawn --presentation-test --ticks 300 \
	>"$log_dir/client.log" 2>&1 &
client_pid=$!
sleep 0.3
"$godot_bin" --headless --path "$project_root" -- \
	--client --host 127.0.0.1 --port "$server_port" --name size-observer \
	--script idle --ticks 330 \
	>"$log_dir/observer.log" 2>&1 &
observer_pid=$!

if ! wait "$client_pid"; then
	echo "vehicle size client failed; logs: $log_dir" >&2
	tail -120 "$log_dir/client.log" >&2
	exit 1
fi
client_pid=""
if ! wait "$observer_pid"; then
	echo "vehicle size observer failed; logs: $log_dir" >&2
	tail -120 "$log_dir/observer.log" >&2
	exit 1
fi
observer_pid=""
if ! wait "$server_pid"; then
	echo "vehicle size server failed; logs: $log_dir" >&2
	tail -120 "$log_dir/server.log" >&2
	exit 1
fi
server_pid=""

if ! rg -q 'VEHICLE_SIZE_APPLIED id=[0-9]+ vehicle=0 scale=1.50 generation=[0-9]+' \
		"$log_dir/server.log"; then
	echo "server did not approve and recreate the tuned vehicle; logs: $log_dir" >&2
	tail -140 "$log_dir/server.log" >&2
	exit 1
fi
for role_log in "$log_dir/server.log" "$log_dir/client.log" "$log_dir/observer.log"; do
	if ! rg -q 'VEHICLE_SIZE_SPAWN id=[0-9]+ vehicle=0 visual=1.50 collider=1.50 radius=1.575 height=5.100' \
			"$role_log"; then
		echo "server and client did not construct matching scaled capsules; logs: $log_dir" >&2
		rg 'VEHICLE_SIZE' "$log_dir"/*.log >&2 || true
		exit 1
	fi
done
for client_log in "$log_dir/client.log" "$log_dir/observer.log"; do
	scaled_client_spawns="$(rg -c 'VEHICLE_SIZE_SPAWN .*vehicle=0 visual=1.50 collider=1.50' \
		"$client_log" || true)"
	if (( ${scaled_client_spawns:-0} != 1 )); then
		echo "a client received ${scaled_client_spawns:-0} scaled respawns instead of one; logs: $log_dir" >&2
		exit 1
	fi
done
if ! rg -q 'CLIENT_TICK tick=2[0-9][0-9].*players=2' "$log_dir/client.log"; then
	echo "client did not continue after the authoritative respawn; logs: $log_dir" >&2
	tail -120 "$log_dir/client.log" >&2
	exit 1
fi
if ! rg -q 'CLIENT_TICK tick=2[0-9][0-9].*players=2' "$log_dir/observer.log"; then
	echo "observer did not retain both players after the authoritative respawn; logs: $log_dir" >&2
	tail -120 "$log_dir/observer.log" >&2
	exit 1
fi
if rg -q 'SCRIPT ERROR|Parse Error|Compile Error|Invalid call|Invalid get index|Node not found|Failed to get path from RPC' \
		"$log_dir"/*.log; then
	echo "vehicle size respawn produced a runtime error; logs: $log_dir" >&2
	rg 'SCRIPT ERROR|Parse Error|Compile Error|Invalid call|Invalid get index|Node not found|Failed to get path from RPC' \
		"$log_dir"/*.log >&2
	exit 1
fi

echo "VEHICLE_SIZE_RESPAWN_GATE PASS scale=1.50 requester=1 observer=1 respawns=1"
echo "log: $log_dir"
