#!/bin/zsh
# Headless moving-join characterization. PASS means complete evidence, not smooth-play acceptance.
set -euo pipefail
project_root="$(cd "$(dirname "$0")/.." && pwd)"
godot_bin="${GODOT_BIN:-/Applications/Godot47.app/Contents/MacOS/Godot}"
server_port="${CAR_FIGHT_STARTUP_TEST_PORT:-11980}"
log_dir="$(mktemp -d "${TMPDIR:-/tmp}/car-fight-startup.XXXXXX")"
server_pid=""
client_pid=""
mode="${1:-stall}"
cases=(0 6000)
duration=25
client_ticks=600
entry_args=()
if [[ "$mode" == "--clock-recovery" ]]; then
	cases=(0 1)
	duration=45
	client_ticks=1800
	entry_args=(--script res://tests/fixtures/startup_stale_clock.gd)
elif [[ "$mode" != "stall" ]]; then
	echo "Usage: $0 [--clock-recovery]" >&2
	exit 1
fi

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

for case_value in "${cases[@]}"; do
	stall_ms="$case_value"
	recovery="${CAR_FIGHT_FORWARD_CLOCK_RECOVERY:-0}"
	case_dir="$log_dir/stall-$case_value"
	if [[ "$mode" == "--clock-recovery" ]]; then
		stall_ms=0
		recovery="$case_value"
		case_dir="$log_dir/recovery-$case_value"
	fi
	mkdir "$case_dir"
	"$godot_bin" --headless --max-fps 60 --path "$project_root" -- \
		--server --no-drone --port "$server_port" --ticks 3600 >"$case_dir/server.log" 2>&1 &
	server_pid=$!
	deadline=$((SECONDS + 10))
	until rg -q 'SERVER_READY' "$case_dir/server.log"; do
		if ! kill -0 "$server_pid" 2>/dev/null || (( SECONDS >= deadline )); then
			echo "startup server failed readiness; logs: $case_dir" >&2
			exit 1
		fi
		sleep 0.1
	done
	if [[ "$mode" == "--clock-recovery" ]]; then sleep 6; fi
	CAR_FIGHT_NETWORK_DIAGNOSTICS_SECONDS="$duration" CAR_FIGHT_STARTUP_TRACE_SECONDS="$duration" \
	CAR_FIGHT_NETWORK_STAGE_TRACE_PATH="$case_dir/startup.jsonl" \
	CAR_FIGHT_FORWARD_CLOCK_RECOVERY="$recovery" \
	CAR_FIGHT_JOIN_STALL_MS="$stall_ms" CAR_FIGHT_JOIN_STALL_AFTER_MS=500 \
		"$godot_bin" --headless --max-fps 60 --path "$project_root" "${entry_args[@]}" -- \
		--client --host 127.0.0.1 --port "$server_port" --name startup \
		--script right --ticks "$client_ticks" >"$case_dir/client.log" 2>&1 &
	client_pid=$!
	deadline=$((SECONDS + duration))
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
	if rg -n 'ERROR:|SCRIPT ERROR|Parse Error|Invalid call|Failed to load script|STARTUP_SEED_FAIL' "$case_dir"/*.log; then
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
	if [[ "$mode" == "--clock-recovery" ]]; then
		rg -q 'STARTUP_SEED offset=-4.7234838' "$case_dir/client.log"
		rg -q 'above panic threshold' "$case_dir/client.log"
	fi
	echo "STARTUP_TRACE_CASE PASS stall_ms=$stall_ms recovery=$recovery evidence=$case_dir/report.json"
done
if [[ "$mode" == "--clock-recovery" ]]; then
	node --input-type=module - "$log_dir" <<'JS'
import fs from 'node:fs';
import assert from 'node:assert/strict';
const dir = process.argv[2];
const read = enabled => JSON.parse(fs.readFileSync(`${dir}/recovery-${enabled}/report.json`, 'utf8'));
const before = read(0), after = read(1);
assert(before.return_to_first_pose_count >= 2, 'control did not reproduce repeated returns to first pose');
const rows = fs.readFileSync(`${dir}/recovery-1/startup.jsonl`, 'utf8').trim().split('\n').map(JSON.parse);
const panic = rows.find(r => r.event === 'startup_panic');
assert(panic, 'missing actual clock correction');
const settled = rows.filter(r => r.event === 'startup_sample' && r.mono_usec > panic.mono_usec + 500000);
assert(settled.length > 300, 'insufficient post-recovery movement');
assert(settled.every(r => Math.abs(r.reference_seconds - r.tick / r.tickrate) < .1), 'timeline did not stay aligned');
const log = fs.readFileSync(`${dir}/recovery-1/client.log`, 'utf8');
assert.equal((log.match(/Forward clock recovery:/g) ?? []).length, 1, 'expected exactly one forward rebase');
assert(!fs.readFileSync(`${dir}/recovery-0/client.log`, 'utf8').includes('Forward clock recovery:'), 'control unexpectedly rebased');
console.log(`STARTUP_CLOCK_TIMELINE PASS; return candidates=${before.return_to_first_pose_count}->${after.return_to_first_pose_count}`);
assert(after.return_to_first_pose_count === 0, 'recovery still returned to first pose');
console.log(`STARTUP_CLOCK_RECOVERY_TEST PASS returns=${before.return_to_first_pose_count}->${after.return_to_first_pose_count}; rendered acceptance pending`);
JS
else
	echo "STARTUP_TRACE_TEST PASS moving join and post-sync stall captured; not rendered acceptance"
fi
