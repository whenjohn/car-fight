#!/bin/zsh
# Networking 1 human feel harness: isolated macai2 server-driven Jeep, one
# locally rendered observer, and one local shaped ENet relay.
set -euo pipefail
unsetopt BG_NICE

project_root="$(cd "$(dirname "$0")/.." && pwd)"
godot_bin="${GODOT_BIN:-/Applications/Godot47.app/Contents/MacOS/Godot}"
remote_ssh="${CAR_FIGHT_SSH_HOST:-macai2-ts}"
remote_root="${CAR_FIGHT_NETWORKING1_REMOTE_ROOT:-/Users/macai2/Projects/car-fight-networking-1}"
remote_godot="${CAR_FIGHT_REMOTE_GODOT:-/Applications/Godot47.app/Contents/MacOS/Godot}"
remote_port="${CAR_FIGHT_NETWORKING1_SERVER_PORT:-12680}"
proxy_port="${CAR_FIGHT_NETWORKING1_PROXY_PORT:-12681}"
profile="${1:-latency120}"
presentation_mode="${2:-adaptive}"
source "$project_root/scripts/network_profiles.sh"
car_fight_network_profile "$profile"

if [[ "$presentation_mode" != "fixed" && "$presentation_mode" != "adaptive" && "$presentation_mode" != "predictive" && "$presentation_mode" != "proxy" ]]; then
	echo "presentation mode must be fixed, adaptive, predictive, or proxy" >&2
	exit 2
fi

stamp="$(date '+%Y%m%d-%H%M%S')"
run_root="$project_root/.crash-runs/networking1-enet-$profile-$presentation_mode-$stamp"
remote_run="$remote_root/.networking1/$stamp"
shape_seed="${CAR_FIGHT_SHAPE_SEED:-13258521}"
remote_pid=""
proxy_pid=""
mkdir -p "$run_root/client"
presentation_control="$run_root/presentation-control.txt"
touch "$presentation_control"

cleanup() {
	if [[ "$proxy_pid" == <-> ]] && (( proxy_pid > 1 )); then
		kill "$proxy_pid" >/dev/null 2>&1 || true
		wait "$proxy_pid" 2>/dev/null || true
	fi
	if [[ -n "$remote_pid" ]]; then
		ssh "$remote_ssh" "kill '$remote_pid' >/dev/null 2>&1 || true" || true
		ssh "$remote_ssh" "test ! -f '$remote_run/server.log' || tail -200 '$remote_run/server.log'" \
			> "$run_root/server-tail.log" 2>&1 || true
	fi
}
trap cleanup EXIT INT TERM

echo "syncing isolated Networking 1 server to $remote_ssh:$remote_root"
ssh "$remote_ssh" "mkdir -p '$remote_root'"
rsync -az --delete --exclude='.git/' --exclude='.godot/' --exclude='.crash-runs/' \
	--exclude='.network-runs/' --exclude='.networking1/' \
	"$project_root/" "$remote_ssh:$remote_root/"
ssh "$remote_ssh" "mkdir -p '$remote_run'"
ssh "$remote_ssh" "'$remote_godot' --headless --path '$remote_root' --editor --quit" \
	> "$run_root/remote-import-first.log" 2>&1
ssh "$remote_ssh" "'$remote_godot' --headless --path '$remote_root' --editor --quit" \
	> "$run_root/remote-import-verify.log" 2>&1
if rg -q 'SCRIPT ERROR|Parse Error|Compile Error|ERROR: Failed to load script' \
		"$run_root/remote-import-verify.log"; then
	cat "$run_root/remote-import-verify.log" >&2
	exit 1
fi

stack_args="--state-bundles --packed-input --packed-state --input-broadcast 0 --state-rate-divisor 1 --net-telemetry --remote-state-transport batch --remote-state-rate 30 --remote-state-relevance same-map --remote-state-include-self 0"
remote_pid="$(ssh "$remote_ssh" "nohup '$remote_godot' --headless --path '$remote_root' -- --server --port '$remote_port' --no-drone --no-ball --server-driver $stack_args > '$remote_run/server.log' 2>&1 & echo \$!")"
sleep 1
ssh "$remote_ssh" "kill -0 '$remote_pid'"

"$godot_bin" --headless --path "$project_root" -- --proxy --host 100.113.2.60 \
	--port "$proxy_port" --to-port "$remote_port" \
	--latency "$CAR_FIGHT_SHAPE_LATENCY_MS" --jitter "$CAR_FIGHT_SHAPE_JITTER_MS" \
	--loss "$CAR_FIGHT_SHAPE_LOSS_PCT" --shape-seed "$shape_seed" \
	> "$run_root/proxy.log" 2>&1 &
proxy_pid=$!
sleep 0.5
kill -0 "$proxy_pid"

{
	echo "transport=enet"
	echo "profile=$profile"
	echo "presentation_mode=$presentation_mode"
	echo "remote=$remote_ssh:$remote_port"
	echo "one_way_ms=$CAR_FIGHT_SHAPE_LATENCY_MS"
	echo "jitter_ms=$CAR_FIGHT_SHAPE_JITTER_MS"
	echo "loss_pct=$CAR_FIGHT_SHAPE_LOSS_PCT"
} > "$run_root/condition.txt"

echo "Networking 1 ENet: $profile / $presentation_mode"
echo "server-driven Jeep: macai2 peer 1; local process: one rendered observer"
echo "evidence: $run_root"
monitor_args=(--host 127.0.0.1 --name observer)
headless_ticks="${CAR_FIGHT_NETWORKING1_HEADLESS_TICKS:-0}"
if [[ "$headless_ticks" == <-> ]] && (( headless_ticks > 0 )); then
	monitor_args+=(--headless --ticks "$headless_ticks")
fi
CAR_FIGHT_G2_STACK=1 CAR_FIGHT_STATE_RATE_DIVISOR=1 \
CAR_FIGHT_NETWORK_HUD=1 CAR_FIGHT_NETWORK_PROFILE="$profile" \
CAR_FIGHT_HIDE_HOTKEY_HINTS=1 \
CAR_FIGHT_REMOTE_INTERP_MODE="$presentation_mode" \
CAR_FIGHT_REMOTE_INTERP_MS="${CAR_FIGHT_REMOTE_INTERP_MS:-75}" \
CAR_FIGHT_REMOTE_INTERP_MAX_MS="${CAR_FIGHT_REMOTE_INTERP_MAX_MS:-150}" \
CAR_FIGHT_PRESENTATION_TRACE_SECONDS="${CAR_FIGHT_PRESENTATION_TRACE_SECONDS:-120}" \
CAR_FIGHT_PRESENTATION_CONTROL_PATH="$presentation_control" \
CAR_FIGHT_NO_RAMPS=1 CAR_FIGHT_NO_DRONE=1 CAR_FIGHT_NO_BALL=1 \
CAR_FIGHT_HIDE_PEER_MARKERS=1 CAR_FIGHT_PORT="$proxy_port" \
CAR_FIGHT_MONITOR_ROOT="$run_root/client" \
CAR_FIGHT_SESSION_LABEL="networking1-$profile-$presentation_mode" \
	"$project_root/scripts/play_monitored.sh" "${monitor_args[@]}"

tail -1 "$run_root/proxy.log"
