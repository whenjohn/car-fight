#!/bin/zsh
set -euo pipefail
project_root="$(cd "$(dirname "$0")/.." && pwd)"
godot_bin="${GODOT_BIN:-/Applications/Godot47.app/Contents/MacOS/Godot}"
port="${CAR_FIGHT_SPRITE_AI_TEST_PORT:-13984}"
transport="${1:-enet}"
logs="$(mktemp -d "${TMPDIR:-/tmp}/car-fight-sprite-ai-network.XXXXXX")"
pids=()
cleanup() {
	for pid in "${pids[@]}"; do
		kill "$pid" >/dev/null 2>&1 || true
	done
}
trap cleanup EXIT INT TERM
server_args=(--transport enet)
observer_args=(--host 127.0.0.1 --port "$port")
if [[ "$transport" == mux ]]; then
	server_args=(--transport mux --signal-port "$((port + 1))")
	observer_args=(--transport webrtc --signal-url "ws://127.0.0.1:$((port + 1))")
elif [[ "$transport" != enet ]]; then
	echo "usage: $0 [enet|mux]" >&2
	exit 2
fi
CAR_FIGHT_SPRITE_AI=mixed "$godot_bin" --headless --path "$project_root" \
	--script res://scripts/sprite_ai_network_fixture.gd -- --server "${server_args[@]}" \
	--port "$port" --sprite-test --no-drone --net-telemetry --sprite-network-role=server >"$logs/server.log" 2>&1 &
pids+=($!)
sleep 0.8
"$godot_bin" --headless --path "$project_root" --script res://scripts/sprite_ai_network_fixture.gd -- \
	--client --host 127.0.0.1 --port "$port" --no-drone --net-telemetry --sprite-network-role=owner >"$logs/owner.log" 2>&1 &
pids+=($!)
sleep 1.5
"$godot_bin" --headless --path "$project_root" --script res://scripts/sprite_ai_network_fixture.gd -- \
	--client "${observer_args[@]}" --no-drone --net-telemetry --sprite-network-role=observer >"$logs/observer.log" 2>&1 &
pids+=($!)
failed=0
for pid in "${pids[@]}"; do
	wait "$pid" || failed=1
done
pids=()
for role in server owner observer; do
	if ! rg -q "SPRITE_AI_NETWORK PASS role=$role" "$logs/$role.log"; then
		failed=1
	fi
done
if rg -q 'ERROR:|SCRIPT ERROR|Parse Error|Compile Error|above the MTU' "$logs"/*.log; then
	failed=1
fi
rg 'SPRITE_AI_NETWORK_COST' "$logs/server.log" || true
if (( failed )); then
	echo "SPRITE_AI_NETWORK_TEST FAIL transport=$transport logs=$logs" >&2
	rg -m 6 'ERROR:|SCRIPT ERROR|SPRITE_AI_NETWORK FAIL' "$logs"/*.log >&2 || true
	exit 1
fi
echo "SPRITE_AI_NETWORK_TEST PASS transport=$transport logs=$logs"
