#!/bin/zsh
set -u
unsetopt BG_NICE

run_dir="${1:?run directory required}"
label="${2:?snapshot label required}"
shift 2

if [[ ! -d "$run_dir" || -z "$label" || "$label" == *[^A-Za-z0-9_-]* ]]; then
	echo "invalid display snapshot target: $run_dir / $label" >&2
	exit 2
fi

snapshot_dir="$run_dir/snapshots/$label"
mkdir -p "$snapshot_dir"
{
	echo "local_time=$(date '+%Y-%m-%d %H:%M:%S')"
	echo "epoch=$(date '+%s')"
	echo "label=$label"
	echo "requested_pids=${(j:,:)@}"
} > "$snapshot_dir/metadata.txt"

ps -axo pid=,ppid=,state=,%cpu=,%mem=,rss=,vsz=,etime=,time=,command= \
	> "$snapshot_dir/processes.txt" 2>&1 || true
pmset -g therm > "$snapshot_dir/thermal.txt" 2>&1 || true
pmset -g assertions > "$snapshot_dir/power-assertions.txt" 2>&1 || true
pmset -g log | tail -500 > "$snapshot_dir/power-history-tail.txt" 2>&1 || true
vm_stat > "$snapshot_dir/vm-stat.txt" 2>&1 || true
memory_pressure > "$snapshot_dir/memory-pressure.txt" 2>&1 || true
sysctl vm.swapusage > "$snapshot_dir/swap.txt" 2>&1 || true
system_profiler SPDisplaysDataType > "$snapshot_dir/displays.txt" 2>&1 || true
ioreg -l -w 0 -r -c AppleBacklightDisplay \
	> "$snapshot_dir/ioreg-backlight.txt" 2>&1 || true
ioreg -l -w 0 -r -c AppleIntelFramebuffer \
	> "$snapshot_dir/ioreg-intel-framebuffer.txt" 2>&1 || true
ioreg -l -w 0 -r -c IOFramebuffer \
	> "$snapshot_dir/ioreg-framebuffers.txt" 2>&1 || true
ioreg -l -w 0 -r -c IOAccelerator \
	> "$snapshot_dir/ioreg-accelerators.txt" 2>&1 || true

typeset -a sample_pids
sample_pids=()
for watched_pid in "$@"; do
	if [[ "$watched_pid" != <-> ]] || ! kill -0 "$watched_pid" >/dev/null 2>&1; then
		continue
	fi
	ps -M -p "$watched_pid" > "$snapshot_dir/threads-$watched_pid.txt" 2>&1 || true
	vmmap -summary "$watched_pid" > "$snapshot_dir/vmmap-$watched_pid.txt" 2>&1 || true
	/usr/bin/sample "$watched_pid" 2 -file \
		"$snapshot_dir/sample-$watched_pid.txt" \
		> "$snapshot_dir/sample-$watched_pid-command.log" 2>&1 &
	sample_pids+=("$!")
done
if (( ${#sample_pids} > 0 )); then
	wait "${sample_pids[@]}" 2>/dev/null || true
fi

touch "$snapshot_dir/complete.marker"
echo "display snapshot: $snapshot_dir"
