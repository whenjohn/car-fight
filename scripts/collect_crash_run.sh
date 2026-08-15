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
start_epoch="$(sed -n 's/^start_epoch=//p' "$run_dir/metadata.txt" | head -1)"
typeset -a diagnostic_roots
if [[ -n "${CAR_FIGHT_DIAGNOSTIC_ROOTS:-}" ]]; then
	diagnostic_roots=("${(@s/:/)CAR_FIGHT_DIAGNOSTIC_ROOTS}")
else
	diagnostic_roots=(
		/Library/Logs/DiagnosticReports
		"$HOME/Library/Logs/DiagnosticReports"
	)
fi

report_epoch_from_text() {
	local report_time_text="$1"
	local report_time_without_fraction
	report_time_without_fraction="$(print -r -- "$report_time_text" \
		| sed 's/\.[0-9][0-9]* \([+-][0-9][0-9][0-9][0-9]\)$/ \1/')"
	if [[ "$report_time_without_fraction" == *" +"* \
			|| "$report_time_without_fraction" == *" -"* ]]; then
		date -j -f '%Y-%m-%d %H:%M:%S %z' \
			"$report_time_without_fraction" '+%s' 2>/dev/null || true
	else
		date -j -f '%Y-%m-%d %H:%M:%S' \
			"$(print -r -- "$report_time_without_fraction" | cut -c1-19)" \
			'+%s' 2>/dev/null || true
	fi
}

find "${diagnostic_roots[@]}" -maxdepth 2 -type f \
	-newer "$run_dir/started.marker" \
	\( -name 'WindowServer*.ips' -o -name 'WindowServer*.spin' \
		-o -name 'Godot*.ips' -o -name 'Godot*.spin' \
		-o -iname 'panic-full*.ips' -o -iname 'Kernel*.panic' \) \
	-print0 2>/dev/null \
	| while IFS= read -r -d '' report; do
		report_time_text=""
		case "$report" in
			*.ips)
				report_time_text="$(sed -n \
					's/.*"captureTime"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' \
					"$report" | head -1)"
				if [[ -z "$report_time_text" ]]; then
					report_time_text="$(sed -n \
						's/.*"timestamp"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' \
						"$report" | head -1)"
				fi
				;;
			*.spin)
				report_time_text="$(sed -n \
					's/^Date\/Time: *\([0-9-]* [0-9:]*\).*/\1/p' "$report" | head -1)"
				;;
		esac
		if [[ "$start_epoch" == <-> && -n "$report_time_text" ]]; then
			report_epoch="$(report_epoch_from_text "$report_time_text")"
			if [[ "$report_epoch" == <-> ]] && (( report_epoch < start_epoch )); then
				continue
			fi
		fi
		cp -p "$report" "$reports_dir/"
	done

start_local="$(sed -n 's/^start_local=//p' "$run_dir/metadata.txt" | head -1)"
deep_capture="$(sed -n 's/^deep_capture=//p' "$run_dir/metadata.txt" | head -1)"
end_local="$(date '+%Y-%m-%d %H:%M:%S')"
log_predicate='((process == "Godot") AND ((eventMessage CONTAINS[c] "WindowServer") OR (eventMessage CONTAINS[c] "OpenGL") OR (eventMessage CONTAINS[c] "GPU") OR (eventMessage CONTAINS[c] "IOAccelerator"))) OR ((process == "watchdogd") AND ((eventMessage CONTAINS[c] "WindowServer") OR (eventMessage CONTAINS[c] "userspace_watchdog_timeout") OR (eventMessage CONTAINS[c] "unresponsive") OR (eventMessage CONTAINS[c] "type 409"))) OR ((process == "WindowServer") AND ((eventMessage CONTAINS[c] "event port") OR (eventMessage CONTAINS[c] "actual_host_time") OR (eventMessage CONTAINS[c] "not ready") OR (eventMessage CONTAINS[c] "unresponsive") OR (eventMessage CONTAINS[c] "surface"))) OR ((process == "powerd") AND ((eventMessage CONTAINS[c] "thermal") OR (eventMessage CONTAINS[c] "display"))) OR (eventMessage CONTAINS[c] "VBlank") OR (eventMessage CONTAINS[c] "GPU Reset") OR (eventMessage CONTAINS[c] "IOAccelerator") OR (eventMessage CONTAINS[c] "Setting display mode")'
if [[ "$deep_capture" == "1" ]]; then
	log_predicate='(process == "Godot") OR (process == "WindowServer") OR (process == "watchdogd") OR ((process == "powerd") AND ((eventMessage CONTAINS[c] "thermal") OR (eventMessage CONTAINS[c] "display") OR (eventMessage CONTAINS[c] "sleep") OR (eventMessage CONTAINS[c] "wake"))) OR (senderImagePath CONTAINS[c] "AppleIntelICL") OR (senderImagePath CONTAINS[c] "IOAccelerator") OR (eventMessage CONTAINS[c] "VBlank") OR (eventMessage CONTAINS[c] "GPU Reset") OR (eventMessage CONTAINS[c] "Setting display mode")'
	if [[ "$start_epoch" == <-> ]]; then
		start_local="$(date -r "$((start_epoch - 600))" '+%Y-%m-%d %H:%M:%S')"
	fi
fi
if [[ -n "$start_local" ]]; then
	/usr/bin/log show --style compact --start "$start_local" --end "$end_local" \
		--predicate "$log_predicate" > "$run_dir/unified-recovered.log" 2>&1 || true
fi

system_profiler SPDisplaysDataType > "$run_dir/displays-recovered.txt" 2>&1 || true
ioreg -l -w 0 -r -c AppleBacklightDisplay > "$run_dir/backlight-recovered.txt" 2>&1 || true
pmset -g therm > "$run_dir/thermal-recovered.txt" 2>&1 || true
pmset -g assertions > "$run_dir/power-assertions-recovered.txt" 2>&1 || true
pmset -g log | tail -1000 > "$run_dir/power-history-recovered.txt" 2>&1 || true
ioreg -l -w 0 -r -c AppleIntelFramebuffer \
	> "$run_dir/intel-framebuffer-recovered.txt" 2>&1 || true
ioreg -l -w 0 -r -c IOAccelerator \
	> "$run_dir/ioaccelerator-recovered.txt" 2>&1 || true
start_windowserver_pid="$(sed -n 's/^windowserver_pid_start=//p' \
	"$run_dir/metadata.txt" | head -1)"
recovered_windowserver_pid="$(pgrep -x WindowServer 2>/dev/null | head -1 || true)"
server_pid="$(sed -n 's/^server_pid=//p' "$run_dir/metadata.txt" | head -1)"
client_pid="$(sed -n 's/^client_pid=//p' "$run_dir/metadata.txt" | head -1)"
server_alive=0
client_alive=0
if [[ "$server_pid" == <-> ]] && kill -0 "$server_pid" >/dev/null 2>&1; then
	server_alive=1
fi
if [[ "$client_pid" == <-> ]] && kill -0 "$client_pid" >/dev/null 2>&1; then
	client_alive=1
fi
collector_state="collected"
panic_report_count="$(find "$reports_dir" -type f \
	\( -iname 'panic-full*.ips' -o -iname 'Kernel*.panic' \) \
	| wc -l | tr -d ' ')"
if (( panic_report_count > 0 )); then
	collector_state="kernel-panic"
	print -r -- "$collector_state" > "$run_dir/state"
elif [[ "$start_windowserver_pid" == <-> && "$recovered_windowserver_pid" == <-> \
		&& "$start_windowserver_pid" != "$recovered_windowserver_pid" ]]; then
	collector_state="windowserver-restarted"
	print -r -- "$collector_state" > "$run_dir/state"
fi
{
	echo "collected_local=$end_local"
	echo "windowserver_pid_recovered=$recovered_windowserver_pid"
	echo "server_alive_at_collection=$server_alive"
	echo "client_alive_at_collection=$client_alive"
	echo "report_count=$(find "$reports_dir" -type f | wc -l | tr -d ' ')"
	echo "panic_report_count=$panic_report_count"
	echo "collector_state=$collector_state"
} >> "$run_dir/metadata.txt"
if command -v rg >/dev/null 2>&1; then
	{
		echo "collector_state=$collector_state"
		echo "panic_report_count=$panic_report_count"
		rg -n -m 30 '"incident"|"captureTime"|"thermalPressureLevel"|"displayState"|VBlank|DisplayID|FB RegID' \
			"$reports_dir" -g '!panic-full*.ips' 2>/dev/null || true
		find "$reports_dir" -type f \
			\( -iname 'panic-full*.ips' -o -iname 'Kernel*.panic' \) \
			-print0 2>/dev/null \
			| while IFS= read -r -d '' report; do
				echo "kernel_panic_report=$report"
				rg -o '"incident_id":"[^"]+"|"timestamp":"[^"]+"|"bug_type":"[^"]+"' \
					"$report" 2>/dev/null | sed -n '1,6p' || true
				rg -o 'Submission on work queue [0-9]+ failed due to insufficient space|@IGGuC\.cpp:[0-9]+|pid [0-9]+: Godot' \
					"$report" 2>/dev/null | sed -n '1,6p' || true
			done
		find "$reports_dir" -type f -name '*.spin' -print0 2>/dev/null \
			| while IFS= read -r -d '' report; do
				awk '
					/^Process: +WindowServer|^Process: +Godot/ { capture = 1; fields = 0 }
					capture && /^(Process:|Footprint:|Time Since Fork:|CPU Time:)/ {
						print FNR ":" $0
						fields++
						if (fields == 4) capture = 0
					}
				' "$report"
				done
		for log_file in "$run_dir/unified-live.log" "$run_dir/unified-recovered.log"; do
			if [[ -f "$log_file" ]]; then
				invalid_count="$(rg -c 'Invalid actual_host_time' "$log_file" 2>/dev/null || true)"
				echo "$log_file Invalid actual_host_time count: ${invalid_count:-0}"
				rg 'Invalid actual_host_time' "$log_file" 2>/dev/null | sed -n '1p;$p' || true
				rg -i 'VBlank|display.*not ready|event port.*(dead|died)|GPU Reset' \
					"$log_file" 2>/dev/null | tail -20 || true
			fi
		done
	} > "$run_dir/report-summary.txt"
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
