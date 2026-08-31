#!/bin/zsh
set -euo pipefail

project_root="$(cd "$(dirname "$0")/.." && pwd)"
godot_bin="${GODOT_BIN:-/Applications/Godot.app/Contents/MacOS/Godot}"
port="${CAR_FIGHT_DET_PORT:-10780}"
log_dir="$(mktemp -d "${TMPDIR:-/tmp}/car-fight-det.XXXXXX")"
server_pid=""
client_pid=""

cleanup() {
	for process_id in "$client_pid" "$server_pid"; do
		[[ -n "$process_id" ]] && kill "$process_id" >/dev/null 2>&1 || true
	done
}
trap cleanup EXIT INT TERM

"$godot_bin" --headless --path "$project_root" -- --server --port "$port" --ticks 420 \
	>"$log_dir/server.log" 2>&1 &
server_pid=$!
sleep 0.8
"$godot_bin" --headless --path "$project_root" -- --client --host 127.0.0.1 --port "$port" \
	--name det --script det --ticks 500 >"$log_dir/client.log" 2>&1 &
client_pid=$!
wait "$server_pid"
server_pid=""
kill "$client_pid" >/dev/null 2>&1 || true
client_pid=""

result="$(rg 'RESULT players=1' "$log_dir/server.log" | tail -1)"
if [[ -z "$result" ]] || ! print -r -- "$result" | rg -q 'droneshots=[1-9][0-9]* .*dets=[1-9][0-9]* .*impacthits=0 shieldhits=0'; then
	echo "det did not nullify authoritative drone bolts: $result; logs: $log_dir" >&2
	exit 1
fi
if ! rg -q 'CLIENT_TICK .*cloak=0 shield=0' "$log_dir/client.log"; then
	echo "det client did not connect cleanly; logs: $log_dir" >&2
	exit 1
fi
if rg -q 'SCRIPT ERROR|Parse Error|Invalid call|Invalid get index' "$log_dir"/*.log; then
	rg 'SCRIPT ERROR|Parse Error|Invalid call|Invalid get index' "$log_dir"/*.log >&2
	exit 1
fi
echo "DET_TEST PASS: $result"
echo "logs: $log_dir"
