#!/bin/zsh
set -euo pipefail
unsetopt BG_NICE

project_root="$(cd "$(dirname "$0")/.." && pwd)"
godot_bin="${GODOT_BIN:-/Applications/Godot.app/Contents/MacOS/Godot}"
web_port="${CAR_FIGHT_WEB_NETWORK_PORT:-18088}"
enet_port="${CAR_FIGHT_MUX_ENET_PORT:-12380}"
signal_port="${CAR_FIGHT_MUX_SIGNAL_PORT:-12381}"
log_dir="$(mktemp -d "${TMPDIR:-/tmp}/car-fight-web-network.XXXXXX")"
web_pid=""
server_pid=""
native_pid=""
stack_args=()
browser_stack_query=""
stack_label="legacy"
server_fixture_args=()
native_script_args=(--script right)
if [[ "${CAR_FIGHT_SERVER_DRIVER_LANE:-0}" == "1" ]]; then
	server_fixture_args=(--server-driver-lane --player-capsule)
	native_script_args=()
fi
if [[ "${CAR_FIGHT_G2_STACK:-0}" == "1" ]]; then
	state_rate_divisor="${CAR_FIGHT_STATE_RATE_DIVISOR:-3}"
	stack_args=(--state-bundles --packed-input --packed-state --input-broadcast 0 \
		--state-rate-divisor "$state_rate_divisor" --remote-state-transport batch \
		--remote-state-rate 30 --remote-state-relevance same-map --remote-state-include-self 0)
	browser_stack_query="&stateBundles=1&packedInput=1&packedState=1&inputBroadcast=0&stateRateDivisor=$state_rate_divisor&remoteStateTransport=batch&remoteStateRate=30&remoteStateRelevance=same-map&remoteStateIncludeSelf=0"
	stack_label="g2"
fi
if [[ -n "${CAR_FIGHT_RESIM_BUDGET_MS:-}" ]]; then
	stack_args+=(--resim-budget-ms "$CAR_FIGHT_RESIM_BUDGET_MS")
	browser_stack_query+="&resimBudgetMs=$CAR_FIGHT_RESIM_BUDGET_MS"
fi
if [[ "${CAR_FIGHT_ADAPTIVE_STATE_RATE:-0}" == "1" ]]; then
	stack_args+=(--adaptive-state-rate 1)
	browser_stack_query+="&adaptiveStateRate=1"
fi
presentation_mode="${CAR_FIGHT_REMOTE_INTERP_MODE:-fixed}"
presentation_min="${CAR_FIGHT_REMOTE_INTERP_MS:-75}"
presentation_max="${CAR_FIGHT_REMOTE_INTERP_MAX_MS:-150}"
stack_args+=(--remote-interp-mode "$presentation_mode" --remote-interp "$presentation_min" \
	--remote-interp-max "$presentation_max")
browser_stack_query+="&remoteInterpMode=$presentation_mode&remoteInterpMs=$presentation_min&remoteInterpMaxMs=$presentation_max&networkProfile=web-smoke"
if [[ "${CAR_FIGHT_NETWORK_HUD:-0}" == "1" ]]; then
	browser_stack_query+="&networkHud=1&netTelemetry=1"
fi

cleanup() {
	for process_id in "$native_pid" "$server_pid" "$web_pid"; do
		if [[ "$process_id" == <-> ]] && (( process_id > 1 )); then
			kill "$process_id" >/dev/null 2>&1 || true
		fi
	done
	wait 2>/dev/null || true
}
trap cleanup EXIT INT TERM

"$project_root/scripts/web_network_build.sh" release
CAR_FIGHT_WEB_PORT="$web_port" CAR_FIGHT_WEB_OUTPUT="$project_root/build/web-network" \
	"$project_root/scripts/web_serve.sh" >"$log_dir/web-server.log" 2>&1 &
web_pid=$!
for _attempt in {1..100}; do
	if curl -fs -o /dev/null "http://127.0.0.1:$web_port/"; then
		break
	fi
	sleep 0.05
done
curl -fs -o /dev/null "http://127.0.0.1:$web_port/"

"$godot_bin" --headless --path "$project_root" -- --server --transport mux \
	--port "$enet_port" --signal-port "$signal_port" --no-drone \
	"${server_fixture_args[@]}" \
	"${stack_args[@]}" \
	>"$log_dir/server.log" 2>&1 &
server_pid=$!
sleep 0.8
"$godot_bin" --headless --path "$project_root" -- --client --transport enet \
	--host 127.0.0.1 --port "$enet_port" --name native-survivor "${native_script_args[@]}" \
	"${stack_args[@]}" \
	>"$log_dir/native.log" 2>&1 &
native_pid=$!
sleep 0.8

browser_url="http://127.0.0.1:$web_port/?signal=ws%3A%2F%2F127.0.0.1%3A$signal_port&name=browser&webrtcTelemetry=1$browser_stack_query"
node "$project_root/scripts/web_network_smoke.mjs" "$browser_url" \
	"$log_dir/browser-report.json" "$log_dir/browser.png" \
	| tee "$log_dir/browser.log"

sleep 1
first_two_line="$(rg -n 'CLIENT_TICK .*players=2 world=[^|]+\|[^ ]+' "$log_dir/native.log" \
	| head -1 | cut -d: -f1 || true)"
one_line="$(rg -n 'CLIENT_TICK .*players=1 world=[^| ]+ ' "$log_dir/native.log" \
	| cut -d: -f1 | awk -v after="${first_two_line:-0}" '$1 > after {print; exit}' || true)"
last_two_line="$(rg -n 'CLIENT_TICK .*players=2 world=[^|]+\|[^ ]+' "$log_dir/native.log" \
	| tail -1 | cut -d: -f1 || true)"
if [[ -z "$first_two_line" || -z "$one_line" || -z "$last_two_line" ]] \
		|| (( first_two_line >= one_line || one_line >= last_two_line )); then
	echo "Native ENet survivor did not observe shared-world leave/rejoin; logs: $log_dir" >&2
	exit 1
fi
if [[ "$(rg -c 'peer_connected id=.*transport=webrtc' "$log_dir/server.log" || true)" -lt 2 ]]; then
	echo "Mux server did not admit both browser generations; logs: $log_dir" >&2
	exit 1
fi
if rg -q 'SCRIPT ERROR|Parse Error|Invalid call|Invalid get index|Node not found|Failed to get path from RPC' \
		"$log_dir"/*.log; then
	echo "Mixed browser/native run emitted a runtime error; logs: $log_dir" >&2
	rg 'SCRIPT ERROR|Parse Error|Invalid call|Invalid get index|Node not found|Failed to get path from RPC' \
		"$log_dir"/*.log >&2
	exit 1
fi
# Netfox writes each warning once through Godot's WARNING line and once through
# its own logger. Count the actual warning emission, not both textual copies.
stale_count="$(rg -c '^WARNING: .*Skipping stale rollback origin' \
	"$log_dir/server.log" || true)"
if (( stale_count > 4 )); then
	echo "Browser refresh produced a stale-history warning flood ($stale_count); logs: $log_dir" >&2
	exit 1
fi
if [[ "$stack_label" == "g2" ]] \
		&& ! rg -q '\[remote-state-batch-proof\].*bodies=[1-9][0-9]*' "$log_dir/server.log"; then
	echo "G2 stack sent no non-empty remote-position batch; logs: $log_dir" >&2
	exit 1
fi

echo "WEB_NETWORK_TEST PASS stack=$stack_label"
echo "logs: $log_dir"
