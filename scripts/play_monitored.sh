#!/bin/zsh
set -euo pipefail
unsetopt BG_NICE

project_root="${CAR_FIGHT_PROJECT_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
godot_bin="${GODOT_BIN:-/Applications/Godot47.app/Contents/MacOS/Godot}"
port="${CAR_FIGHT_PORT:-10080}"
monitor_root="${CAR_FIGHT_MONITOR_ROOT:-$project_root/.crash-runs}"
headless=0
fullscreen=0
fake_stall=0
ticks=0
rendering_driver="${CAR_FIGHT_RENDERING_DRIVER:-}"
deep_capture=0
post_exit_seconds=-1
client_host="${CAR_FIGHT_HOST:-100.113.2.60}"
client_name="monitored"
client_position=""
start_local_server=0
offline=0
sprite_test=0

while (( $# > 0 )); do
	case "$1" in
		--sprite-test)
			sprite_test=1
			shift
			;;
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
		--deep-capture)
			deep_capture=1
			shift
			;;
		--post-exit-seconds)
			post_exit_seconds="${2:?--post-exit-seconds requires a value}"
			shift 2
			;;
		--host)
			client_host="${2:?--host requires a value}"
			start_local_server=0
			offline=0
			shift 2
			;;
		--local)
			client_host="127.0.0.1"
			start_local_server=1
			offline=0
			shift
			;;
		--offline)
			client_host="offline"
			start_local_server=0
			offline=1
			shift
			;;
		--name)
			client_name="${2:?--name requires a value}"
			shift 2
			;;
		--position)
			client_position="${2:?--position requires X,Y}"
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
if (( headless == 1 )) && [[ -n "$client_position" ]]; then
	echo "--position cannot be combined with --headless" >&2
	exit 2
fi
if [[ -n "$client_position" && "$client_position" != <->,<-> ]]; then
	echo "--position must be non-negative X,Y coordinates" >&2
	exit 2
fi
if [[ "$post_exit_seconds" != -1 && "$post_exit_seconds" != <-> ]]; then
	echo "--post-exit-seconds must be a non-negative integer" >&2
	exit 2
fi
if (( post_exit_seconds < 0 )); then
	post_exit_seconds=$((deep_capture == 1 && fullscreen == 1 ? 90 : 0))
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
	echo "client_host=$client_host"
	echo "client_name=$client_name"
	echo "client_position=${client_position:-default}"
	echo "start_local_server=$start_local_server"
	echo "offline=$offline"
	echo "sprite_test=$sprite_test"
	echo "sprite_count=${CAR_FIGHT_SPRITE_COUNT:-16}"
	echo "ramming_lab=${CAR_FIGHT_RAMMING_LAB:-0}"
	echo "headless=$headless"
	echo "fullscreen_requested=$fullscreen"
	echo "fake_stall=$fake_stall"
	echo "ticks=$ticks"
	echo "rendering_driver=${rendering_driver:-project-default}"
	echo "deep_capture=$deep_capture"
	echo "post_exit_seconds=$post_exit_seconds"
	echo "windowserver_pid_start=$initial_windowserver_pid"
	echo "uname=$(uname -a)"
} > "$run_dir/metadata.txt"

sw_vers > "$run_dir/os.txt" 2>&1 || true
system_profiler SPDisplaysDataType > "$run_dir/displays-start.txt" 2>&1 || true
ioreg -l -w 0 -r -c AppleBacklightDisplay > "$run_dir/backlight-start.txt" 2>&1 || true
pmset -g therm > "$run_dir/thermal-start.txt" 2>&1 || true
if (( deep_capture == 1 )); then
	pmset -g assertions > "$run_dir/power-assertions-start.txt" 2>&1 || true
	pmset -g log | tail -1000 > "$run_dir/power-history-start.txt" 2>&1 || true
	ioreg -l -w 0 -r -c AppleIntelFramebuffer \
		> "$run_dir/intel-framebuffer-start.txt" 2>&1 || true
	ioreg -l -w 0 -r -c IOAccelerator \
		> "$run_dir/ioaccelerator-start.txt" 2>&1 || true
fi

log_predicate='((process == "Godot") AND ((eventMessage CONTAINS[c] "WindowServer") OR (eventMessage CONTAINS[c] "OpenGL") OR (eventMessage CONTAINS[c] "GPU") OR (eventMessage CONTAINS[c] "IOAccelerator"))) OR ((process == "watchdogd") AND ((eventMessage CONTAINS[c] "WindowServer") OR (eventMessage CONTAINS[c] "userspace_watchdog_timeout") OR (eventMessage CONTAINS[c] "unresponsive") OR (eventMessage CONTAINS[c] "type 409"))) OR ((process == "WindowServer") AND ((eventMessage CONTAINS[c] "event port") OR (eventMessage CONTAINS[c] "actual_host_time") OR (eventMessage CONTAINS[c] "not ready") OR (eventMessage CONTAINS[c] "unresponsive") OR (eventMessage CONTAINS[c] "surface"))) OR ((process == "powerd") AND ((eventMessage CONTAINS[c] "thermal") OR (eventMessage CONTAINS[c] "display"))) OR (eventMessage CONTAINS[c] "VBlank") OR (eventMessage CONTAINS[c] "GPU Reset") OR (eventMessage CONTAINS[c] "IOAccelerator") OR (eventMessage CONTAINS[c] "Setting display mode")'
if (( deep_capture == 1 )); then
	log_predicate='(process == "Godot") OR (process == "WindowServer") OR (process == "watchdogd") OR ((process == "powerd") AND ((eventMessage CONTAINS[c] "thermal") OR (eventMessage CONTAINS[c] "display") OR (eventMessage CONTAINS[c] "sleep") OR (eventMessage CONTAINS[c] "wake"))) OR (senderImagePath CONTAINS[c] "AppleIntelICL") OR (senderImagePath CONTAINS[c] "IOAccelerator") OR (eventMessage CONTAINS[c] "VBlank") OR (eventMessage CONTAINS[c] "GPU Reset") OR (eventMessage CONTAINS[c] "Setting display mode")'
fi
/usr/bin/log stream --style compact --level info --predicate "$log_predicate" \
	> "$run_dir/unified-live.log" 2>&1 &
log_pid=$!

typeset -a driver_args client_display_args client_user_args network_stack_args server_fixture_args
driver_args=()
client_display_args=(--windowed)
session_label="${CAR_FIGHT_SESSION_LABEL:-$(git -C "$project_root" branch --show-current)}"
if (( offline == 1 )); then
	client_user_args=(--offline --name "$client_name" --session-label "$session_label")
else
	client_user_args=(--client --host "$client_host" --port "$port" --name "$client_name" --session-label "$session_label")
fi
network_stack_args=()
server_fixture_args=()
if [[ "${CAR_FIGHT_G2_STACK:-0}" == "1" ]]; then
	network_stack_args=(--state-bundles --packed-input --packed-state --input-broadcast 0 \
		--state-rate-divisor "${CAR_FIGHT_STATE_RATE_DIVISOR:-3}" \
		--remote-state-transport batch --remote-state-rate 30 \
		--remote-state-relevance same-map --remote-state-include-self 0)
	if [[ "${CAR_FIGHT_ADAPTIVE_STATE_RATE:-0}" == "1" ]]; then
		network_stack_args+=(--adaptive-state-rate 1)
	fi
	if [[ -n "${CAR_FIGHT_RESIM_BUDGET_MS:-}" ]]; then
		network_stack_args+=(--resim-budget-ms "$CAR_FIGHT_RESIM_BUDGET_MS")
	fi
fi
if [[ "${CAR_FIGHT_RAMMING_LAB:-0}" == "1" ]]; then
	server_fixture_args=(--ramming-lab)
elif [[ "${CAR_FIGHT_SERVER_DRIVER:-0}" == "1" ]]; then
	server_fixture_args=(--server-driver)
fi
if (( sprite_test == 1 )); then
	client_user_args+=(--sprite-test)
	server_fixture_args+=(--sprite-test)
fi
client_user_args+=("${network_stack_args[@]}")
if [[ "${CAR_FIGHT_CLIENT_CRUISE:-0}" == "1" ]]; then
	client_user_args+=(--client-cruise)
fi
if [[ "${CAR_FIGHT_NETWORK_HUD:-0}" == "1" ]]; then
	client_user_args+=(--network-hud --network-profile "${CAR_FIGHT_NETWORK_PROFILE:-unshaped}" \
		--net-telemetry)
fi
if [[ "${CAR_FIGHT_HIDE_HOTKEY_HINTS:-0}" == "1" ]]; then
	client_user_args+=(--hide-hotkey-hints)
fi
if [[ -n "${CAR_FIGHT_REMOTE_INTERP_MODE:-}" ]]; then
	client_user_args+=(--remote-interp-mode "$CAR_FIGHT_REMOTE_INTERP_MODE" \
		--remote-interp "${CAR_FIGHT_REMOTE_INTERP_MS:-75}" \
		--remote-interp-max "${CAR_FIGHT_REMOTE_INTERP_MAX_MS:-150}")
fi
if [[ "${CAR_FIGHT_PRESENTATION_TRACE_SECONDS:-0}" != "0" ]]; then
	client_user_args+=(--presentation-trace "$run_dir/presentation-trace.jsonl" \
		--presentation-trace-seconds "$CAR_FIGHT_PRESENTATION_TRACE_SECONDS")
fi
if [[ -n "${CAR_FIGHT_PRESENTATION_CONTROL_PATH:-}" ]]; then
	client_user_args+=(--presentation-control "$CAR_FIGHT_PRESENTATION_CONTROL_PATH")
fi
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
elif [[ -n "$client_position" ]]; then
	client_display_args+=(--position "$client_position")
fi

fake_stall_after=""
fake_stall_duration=""
if (( fake_stall == 1 )); then
	fake_stall_after="1.5"
	fake_stall_duration="7.0"
fi

server_pid=""
if (( start_local_server == 1 )); then
	CAR_FIGHT_TELEMETRY_FILE="$run_dir/server.telemetry.jsonl" \
		"$godot_bin" "${driver_args[@]}" --headless --path "$project_root" -- \
		--server --port "$port" "${network_stack_args[@]}" \
		"${server_fixture_args[@]}" > "$run_dir/server.log" 2>&1 &
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

snapshot_script="$(cd "$(dirname "$0")" && pwd)/capture_display_snapshot.sh"
start_snapshot_pid=""
precursor_watcher_pid=""

watch_display_precursor() {
	local marker="$run_dir/precursor.marker"
	local precursor_line=""
	while true; do
		precursor_line="$(rg -m 1 'Invalid actual_host_time' \
			"$run_dir/unified-live.log" 2>/dev/null || true)"
		if [[ -n "$precursor_line" ]]; then
			print -r -- "$precursor_line" > "$marker"
			{
				echo "precursor_detected_local=$(date '+%Y-%m-%d %H:%M:%S')"
				echo "precursor_detected_epoch=$(date '+%s')"
			} >> "$run_dir/metadata.txt"
			"$snapshot_script" "$run_dir" precursor \
				"$server_pid" "$client_pid" "$initial_windowserver_pid" \
				> "$run_dir/precursor-snapshot.log" 2>&1 || true
			return
		fi
		sleep 0.25
	done
}

sample_processes() {
	local sample_count=0
	local watched_pids="$client_pid"
	if [[ "$server_pid" == <-> ]]; then
		watched_pids="$server_pid,$watched_pids"
	fi
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
if (( deep_capture == 1 )); then
	"$snapshot_script" "$run_dir" start \
		"$server_pid" "$client_pid" "$initial_windowserver_pid" \
		> "$run_dir/start-snapshot.log" 2>&1 &
	start_snapshot_pid=$!
	watch_display_precursor &
	precursor_watcher_pid=$!
fi

cleanup() {
	for pid in "$precursor_watcher_pid" "$start_snapshot_pid" \
			"$stall_sampler_pid" "$process_sampler_pid" "$log_pid" \
			"$client_pid" "$server_pid"; do
		if [[ "$pid" == <-> ]] && (( pid > 1 )); then
			kill "$pid" >/dev/null 2>&1 || true
		fi
	done
	wait 2>/dev/null || true
}
trap cleanup EXIT
requested_exit_status=0
handle_signal() {
	requested_exit_status="$1"
	echo "signal received; stopping Godot and preserving post-exit evidence"
	kill "$client_pid" >/dev/null 2>&1 || true
	if [[ "$server_pid" == <-> ]]; then
		kill "$server_pid" >/dev/null 2>&1 || true
	fi
}
trap 'handle_signal 129' HUP
trap 'handle_signal 130' INT
trap 'handle_signal 143' TERM

echo "monitored run: $run_dir"
echo "server PID ${server_pid:-remote}, client PID $client_pid, WindowServer PID $initial_windowserver_pid"
echo "If the login session restarts, run: ./scripts/collect_crash_run.sh"

set +e
wait "$client_pid"
client_status=$?
set -e
if (( requested_exit_status != 0 )); then
	client_status="$requested_exit_status"
fi

if [[ "$server_pid" == <-> ]]; then
	kill "$server_pid" >/dev/null 2>&1 || true
	wait "$server_pid" 2>/dev/null || true
fi

if (( deep_capture == 1 )); then
	"$snapshot_script" "$run_dir" client-exit "$initial_windowserver_pid" \
		> "$run_dir/client-exit-snapshot.log" 2>&1 || true
fi

if (( post_exit_seconds > 0 )); then
	echo "Godot stopped; watching WindowServer for $post_exit_seconds seconds"
	post_exit_start_epoch="$(date '+%s')"
	post_exit_deadline=$((post_exit_start_epoch + post_exit_seconds))
	while (( $(date '+%s') < post_exit_deadline )); do
		current_windowserver_pid="$(pgrep -x WindowServer | head -1 || true)"
		{
			echo "timestamp=$(date '+%Y-%m-%d %H:%M:%S') epoch=$(date '+%s')"
			echo "windowserver_pid=${current_windowserver_pid:-missing}"
			if [[ "$current_windowserver_pid" == <-> ]]; then
				ps -p "$current_windowserver_pid" \
					-o pid=,ppid=,state=,%cpu=,%mem=,rss=,vsz=,etime=,time=,command= \
					2>&1 || true
			fi
			echo
		} >> "$run_dir/post-exit-windowserver.log"
		if [[ "$initial_windowserver_pid" == <-> \
				&& "$current_windowserver_pid" == <-> \
				&& "$initial_windowserver_pid" != "$current_windowserver_pid" ]]; then
			touch "$run_dir/windowserver-restarted.marker"
		fi
		sleep 1
	done
	{
		echo "post_exit_watch_started_epoch=$post_exit_start_epoch"
		echo "post_exit_watch_ended_epoch=$(date '+%s')"
	} >> "$run_dir/metadata.txt"
fi

if (( deep_capture == 1 )); then
	end_snapshot_windowserver_pid="$(pgrep -x WindowServer | head -1 || true)"
	"$snapshot_script" "$run_dir" post-exit \
		"${end_snapshot_windowserver_pid:-unknown}" \
		> "$run_dir/post-exit-snapshot.log" 2>&1 || true
fi

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
