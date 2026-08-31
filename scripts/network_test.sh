#!/bin/zsh
set -euo pipefail

project_root="$(cd "$(dirname "$0")/.." && pwd)"
godot_bin="${GODOT_BIN:-/Applications/Godot.app/Contents/MacOS/Godot}"
source "$project_root/scripts/network_profiles.sh"
profile="${1:-latency120}"
car_fight_network_profile "$profile"
latency_ms="${CAR_FIGHT_SHAPE_LATENCY_MS}"
jitter_ms="${CAR_FIGHT_SHAPE_JITTER_MS}"
loss_pct="${CAR_FIGHT_SHAPE_LOSS_PCT}"
loss_print="$(printf '%.2f' "$loss_pct")"
shape_seed="${CAR_FIGHT_SHAPE_SEED:-13258521}"
stack_args=()
stack_label="legacy"
if [[ "${CAR_FIGHT_G2_STACK:-0}" == "1" ]]; then
	stack_args=(--state-bundles --packed-input --packed-state --input-broadcast 0 \
		--state-rate-divisor "${CAR_FIGHT_STATE_RATE_DIVISOR:-3}" --net-telemetry \
		--remote-state-transport batch --remote-state-rate 30 \
		--remote-state-relevance same-map --remote-state-include-self 0)
	stack_label="g2"
elif [[ "${CAR_FIGHT_STATE_BUNDLES:-0}" == "1" \
		|| "${CAR_FIGHT_PACKED_INPUT:-0}" == "1" \
		|| "${CAR_FIGHT_PACKED_STATE:-0}" == "1" ]]; then
	[[ "${CAR_FIGHT_STATE_BUNDLES:-0}" == "1" ]] && stack_args+=(--state-bundles)
	[[ "${CAR_FIGHT_PACKED_INPUT:-0}" == "1" ]] && stack_args+=(--packed-input)
	[[ "${CAR_FIGHT_PACKED_STATE:-0}" == "1" ]] && stack_args+=(--packed-state)
	stack_args+=(--input-broadcast "${CAR_FIGHT_INPUT_BROADCAST:-0}" \
		--state-rate-divisor "${CAR_FIGHT_STATE_RATE_DIVISOR:-1}" --net-telemetry)
	stack_label="custom"
fi
if [[ -n "${CAR_FIGHT_RESIM_BUDGET_MS:-}" ]]; then
	stack_args+=(--resim-budget-ms "$CAR_FIGHT_RESIM_BUDGET_MS")
fi
if [[ "${CAR_FIGHT_ADAPTIVE_STATE_RATE:-0}" == "1" ]]; then
	stack_args+=(--adaptive-state-rate 1)
fi
if [[ -n "${CAR_FIGHT_REMOTE_INTERP_MODE:-}" ]]; then
	stack_args+=(--remote-interp-mode "$CAR_FIGHT_REMOTE_INTERP_MODE" \
		--remote-interp "${CAR_FIGHT_REMOTE_INTERP_MS:-75}" \
		--remote-interp-max "${CAR_FIGHT_REMOTE_INTERP_MAX_MS:-150}")
fi
server_port="${CAR_FIGHT_TEST_PORT:-10380}"
proxy_port=$((server_port + 1))
server_ticks="${CAR_FIGHT_NETWORK_SERVER_TICKS:-480}"
client_ticks="${CAR_FIGHT_NETWORK_CLIENT_TICKS:-600}"
log_dir="$(mktemp -d "${TMPDIR:-/tmp}/car-fight-network.XXXXXX")"
server_pid=""
proxy_pid=""
client_a_pid=""
client_b_pid=""

cleanup() {
	for process_id in "$client_a_pid" "$client_b_pid" "$proxy_pid" "$server_pid"; do
		if [[ -n "$process_id" ]]; then
			kill "$process_id" >/dev/null 2>&1 || true
		fi
	done
}
trap cleanup EXIT INT TERM

"$godot_bin" --headless --path "$project_root" -- --server --no-drone --port "$server_port" --ticks "$server_ticks" "${stack_args[@]}" >"$log_dir/server.log" 2>&1 &
server_pid=$!
sleep 0.8
"$godot_bin" --headless --path "$project_root" -- --proxy --host 127.0.0.1 \
	--port "$proxy_port" --to-port "$server_port" --latency "$latency_ms" \
	--jitter "$jitter_ms" --loss "$loss_pct" --shape-seed "$shape_seed" \
	>"$log_dir/proxy.log" 2>&1 &
proxy_pid=$!
sleep 0.3
"$godot_bin" --headless --path "$project_root" -- --client --host 127.0.0.1 --port "$proxy_port" --name alpha --script converge --presentation-test --ticks "$client_ticks" "${stack_args[@]}" >"$log_dir/client-a.log" 2>&1 &
client_a_pid=$!
sleep 0.2
"$godot_bin" --headless --path "$project_root" -- --client --host 127.0.0.1 --port "$proxy_port" --name bravo --script converge --ticks "$client_ticks" "${stack_args[@]}" >"$log_dir/client-b.log" 2>&1 &
client_b_pid=$!

if ! wait "$server_pid"; then
	echo "server failed; logs: $log_dir" >&2
	tail -80 "$log_dir/server.log" >&2
	exit 1
fi
server_pid=""

if ! rg -q 'CLIENT_READY' "$log_dir/client-a.log" || ! rg -q 'CLIENT_READY' "$log_dir/client-b.log"; then
	echo "a client did not complete the ENet handshake; logs: $log_dir" >&2
	tail -60 "$log_dir/client-a.log" >&2
	tail -60 "$log_dir/client-b.log" >&2
	exit 1
fi
for client_log in "$log_dir/client-a.log" "$log_dir/client-b.log"; do
	if ! rg -q 'CLIENT_TICK .*players=2 world=[^|]+\|[^ ]+' "$client_log"; then
		echo "a client did not replicate both player bodies into one world; logs: $log_dir" >&2
		tail -80 "$client_log" >&2
		exit 1
	fi
done
if ! rg -q 'RESULT players=2 .*contact=1' "$log_dir/server.log"; then
	echo "authoritative two-car contact was not observed; logs: $log_dir" >&2
	tail -100 "$log_dir/server.log" >&2
	exit 1
fi
if ! rg -q 'RESULT players=2 .*contact=1 escapes=[1-9][0-9]*' "$log_dir/server.log"; then
	echo "colliding cars never triggered the authoritative escape assist; logs: $log_dir" >&2
	tail -100 "$log_dir/server.log" >&2
	exit 1
fi
if rg -q 'SCRIPT ERROR|Parse Error|Invalid call|Invalid get index' "$log_dir"/*.log; then
	echo "runtime script error; logs: $log_dir" >&2
	rg 'SCRIPT ERROR|Parse Error|Invalid call|Invalid get index' "$log_dir"/*.log >&2
	exit 1
fi
if [[ -n "${CAR_FIGHT_REMOTE_INTERP_MODE:-}" ]]; then
	for client_log in "$log_dir/client-a.log" "$log_dir/client-b.log"; do
		if ! rg -q "\[presentation-buffer\] mode=${CAR_FIGHT_REMOTE_INTERP_MODE} min_ms=${CAR_FIGHT_REMOTE_INTERP_MS:-75} max_ms=${CAR_FIGHT_REMOTE_INTERP_MAX_MS:-150}" "$client_log"; then
			echo "client did not apply requested presentation mode; logs: $log_dir" >&2
			exit 1
		fi
	done
fi
if rg -q 'Reference tick .* missing .* applying' "$log_dir"/client-*.log; then
	echo "a client applied a diff without its reference snapshot; logs: $log_dir" >&2
	rg 'Reference tick .* missing .* applying' "$log_dir"/client-*.log >&2
	exit 1
fi
reference_rejections="$(rg --no-filename '^WARNING: .*Rejecting diff .* reference tick .* unavailable' \
		"$log_dir"/client-*.log | wc -l | tr -d ' ' || true)"
# The diagnostic is rate-limited to once per second per client. A higher count
# means a recovery loop survived for essentially the entire short gate.
if (( reference_rejections > 20 )); then
	echo "missing-reference recovery was unbounded ($reference_rejections); logs: $log_dir" >&2
	exit 1
fi
if ! rg -Fq "latency=${latency_ms}ms jitter=+/-${jitter_ms}ms loss=${loss_print}% seed=${shape_seed}" \
		"$log_dir/proxy.log"; then
	echo "proxy did not echo the requested '$profile' profile; logs: $log_dir" >&2
	tail -40 "$log_dir/proxy.log" >&2
	exit 1
fi
proxy_stats="$(rg '\[proxy-stats\]' "$log_dir/proxy.log" | tail -1 || true)"
if [[ -z "$proxy_stats" ]]; then
	echo "proxy emitted no traffic telemetry; logs: $log_dir" >&2
	exit 1
fi
proxy_recv="$(print -r -- "$proxy_stats" | sed -E 's/.*recv=([0-9]+)\/([0-9]+).*/\1 \2/')"
read -r proxy_recv_c2s proxy_recv_s2c <<< "$proxy_recv"
if (( proxy_recv_c2s < 20 || proxy_recv_s2c < 20 )); then
	echo "proxy traffic proof was too small: $proxy_stats; logs: $log_dir" >&2
	exit 1
fi
if awk -v loss="$loss_pct" 'BEGIN { exit !(loss > 0) }'; then
	proxy_drops="$(print -r -- "$proxy_stats" | sed -E 's/.*drop=([0-9]+)\/([0-9]+).*/\1 \2/')"
	read -r proxy_drop_c2s proxy_drop_s2c <<< "$proxy_drops"
	if (( proxy_drop_c2s + proxy_drop_s2c < 1 )); then
		echo "loss profile dropped no packets: $proxy_stats; logs: $log_dir" >&2
		exit 1
	fi
fi
if (( jitter_ms > 0 )); then
	proxy_reorders="$(print -r -- "$proxy_stats" | sed -E 's/.*reorder=([0-9]+)\/([0-9]+).*/\1 \2/')"
	read -r proxy_reorder_c2s proxy_reorder_s2c <<< "$proxy_reorders"
	if (( proxy_reorder_c2s + proxy_reorder_s2c < 1 )); then
		echo "jitter profile produced no measured packet reordering: $proxy_stats; logs: $log_dir" >&2
		exit 1
	fi
fi
correction_lines="$(rg 'CORRECTION .*error=' "$log_dir"/client-*.log || true)"
if [[ -z "$correction_lines" ]]; then
	echo "clients received no same-tick authority probes; logs: $log_dir" >&2
	exit 1
fi
worst_error="$(print -r -- "$correction_lines" | sed -E 's/.*error=([0-9.]+).*/\1/' | sort -n | tail -1)"
if ! awk -v value="$worst_error" 'BEGIN { exit !(value <= 2.0) }'; then
	echo "local prediction correction exceeded 2 units: $worst_error; logs: $log_dir" >&2
	exit 1
fi

result_line="$(rg 'RESULT players=2' "$log_dir/server.log" | tail -1)"
echo "NETWORK_TEST PASS profile=$profile stack=$stack_label one_way=${latency_ms}ms jitter=+/-${jitter_ms}ms loss=${loss_pct}% worst_correction=${worst_error} reference_rejections=${reference_rejections}"
echo "$proxy_stats"
echo "$result_line"
echo "logs: $log_dir"
