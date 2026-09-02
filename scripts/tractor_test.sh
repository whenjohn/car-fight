#!/bin/zsh
set -euo pipefail

project_root="$(cd "$(dirname "$0")/.." && pwd)"
godot_bin="${GODOT_BIN:-/Applications/Godot47.app/Contents/MacOS/Godot}"
port="${CAR_FIGHT_TRACTOR_TEST_PORT:-10680}"
log_dir="$(mktemp -d "${TMPDIR:-/tmp}/car-fight-tractor.XXXXXX")"
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

"$godot_bin" --headless --path "$project_root" -- --server --no-drone --port "$port" \
	--ticks 420 >"$log_dir/server.log" 2>&1 &
server_pid=$!
sleep 0.8
"$godot_bin" --headless --path "$project_root" -- --client --host 127.0.0.1 \
	--port "$port" --name hauler --script tractor --ticks 500 \
	>"$log_dir/client.log" 2>&1 &
client_pid=$!

if ! wait "$server_pid"; then
	echo "tractor server failed; logs: $log_dir" >&2
	tail -100 "$log_dir/server.log" >&2
	exit 1
fi
server_pid=""
wait "$client_pid" || true
client_pid=""

result_line="$(rg 'RESULT players=1 .*tractorgrabs=' "$log_dir/server.log" | tail -1)"
if [[ -z "$result_line" ]]; then
	echo "tractor test produced no server result; logs: $log_dir" >&2
	exit 1
fi
grabs="$(print -r -- "$result_line" | sed -E 's/.*tractorgrabs=([0-9]+).*/\1/')"
ticks="$(print -r -- "$result_line" | sed -E 's/.*tractorticks=([0-9]+).*/\1/')"
if [[ "$grabs" -lt 1 || "$ticks" -lt 30 ]]; then
	echo "vacuum did not pull the authoritative ball: grabs=$grabs ticks=$ticks" >&2
	tail -100 "$log_dir/server.log" >&2
	exit 1
fi
if ! print -r -- "$result_line" | rg -q 'shots=[1-9][0-9]*'; then
	echo "auto-fire stopped while the tractor vacuum was held: $result_line" >&2
	exit 1
fi
if ! print -r -- "$result_line" | rg -q 'ballhits=[1-9][0-9]*'; then
	echo "auto-fire did not acquire and hit the vacuumed ball: $result_line" >&2
	exit 1
fi
if rg -q 'SCRIPT ERROR|Parse Error|Trying to run rollback .*past the history limit' "$log_dir"/*.log; then
	echo "tractor produced a runtime or rollback-history error; logs: $log_dir" >&2
	rg 'SCRIPT ERROR|Parse Error|Trying to run rollback .*past the history limit' "$log_dir"/*.log >&2
	exit 1
fi

echo "TRACTOR_TEST PASS grabs=$grabs reel_ticks=$ticks: $result_line"
echo "logs: $log_dir"
