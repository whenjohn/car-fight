#!/bin/zsh
set -euo pipefail
unsetopt BG_NICE

project_root="$(cd "$(dirname "$0")/.." && pwd)"
godot_bin="${GODOT_BIN:-/Applications/Godot47.app/Contents/MacOS/Godot}"
port="${CAR_FIGHT_PORT:-10080}"
monitor_root="${CAR_FIGHT_MONITOR_ROOT:-$project_root/.crash-runs}"
headless=0
fullscreen=0
fake_stall=0
ticks=0
rendering_driver="${CAR_FIGHT_RENDERING_DRIVER:-}"

while (( $# > 0 )); do
	case "$1" in
		--headless)
			headless=1
			shift
			;;
		--fullscreen)
			fullscreen=1
			shift
			;;
		--fake-stall)
			fake_stall=1
			shift
			;;
		--ticks)
			ticks="${2:?--ticks requires a value}"
			shift 2
			;;
		--driver)
			rendering_driver="${2:?--driver requires a value}"
			shift 2
			;;
		*)
			echo "unknown option: $1" >&2
			exit 2
			;;
	esac
done

if [[ ! -x "$godot_bin" ]]; then
	echo "Godot not found: $godot_bin" >&2
	exit 2
fi
if (( headless == 0 && ticks > 0 )); then
	echo "--ticks is intended for the headless monitor check" >&2
	exit 2
fi
if (( headless == 1 && fullscreen == 1 )); then
	echo "--headless and --fullscreen cannot be combined" >&2
	exit 2
fi
if (( fake_stall == 1 && headless == 0 )); then
	echo "--fake-stall is restricted to --headless monitor tests" >&2
	exit 2
fi

run_stamp="$(date '+%Y%m%d-%H%M%S')"
run_dir="$monitor_root/$run_stamp"
mkdir -p "$run_dir"
print -r -- "$run_dir" > "$monitor_root/last_run"
touch "$run_dir/started.marker"

start_local="$(date '+%Y-%m-%d %H:%M:%S')"
start_epoch="$(date '+%s')"
initial_windowserver_pid="$(pgrep -x WindowServer | head -1 || true)"
initial_windowserver_pid="${initial_windowserver_pid:-unknown}"

{
	echo "state=active"
	echo "run_dir=$run_dir"
	echo "start_local=$start_local"
	echo "start_epoch=$start_epoch"
	echo "commit=$(git -C "$project_root" rev-parse HEAD)"
	echo "worktree_changes=$(git -C "$project_root" status --short | wc -l | tr -d ' ')"
	echo "godot_bin=$godot_bin"
	echo "godot_version=$($godot_bin --version | head -1)"
	echo "port=$port"
	echo "headless=$headless"
	echo "fullscreen_requested=$fullscreen"
	echo "fake_stall=$fake_stall"
	echo "ticks=$ticks"
	echo "rendering_driver=${rendering_driver:-project-default}"
	echo "windowserver_pid_start=$initial_windowserver_pid"
	echo "uname=$(uname -a)"
} > "$run_dir/metadata.txt"

sw_vers > "$run_dir/os.txt" 2>&1 || true
system_profiler SPDisplaysDataType > "$run_dir/displays-start.txt" 2>&1 || true
ioreg -l -w 0 -r -c AppleBacklightDisplay > "$run_dir/backlight-start.txt" 2>&1 || true
pmset -g therm > "$run_dir/thermal-start.txt" 2>&1 || true

log_predicate='((process == "Godot") AND ((eventMessage CONTAINS[c] "WindowServer") OR (eventMessage CONTAINS[c] "OpenGL") OR (eventMessage CONTAINS[c] "GPU") OR (eventMessage CONTAINS[c] "IOAccelerator"))) OR ((process == "watchdogd") AND ((eventMessage CONTAINS[c] "WindowServer") OR (eventMessage CONTAINS[c] "userspace_watchdog_timeout") OR (eventMessage CONTAINS[c] "unresponsive") OR (eventMessage CONTAINS[c] "type 409"))) OR ((process == "WindowServer") AND ((eventMessage CONTAINS[c] "event port") OR (eventMessage CONTAINS[c] "actual_host_time") OR (eventMessage CONTAINS[c] "not ready") OR (eventMessage CONTAINS[c] "unresponsive") OR (eventMessage CONTAINS[c] "surface"))) OR ((process == "powerd") AND ((eventMessage CONTAINS[c] "thermal") OR (eventMessage CONTAINS[c] "display"))) OR (eventMessage CONTAINS[c] "VBlank") OR (eventMessage CONTAINS[c] "GPU Reset") OR (eventMessage CONTAINS[c] "IOAccelerator") OR (eventMessage CONTAINS[c] "Setting display mode")'
/usr/bin/log stream --style compact --level info --predicate "$log_predicate" \
	> "$run_dir/unified-live.log" 2>&1 &
log_pid=$!

typeset -a driver_args client_display_args client_user_args
driver_args=()
client_display_args=(--windowed)
client_user_args=(--client --host 127.0.0.1 --port "$port" --name monitored)
if [[ -n "$rendering_driver" ]]; then
	driver_args=(--rendering-driver "$rendering_driver")
fi
if (( headless == 1 )); then
	client_display_args=(--headless)
	if (( ticks > 0 )); then
		client_user_args+=(--ticks "$ticks")
	fi
elif (( fullscreen == 1 )); then
	client_display_args=(--fullscreen)
fi

fake_stall_after=""
fake_stall_duration=""
if (( fake_stall == 1 )); then
	fake_stall_after="1.5"
	fake_stall_duration="7.0"
fi

CAR_FIGHT_TELEMETRY_FILE="$run_dir/server.telemetry.jsonl" \
	"$godot_bin" "${driver_args[@]}" --headless --path "$project_root" -- \
	--server --port "$port" > "$run_dir/server.log" 2>&1 &
server_pid=$!
sleep 0.8
if ! kill -0 "$server_pid" >/dev/null 2>&1; then
	set +e
	wait "$server_pid"
	server_status=$?
	set -e
	echo "state=server-exit-$server_status" >> "$run_dir/metadata.txt"
	print -r -- "server-exit-$server_status" > "$run_dir/state"
	kill "$log_pid" >/dev/null 2>&1 || true
	wait "$log_pid" 2>/dev/null || true
	echo "server failed before client launch; see $run_dir/server.log" >&2
	exit "$server_status"
fi
CAR_FIGHT_TELEMETRY_FILE="$run_dir/client.telemetry.jsonl" \
	CAR_FIGHT_FAKE_STALL_AFTER_SECONDS="$fake_stall_after" \
	CAR_FIGHT_FAKE_STALL_DURATION_SECONDS="$fake_stall_duration" \
	"$godot_bin" "${driver_args[@]}" "${client_display_args[@]}" \
	--path "$project_root" -- "${client_user_args[@]}" \
	> "$run_dir/client.log" 2>&1 &
client_pid=$!

{
	echo "server_pid=$server_pid"
	echo "client_pid=$client_pid"
} >> "$run_dir/metadata.txt"

sample_processes() {
	local sample_count=0
	local watched_pids="$server_pid,$client_pid"
	if [[ "$initial_windowserver_pid" == <-> ]]; then
		watched_pids+=",$initial_windowserver_pid"
	fi
	while kill -0 "$client_pid" >/dev/null 2>&1; do
		{
			echo "timestamp=$(date '+%Y-%m-%d %H:%M:%S') epoch=$(date '+%s')"
			ps -p "$watched_pids" \
				-o pid=,ppid=,state=,%cpu=,%mem=,rss=,vsz=,etime=,time=,command= \
				2>&1 || true
			if (( sample_count % 5 == 0 )); then
				for watched_pid in ${(s:,:)watched_pids}; do
					thread_lines="$(ps -M -p "$watched_pid" 2>/dev/null | wc -l | tr -d ' ')"
					echo "pid=$watched_pid threads=$((thread_lines > 0 ? thread_lines - 1 : 0))"
				done
				pmset -g therm 2>&1 || true
				sysctl vm.swapusage 2>&1 || true
			fi
			echo
		} >> "$run_dir/process-samples.log"
		sample_count=$((sample_count + 1))
		sleep 1
	done
}

sample_on_stall() {
	local sampled_mtime=0
	local telemetry_file="$run_dir/client.telemetry.jsonl"
	while kill -0 "$client_pid" >/dev/null 2>&1; do
		if [[ -f "$telemetry_file" ]]; then
			local telemetry_mtime="$(stat -f '%m' "$telemetry_file")"
			local now_epoch="$(date '+%s')"
			if (( now_epoch - telemetry_mtime >= 4 && telemetry_mtime != sampled_mtime )); then
				sampled_mtime="$telemetry_mtime"
				/usr/bin/sample "$client_pid" 2 -file \
					"$run_dir/client-stall-$now_epoch.sample.txt" \
					> "$run_dir/client-stall-$now_epoch.sample-command.log" 2>&1 || true
			fi
		fi
		sleep 1
	done
}

sample_processes &
process_sampler_pid=$!
sample_on_stall &
stall_sampler_pid=$!

cleanup() {
	for pid in "$stall_sampler_pid" "$process_sampler_pid" "$log_pid" \
			"$client_pid" "$server_pid"; do
		kill "$pid" >/dev/null 2>&1 || true
	done
	wait "$stall_sampler_pid" "$process_sampler_pid" "$log_pid" \
		"$client_pid" "$server_pid" 2>/dev/null || true
}
trap cleanup EXIT
trap 'exit 129' HUP
trap 'exit 130' INT
trap 'exit 143' TERM

echo "monitored run: $run_dir"
echo "server PID $server_pid, client PID $client_pid, WindowServer PID $initial_windowserver_pid"
echo "If the login session restarts, run: ./scripts/collect_crash_run.sh"

set +e
wait "$client_pid"
client_status=$?
set -e

end_windowserver_pid="$(pgrep -x WindowServer | head -1 || true)"
end_windowserver_pid="${end_windowserver_pid:-missing}"
recovered_windowserver_pid="$(sed -n 's/^windowserver_pid_recovered=//p' \
	"$run_dir/metadata.txt" | tail -1)"
end_local="$(date '+%Y-%m-%d %H:%M:%S')"
if [[ "$initial_windowserver_pid" == <-> && "$end_windowserver_pid" == <-> \
		&& "$initial_windowserver_pid" != "$end_windowserver_pid" ]]; then
	run_state="windowserver-restarted"
elif [[ "$initial_windowserver_pid" == <-> && "$recovered_windowserver_pid" == <-> \
		&& "$initial_windowserver_pid" != "$recovered_windowserver_pid" ]]; then
	run_state="windowserver-restarted"
elif (( client_status == 0 )); then
	run_state="clean"
else
	run_state="client-exit-$client_status"
fi
{
	echo "end_local=$end_local"
	echo "client_status=$client_status"
	echo "windowserver_pid_end=$end_windowserver_pid"
	echo "state=$run_state"
} >> "$run_dir/metadata.txt"
print -r -- "$run_state" > "$run_dir/state"
pmset -g therm > "$run_dir/thermal-end.txt" 2>&1 || true

echo "run state: $run_state"
echo "evidence: $run_dir"
exit "$client_status"
