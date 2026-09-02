#!/bin/zsh
set -euo pipefail
unsetopt BG_NICE

project_root="$(cd "$(dirname "$0")/.." && pwd)"
godot_bin="${GODOT_BIN:-/Applications/Godot47.app/Contents/MacOS/Godot}"
source "$project_root/scripts/network_profiles.sh"
profile="${1:-combined}"
server_host="${2:-${CAR_FIGHT_HOST:-100.113.2.60}}"
server_port="${CAR_FIGHT_SERVER_PORT:-10080}"
proxy_port="${CAR_FIGHT_SHAPE_PORT:-10081}"
shape_seed="${CAR_FIGHT_SHAPE_SEED:-13258521}"
car_fight_network_profile "$profile"

run_stamp="$(date '+%Y%m%d-%H%M%S')"
run_root="$project_root/.crash-runs/shaped-two-$profile-$run_stamp"
proxy_pid=""
mkdir -p "$run_root"

cleanup() {
	if [[ "$proxy_pid" == <-> ]] && (( proxy_pid > 1 )); then
		kill "$proxy_pid" >/dev/null 2>&1 || true
		wait "$proxy_pid" 2>/dev/null || true
	fi
}
trap cleanup EXIT INT TERM

"$godot_bin" --headless --path "$project_root" -- --proxy \
	--host "$server_host" --port "$proxy_port" --to-port "$server_port" \
	--latency "$CAR_FIGHT_SHAPE_LATENCY_MS" --jitter "$CAR_FIGHT_SHAPE_JITTER_MS" \
	--loss "$CAR_FIGHT_SHAPE_LOSS_PCT" --shape-seed "$shape_seed" \
	> "$run_root/proxy.log" 2>&1 &
proxy_pid=$!
sleep 0.5
if ! kill -0 "$proxy_pid" >/dev/null 2>&1; then
	echo "network relay failed to start; see $run_root/proxy.log" >&2
	exit 1
fi

echo "two-client shaped native play: profile=$profile server=$server_host:$server_port"
echo "one-way: ${CAR_FIGHT_SHAPE_LATENCY_MS}ms jitter=+/-${CAR_FIGHT_SHAPE_JITTER_MS}ms loss=${CAR_FIGHT_SHAPE_LOSS_PCT}%"
CAR_FIGHT_HOST=127.0.0.1 CAR_FIGHT_PORT="$proxy_port" \
CAR_FIGHT_SESSION_LABEL="network-$profile" \
	"$project_root/scripts/play_macai2_two.sh"

tail -1 "$run_root/proxy.log"

