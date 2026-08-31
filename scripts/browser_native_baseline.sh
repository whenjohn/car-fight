#!/bin/zsh
# Measure the Phase-2 CPU/render control: one offline Web client plus one
# native ENet client on this Mac. This deliberately proves co-residency only;
# the two clients are not connected to each other yet.
set -euo pipefail
unsetopt BG_NICE

project_root="$(cd "$(dirname "$0")/.." && pwd)"
godot_bin="${GODOT_BIN:-/Applications/Godot.app/Contents/MacOS/Godot}"
native_port="${CAR_FIGHT_NATIVE_BASELINE_PORT:-10180}"
web_port="${CAR_FIGHT_WEB_BASELINE_PORT:-18088}"
run_stamp="$(date '+%Y%m%d-%H%M%S')"
run_root="${CAR_FIGHT_BASELINE_ROOT:-$project_root/.crash-runs/browser-native-$run_stamp}"
web_server_pid=""
native_runner_pid=""

if [[ ! -x "$godot_bin" ]]; then
	echo "Godot not found: $godot_bin" >&2
	exit 2
fi

cleanup() {
	for pid in "$native_runner_pid" "$web_server_pid"; do
		if [[ "$pid" == <-> ]] && (( pid > 1 )); then
			kill "$pid" >/dev/null 2>&1 || true
		fi
	done
	wait 2>/dev/null || true
}
trap cleanup EXIT INT TERM

mkdir -p "$run_root/native"
echo "baseline: preparing Web export"

# Complete all import/export work before measuring the concurrent clients.
"$project_root/scripts/web_build.sh" release >"$run_root/web-build.log" 2>&1
CAR_FIGHT_WEB_PORT="$web_port" "$project_root/scripts/web_serve.sh" \
	>"$run_root/web-server.log" 2>&1 &
web_server_pid=$!
echo "baseline: waiting for Web server on $web_port"
for _attempt in {1..100}; do
	if curl -fs -o /dev/null "http://127.0.0.1:$web_port/"; then
		break
	fi
	if ! kill -0 "$web_server_pid" >/dev/null 2>&1; then
		echo "Web server exited early; see $run_root/web-server.log" >&2
		exit 1
	fi
	sleep 0.05
done
if ! curl -fs -o /dev/null "http://127.0.0.1:$web_port/"; then
	echo "Web server did not become ready; see $run_root/web-server.log" >&2
	exit 1
fi

CAR_FIGHT_PORT="$native_port" CAR_FIGHT_MONITOR_ROOT="$run_root/native" \
	"$project_root/scripts/play_monitored.sh" --name browser-baseline \
	--local \
	--position 80,80 >"$run_root/native-runner.log" 2>&1 &
native_runner_pid=$!
echo "baseline: waiting for native client telemetry"

# Wait until the client telemetry exists, not an arbitrary renderer delay.
for _attempt in {1..100}; do
	if [[ -f "$run_root/native/last_run" ]]; then
		native_dir="$(<"$run_root/native/last_run")"
		if [[ -f "$native_dir/client.telemetry.jsonl" ]]; then
			break
		fi
	fi
	if ! kill -0 "$native_runner_pid" >/dev/null 2>&1; then
		echo "Native monitor exited early; see $run_root/native-runner.log" >&2
		exit 1
	fi
	sleep 0.1
done

echo "baseline: running concurrent browser smoke"
node "$project_root/scripts/web_smoke.mjs" "http://127.0.0.1:$web_port/" \
	"$run_root/browser-report.json" "$run_root/browser.png" \
	| tee "$run_root/browser.log"

native_dir="$(<"$run_root/native/last_run")"
cp "$native_dir/client.telemetry.jsonl" "$run_root/native-client.telemetry.jsonl"
cp "$native_dir/process-samples.log" "$run_root/native-process-samples.log"

echo "BROWSER_NATIVE_BASELINE PASS"
echo "evidence: $run_root"
