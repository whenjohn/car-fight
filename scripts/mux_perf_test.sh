#!/bin/zsh
# Three-sample CPU A/B: unchanged pure ENet versus a mux server carrying the
# same two ENet clients and world. WebRTC listens but has no admitted peer.
set -euo pipefail
unsetopt BG_NICE

project_root="$(cd "$(dirname "$0")/.." && pwd)"
godot_bin="${GODOT_BIN:-/Applications/Godot.app/Contents/MacOS/Godot}"
base_port="${CAR_FIGHT_MUX_PERF_PORT:-12680}"
log_dir="$(mktemp -d "${TMPDIR:-/tmp}/car-fight-mux-perf.XXXXXX")"
results="$log_dir/results.txt"
server_pid=""
client_a_pid=""
client_b_pid=""

cleanup() {
	for process_id in "$client_b_pid" "$client_a_pid" "$server_pid"; do
		if [[ "$process_id" == <-> ]] && (( process_id > 1 )); then
			kill "$process_id" >/dev/null 2>&1 || true
		fi
	done
	wait 2>/dev/null || true
}
trap cleanup EXIT INT TERM

run_leg() {
	local mode="$1"
	local sample="$2"
	local port="$3"
	local run_dir="$log_dir/$mode-$sample"
	mkdir -p "$run_dir"
	/usr/bin/time -p "$godot_bin" --headless --path "$project_root" -- \
		--server --transport "$mode" --port "$port" --signal-port "$((port + 1))" \
		--no-drone --ticks 480 >"$run_dir/server.log" 2>"$run_dir/time.log" &
	server_pid=$!
	sleep 0.8
	"$godot_bin" --headless --path "$project_root" -- --client --host 127.0.0.1 \
		--port "$port" --name alpha --script converge --ticks 360 \
		>"$run_dir/alpha.log" 2>&1 &
	client_a_pid=$!
	sleep 0.2
	"$godot_bin" --headless --path "$project_root" -- --client --host 127.0.0.1 \
		--port "$port" --name bravo --script converge --ticks 360 \
		>"$run_dir/bravo.log" 2>&1 &
	client_b_pid=$!
	wait "$client_a_pid"; client_a_pid=""
	wait "$client_b_pid"; client_b_pid=""
	wait "$server_pid"; server_pid=""
	local cpu_seconds="$(awk '$1 == "user" || $1 == "sys" {sum += $2} END {printf "%.3f", sum}' \
		"$run_dir/time.log")"
	if [[ -z "$cpu_seconds" ]] || rg -q 'SCRIPT ERROR|Parse Error|Invalid call' "$run_dir"/*.log; then
		echo "Performance leg failed: $mode sample $sample; logs: $log_dir" >&2
		exit 1
	fi
	print -r -- "$mode $cpu_seconds" >> "$results"
	echo "MUX_PERF sample=$sample mode=$mode server_cpu_seconds=$cpu_seconds"
}

for sample in 1 2 3; do
	if (( sample % 2 == 1 )); then
		run_leg enet "$sample" "$((base_port + sample * 10))"
		run_leg mux "$sample" "$((base_port + sample * 10 + 2))"
	else
		run_leg mux "$sample" "$((base_port + sample * 10))"
		run_leg enet "$sample" "$((base_port + sample * 10 + 2))"
	fi
done

enet_median="$(awk '$1 == "enet" {print $2}' "$results" | sort -n | sed -n '2p')"
mux_median="$(awk '$1 == "mux" {print $2}' "$results" | sort -n | sed -n '2p')"
overhead="$(awk -v enet="$enet_median" -v mux="$mux_median" \
	'BEGIN {printf "%.2f", ((mux - enet) / enet) * 100.0}')"
added_cpu="$(awk -v enet="$enet_median" -v mux="$mux_median" \
	'BEGIN {printf "%.3f", mux - enet}')"
added_core_pct="$(awk -v added="$added_cpu" \
	'BEGIN {printf "%.2f", (added / 8.0) * 100.0}')"
echo "MUX_PERF medians enet=$enet_median mux=$mux_median overhead_pct=$overhead added_cpu_seconds=$added_cpu added_core_pct=$added_core_pct"
echo "logs: $log_dir"
# This deliberately tiny world makes the mux's fixed listener/poll cost look
# large as a relative percentage. Bound both the real capacity cost (7.5% of
# one core over the eight-second sample) and the relative regression so neither
# a fixed nor load-proportional regression can hide behind the other metric.
if ! awk -v relative="$overhead" -v core="$added_core_pct" \
	'BEGIN {exit !(relative <= 15.0 && core <= 7.5)}'; then
	echo "MUX_PERF_TEST FAIL mux cost exceeds relative or core budget" >&2
	exit 1
fi
echo "MUX_PERF_TEST PASS"
