#!/bin/zsh
set -euo pipefail
project_root="$(cd "$(dirname "$0")/.." && pwd)"
godot_bin="${GODOT_BIN:-/Applications/Godot47.app/Contents/MacOS/Godot}"
port="${CAR_FIGHT_SPRITE_TEST_PORT:-10984}"
logs="$(mktemp -d "${TMPDIR:-/tmp}/car-fight-sprite-network.XXXXXX")"
pids=()
cleanup() {
	for pid in "${pids[@]}"; do
		kill "$pid" >/dev/null 2>&1 || true
	done
}
trap cleanup EXIT INT TERM
"$godot_bin" --headless --path "$project_root" --script res://scripts/sprite_network_fixture.gd -- \
	--server --port "$port" --sprite-test --no-drone --sprite-network-role=server >"$logs/server.log" 2>&1 &
pids+=($!)
sleep 0.8
"$godot_bin" --headless --path "$project_root" --script res://scripts/sprite_network_fixture.gd -- \
	--client --host 127.0.0.1 --port "$port" --no-drone --sprite-network-role=owner >"$logs/owner.log" 2>&1 &
pids+=($!)
sleep 5
"$godot_bin" --headless --path "$project_root" --script res://scripts/sprite_network_fixture.gd -- \
	--client --host 127.0.0.1 --port "$port" --no-drone --sprite-network-role=observer >"$logs/observer.log" 2>&1 &
pids+=($!)
failed=0
for pid in "${pids[@]}"; do
	wait "$pid" || failed=1
done
pids=()
for role in server owner observer; do
	if ! rg -q "SPRITE_NETWORK_FIXTURE PASS role=$role" "$logs/$role.log"; then
		failed=1
	fi
done
if rg -q 'SCRIPT ERROR|Parse Error|Compile Error|SPRITE_NETWORK_FIXTURE FAIL|above the MTU' "$logs"/*.log; then
	failed=1
fi
if (( failed )); then
	echo "SPRITE_NETWORK_TEST FAIL logs=$logs" >&2
	tail -35 "$logs"/*.log >&2
	exit 1
fi
echo "SPRITE_NETWORK_TEST PASS hit death late-join owner-control disable; logs=$logs"
