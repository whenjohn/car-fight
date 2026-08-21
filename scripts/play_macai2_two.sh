#!/bin/zsh
set -euo pipefail
unsetopt BG_NICE

project_root="$(cd "$(dirname "$0")/.." && pwd)"
host="${CAR_FIGHT_HOST:-100.113.2.60}"
port="${CAR_FIGHT_PORT:-10080}"
second_client_delay_seconds="${CAR_FIGHT_SECOND_CLIENT_DELAY_SECONDS:-3}"
run_stamp="$(date '+%Y%m%d-%H%M%S')"
run_root="$project_root/.crash-runs/two-client-$run_stamp"
alpha_runner_pid=""
bravo_runner_pid=""

mkdir -p "$run_root/alpha" "$run_root/bravo"

cleanup() {
	for runner_pid in "$alpha_runner_pid" "$bravo_runner_pid"; do
		if [[ "$runner_pid" == <-> ]] && (( runner_pid > 1 )); then
			kill "$runner_pid" >/dev/null 2>&1 || true
		fi
	done
	wait 2>/dev/null || true
}
trap cleanup EXIT INT TERM

CAR_FIGHT_PORT="$port" CAR_FIGHT_MONITOR_ROOT="$run_root/alpha" \
	"$project_root/scripts/play_monitored.sh" \
	--host "$host" --name alpha --position 80,100 &
alpha_runner_pid=$!

# Match G2's rendered latency-play safeguard: let the first window finish its
# initial shader/loading work before the second joins, so both netfox clocks do
# not cross the retained-history limit during simultaneous startup work.
sleep "$second_client_delay_seconds"

CAR_FIGHT_PORT="$port" CAR_FIGHT_MONITOR_ROOT="$run_root/bravo" \
	"$project_root/scripts/play_monitored.sh" \
	--host "$host" --name bravo --position 1520,100 &
bravo_runner_pid=$!

echo "two-client monitored run: $run_root"
echo "server: udp://$host:$port"
echo "second-client stagger: ${second_client_delay_seconds}s"
echo "close both game windows to finish"

set +e
wait "$alpha_runner_pid"
alpha_status=$?
alpha_runner_pid=""
wait "$bravo_runner_pid"
bravo_status=$?
bravo_runner_pid=""
set -e

echo "alpha status: $alpha_status"
echo "bravo status: $bravo_status"
echo "evidence: $run_root"
if (( alpha_status != 0 )); then
	exit "$alpha_status"
fi
exit "$bravo_status"
