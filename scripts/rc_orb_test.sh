#!/bin/zsh
set -euo pipefail

project_root="$(cd "$(dirname "$0")/.." && pwd)"
godot_bin="${GODOT_BIN:-/Applications/Godot.app/Contents/MacOS/Godot}"
port="${CAR_FIGHT_RC_ORB_PORT:-10880}"
log_dir="$(mktemp -d "${TMPDIR:-/tmp}/car-fight-rc-orb.XXXXXX")"
server_pid=""
client_pid=""

cleanup() {
	for process_id in "$client_pid" "$server_pid"; do
		[[ -n "$process_id" ]] && kill "$process_id" >/dev/null 2>&1 || true
	done
}
trap cleanup EXIT INT TERM

"$godot_bin" --headless --path "$project_root" -- --server --no-drone --port "$port" \
	--ticks 270 >"$log_dir/server.log" 2>&1 &
server_pid=$!
sleep 0.8
"$godot_bin" --headless --path "$project_root" -- --client --host 127.0.0.1 --port "$port" \
	--name rc-orb --script rc-orb --ticks 300 >"$log_dir/client.log" 2>&1 &
client_pid=$!
wait "$server_pid"
server_pid=""
kill "$client_pid" >/dev/null 2>&1 || true
client_pid=""

if ! rg -q 'RCSPAWN ' "$log_dir/server.log" || ! rg -q 'RCDET .*reason=manual' "$log_dir/server.log"; then
	echo "RC orb did not fire and manually detonate; logs: $log_dir" >&2
	exit 1
fi
if ! rg -q 'RESULT players=1 .*rcshots=[1-9][0-9]* rcdets=[1-9][0-9]*' "$log_dir/server.log"; then
	echo "RC orb result counters are missing; logs: $log_dir" >&2
	exit 1
fi
if rg -q 'SCRIPT ERROR|Parse Error|Invalid call|Invalid get index' "$log_dir"/*.log; then
	rg 'SCRIPT ERROR|Parse Error|Invalid call|Invalid get index' "$log_dir"/*.log >&2
	exit 1
fi
echo "RC_ORB_TEST PASS logs: $log_dir"
