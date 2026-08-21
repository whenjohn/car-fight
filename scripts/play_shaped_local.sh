#!/bin/zsh
# Human smoothness check: isolated authoritative server with a server-driven
# open-area car, one shaped relay, and one monitored native observer.
set -euo pipefail
unsetopt BG_NICE

project_root="$(cd "$(dirname "$0")/.." && pwd)"
godot_bin="${GODOT_BIN:-/Applications/Godot47.app/Contents/MacOS/Godot}"
source "$project_root/scripts/network_profiles.sh"
profile="${1:-latency120}"
car_fight_network_profile "$profile"

server_port="${CAR_FIGHT_LOCAL_SHAPED_SERVER_PORT:-12680}"
proxy_port="${CAR_FIGHT_LOCAL_SHAPED_PROXY_PORT:-12681}"
shape_seed="${CAR_FIGHT_SHAPE_SEED:-13258521}"
run_stamp="$(date '+%Y%m%d-%H%M%S')"
run_root="$project_root/.crash-runs/shaped-local-$profile-$run_stamp"
server_pid=""
proxy_pid=""

stack_args=(--state-bundles --packed-input --packed-state --input-broadcast 0 \
	--state-rate-divisor "${CAR_FIGHT_STATE_RATE_DIVISOR:-3}" \
	--remote-state-transport batch --remote-state-rate 30 \
	--remote-state-relevance same-map --remote-state-include-self 0)
if [[ "${CAR_FIGHT_ADAPTIVE_STATE_RATE:-0}" == "1" ]]; then
	stack_args+=(--adaptive-state-rate 1)
fi

cleanup() {
	for process_id in "$proxy_pid" "$server_pid"; do
		if [[ "$process_id" == <-> ]] && (( process_id > 1 )); then
			kill "$process_id" >/dev/null 2>&1 || true
		fi
	done
	wait 2>/dev/null || true
}
trap cleanup EXIT INT TERM

mkdir -p "$run_root/client"
"$godot_bin" --headless --path "$project_root" -- --server --no-drone \
	--server-driver --port "$server_port" "${stack_args[@]}" \
	>"$run_root/server.log" 2>&1 &
server_pid=$!
sleep 0.8
if ! kill -0 "$server_pid" >/dev/null 2>&1; then
	echo "local server failed to start; see $run_root/server.log" >&2
	exit 1
fi

"$godot_bin" --headless --path "$project_root" -- --proxy \
	--host 127.0.0.1 --port "$proxy_port" --to-port "$server_port" \
	--latency "$CAR_FIGHT_SHAPE_LATENCY_MS" --jitter "$CAR_FIGHT_SHAPE_JITTER_MS" \
	--loss "$CAR_FIGHT_SHAPE_LOSS_PCT" --shape-seed "$shape_seed" \
	>"$run_root/proxy.log" 2>&1 &
proxy_pid=$!
sleep 0.5
if ! kill -0 "$proxy_pid" >/dev/null 2>&1; then
	echo "network relay failed to start; see $run_root/proxy.log" >&2
	exit 1
fi

echo "shaped local one-client play: profile=$profile"
echo "server open-area car: peer 1"
echo "one-way: ${CAR_FIGHT_SHAPE_LATENCY_MS}ms jitter=+/-${CAR_FIGHT_SHAPE_JITTER_MS}ms loss=${CAR_FIGHT_SHAPE_LOSS_PCT}%"
echo "evidence: $run_root"

CAR_FIGHT_G2_STACK=1 CAR_FIGHT_PORT="$proxy_port" \
CAR_FIGHT_MONITOR_ROOT="$run_root/client" \
CAR_FIGHT_SESSION_LABEL="network-$profile-server-driver" \
	"$project_root/scripts/play_monitored.sh" --host 127.0.0.1 \
	--name "${CAR_FIGHT_NAME:-observer}"

tail -1 "$run_root/proxy.log"
