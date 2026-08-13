#!/bin/zsh
set -euo pipefail

project_root="$(cd "$(dirname "$0")/.." && pwd)"
monitor_root="${CAR_FIGHT_MONITOR_ROOT:-$project_root/.crash-runs}"
run_dir="${1:-}"
if [[ -z "$run_dir" ]]; then
	if [[ ! -f "$monitor_root/last_run" ]]; then
		echo "No monitored run found under $monitor_root" >&2
		exit 2
	fi
	run_dir="$(< "$monitor_root/last_run")"
fi
if [[ ! -d "$run_dir" || ! -f "$run_dir/started.marker" ]]; then
	echo "Not a monitored run directory: $run_dir" >&2
	exit 2
fi

reports_dir="$run_dir/reports"
mkdir -p "$reports_dir"
find /Library/Logs/DiagnosticReports /Users/johnnguyen/Library/Logs/DiagnosticReports \
	-maxdepth 1 -type f -newer "$run_dir/started.marker" \
	\( -name 'WindowServer*.ips' -o -name 'WindowServer*.spin' \
		-o -name 'Godot*.ips' -o -name 'Godot*.spin' \) -print0 2>/dev/null \
	| while IFS= read -r -d '' report; do
		cp -p "$report" "$reports_dir/"
	done

start_local="$(sed -n 's/^start_local=//p' "$run_dir/metadata.txt" | head -1)"
end_local="$(date '+%Y-%m-%d %H:%M:%S')"
log_predicate='((process == "Godot") AND ((eventMessage CONTAINS[c] "WindowServer") OR (eventMessage CONTAINS[c] "OpenGL") OR (eventMessage CONTAINS[c] "GPU") OR (eventMessage CONTAINS[c] "IOAccelerator"))) OR (process == "watchdogd") OR ((process == "WindowServer") AND ((eventMessage CONTAINS[c] "event port") OR (eventMessage CONTAINS[c] "actual_host_time") OR (eventMessage CONTAINS[c] "not ready") OR (eventMessage CONTAINS[c] "unresponsive") OR (eventMessage CONTAINS[c] "surface"))) OR ((process == "powerd") AND ((eventMessage CONTAINS[c] "thermal") OR (eventMessage CONTAINS[c] "display"))) OR (eventMessage CONTAINS[c] "VBlank") OR (eventMessage CONTAINS[c] "GPU Reset") OR (eventMessage CONTAINS[c] "IOAccelerator") OR (eventMessage CONTAINS[c] "Setting display mode")'
if [[ -n "$start_local" ]]; then
	/usr/bin/log show --style compact --start "$start_local" --end "$end_local" \
		--predicate "$log_predicate" > "$run_dir/unified-recovered.log" 2>&1 || true
fi

system_profiler SPDisplaysDataType > "$run_dir/displays-recovered.txt" 2>&1 || true
ioreg -l -w 0 -r -c AppleBacklightDisplay > "$run_dir/backlight-recovered.txt" 2>&1 || true
pmset -g therm > "$run_dir/thermal-recovered.txt" 2>&1 || true
{
	echo "collected_local=$end_local"
	echo "windowserver_pid_recovered=$(pgrep -x WindowServer | head -1 || true)"
	echo "report_count=$(find "$reports_dir" -type f | wc -l | tr -d ' ')"
} >> "$run_dir/metadata.txt"
if command -v rg >/dev/null 2>&1; then
	rg -n -m 80 '"incident"|"captureTime"|"thermalPressureLevel"|"displayState"|VBlank|DisplayID|FB RegID|Process: +Godot|Footprint:|Time Since Fork:|CPU Time:' \
		"$reports_dir" > "$run_dir/report-summary.txt" 2>/dev/null || true
fi
if [[ -f "$run_dir/client.telemetry.jsonl" ]]; then
	tail -120 "$run_dir/client.telemetry.jsonl" \
		> "$run_dir/client-telemetry-tail.jsonl"
fi
if [[ -f "$run_dir/process-samples.log" ]]; then
	tail -300 "$run_dir/process-samples.log" \
		> "$run_dir/process-samples-tail.log"
fi

echo "collected run: $run_dir"
echo "reports: $(find "$reports_dir" -type f | wc -l | tr -d ' ')"
echo "summary: $run_dir/report-summary.txt"
