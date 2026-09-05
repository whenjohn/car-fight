#!/bin/zsh
# Headless moving-join characterization. PASS means complete evidence, not smooth-play acceptance.
set -euo pipefail
project_root="$(cd "$(dirname "$0")/.." && pwd)"
godot_bin="${GODOT_BIN:-/Applications/Godot47.app/Contents/MacOS/Godot}"
server_port="${CAR_FIGHT_STARTUP_TEST_PORT:-11980}"
log_dir="$(mktemp -d "${TMPDIR:-/tmp}/car-fight-startup.XXXXXX")"
server_pid=""
client_pid=""

cleanup() {
	for process_id in "$client_pid" "$server_pid"; do
		if [[ -n "$process_id" ]]; then
			kill "$process_id" 2>/dev/null || true
			wait "$process_id" 2>/dev/null || true
		fi
	done
}
trap cleanup EXIT
trap 'exit 130' INT TERM
echo "startup trace logs: $log_dir"

for stall_ms in 0 6000; do
	case_dir="$log_dir/stall-$stall_ms"
	mkdir "$case_dir"
	"$godot_bin" --headless --max-fps 60 --path "$project_root" -- \
		--server --no-drone --port "$server_port" --ticks 1800 >"$case_dir/server.log" 2>&1 &
	server_pid=$!
	deadline=$((SECONDS + 10))
	until rg -q 'SERVER_READY' "$case_dir/server.log"; do
		if ! kill -0 "$server_pid" 2>/dev/null || (( SECONDS >= deadline )); then
			echo "startup server failed readiness; logs: $case_dir" >&2
			exit 1
		fi
		sleep 0.1
	done
	CAR_FIGHT_NETWORK_DIAGNOSTICS_SECONDS=25 CAR_FIGHT_STARTUP_TRACE_SECONDS=25 \
	CAR_FIGHT_NETWORK_STAGE_TRACE_PATH="$case_dir/startup.jsonl" \
	CAR_FIGHT_JOIN_STALL_MS="$stall_ms" CAR_FIGHT_JOIN_STALL_AFTER_MS=500 \
		"$godot_bin" --headless --max-fps 60 --path "$project_root" -- \
		--client --host 127.0.0.1 --port "$server_port" --name startup \
		--script right --ticks 600 >"$case_dir/client.log" 2>&1 &
	client_pid=$!
	deadline=$((SECONDS + 25))
	while kill -0 "$client_pid" 2>/dev/null; do
		if (( SECONDS >= deadline )); then
			kill -KILL "$client_pid" 2>/dev/null || true
			echo "startup client timed out; logs: $case_dir" >&2
			exit 1
		fi
		sleep 0.1
	done
	wait "$client_pid"
	client_pid=""
	cleanup
	server_pid=""
	if rg -n 'ERROR:|SCRIPT ERROR|Parse Error|Invalid call|Failed to load script' "$case_dir"/*.log; then
		echo "startup trace runtime error; logs: $case_dir" >&2
		exit 1
	fi
	if (( stall_ms > 0 )); then
		[[ "$(rg -c 'JOINSTALL begin' "$case_dir/client.log")" == 1 ]]
		[[ "$(rg -c 'JOINSTALL end' "$case_dir/client.log")" == 1 ]]
		rg -q 'Game stalled for' "$case_dir/client.log"
	fi
	node "$project_root/scripts/network_startup_report.mjs" "$case_dir/startup.jsonl" >"$case_dir/report.json"
	node --input-type=module - "$case_dir/startup.jsonl" <<'JS'
import fs from 'node:fs';
import assert from 'node:assert/strict';
const rows = fs.readFileSync(process.argv[2], 'utf8').trim().split('\n').map(JSON.parse);
const samples = rows.filter(r => r.event === 'startup_sample');
assert(rows.some(r => r.event === 'startup_sync'), 'initial sync not observed');
assert(samples.length >= 30, 'insufficient startup samples');
assert(samples.some(r => r.recorded_cursor?.[0] > 0), 'moving input not observed');
const first = samples[0].physics.position;
assert(samples.some(r => Math.hypot(...r.physics.position.map((v, i) => v - first[i])) > 1), 'no actual movement');
JS
	echo "STARTUP_TRACE_CASE PASS stall_ms=$stall_ms evidence=$case_dir/report.json"
done
echo "STARTUP_TRACE_TEST PASS moving join and post-sync stall captured; not rendered acceptance"
