#!/bin/zsh
set -euo pipefail
unsetopt BG_NICE

project_root="$(cd "$(dirname "$0")/.." && pwd)"
test_root="$(mktemp -d "${TMPDIR:-/tmp}/car-fight-monitor-test.XXXXXX")"
test_port="${CAR_FIGHT_MONITOR_TEST_PORT:-10190}"

CAR_FIGHT_MONITOR_ROOT="$test_root" CAR_FIGHT_PORT="$test_port" \
	"$project_root/scripts/play_monitored.sh" --headless --ticks 180 --fake-stall

run_dir="$(< "$test_root/last_run")"
if [[ "$(< "$run_dir/state")" != "clean" ]]; then
	echo "CRASH_MONITOR_TEST FAIL: simulated stall did not recover cleanly" >&2
	exit 1
fi
if ! rg -q '"event":"fake_stall_begin"' "$run_dir/client.telemetry.jsonl" \
		|| ! rg -q '"event":"fake_stall_end"' "$run_dir/client.telemetry.jsonl"; then
	echo "CRASH_MONITOR_TEST FAIL: telemetry did not bracket the simulated stall" >&2
	exit 1
fi
sample_files=("$run_dir"/client-stall-*.sample.txt(N))
if (( ${#sample_files} == 0 )); then
	echo "CRASH_MONITOR_TEST FAIL: external watcher did not capture a stall sample" >&2
	exit 1
fi
if ! rg -q 'Process:|Call graph:|Sampling process' "${sample_files[1]}"; then
	echo "CRASH_MONITOR_TEST FAIL: stall sample has no process stack" >&2
	exit 1
fi

echo "CRASH_MONITOR_TEST PASS simulated=7s samples=${#sample_files}"
echo "evidence: $run_dir"
