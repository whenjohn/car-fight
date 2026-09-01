#!/bin/zsh
set -euo pipefail

project_root="$(cd "$(dirname "$0")/.." && pwd)"
godot_bin="${GODOT_BIN:-/Applications/Godot.app/Contents/MacOS/Godot}"
server_port="${CAR_FIGHT_REVERSE_TEST_PORT:-10680}"
log_dir="$(mktemp -d "${TMPDIR:-/tmp}/car-fight-reverse.XXXXXX")"
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

"$godot_bin" --headless --path "$project_root" -- --server --no-drone --port "$server_port" \
	--reverse-test --ticks 240 >"$log_dir/server.log" 2>&1 &
server_pid=$!
sleep 0.8
"$godot_bin" --headless --path "$project_root" -- --client --host 127.0.0.1 --port "$server_port" \
	--name reverser --script reverse --ticks 320 >"$log_dir/client.log" 2>&1 &
client_pid=$!

if ! wait "$server_pid"; then
	echo "reverse test server failed; logs: $log_dir" >&2
	tail -80 "$log_dir/server.log" >&2
	exit 1
fi
server_pid=""
wait "$client_pid" || true
client_pid=""

result_line="$(rg 'RESULT players=1 .*minx=' "$log_dir/server.log" | tail -1)"
min_x="$(print -r -- "$result_line" | sed -E 's/.*minx=([-0-9.]+).*/\1/')"
city_half="$(sed -nE 's/^const CITY_HALF_EXTENT := ([0-9.]+)$/\1/p' \
	"$project_root/world/map_layout.gd")"
if [[ -z "$result_line" || -z "$city_half" ]] \
		|| ! awk -v value="$min_x" -v edge="$city_half" \
		'BEGIN { exit !(value <= edge - 8.0) }'; then
	echo "reverse did not back the wall-facing car clear: min x $min_x; logs: $log_dir" >&2
	tail -100 "$log_dir/server.log" >&2
	exit 1
fi
if rg -q 'SCRIPT ERROR|Parse Error|Trying to run rollback .*past the history limit' "$log_dir"/*.log; then
	echo "reverse produced a runtime or rollback-history error; logs: $log_dir" >&2
	rg 'SCRIPT ERROR|Parse Error|Trying to run rollback .*past the history limit' "$log_dir"/*.log >&2
	exit 1
fi

echo "REVERSE_TEST PASS: $result_line"
echo "logs: $log_dir"
