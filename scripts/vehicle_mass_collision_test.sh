#!/bin/zsh
set -euo pipefail

project_root="$(cd "$(dirname "$0")/.." && pwd)"
godot_bin="${GODOT_BIN:-/Applications/Godot47.app/Contents/MacOS/Godot}"
server_port="${CAR_FIGHT_MASS_TEST_PORT:-10500}"
log_dir="$(mktemp -d "${TMPDIR:-/tmp}/car-fight-vehicle-mass.XXXXXX")"
server_pid=""
heavy_pid=""
light_pid=""

cleanup() {
	for process_id in "$light_pid" "$heavy_pid" "$server_pid"; do
		if [[ "$process_id" == <-> ]] && (( process_id > 1 )); then
			kill "$process_id" >/dev/null 2>&1 || true
		fi
	done
}
trap cleanup EXIT INT TERM

"$godot_bin" --headless --path "$project_root" -- \
	--server --no-drone --no-ball --port "$server_port" --ticks 720 \
	>"$log_dir/server.log" 2>&1 &
server_pid=$!
sleep 0.8
"$godot_bin" --headless --path "$project_root" -- \
	--client --host 127.0.0.1 --port "$server_port" --name heavy \
	--script mass-heavy --presentation-test --ticks 900 >"$log_dir/heavy.log" 2>&1 &
heavy_pid=$!
sleep 0.2
"$godot_bin" --headless --path "$project_root" -- \
	--client --host 127.0.0.1 --port "$server_port" --name light \
	--script mass-light --presentation-test --ticks 900 >"$log_dir/light.log" 2>&1 &
light_pid=$!

if ! wait "$server_pid"; then
	echo "mass collision server failed; logs: $log_dir" >&2
	tail -160 "$log_dir/server.log" >&2
	exit 1
fi
server_pid=""
wait "$heavy_pid" || true
heavy_pid=""
wait "$light_pid" || true
light_pid=""

if ! rg -q 'VEHICLE_TUNING_APPLIED .*vehicle=0 scale=1.00 mass=4.5' \
		"$log_dir/server.log" \
		|| ! rg -q 'VEHICLE_TUNING_APPLIED .*vehicle=0 scale=1.00 mass=1.6' \
		"$log_dir/server.log"; then
	echo "server did not approve both mass classes; logs: $log_dir" >&2
	rg 'VEHICLE_TUNING' "$log_dir"/*.log >&2 || true
	exit 1
fi
for client_log in "$log_dir/heavy.log" "$log_dir/light.log"; do
	for expected_mass in 4.5 1.6; do
		if ! rg -q "VEHICLE_TUNING_SPAWN .*vehicle=0 scale=1.00 mass=${expected_mass}" \
				"$client_log"; then
			echo "a client did not receive mass ${expected_mass}; logs: $log_dir" >&2
			rg 'VEHICLE_TUNING' "$log_dir"/*.log >&2 || true
			exit 1
		fi
	done
done
mass_line="$(rg 'MASS_BASELINE .*hm=4.5 .*lm=1.6 ' "$log_dir/server.log" | head -1 || true)"
if [[ -z "$mass_line" ]]; then
	echo "server observed no heavy-versus-light contact baseline; logs: $log_dir" >&2
	tail -180 "$log_dir/server.log" >&2
	exit 1
fi
heavy_delta="$(print -r -- "$mass_line" | sed -E 's/.*heavy_dv=([0-9.]+).*/\1/')"
light_delta="$(print -r -- "$mass_line" | sed -E 's/.*light_dv=([0-9.]+).*/\1/')"
ratio="$(print -r -- "$mass_line" | sed -E 's/.*ratio=([0-9.]+).*/\1/')"
if ! awk -v heavy="$heavy_delta" -v light="$light_delta" -v ratio="$ratio" \
		'BEGIN { exit !(heavy > 0.01 && light > heavy && ratio >= 1.5) }'; then
	echo "mass response did not favor the heavy vehicle: $mass_line; logs: $log_dir" >&2
	exit 1
fi
if ! rg -q 'RESULT players=2 .*contact=1' "$log_dir/server.log"; then
	echo "server did not retain the two tuned bodies through contact; logs: $log_dir" >&2
	exit 1
fi
if rg -q 'SCRIPT ERROR|Parse Error|Compile Error|Invalid call|Invalid get index|Node not found|Failed to get path from RPC' \
		"$log_dir"/*.log; then
	echo "mass collision produced a runtime error; logs: $log_dir" >&2
	rg 'SCRIPT ERROR|Parse Error|Compile Error|Invalid call|Invalid get index|Node not found|Failed to get path from RPC' \
		"$log_dir"/*.log >&2
	exit 1
fi

echo "VEHICLE_MASS_COLLISION_GATE PASS heavy_dv=${heavy_delta} light_dv=${light_delta} ratio=${ratio}"
echo "log: $log_dir"
