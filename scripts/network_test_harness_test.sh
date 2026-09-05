#!/bin/zsh
set -euo pipefail

project_root="$(cd "$(dirname "$0")/.." && pwd)"
log_dir="$(mktemp -d "${TMPDIR:-/tmp}/car-fight-network-harness.XXXXXX")"
node --check "$project_root/tests/network_test_fake_godot.mjs"
for scenario in clean late-error bad-exit hang; do
	result=0
	GODOT_BIN="$project_root/tests/network_test_fake_godot.mjs" \
		CAR_FIGHT_HARNESS_CASE="$scenario" CAR_FIGHT_HARNESS_PID_LOG="$log_dir/$scenario.pids" \
		CAR_FIGHT_NETWORK_SHUTDOWN_TIMEOUT=2 \
		"$project_root/scripts/network_test.sh" clean >"$log_dir/$scenario.log" 2>&1 || result=$?
	if [[ "$scenario" == clean ]]; then
		if (( result != 0 )) || ! rg -q 'NETWORK_TEST PASS' "$log_dir/$scenario.log"; then
			echo "clean server-first shutdown was rejected; logs: $log_dir" >&2
			exit 1
		fi
	else
		if (( result == 0 )) || rg -q 'NETWORK_TEST PASS' "$log_dir/$scenario.log"; then
			echo "$scenario incorrectly passed; logs: $log_dir" >&2
			exit 1
		fi
		case "$scenario" in
			late-error) expected='runtime engine/script error' ;;
			bad-exit) expected='client exited unexpectedly (3)' ;;
			hang) expected='client shutdown timed out' ;;
		esac
		if ! rg -Fq "$expected" "$log_dir/$scenario.log"; then
			echo "$scenario failed for the wrong reason; logs: $log_dir" >&2
			exit 1
		fi
	fi
	while IFS= read -r process_id; do
		if kill -0 "$process_id" 2>/dev/null; then
			echo "$scenario leaked child $process_id; logs: $log_dir" >&2
			exit 1
		fi
	done < "$log_dir/$scenario.pids"
done
echo "NETWORK_TEST_HARNESS_TEST PASS clean=accepted late_error=rejected bad_exit=rejected hang=bounded children=reaped"
echo "logs: $log_dir"
