#!/bin/zsh
set -euo pipefail
unsetopt BG_NICE

project_root="$(cd "$(dirname "$0")/.." && pwd)"
godot_bin="${GODOT_BIN:-/Applications/Godot47.app/Contents/MacOS/Godot}"
base_port="${CAR_FIGHT_MIXED_TEST_PORT:-12480}"
log_dir="$(mktemp -d "${TMPDIR:-/tmp}/car-fight-mixed.XXXXXX")"
server_pid=""
enet_pid=""
rtc_pid=""

cleanup() {
	for process_id in "$rtc_pid" "$enet_pid" "$server_pid"; do
		if [[ "$process_id" == <-> ]] && (( process_id > 1 )); then
			kill "$process_id" >/dev/null 2>&1 || true
		fi
	done
	wait 2>/dev/null || true
}
trap cleanup EXIT INT TERM

shared="$log_dir/shared"
mkdir -p "$shared"
"$godot_bin" --headless --path "$project_root" -- --server --transport mux \
	--port "$base_port" --signal-port "$((base_port + 1))" --no-drone --ticks 720 \
	>"$shared/server.log" 2>&1 &
server_pid=$!
sleep 0.8
"$godot_bin" --headless --path "$project_root" -- --client --host 127.0.0.1 \
	--port "$base_port" --name enet --script converge --ticks 300 \
	>"$shared/enet.log" 2>&1 &
enet_pid=$!
sleep 0.8
"$godot_bin" --headless --path "$project_root" -- --client --transport webrtc \
	--signal-url "ws://127.0.0.1:$((base_port + 1))" --name rtc \
	--script converge --ticks 420 >"$shared/rtc.log" 2>&1 &
rtc_pid=$!

wait "$enet_pid"; enet_pid=""
wait "$rtc_pid"; rtc_pid=""
wait "$server_pid"; server_pid=""

enet_id="$(sed -nE 's/.*peer_connected id=([0-9]+) transport=enet.*/\1/p' \
	"$shared/server.log" | head -1)"
rtc_id="$(sed -nE 's/.*peer_connected id=([0-9]+) transport=webrtc.*/\1/p' \
	"$shared/server.log" | head -1)"
if [[ -z "$enet_id" || -z "$rtc_id" || "$enet_id" == "$rtc_id" ]]; then
	echo "Mux did not establish distinct ENet and WebRTC peer IDs; logs: $log_dir" >&2
	exit 1
fi
for client in enet rtc; do
	if ! rg -q 'CLIENT_TICK .*players=2 world=[^|]+\|[^ ]+' "$shared/$client.log"; then
		echo "$client did not observe the shared mixed-transport world; logs: $log_dir" >&2
		exit 1
	fi
done
if ! rg -q 'CLIENT_TICK .*players=1 world=[^| ]+ ' "$shared/rtc.log" \
		|| ! rg -q 'MUX_DEPARTURE_DRAINED id=' "$shared/server.log"; then
	echo "WebRTC survivor did not observe the drained ENet departure; logs: $log_dir" >&2
	exit 1
fi
if ! rg -q 'RESULT .*contact=1' "$shared/server.log"; then
	echo "Authoritative mixed-transport contact was not observed; logs: $log_dir" >&2
	exit 1
fi
correction_lines="$(rg 'CORRECTION .*error=' "$shared"/enet.log "$shared"/rtc.log || true)"
worst_error="$(print -r -- "$correction_lines" | sed -E 's/.*error=([0-9.]+).*/\1/' \
	| sort -n | tail -1)"
if [[ -z "$worst_error" ]] \
		|| ! awk -v value="$worst_error" 'BEGIN { exit !(value <= 2.0) }'; then
	echo "Mixed-transport correction exceeded two units: ${worst_error:-missing}; logs: $log_dir" >&2
	exit 1
fi
if rg -q 'SCRIPT ERROR|Parse Error|Invalid call|Invalid get index|Node not found|Failed to get path from RPC' \
		"$shared"/*.log; then
	echo "Mixed-transport shared-world run emitted a runtime error; logs: $log_dir" >&2
	exit 1
fi

collision="$log_dir/collision"
mkdir -p "$collision"
collision_port=$((base_port + 10))
"$godot_bin" --headless --path "$project_root" -- --server --transport mux \
	--mux-collision-test --port "$collision_port" --signal-port "$((collision_port + 1))" \
	--no-drone --ticks 480 >"$collision/server.log" 2>&1 &
server_pid=$!
sleep 0.8
"$godot_bin" --headless --path "$project_root" -- --client --host 127.0.0.1 \
	--port "$collision_port" --name established --script right --ticks 360 \
	>"$collision/enet.log" 2>&1 &
enet_pid=$!
sleep 0.8
"$godot_bin" --headless --path "$project_root" -- --client --transport webrtc \
	--signal-url "ws://127.0.0.1:$((collision_port + 1))" --name colliding \
	--ticks 600 >"$collision/rtc.log" 2>&1 &
rtc_pid=$!

wait "$enet_pid"; enet_pid=""
wait "$server_pid"; server_pid=""
kill "$rtc_pid" >/dev/null 2>&1 || true
wait "$rtc_pid" 2>/dev/null || true
rtc_pid=""

collision_id="$(sed -nE 's/.*PEER-ID COLLISION id=([0-9]+).*/\1/p' \
	"$collision/server.log" | head -1)"
established_id="$(sed -nE 's/.*peer_connected id=([0-9]+) transport=enet.*/\1/p' \
	"$collision/server.log" | head -1)"
join_count="$(rg -c 'PEER_JOIN id=' "$collision/server.log" || true)"
if [[ -z "$collision_id" || "$collision_id" != "$established_id" || "$join_count" -ne 1 ]]; then
	echo "Cross-transport peer-ID collision was not contained; logs: $log_dir" >&2
	exit 1
fi
if ! rg -q 'CLIENT_TICK tick=360' "$collision/enet.log"; then
	echo "Established ENet peer did not survive collision rejection; logs: $log_dir" >&2
	exit 1
fi

# Closing an unused transport listener must not interrupt a live client on the
# other leg. These are server-door failures, distinct from an ordinary leave.
for closed_transport in webrtc enet; do
	control="$log_dir/close-$closed_transport"
	mkdir -p "$control"
	if [[ "$closed_transport" == "webrtc" ]]; then
		control_port=$((base_port + 20))
	else
		control_port=$((base_port + 30))
	fi
	"$godot_bin" --headless --path "$project_root" -- --server --transport mux \
		--mux-close-transport-test "$closed_transport" --port "$control_port" \
		--signal-port "$((control_port + 1))" --no-drone --ticks 480 \
		>"$control/server.log" 2>&1 &
	server_pid=$!
	sleep 0.8
	if [[ "$closed_transport" == "webrtc" ]]; then
		"$godot_bin" --headless --path "$project_root" -- --client --host 127.0.0.1 \
			--port "$control_port" --name survivor --script right --ticks 300 \
			>"$control/client.log" 2>&1 &
	else
		"$godot_bin" --headless --path "$project_root" -- --client --transport webrtc \
			--signal-url "ws://127.0.0.1:$((control_port + 1))" --name survivor \
			--script right --ticks 300 >"$control/client.log" 2>&1 &
	fi
	enet_pid=$!
	wait "$enet_pid"; enet_pid=""
	wait "$server_pid"; server_pid=""
	if ! rg -q "MUX_TEST_CLOSED transport=$closed_transport tick=180" "$control/server.log" \
			|| ! rg -q 'CLIENT_TICK tick=300' "$control/client.log"; then
		echo "$closed_transport-down control interrupted the surviving leg; logs: $log_dir" >&2
		exit 1
	fi
	if rg -q 'SCRIPT ERROR|Parse Error|Invalid call|Invalid get index' "$control"/*.log; then
		echo "$closed_transport-down control emitted a runtime error; logs: $log_dir" >&2
		exit 1
	fi
done

echo "MIXED_TRANSPORT_TEST PASS ids=$enet_id,$rtc_id worst_correction=$worst_error"
echo "logs: $log_dir"
