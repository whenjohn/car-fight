#!/bin/zsh
# Keep one client live while a second disconnects and rejoins. This exercises
# replicated player teardown, detached input callbacks, and clean replacement.
set -euo pipefail

project_root="$(cd "$(dirname "$0")/.." && pwd)"
godot_bin="${GODOT_BIN:-/Applications/Godot.app/Contents/MacOS/Godot}"
server_port="${CAR_FIGHT_RECONNECT_TEST_PORT:-11080}"
log_dir="$(mktemp -d "${TMPDIR:-/tmp}/car-fight-reconnect.XXXXXX")"
server_pid=""
survivor_pid=""
leaver_pid=""
replacement_pid=""

cleanup() {
	for process_id in "$replacement_pid" "$leaver_pid" "$survivor_pid" "$server_pid"; do
		if [[ -n "$process_id" ]]; then
			kill "$process_id" >/dev/null 2>&1 || true
		fi
	done
}
trap cleanup EXIT INT TERM

# Leave enough tail room for the replacement client after larger presentation
# libraries have completed their first process-local resource scan.
"$godot_bin" --headless --path "$project_root" -- \
	--server --no-drone --port "$server_port" --ticks 900 \
	>"$log_dir/server.log" 2>&1 &
server_pid=$!
sleep 0.8
"$godot_bin" --headless --path "$project_root" -- \
	--client --host 127.0.0.1 --port "$server_port" --name survivor --ticks 800 \
	>"$log_dir/survivor.log" 2>&1 &
survivor_pid=$!
sleep 0.4
"$godot_bin" --headless --path "$project_root" -- \
	--client --host 127.0.0.1 --port "$server_port" --name cycler --ticks 90 \
	>"$log_dir/leaver.log" 2>&1 &
leaver_pid=$!

if ! wait "$leaver_pid"; then
	echo "first cycler client failed; logs: $log_dir" >&2
	tail -80 "$log_dir/leaver.log" >&2
	exit 1
fi
leaver_pid=""
sleep 1.2
"$godot_bin" --headless --path "$project_root" -- \
	--client --host 127.0.0.1 --port "$server_port" --name cycler --ticks 300 \
	>"$log_dir/replacement.log" 2>&1 &
replacement_pid=$!

if ! wait "$replacement_pid"; then
	echo "replacement cycler client failed; logs: $log_dir" >&2
	tail -80 "$log_dir/replacement.log" >&2
	exit 1
fi
replacement_pid=""
if ! wait "$survivor_pid"; then
	echo "survivor client failed across disconnect/reconnect; logs: $log_dir" >&2
	tail -100 "$log_dir/survivor.log" >&2
	exit 1
fi
survivor_pid=""
if ! wait "$server_pid"; then
	echo "reconnect server failed; logs: $log_dir" >&2
	tail -100 "$log_dir/server.log" >&2
	exit 1
fi
server_pid=""

joins="$(rg -c 'PEER_JOIN id=' "$log_dir/server.log" || true)"
leaves="$(rg -c 'PEER_LEAVE id=' "$log_dir/server.log" || true)"
if [[ "${joins:-0}" -ne 3 || "${leaves:-0}" -lt 2 ]]; then
	echo "server did not observe survivor plus disconnect/reconnect: joins=${joins:-0} leaves=${leaves:-0}; logs: $log_dir" >&2
	exit 1
fi
if ! rg -q 'CLIENT_TICK tick=.*players=2 world=[^|]+\|[^ ]+' "$log_dir/survivor.log" \
		|| ! rg -q 'CLIENT_TICK tick=.*players=1 world=[^| ]+ ' "$log_dir/survivor.log"; then
	echo "survivor did not observe both teardown and replacement topology; logs: $log_dir" >&2
	tail -120 "$log_dir/survivor.log" >&2
	exit 1
fi
two_player_samples="$(rg -c 'CLIENT_TICK tick=.*players=2 world=[^|]+\|[^ ]+' "$log_dir/survivor.log" || true)"
if [[ "${two_player_samples:-0}" -lt 2 ]] \
		|| ! rg -q 'CLIENT_TICK tick=3[0-9][0-9].*players=2' "$log_dir/replacement.log"; then
	echo "replacement did not rejoin the survivor's world cleanly; logs: $log_dir" >&2
	tail -100 "$log_dir/survivor.log" >&2
	tail -100 "$log_dir/replacement.log" >&2
	exit 1
fi
known_shutdown_warning='ERROR: 1 resources still in use at exit'
known_shutdown_warnings="$(rg -c "$known_shutdown_warning" "$log_dir"/*.log \
	| awk -F: '{ total += $NF } END { print total + 0 }')"
unexpected_errors="$(rg -n 'ERROR:|SCRIPT ERROR|Parse Error|Invalid call|Invalid get index|Parameter .* is null|Node not found|Failed to get path from RPC' \
		"$log_dir"/*.log | rg -v "$known_shutdown_warning" || true)"
if [[ -n "$unexpected_errors" ]]; then
	echo "disconnect/reconnect produced a runtime or detached-node error; logs: $log_dir" >&2
	print -r -- "$unexpected_errors" >&2
	exit 1
fi

echo "RECONNECT_TEST PASS joins=${joins:-0} leaves=${leaves:-0} survivor_two_player_samples=${two_player_samples:-0}"
echo "known Godot 4.6 shutdown warnings: $known_shutdown_warnings"
echo "logs: $log_dir"
