#!/bin/zsh
set -euo pipefail

project_root="$(cd "$(dirname "$0")/.." && pwd)"
godot_bin="${GODOT_BIN:-/Applications/Godot47.app/Contents/MacOS/Godot}"
port="${CAR_FIGHT_SHIELD_PORT:-10680}"
log_dir="$(mktemp -d "${TMPDIR:-/tmp}/car-fight-shield.XXXXXX")"
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
	"$godot_bin" --headless --path "$project_root" -- --server --port "$case_port" \
		--ticks 420 >"$log_dir/$case_name-server.log" 2>&1 &
	server_pid=$!
	sleep 0.8
	"$godot_bin" --headless --path "$project_root" -- --client --host 127.0.0.1 \
		--port "$case_port" --name "$case_name" --script "$script_name" --ticks 500 \
		>"$log_dir/$case_name-client.log" 2>&1 &
	client_pid=$!
	wait "$server_pid"
	server_pid=""
	kill "$client_pid" >/dev/null 2>&1 || true
	client_pid=""
}

run_case hull drone-hit "$port"
run_case shield shield "$((port + 1))"
run_case exclusion cloak-shield "$((port + 2))"

for case_name in hull shield exclusion; do
	if ! rg -q 'CLIENT_READY' "$log_dir/$case_name-client.log"; then
		echo "$case_name client did not connect; logs: $log_dir" >&2
		exit 1
	fi
done

hull_result="$(rg 'RESULT players=1' "$log_dir/hull-server.log" | tail -1)"
shield_result="$(rg 'RESULT players=1' "$log_dir/shield-server.log" | tail -1)"
exclusion_result="$(rg 'RESULT players=1' "$log_dir/exclusion-server.log" | tail -1)"

if [[ -z "$hull_result" || -z "$shield_result" || -z "$exclusion_result" ]]; then
	echo "shield test produced no server result; logs: $log_dir" >&2
	exit 1
fi
if ! print -r -- "$hull_result" | rg -q 'droneshots=[1-9][0-9]* impacthits=[1-9][0-9]* shieldhits=0'; then
	echo "unshielded drone bolts did not authoritatively hit the Jeep: $hull_result" >&2
	exit 1
fi
if ! print -r -- "$shield_result" | rg -q 'cloaked=0 shields=1 .*droneshots=[1-9][0-9]* impacthits=[1-9][0-9]* shieldhits=[1-9][0-9]*'; then
	echo "raised shield did not absorb authoritative drone hits: $shield_result" >&2
	exit 1
fi
if ! print -r -- "$exclusion_result" | rg -q 'cloaked=1 shields=0 .*droneshots=0 impacthits=0 shieldhits=0'; then
	echo "cloak did not win shield mutual exclusion and drone targeting: $exclusion_result" >&2
	exit 1
fi
if ! rg -q 'CLIENT_TICK .*cloak=0 shield=1' "$log_dir/shield-client.log"; then
	echo "owner never observed the authoritative raised shield; logs: $log_dir" >&2
	exit 1
fi
if ! rg -q 'CLIENT_TICK .*cloak=1 shield=0' "$log_dir/exclusion-client.log"; then
	echo "owner disagreed with cloak/shield mutual exclusion; logs: $log_dir" >&2
	exit 1
fi

hull_speed="$(print -r -- "$hull_result" | sed -E 's/.*impactmax=([0-9.]+).*/\1/')"
shield_speed="$(print -r -- "$shield_result" | sed -E 's/.*impactmax=([0-9.]+).*/\1/')"
hull_tilt="$(print -r -- "$hull_result" | sed -E 's/.*maxtilt=([0-9.]+).*/\1/')"
shield_tilt="$(print -r -- "$shield_result" | sed -E 's/.*maxtilt=([0-9.]+).*/\1/')"
if ! awk -v hull="$hull_speed" -v shield="$shield_speed" \
		-v hull_tilt="$hull_tilt" -v shield_tilt="$shield_tilt" \
	'BEGIN { exit !(hull >= 2.0 && shield >= 0.25 && shield < hull * 0.5 \
		&& hull_tilt >= 5.0 && shield_tilt >= 0.8 && shield_tilt < hull_tilt * 0.5) }'; then
	echo "shield did not substantially reduce trajectory shove: hull=$hull_speed shield=$shield_speed" >&2
	echo "body jostle was not readable: hull_tilt=$hull_tilt shield_tilt=$shield_tilt" >&2
	echo "$hull_result" >&2
	echo "$shield_result" >&2
	exit 1
fi
if rg -q 'SCRIPT ERROR|Parse Error|Invalid call|Invalid get index' "$log_dir"/*.log; then
	echo "shield runtime script error; logs: $log_dir" >&2
	rg 'SCRIPT ERROR|Parse Error|Invalid call|Invalid get index' "$log_dir"/*.log >&2
	exit 1
fi

echo "SHIELD_TEST PASS unshielded=${hull_speed}/${hull_tilt}deg shielded=${shield_speed}/${shield_tilt}deg"
echo "logs: $log_dir"
