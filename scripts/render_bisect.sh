#!/bin/zsh
set -euo pipefail
unsetopt BG_NICE

project_root="$(cd "$(dirname "$0")/.." && pwd)"
control_root="$project_root/render_bisect"
run_root="${CAR_FIGHT_RENDER_BISECT_ROOT:-$project_root/.render-bisect-runs}"
godot_bin="${GODOT_BIN:-/Applications/Godot47.app/Contents/MacOS/Godot}"
post_exit_seconds="${CAR_FIGHT_RENDER_BISECT_POST_EXIT_SECONDS:-120}"
action="${1:-list}"

print_stages() {
	cat <<'EOF'
Render-isolation stages:

  stage0-control   Clean project, OpenGL Compatibility, engine primitives only
  stage1-jeep      Stage 0 plus raw car-fight Jeep mesh and embedded materials

Stage 0 starts windowed. Enter fullscreen manually from the Godot window so the
entry path matches the known-good comparison. No car-fight assets or gameplay
are loaded by Stage 0. Stage 1 loads only the raw Jeep presentation asset;
shadows, physics, controls, animation, effects, and gameplay remain absent.
EOF
}

usage() {
	cat <<'EOF'
Usage:
  ./scripts/render_bisect.sh list
  ./scripts/render_bisect.sh run STAGE --dry-run [--seconds N]
  ./scripts/render_bisect.sh run STAGE --accept-crash-risk \
    [--startup-fullscreen] [--seconds N]

A real rendered run can trigger the Intel display-driver failure. Save work and
run only one stage per boot. The launcher never enters fullscreen itself.
EOF
}

if [[ "$action" == "list" ]]; then
	print_stages
	exit 0
fi
if [[ "$action" != "run" || $# -lt 2 ]]; then
	usage >&2
	exit 2
fi

stage="$2"
shift 2
accept_risk=0
dry_run=0
run_seconds=30
fullscreen_entry="manual"
while (( $# > 0 )); do
	case "$1" in
		--accept-crash-risk)
			accept_risk=1
			shift
			;;
		--dry-run)
			dry_run=1
			shift
			;;
		--startup-fullscreen)
			fullscreen_entry="startup"
			shift
			;;
		--seconds)
			run_seconds="${2:?--seconds requires a value}"
			shift 2
			;;
		*)
			echo "unknown option: $1" >&2
			exit 2
			;;
	esac
done

if [[ "$stage" != "stage0-control" && "$stage" != "stage1-jeep" ]]; then
	echo "unknown render-isolation stage: $stage" >&2
	print_stages >&2
	exit 2
fi
if [[ "$run_seconds" != <-> ]] || (( run_seconds < 10 || run_seconds > 120 )); then
	echo "--seconds must be an integer from 10 through 120" >&2
	exit 2
fi
if [[ "$post_exit_seconds" != <-> ]] || (( post_exit_seconds > 300 )); then
	echo "CAR_FIGHT_RENDER_BISECT_POST_EXIT_SECONDS must be 0 through 300" >&2
	exit 2
fi
if (( dry_run == 0 && accept_risk == 0 )); then
	echo "refusing rendered probe without --accept-crash-risk" >&2
	echo "use --dry-run to inspect the launch without opening a window" >&2
	exit 2
fi

typeset -a command
command=(
	"$godot_bin"
	--rendering-driver opengl3
)
if [[ "$fullscreen_entry" == "startup" ]]; then
	command+=(--fullscreen)
else
	command+=(--windowed)
fi
command+=(--path "$control_root")
echo "stage=$stage"
echo "duration_seconds=$run_seconds"
echo "post_fullscreen_watch_seconds=$post_exit_seconds"
echo "fullscreen_entry=$fullscreen_entry"
echo "control_project=$control_root"
if [[ "$stage" == "stage1-jeep" ]]; then
	echo "asset_import_preflight=headless"
fi
echo "command=${(q-)command}"
if (( dry_run == 1 )); then
	exit 0
fi

log_pid=""
client_pid=""
cleanup_exact_pids() {
	if [[ "$log_pid" == <-> ]] && kill -0 "$log_pid" >/dev/null 2>&1; then
		kill -TERM "$log_pid" >/dev/null 2>&1 || true
	fi
	if [[ "$client_pid" == <-> ]] && kill -0 "$client_pid" >/dev/null 2>&1; then
		kill -TERM "$client_pid" >/dev/null 2>&1 || true
	fi
}
abort_run() {
	trap - EXIT HUP INT TERM
	cleanup_exact_pids
	exit 130
}
trap cleanup_exact_pids EXIT
trap abort_run HUP INT TERM

mkdir -p "$run_root"
run_id="$(date '+%Y%m%d-%H%M%S')"
run_dir="$run_root/$run_id-$stage"
mkdir -p "$run_dir"
touch "$run_dir/started.marker"
print -r -- "$run_dir" > "$run_root/last_run"
start_epoch="$(date '+%s')"
start_local="$(date '+%Y-%m-%d %H:%M:%S')"
windowserver_pid_start="$(pgrep -x WindowServer | head -1 || true)"
{
	echo "stage=$stage"
	echo "start_epoch=$start_epoch"
	echo "start_local=$start_local"
	echo "deep_capture=1"
	echo "windowserver_pid_start=$windowserver_pid_start"
	echo "server_pid=none"
	echo "fullscreen_entry=$fullscreen_entry"
	echo "commit=$(git -C "$project_root" rev-parse HEAD)"
} > "$run_dir/metadata.txt"
print -r -- "running" > "$run_dir/state"

if [[ "$stage" == "stage1-jeep" ]]; then
	"$godot_bin" --headless --path "$control_root" --editor --quit \
		> "$run_dir/import-preflight.log" 2>&1
	if rg -q 'SCRIPT ERROR|Parse Error|Compile Error|ERROR: Failed to load script|Import failed' \
			"$run_dir/import-preflight.log"; then
		print -r -- "import-error" > "$run_dir/state"
		cat "$run_dir/import-preflight.log" >&2
		exit 1
	fi
fi

"$project_root/scripts/capture_display_snapshot.sh" \
	"$run_dir" before "$windowserver_pid_start" >/dev/null 2>&1 || true

log_predicate='(process == "Godot") OR (process == "WindowServer") OR (process == "watchdogd") OR (senderImagePath CONTAINS[c] "AppleIntelICL") OR (senderImagePath CONTAINS[c] "IOAccelerator") OR (eventMessage CONTAINS[c] "VBlank") OR (eventMessage CONTAINS[c] "GPU Reset")'
/usr/bin/log stream --style compact --predicate "$log_predicate" \
	> "$run_dir/unified-live.log" 2>&1 &
log_pid=$!

CAR_FIGHT_BISECT_TELEMETRY="$run_dir/client.telemetry.jsonl" \
	CAR_FIGHT_BISECT_AUTO_QUIT_SECONDS="$run_seconds" \
	CAR_FIGHT_BISECT_STAGE="$stage" \
	"${command[@]}" > "$run_dir/client.log" 2>&1 &
client_pid=$!
echo "client_pid=$client_pid" >> "$run_dir/metadata.txt"

echo "Render control started (PID $client_pid)."
if [[ "$fullscreen_entry" == "manual" ]]; then
	echo "Enter fullscreen manually if you are ready; the probe exits after ${run_seconds}s."
else
	echo "Startup fullscreen requested; the probe exits after ${run_seconds}s."
fi
echo "Evidence: $run_dir"

deadline=$(( $(date '+%s') + run_seconds + 20 ))
while kill -0 "$client_pid" >/dev/null 2>&1 \
		&& (( $(date '+%s') < deadline )); do
	{
		date '+time=%Y-%m-%d %H:%M:%S'
		ps -p "$client_pid,$windowserver_pid_start" \
			-o pid=,ppid=,state=,%cpu=,%mem=,rss=,etime=,time=,command=
	} >> "$run_dir/process-samples.log" 2>&1 || true
	sleep 1
done

stuck=0
if kill -0 "$client_pid" >/dev/null 2>&1; then
	stuck=1
	"$project_root/scripts/capture_display_snapshot.sh" \
		"$run_dir" stuck "$client_pid" "$windowserver_pid_start" >/dev/null 2>&1 || true
	kill -TERM "$client_pid" >/dev/null 2>&1 || true
	sleep 3
	if kill -0 "$client_pid" >/dev/null 2>&1; then
		kill -KILL "$client_pid" >/dev/null 2>&1 || true
	fi
fi

set +e
wait "$client_pid"
client_status=$?
set -e
kill -TERM "$log_pid" >/dev/null 2>&1 || true
wait "$log_pid" >/dev/null 2>&1 || true

"$project_root/scripts/capture_display_snapshot.sh" \
	"$run_dir" after "$windowserver_pid_start" >/dev/null 2>&1 || true

fullscreen_seen=0
if rg -q '"window_mode":(3|4)|"event":"window_mode_change".*"window_mode":(3|4)' \
		"$run_dir/client.telemetry.jsonl" 2>/dev/null; then
	fullscreen_seen=1
fi
display_precursor_seen=0
invalid_host_time_count="$(rg -c 'Invalid actual_host_time' \
	"$run_dir/unified-live.log" 2>/dev/null || true)"
invalid_host_time_count="${invalid_host_time_count:-0}"
if rg -q -i 'Not Ready for Transaction Processing|VBlank timeout|GPU Reset|event port.*(dead|died)' \
		"$run_dir/unified-live.log" 2>/dev/null; then
	display_precursor_seen=1
fi

if (( fullscreen_seen == 1 || display_precursor_seen == 1 )); then
	echo "Fullscreen or a display precursor was observed; watching WindowServer for ${post_exit_seconds}s after exit."
	post_exit_deadline=$(( $(date '+%s') + post_exit_seconds ))
	while (( $(date '+%s') < post_exit_deadline )); do
		current_windowserver_pid="$(pgrep -x WindowServer | head -1 || true)"
		{
			date '+post_exit_time=%Y-%m-%d %H:%M:%S'
			echo "windowserver_pid=$current_windowserver_pid"
		} >> "$run_dir/process-samples.log"
		if [[ "$windowserver_pid_start" == <-> \
				&& "$current_windowserver_pid" != "$windowserver_pid_start" ]]; then
			break
		fi
		sleep 1
	done
fi

state="pass"
if (( stuck == 1 )); then
	state="client-stuck"
elif (( client_status != 0 )); then
	state="client-error"
elif (( display_precursor_seen == 1 )); then
	state="display-precursor"
elif (( fullscreen_seen == 0 )); then
	state="not-fullscreen"
fi
windowserver_pid_end="$(pgrep -x WindowServer | head -1 || true)"
if [[ "$windowserver_pid_start" == <-> && "$windowserver_pid_end" == <-> \
		&& "$windowserver_pid_start" != "$windowserver_pid_end" ]]; then
	state="windowserver-restarted"
fi

print -r -- "$state" > "$run_dir/state"
{
	echo "client_exit_status=$client_status"
	echo "client_stuck=$stuck"
	echo "fullscreen_seen=$fullscreen_seen"
	echo "invalid_host_time_count=$invalid_host_time_count"
	echo "display_precursor_seen=$display_precursor_seen"
	echo "windowserver_pid_end=$windowserver_pid_end"
	echo "end_local=$(date '+%Y-%m-%d %H:%M:%S')"
} >> "$run_dir/metadata.txt"

"$project_root/scripts/collect_crash_run.sh" "$run_dir" >/dev/null 2>&1 || true
echo "run_state=$(< "$run_dir/state")"
echo "evidence=$run_dir"
echo "summary=$run_dir/report-summary.txt"
[[ "$(< "$run_dir/state")" == "pass" ]]
