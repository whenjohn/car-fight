#!/bin/zsh
set -euo pipefail

project_root="$(cd "$(dirname "$0")/.." && pwd)"
godot_bin="${GODOT_BIN:-/Applications/Godot47.app/Contents/MacOS/Godot}"
server_port="${CAR_FIGHT_TEST_PORT:-10480}"
server_ticks="${CAR_FIGHT_RAMMING_SERVER_TICKS:-720}"
client_ticks="${CAR_FIGHT_RAMMING_CLIENT_TICKS:-780}"
log_dir="$(mktemp -d "${TMPDIR:-/tmp}/car-fight-ramming-lab.XXXXXX")"
server_pid=""
client_pid=""

cleanup() {
	for process_id in "$client_pid" "$server_pid"; do
		if [[ "$process_id" == <-> ]] && (( process_id > 1 )); then
			kill "$process_id" >/dev/null 2>&1 || true
		fi
	done
}
trap cleanup EXIT INT TERM

"$godot_bin" --headless --path "$project_root" -- \
	--server --port "$server_port" --ramming-lab --ticks "$server_ticks" \
	>"$log_dir/server.log" 2>&1 &
server_pid=$!
sleep 0.8
"$godot_bin" --headless --path "$project_root" -- \
	--client --host 127.0.0.1 --port "$server_port" --name rammer \
	--script ram-lab --presentation-test --ticks "$client_ticks" \
	>"$log_dir/client.log" 2>&1 &
client_pid=$!

if ! wait "$server_pid"; then
	echo "ramming lab server failed; logs: $log_dir" >&2
	tail -100 "$log_dir/server.log" >&2
	exit 1
fi
server_pid=""

if ! rg -q 'RAMMING_LAB_READY drones=3 speed=6.0 lanes=-6,0,6' \
		"$log_dir/server.log"; then
	echo "ramming lab did not spawn all drones; logs: $log_dir" >&2
	tail -100 "$log_dir/server.log" >&2
	exit 1
fi
if ! rg -q 'RAMMING_LAB_PROPS_READY count=12 max_mass=0.18' \
		"$log_dir/server.log"; then
	echo "ramming lab did not spawn lightweight props; logs: $log_dir" >&2
	tail -120 "$log_dir/server.log" >&2
	exit 1
fi
for drone_id in 2000002001 2000002002 2000002003; do
	if ! rg -q "RAMMING_DRONE .*id=${drone_id} .*speed=[1-9]" "$log_dir/server.log"; then
		echo "ramming drone $drone_id never moved; logs: $log_dir" >&2
		tail -120 "$log_dir/server.log" >&2
		exit 1
	fi
done
if ! rg -q 'CLIENT_TICK .*players=4 world=.*2000002001:.*2000002002:.*2000002003:' \
		"$log_dir/client.log"; then
	echo "client did not replicate the three server-owned drones; logs: $log_dir" >&2
	tail -120 "$log_dir/client.log" >&2
	exit 1
fi
if ! rg -q 'CLIENT_TICK .*props=12 ' "$log_dir/client.log"; then
	echo "client did not replicate all scatter props; logs: $log_dir" >&2
	tail -140 "$log_dir/client.log" >&2
	exit 1
fi
for visual_profile in 'Humvee M242|3.2' 'Apocalypse Bus|4.5' 'LP Car A03-1|1.6'; do
	vehicle_name="${visual_profile%|*}"
	vehicle_mass="${visual_profile##*|}"
	if ! rg -Fq "RAMMING_DRONE_VISUAL" "$log_dir/client.log" \
			|| ! rg -Fq "vehicle=$vehicle_name scale=1.50 mass=$vehicle_mass" \
			"$log_dir/client.log"; then
		echo "client did not construct ramming drone visual '$vehicle_name'; logs: $log_dir" >&2
		tail -120 "$log_dir/client.log" >&2
		exit 1
	fi
done
if ! rg -q 'RAM_BASELINE .*closing=' "$log_dir/server.log"; then
	echo "scripted rammer never produced a baseline contact; logs: $log_dir" >&2
	tail -140 "$log_dir/server.log" >&2
	exit 1
fi
prop_peak="$(rg 'SCATTER_PROP_STATE .*peak=' "$log_dir/server.log" \
	| tail -1 | sed -E 's/.*peak=([0-9.]+).*/\1/' || true)"
if [[ -z "$prop_peak" ]] || ! awk -v peak="$prop_peak" \
		'BEGIN { exit !(peak >= 1.0) }'; then
	echo "no lightweight prop was scattered by traffic; peak=${prop_peak:-missing}; logs: $log_dir" >&2
	rg 'SCATTER_PROP_STATE' "$log_dir/server.log" >&2 || true
	exit 1
fi
if ! rg -q 'RESULT players=4 .*shots=0 .*droneshots=0' "$log_dir/server.log"; then
	echo "lab result did not retain four bodies with combat isolated; logs: $log_dir" >&2
	tail -100 "$log_dir/server.log" >&2
	exit 1
fi
if rg -q 'SCRIPT ERROR|Parse Error|Compile Error|Invalid call|Invalid get index|State bundle root|inconsistent' \
		"$log_dir"/*.log; then
	echo "ramming lab produced a runtime error; logs: $log_dir" >&2
	rg 'SCRIPT ERROR|Parse Error|Compile Error|Invalid call|Invalid get index|State bundle root|inconsistent' \
		"$log_dir"/*.log >&2
	exit 1
fi

echo "RAMMING_LAB_GATE PASS drones=3 props=12 prop_peak=${prop_peak} replicated=1 moving=1 baseline_contact=1 combat=off"
echo "log: $log_dir"
