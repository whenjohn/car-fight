#!/bin/zsh
# Isolated browser/native WebRTC shaping gate. The browser is forced through a
# dedicated TURN container on macmini; netem shapes that container's egress in
# both directions. The authoritative mux server runs from a separate checkout
# and separate ports on macai2. Production UDP 10080/TCP 10181 are untouched.
set -euo pipefail
unsetopt BG_NICE

project_root="$(cd "$(dirname "$0")/.." && pwd)"
source "$project_root/scripts/network_profiles.sh"
profile="${1:-combined}"
car_fight_network_profile "$profile"

server_ssh="${CAR_FIGHT_SHAPE_SERVER_SSH:-macai2-ts}"
server_ip="${CAR_FIGHT_SHAPE_SERVER_IP:-100.113.2.60}"
turn_ssh="${CAR_FIGHT_SHAPE_TURN_SSH:-macmini-ts}"
turn_ip="${CAR_FIGHT_SHAPE_TURN_IP:-192.168.1.202}"
turn_parent="${CAR_FIGHT_SHAPE_TURN_PARENT:-enp4s0f0}"
turn_gateway="${CAR_FIGHT_SHAPE_TURN_GATEWAY:-192.168.1.254}"
turn_subnet="${CAR_FIGHT_SHAPE_TURN_SUBNET:-192.168.1.0/24}"
turn_image="coturn/coturn:4.6.3-r3"
turn_container="car-fight-network-turn"
turn_network="car-fight-network-turn-net"
turn_user="car-fight"
turn_credential="car-fight-shape"
remote_root="${CAR_FIGHT_SHAPE_REMOTE_ROOT:-/Users/macai2/Projects/car-fight-network-shaping}"
remote_godot="${CAR_FIGHT_SHAPE_REMOTE_GODOT:-/Applications/Godot47.app/Contents/MacOS/Godot}"
remote_enet_port="${CAR_FIGHT_SHAPE_REMOTE_ENET_PORT:-12480}"
remote_signal_port="${CAR_FIGHT_SHAPE_REMOTE_SIGNAL_PORT:-12481}"
local_signal_port="${CAR_FIGHT_SHAPE_LOCAL_SIGNAL_PORT:-12581}"
web_port="${CAR_FIGHT_SHAPE_WEB_PORT:-18189}"
remote_pidfile="/tmp/car-fight-network-shaping-server.pid"
remote_log="/tmp/car-fight-network-shaping-server.log"
failsafe_seconds="${CAR_FIGHT_SHAPE_FAILSAFE_SECONDS:-300}"
server_driver_arg=""
if [[ "${CAR_FIGHT_SHAPE_SERVER_DRIVER:-0}" == "1" ]]; then
	server_driver_arg="--server-driver"
fi
stack_label="legacy"
server_stack_args=""
native_stack_args=()
browser_stack_query=""
if [[ "${CAR_FIGHT_G2_STACK:-0}" == "1" ]]; then
	state_rate_divisor="${CAR_FIGHT_STATE_RATE_DIVISOR:-3}"
	server_stack_args="--state-bundles --packed-input --packed-state --input-broadcast 0 --state-rate-divisor $state_rate_divisor --net-telemetry --remote-state-transport batch --remote-state-rate 30 --remote-state-relevance same-map --remote-state-include-self 0"
	native_stack_args=(--state-bundles --packed-input --packed-state --input-broadcast 0 \
		--state-rate-divisor "$state_rate_divisor" --remote-state-transport batch \
		--remote-state-rate 30 --remote-state-relevance same-map --remote-state-include-self 0)
	browser_stack_query="&stateBundles=1&packedInput=1&packedState=1&inputBroadcast=0&stateRateDivisor=$state_rate_divisor&remoteStateTransport=batch&remoteStateRate=30&remoteStateRelevance=same-map&remoteStateIncludeSelf=0"
	stack_label="g2"
fi
if [[ -n "${CAR_FIGHT_RESIM_BUDGET_MS:-}" ]]; then
	server_stack_args+=" --resim-budget-ms $CAR_FIGHT_RESIM_BUDGET_MS"
	native_stack_args+=(--resim-budget-ms "$CAR_FIGHT_RESIM_BUDGET_MS")
	browser_stack_query+="&resimBudgetMs=$CAR_FIGHT_RESIM_BUDGET_MS"
fi
if [[ "${CAR_FIGHT_ADAPTIVE_STATE_RATE:-0}" == "1" ]]; then
	server_stack_args+=" --adaptive-state-rate 1"
	native_stack_args+=(--adaptive-state-rate 1)
	browser_stack_query+="&adaptiveStateRate=1"
fi

run_stamp="$(date -u '+%Y%m%dT%H%M%SZ')"
run_dir="$project_root/.network-runs/$run_stamp-webrtc-$profile"
web_pid=""
native_pid=""
tunnel_pid=""
turn_started=0
failsafe_pid=""
server_started=0
mkdir -p "$run_dir"

stop_remote_server() {
	ssh "$server_ssh" "if test -r '$remote_pidfile'; then pid=\$(cat '$remote_pidfile'); command=\$(ps -p \"\$pid\" -o command= 2>/dev/null || true); case \"\$command\" in *'$remote_root'*'--signal-port $remote_signal_port'*) kill \"\$pid\" >/dev/null 2>&1 || true;; esac; unlink '$remote_pidfile' >/dev/null 2>&1 || true; fi" || true
}

cleanup() {
	for process_id in "$native_pid" "$web_pid" "$tunnel_pid"; do
		if [[ "$process_id" == <-> ]] && (( process_id > 1 )); then
			kill "$process_id" >/dev/null 2>&1 || true
			wait "$process_id" 2>/dev/null || true
		fi
	done
	if (( server_started == 1 )); then
		stop_remote_server
	fi
	if (( turn_started == 1 )); then
		ssh "$turn_ssh" "test -z '$failsafe_pid' || kill '$failsafe_pid' >/dev/null 2>&1 || true; docker rm -f '$turn_container' >/dev/null 2>&1 || true; docker network rm '$turn_network' >/dev/null 2>&1 || true" || true
	fi
}
trap cleanup EXIT INT TERM

echo "WEBRTC_SHAPE profile=$profile one_way=${CAR_FIGHT_SHAPE_LATENCY_MS}ms jitter=+/-${CAR_FIGHT_SHAPE_JITTER_MS}ms loss=${CAR_FIGHT_SHAPE_LOSS_PCT}%"
echo "evidence: $run_dir"

"$project_root/scripts/web_network_build.sh" release

# Sync only to the isolated harness checkout. The production car-fight checkout
# and launchd service are never addressed by this script.
ssh "$server_ssh" "mkdir -p '$remote_root'"
rsync -az --delete --exclude='.git/' --exclude='.godot/' --exclude='build/' \
	--exclude='.crash-runs/' --exclude='.network-runs/' \
	"$project_root/" "$server_ssh:$remote_root/"
ssh "$server_ssh" "'$remote_godot' --headless --path '$remote_root' --editor --quit" \
	> "$run_dir/remote-import.log" 2>&1 || true

# Replace only prior resources with these harness-specific names.
ssh "$turn_ssh" "docker rm -f '$turn_container' >/dev/null 2>&1 || true; docker network rm '$turn_network' >/dev/null 2>&1 || true"
if ping -c 1 -W 1000 "$turn_ip" >/dev/null 2>&1; then
	echo "TURN test address $turn_ip is already in use" >&2
	exit 1
fi
ssh "$turn_ssh" "docker image inspect '$turn_image' >/dev/null 2>&1 || docker pull '$turn_image' >/dev/null; docker network create -d macvlan --subnet='$turn_subnet' --gateway='$turn_gateway' -o parent='$turn_parent' '$turn_network' >/dev/null; docker run -d --name '$turn_container' --cap-add NET_ADMIN --restart=no --network '$turn_network' --ip '$turn_ip' '$turn_image' --lt-cred-mech --user='$turn_user:$turn_credential' --realm=car-fight-network-test --listening-ip='$turn_ip' --relay-ip='$turn_ip' --listening-port=3478 --min-port=40064 --max-port=40127 --no-cli --no-tls --no-dtls --log-file=stdout >/dev/null"
turn_started=1
failsafe_pid="$(ssh "$turn_ssh" "nohup sh -c 'sleep $failsafe_seconds; docker rm -f $turn_container >/dev/null 2>&1 || true; docker network rm $turn_network >/dev/null 2>&1 || true' >/dev/null 2>&1 & echo \$!")"

turn_ready=0
for _attempt in {1..100}; do
	if ssh "$turn_ssh" "docker logs '$turn_container' 2>&1 | grep -q 'Relay ports initialization done'"; then
		turn_ready=1
		break
	fi
	sleep 0.1
done
if (( turn_ready == 0 )); then
	echo "TURN container did not become ready" >&2
	exit 1
fi

netem_args=""
if (( CAR_FIGHT_SHAPE_LATENCY_MS > 0 )); then
	netem_args="delay ${CAR_FIGHT_SHAPE_LATENCY_MS}ms"
	if (( CAR_FIGHT_SHAPE_JITTER_MS > 0 )); then
		netem_args+=" ${CAR_FIGHT_SHAPE_JITTER_MS}ms distribution normal"
	fi
fi
if awk -v loss="$CAR_FIGHT_SHAPE_LOSS_PCT" 'BEGIN { exit !(loss > 0) }'; then
	netem_args+=" loss ${CAR_FIGHT_SHAPE_LOSS_PCT}%"
fi
ssh "$turn_ssh" "pid=\$(docker inspect -f '{{.State.Pid}}' '$turn_container'); sudo nsenter -t \"\$pid\" -n tc qdisc replace dev eth0 root netem $netem_args; sudo nsenter -t \"\$pid\" -n tc -s qdisc show dev eth0" \
	> "$run_dir/netem-before.txt"

# Ensure macai2 can reach the relay before starting ICE negotiation.
ssh "$server_ssh" "ping -c 1 -W 1000 '$turn_ip' >/dev/null"
stop_remote_server
ssh "$server_ssh" "nohup '$remote_godot' --headless --path '$remote_root' -- --server --transport mux --port '$remote_enet_port' --signal-port '$remote_signal_port' --no-drone $server_driver_arg --webrtc-telemetry --ticks 4200 $server_stack_args > '$remote_log' 2>&1 & echo \$! > '$remote_pidfile'"
server_started=1
server_ready=0
for _attempt in {1..100}; do
	if ssh "$server_ssh" "grep -q 'server listening transport=mux' '$remote_log' 2>/dev/null"; then
		server_ready=1
		break
	fi
	sleep 0.1
done
if (( server_ready == 0 )); then
	ssh "$server_ssh" "tail -100 '$remote_log'" >&2 || true
	echo "isolated mux server did not become ready" >&2
	exit 1
fi

ssh -N -o ExitOnForwardFailure=yes \
	-L "127.0.0.1:$local_signal_port:127.0.0.1:$remote_signal_port" "$server_ssh" &
tunnel_pid=$!
sleep 0.5
if ! kill -0 "$tunnel_pid" >/dev/null 2>&1; then
	echo "signaling tunnel failed to start" >&2
	exit 1
fi

CAR_FIGHT_WEB_PORT="$web_port" CAR_FIGHT_WEB_OUTPUT="$project_root/build/web-network" \
	"$project_root/scripts/web_serve.sh" > "$run_dir/web-server.log" 2>&1 &
web_pid=$!
for _attempt in {1..100}; do
	if curl -fs -o /dev/null "http://127.0.0.1:$web_port/"; then
		break
	fi
	sleep 0.05
done
curl -fs -o /dev/null "http://127.0.0.1:$web_port/"

"${GODOT_BIN:-/Applications/Godot47.app/Contents/MacOS/Godot}" --headless \
	--path "$project_root" -- --client --transport enet --host "$server_ip" \
	--port "$remote_enet_port" --name native-survivor --script right --ticks 3900 \
	"${native_stack_args[@]}" \
	> "$run_dir/native.log" 2>&1 &
native_pid=$!
sleep 0.8

browser_url="http://127.0.0.1:$web_port/?signal=ws%3A%2F%2F127.0.0.1%3A$local_signal_port&name=browser&webrtcTelemetry=1&turn=turn%3A$turn_ip%3A3478&turnUser=$turn_user&turnCredential=$turn_credential&relay=1$browser_stack_query"
set +e
node "$project_root/scripts/web_network_smoke.mjs" "$browser_url" \
	"$run_dir/browser-report.json" "$run_dir/browser.png" \
	| tee "$run_dir/browser.log"
browser_status=${pipestatus[1]}
set -e

ssh "$turn_ssh" "pid=\$(docker inspect -f '{{.State.Pid}}' '$turn_container'); sudo nsenter -t \"\$pid\" -n tc -s qdisc show dev eth0" \
	> "$run_dir/netem-after.txt"
ssh "$turn_ssh" "docker logs '$turn_container' 2>&1" > "$run_dir/turn.log"
ssh "$server_ssh" "cp '$remote_log' /tmp/car-fight-network-shaping-server-copy.log; cat /tmp/car-fight-network-shaping-server-copy.log" \
	> "$run_dir/server.log"

netem_packets="$(awk '/Sent [0-9]+ bytes [0-9]+ pkt/ { print $4; exit }' "$run_dir/netem-after.txt")"
netem_drops="$(sed -n 's/.*(dropped \([0-9][0-9]*\),.*/\1/p' "$run_dir/netem-after.txt" | head -1)"
netem_packets="${netem_packets:-0}"
netem_drops="${netem_drops:-0}"
browser_queue_max="$(node -e 'const fs=require("fs"); const r=JSON.parse(fs.readFileSync(process.argv[1], "utf8")); process.stdout.write(String(r.webrtc_buffered_bytes?.maximum ?? -1))' "$run_dir/browser-report.json")"
browser_queue_final="$(node -e 'const fs=require("fs"); const r=JSON.parse(fs.readFileSync(process.argv[1], "utf8")); process.stdout.write(String(r.webrtc_buffered_bytes?.final ?? -1))' "$run_dir/browser-report.json")"
browser_fps_average="$(node -e 'const fs=require("fs"); const r=JSON.parse(fs.readFileSync(process.argv[1], "utf8")); process.stdout.write(String(r.steady_fps?.average ?? 0))' "$run_dir/browser-report.json")"
browser_errors="$(node -e 'const fs=require("fs"); const r=JSON.parse(fs.readFileSync(process.argv[1], "utf8")); process.stdout.write(String(r.errors?.length ?? 0))' "$run_dir/browser-report.json")"
server_queue_max="$(sed -n 's/.*label=ordered.*buffered_bytes=\([0-9][0-9]*\).*/\1/p' "$run_dir/server.log" | sort -n | tail -1)"
server_queue_final="$(sed -n 's/.*label=ordered.*buffered_bytes=\([0-9][0-9]*\).*/\1/p' "$run_dir/server.log" | tail -1)"
server_queue_max="${server_queue_max:-0}"
server_queue_final="${server_queue_final:-0}"
server_stale_warnings="$(rg -c 'Skipping stale rollback origin' "$run_dir/server.log" || true)"
{
	echo "profile=$profile"
	echo "stack=$stack_label"
	echo "latency_each_direction_ms=$CAR_FIGHT_SHAPE_LATENCY_MS"
	echo "jitter_each_direction_ms=$CAR_FIGHT_SHAPE_JITTER_MS"
	echo "loss_each_direction_pct=$CAR_FIGHT_SHAPE_LOSS_PCT"
	echo "turn_qdisc_packets=$netem_packets"
	echo "turn_qdisc_drops=$netem_drops"
	echo "browser_queue_max=$browser_queue_max"
	echo "browser_queue_final=$browser_queue_final"
	echo "browser_fps_average=$browser_fps_average"
	echo "browser_errors=$browser_errors"
	echo "server_ordered_queue_max=$server_queue_max"
	echo "server_ordered_queue_final=$server_queue_final"
	echo "server_stale_warnings=$server_stale_warnings"
	echo "browser_status=$browser_status"
} > "$run_dir/summary.txt"

if (( netem_packets < 100 )); then
	echo "TURN/netem path proof failed: only $netem_packets packets crossed the qdisc" >&2
	exit 1
fi
if awk -v loss="$CAR_FIGHT_SHAPE_LOSS_PCT" 'BEGIN { exit !(loss > 0) }' \
		&& (( netem_drops < 1 )); then
	echo "loss profile produced no measured qdisc drops" >&2
	exit 1
fi
if ! node -e 'const r=require(process.argv[1]); process.exit(r.network_configuration?.some(v => v.includes("turn=true") && v.includes("relay_only=true")) ? 0 : 1)' \
		"$run_dir/browser-report.json"; then
	echo "browser did not prove forced TURN configuration" >&2
	exit 1
fi
if ! rg -q 'CLIENT_TICK .*players=2 world=[^|]+\|[^ ]+' "$run_dir/native.log"; then
	echo "native ENet survivor did not share the mux world with the browser" >&2
	exit 1
fi
if (( server_queue_max > 65536 )); then
	echo "server WebRTC ordered queue exceeded 64 KiB: $server_queue_max bytes" >&2
	exit 1
fi
if rg -q 'SCRIPT ERROR|Parse Error|Invalid call|Invalid get index|Node not found|Failed to get path from RPC' \
		"$run_dir/browser.log" "$run_dir/native.log" "$run_dir/server.log"; then
	echo "runtime error under WebRTC shaping; see $run_dir" >&2
	exit 1
fi

if (( browser_status != 0 )); then
	echo "browser acceptance failed under '$profile'; evidence: $run_dir" >&2
	exit "$browser_status"
fi

echo "WEBRTC_SHAPE PASS profile=$profile qdisc_packets=$netem_packets drops=$netem_drops"
echo "evidence: $run_dir"
