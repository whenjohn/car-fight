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
turn_user="car-fight"
turn_credential="car-fight-shape"
remote_root="${CAR_FIGHT_SHAPE_REMOTE_ROOT:-/Users/macai2/Projects/car-fight-network-shaping}"
remote_godot="${CAR_FIGHT_SHAPE_REMOTE_GODOT:-/Applications/Godot.app/Contents/MacOS/Godot}"
remote_enet_port="${CAR_FIGHT_SHAPE_REMOTE_ENET_PORT:-12480}"
remote_signal_port="${CAR_FIGHT_SHAPE_REMOTE_SIGNAL_PORT:-12481}"
local_signal_port="${CAR_FIGHT_SHAPE_LOCAL_SIGNAL_PORT:-12581}"
web_port="${CAR_FIGHT_SHAPE_WEB_PORT:-18189}"
soak_seconds="${CAR_FIGHT_WEBRTC_SOAK_SECONDS:-0}"
if [[ "$soak_seconds" != <-> ]]; then
	echo "CAR_FIGHT_WEBRTC_SOAK_SECONDS must be a non-negative integer" >&2
	exit 2
fi
failsafe_default=300
if (( soak_seconds > 0 )); then
	failsafe_default=$((soak_seconds + 300))
fi
failsafe_seconds="${CAR_FIGHT_SHAPE_FAILSAFE_SECONDS:-$failsafe_default}"
server_ticks="${CAR_FIGHT_WEBRTC_SERVER_TICKS:-4200}"
native_ticks="${CAR_FIGHT_WEBRTC_NATIVE_TICKS:-3900}"
if (( soak_seconds > 0 )); then
	[[ -n "${CAR_FIGHT_WEBRTC_SERVER_TICKS:-}" ]] \
		|| server_ticks=$(((soak_seconds + 180) * 60))
	[[ -n "${CAR_FIGHT_WEBRTC_NATIVE_TICKS:-}" ]] \
		|| native_ticks=$(((soak_seconds + 150) * 60))
fi
interactive_browser="${CAR_FIGHT_INTERACTIVE_BROWSER:-0}"
interactive_native="${CAR_FIGHT_INTERACTIVE_NATIVE:-0}"
if [[ "$interactive_native" == "1" && "$interactive_browser" != "1" ]]; then
	echo "CAR_FIGHT_INTERACTIVE_NATIVE requires CAR_FIGHT_INTERACTIVE_BROWSER=1" >&2
	exit 2
fi
if [[ "$interactive_browser" == "1" && -z "${CAR_FIGHT_SHAPE_FAILSAFE_SECONDS:-}" ]]; then
	# Human cross-play sessions routinely include several observation passes. Keep
	# the remote cleanup guard, but do not tear TURN down during a careful test.
	failsafe_seconds=7200
fi
presentation_mode="${CAR_FIGHT_REMOTE_INTERP_MODE:-fixed}"
presentation_min="${CAR_FIGHT_REMOTE_INTERP_MS:-75}"
presentation_max="${CAR_FIGHT_REMOTE_INTERP_MAX_MS:-150}"
presentation_trace_seconds="${CAR_FIGHT_PRESENTATION_TRACE_SECONDS:-0}"
server_driver_arg=""
if [[ "$interactive_browser" == "1" || "${CAR_FIGHT_SHAPE_SERVER_DRIVER:-0}" == "1" ]]; then
	server_driver_arg="--server-driver"
fi
driver_mode="perimeter"
if [[ "${CAR_FIGHT_SERVER_DRIVER_LANE:-0}" == "1" ]]; then
	server_driver_arg="--server-driver-lane"
	driver_mode="slow-left-lane"
fi
if [[ "${CAR_FIGHT_SHAPE_HUMANS_ONLY:-0}" == "1" ]]; then
	server_driver_arg=""
	driver_mode="none"
fi
server_drone_arg="--no-drone"
native_no_drone=1
if [[ "${CAR_FIGHT_SHAPE_DRONE:-0}" == "1" ]]; then
	server_drone_arg=""
	native_no_drone=0
fi
player_capsule_enabled="${CAR_FIGHT_PLAYER_CAPSULE:-1}"
player_capsule_arg="--player-capsule"
if [[ "$player_capsule_enabled" == "0" ]]; then
	player_capsule_arg="--no-player-capsule"
fi
network_test_arena="${CAR_FIGHT_NETWORK_TEST_ARENA:-0}"
server_arena_arg=""
native_arena_args=()
browser_arena_query=""
if [[ "$network_test_arena" == "1" ]]; then
	server_arena_arg="--network-test-arena"
	native_arena_args=(--network-test-arena)
	browser_arena_query="&networkTestArena=1"
fi
client_cruise_enabled="${CAR_FIGHT_CLIENT_CRUISE:-0}"
if [[ "$client_cruise_enabled" == "1" ]]; then
	native_arena_args+=(--client-cruise)
	browser_arena_query+="&clientCruise=1"
fi
motion_trace_enabled="${CAR_FIGHT_MOTION_TRACE:-0}"
native_motion_args=()
browser_motion_query=""
if [[ "$motion_trace_enabled" == "1" ]]; then
	native_motion_args=(--motion-trace)
	browser_motion_query="&motionTrace=1"
fi
local_presentation_enabled="${CAR_FIGHT_LOCAL_PRESENTATION_SMOOTHING:-0}"
if [[ "$local_presentation_enabled" == "1" ]]; then
	native_motion_args+=(--local-presentation-smoothing)
	browser_motion_query+="&localPresentationSmoothing=1"
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
native_stack_args+=(--remote-interp-mode "$presentation_mode" \
	--remote-interp "$presentation_min" --remote-interp-max "$presentation_max")
browser_stack_query+="&remoteInterpMode=$presentation_mode&remoteInterpMs=$presentation_min&remoteInterpMaxMs=$presentation_max&networkProfile=$profile"
browser_stack_query+="$browser_arena_query"
browser_stack_query+="$browser_motion_query"
if [[ -n "${CAR_FIGHT_JOIN_STALL_MS:-}" ]]; then
	browser_stack_query+="&joinStallMs=$CAR_FIGHT_JOIN_STALL_MS&joinStallAfterMs=${CAR_FIGHT_JOIN_STALL_AFTER_MS:-0}"
fi
if [[ "$interactive_browser" == "1" || "${CAR_FIGHT_NETWORK_HUD:-0}" == "1" ]]; then
	browser_stack_query+="&networkHud=1&netTelemetry=1&hotkeyHints=0"
fi
if [[ "$presentation_trace_seconds" != "0" ]]; then
	browser_stack_query+="&presentationTraceSeconds=$presentation_trace_seconds"
fi

run_stamp="$(date -u '+%Y%m%dT%H%M%SZ')"
run_id="${run_stamp}-$$-${RANDOM}"
run_dir="$project_root/.network-runs/$run_id-webrtc-$profile"
turn_container="car-fight-network-turn-$run_id"
turn_network="car-fight-network-turn-net-$run_id"
remote_pidfile="/tmp/car-fight-network-shaping-server-$run_id.pid"
remote_log="/tmp/car-fight-network-shaping-server-$run_id.log"
web_pid=""
native_pid=""
chrome_pid=""
tunnel_pid=""
turn_started=0
failsafe_pid=""
server_started=0
cleanup_started=0
evidence_captured=0
run_lock_dir="${TMPDIR:-/tmp}/car-fight-webrtc-turn-${local_signal_port}-${web_port}.lock"
run_lock_owner="$run_lock_dir/owner"
run_lock_acquired=0

release_run_lock() {
	if (( run_lock_acquired == 0 )); then
		return
	fi
	unlink "$run_lock_owner" >/dev/null 2>&1 || true
	rmdir "$run_lock_dir" >/dev/null 2>&1 || true
	run_lock_acquired=0
}

acquire_run_lock() {
	if mkdir "$run_lock_dir" 2>/dev/null; then
		run_lock_acquired=1
		print -r -- "pid=$$ run_id=$run_id project=$project_root" > "$run_lock_owner"
		return
	fi
	local owner="$(command cat "$run_lock_owner" 2>/dev/null || true)"
	local owner_pid="${${owner#pid=}%% *}"
	if [[ "$owner_pid" == <-> ]] && kill -0 "$owner_pid" >/dev/null 2>&1; then
		echo "another WebRTC TURN harness owns ports $local_signal_port/$web_port; refusing concurrent launch:" >&2
		print -r -- "$owner" >&2
		exit 1
	fi
	# A hard-killed shell cannot run its EXIT trap. Recover only this exact,
	# ownerless lock; the later port and remote checks still reject live children.
	unlink "$run_lock_owner" >/dev/null 2>&1 || true
	rmdir "$run_lock_dir" >/dev/null 2>&1 || true
	if ! mkdir "$run_lock_dir" 2>/dev/null; then
		echo "WebRTC TURN harness lock changed during stale-lock recovery; refusing launch" >&2
		exit 1
	fi
	run_lock_acquired=1
	print -r -- "pid=$$ run_id=$run_id project=$project_root" > "$run_lock_owner"
}

port_owner() {
	local port="$1"
	/usr/sbin/lsof -nP -iTCP:"$port" -sTCP:LISTEN 2>/dev/null || true
}

preflight_local_port() {
	local label="$1"
	local port="$2"
	local owner="$(port_owner "$port")"
	if [[ -n "$owner" ]]; then
		echo "$label port $port is already occupied; refusing stale harness reuse:" >&2
		print -r -- "$owner" >&2
		exit 1
	fi
}

# The lock must precede port checks: two launches can both pass read-only
# preflight before either has opened a port or created TURN.
trap release_run_lock EXIT
acquire_run_lock

# These checks must happen before a build, rsync, or remote/container mutation.
preflight_local_port "signaling tunnel" "$local_signal_port"
preflight_local_port "web server" "$web_port"

mkdir -p "$run_dir"
chrome_profile=""
if [[ "$interactive_browser" == "1" ]]; then
	chrome_profile="$run_dir/chrome-profile"
	mkdir -p "$chrome_profile"
fi

stop_remote_server() {
	ssh "$server_ssh" "if test -r '$remote_pidfile'; then pid=\$(cat '$remote_pidfile'); command=\$(ps -p \"\$pid\" -o command= 2>/dev/null || true); case \"\$command\" in *'$remote_root'*'--signal-port $remote_signal_port'*'--run-id $run_id'*) kill \"\$pid\" >/dev/null 2>&1 || true;; esac; unlink '$remote_pidfile' >/dev/null 2>&1 || true; fi" || true
}

capture_owned_evidence() {
	if (( evidence_captured == 1 )); then
		return
	fi
	evidence_captured=1
	if (( server_started == 1 )); then
		ssh "$server_ssh" "test -r '$remote_log' && cat '$remote_log'" \
			> "$run_dir/server.log" 2>/dev/null || true
	fi
	if (( turn_started == 1 )); then
		ssh "$turn_ssh" "docker logs '$turn_container' 2>&1" \
			> "$run_dir/turn.log" 2>/dev/null || true
		ssh "$turn_ssh" "pid=\$(docker inspect -f '{{.State.Pid}}' '$turn_container' 2>/dev/null) || exit 0; sudo nsenter -t \"\$pid\" -n tc -s qdisc show dev eth0" \
			> "$run_dir/netem-final.txt" 2>/dev/null || true
	fi
}

cleanup() {
	if (( cleanup_started == 1 )); then
		return
	fi
	cleanup_started=1
	capture_owned_evidence
	for process_id in "$chrome_pid" "$native_pid" "$web_pid" "$tunnel_pid"; do
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
	release_run_lock
}

handle_signal() {
	local exit_status="$1"
	cleanup
	trap - EXIT HUP INT TERM
	exit "$exit_status"
}

trap cleanup EXIT
trap 'handle_signal 129' HUP
trap 'handle_signal 130' INT
trap 'handle_signal 143' TERM

echo "WEBRTC_SHAPE profile=$profile one_way=${CAR_FIGHT_SHAPE_LATENCY_MS}ms jitter=+/-${CAR_FIGHT_SHAPE_JITTER_MS}ms loss=${CAR_FIGHT_SHAPE_LOSS_PCT}%"
echo "run_id: $run_id"
echo "evidence: $run_dir"
if (( soak_seconds > 0 )); then
	echo "soak: ${soak_seconds}s with one browser leave/rejoin; server_ticks=$server_ticks native_ticks=$native_ticks"
fi
if [[ "$interactive_browser" == "1" ]]; then
	echo "interactive browser: driver=$driver_mode; drone=${CAR_FIGHT_SHAPE_DRONE:-0}; player_capsule=$player_capsule_enabled; failsafe=${failsafe_seconds}s; close Chrome to stop"
fi

if [[ "${CAR_FIGHT_HARNESS_LIFECYCLE_TEST:-0}" == "1" ]]; then
	node "$project_root/scripts/harness_port_listener.mjs" \
		"$local_signal_port" "$web_port" "$run_id" > "$run_dir/lifecycle-listener.log" 2>&1 &
	web_pid=$!
	for _attempt in {1..100}; do
		if rg -q "HARNESS_PORTS_READY run_id=$run_id" "$run_dir/lifecycle-listener.log"; then
			echo "HARNESS_LIFECYCLE_READY run_id=$run_id signal=$local_signal_port web=$web_port"
			wait "$web_pid"
			exit $?
		fi
		sleep 0.05
	done
	echo "lifecycle listener did not acquire both ports" >&2
	exit 1
fi

remote_signal_owner="$(ssh "$server_ssh" "/usr/sbin/lsof -nP -iTCP:$remote_signal_port -sTCP:LISTEN 2>/dev/null || true")"
if [[ -n "$remote_signal_owner" ]]; then
	echo "remote signaling port $remote_signal_port on $server_ssh is occupied; refusing stale server reuse:" >&2
	print -r -- "$remote_signal_owner" >&2
	exit 1
fi

web_build_mode="${CAR_FIGHT_WEB_BUILD_MODE:-release}"
"$project_root/scripts/web_network_build.sh" "$web_build_mode"

# Sync only to the isolated harness checkout. The production car-fight checkout
# and launchd service are never addressed by this script.
ssh "$server_ssh" "mkdir -p '$remote_root'"
rsync -az --delete --exclude='.git/' --exclude='.godot/' --exclude='build/' \
	--exclude='.crash-runs/' --exclude='.network-runs/' \
	"$project_root/" "$server_ssh:$remote_root/"
ssh "$server_ssh" "'$remote_godot' --headless --path '$remote_root' --editor --quit" \
	> "$run_dir/remote-import.log" 2>&1 || true

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
server_ticks_arg="--ticks $server_ticks"
if [[ "$interactive_browser" == "1" ]]; then
	server_ticks_arg=""
fi
ssh "$server_ssh" "nohup '$remote_godot' --headless --path '$remote_root' -- --server --transport mux --port '$remote_enet_port' --signal-port '$remote_signal_port' --run-id '$run_id' $server_drone_arg $server_driver_arg $player_capsule_arg $server_arena_arg --webrtc-telemetry $server_ticks_arg $server_stack_args > '$remote_log' 2>&1 & echo \$! > '$remote_pidfile'"
server_started=1
server_ready=0
for _attempt in {1..100}; do
	if ssh "$server_ssh" "grep -q 'server listening transport=mux' '$remote_log' 2>/dev/null"; then
		server_ready=1
		break
	fi
	sleep 0.1
done
if (( server_ready == 0 )) || ! ssh "$server_ssh" "grep -q 'RUN_ID id=$run_id role=server transport=mux' '$remote_log'"; then
	ssh "$server_ssh" "tail -100 '$remote_log'" >&2 || true
	echo "isolated mux server did not become ready with run ID $run_id" >&2
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

{
	echo "HARNESS_RUN_ID id=$run_id component=web-server port=$web_port"
	CAR_FIGHT_WEB_PORT="$web_port" CAR_FIGHT_WEB_OUTPUT="$project_root/build/web-network" \
		"$project_root/scripts/web_serve.sh"
} > "$run_dir/web-server.log" 2>&1 &
web_pid=$!
for _attempt in {1..100}; do
	if curl -fs -o /dev/null "http://127.0.0.1:$web_port/"; then
		break
	fi
	sleep 0.05
done
curl -fs -o /dev/null "http://127.0.0.1:$web_port/"

if [[ "$interactive_native" == "1" ]]; then
	mkdir -p "$run_dir/native-client"
	CAR_FIGHT_TELEMETRY_FILE="$run_dir/native-client/telemetry.jsonl" \
	CAR_FIGHT_NO_DRONE="$native_no_drone" CAR_FIGHT_NETWORK_HUD=1 \
		"${GODOT_BIN:-/Applications/Godot.app/Contents/MacOS/Godot}" \
		--windowed --position 80,80 --path "$project_root" -- \
		--client --transport enet --host "$server_ip" --port "$remote_enet_port" \
		--name macos-enet --session-label networking2-mixed --run-id "$run_id" \
		--network-hud --network-profile "$profile" --net-telemetry --hide-hotkey-hints \
		"${native_stack_args[@]}" "${native_arena_args[@]}" "${native_motion_args[@]}" \
		> "$run_dir/native.log" 2>&1 &
	native_pid=$!
	native_ready=0
	for _attempt in {1..450}; do
		if ! kill -0 "$native_pid" >/dev/null 2>&1; then
			break
		fi
		if rg -q "RUN_ID id=$run_id role=client transport=enet" "$run_dir/native.log" \
				&& rg -q 'CLIENT_READY id=' "$run_dir/native.log"; then
			native_ready=1
			break
		fi
		sleep 0.1
	done
	if (( native_ready == 0 )); then
		echo "interactive native ENet client did not become ready; see $run_dir/native.log" >&2
		exit 1
	fi
	sleep 0.5
elif [[ "$interactive_browser" != "1" ]]; then
	native_script_args=(--script right)
	if (( soak_seconds > 0 )); then
		# The survivor proves mux topology only. Keep it in map 0 during a long
		# soak instead of letting the scripted drive eventually enter a map gate.
		native_script_args=()
	fi
	"${GODOT_BIN:-/Applications/Godot.app/Contents/MacOS/Godot}" --headless \
		--path "$project_root" -- --client --transport enet --host "$server_ip" \
		--port "$remote_enet_port" --name native-survivor "${native_script_args[@]}" --ticks "$native_ticks" \
		"${native_stack_args[@]}" \
		> "$run_dir/native.log" 2>&1 &
	native_pid=$!
	sleep 0.8
fi

browser_script_query=""
if (( soak_seconds > 0 )) && [[ "$interactive_browser" != "1" ]]; then
	# Automated soaks stay parked so topology is stable. Human browser soaks
	# must keep ordinary input active, including the opt-in P cruise control.
	browser_script_query="&script=idle"
fi
browser_url="http://127.0.0.1:$web_port/?signal=ws%3A%2F%2F127.0.0.1%3A$local_signal_port&name=browser&runId=$run_id&webrtcTelemetry=1&turn=turn%3A$turn_ip%3A3478&turnUser=$turn_user&turnCredential=$turn_credential&relay=1$browser_stack_query$browser_script_query"
if [[ "$interactive_browser" == "1" ]]; then
	chrome_bin="${CHROME_BIN:-/Applications/Google Chrome.app/Contents/MacOS/Google Chrome}"
	echo "browser control: node scripts/set_networking1_browser_mode.mjs '$chrome_profile' fixed|adaptive|predictive|proxy|cruise"
	"$chrome_bin" --remote-debugging-port=0 --user-data-dir="$chrome_profile" \
		--no-first-run --no-default-browser-check --disable-extensions \
		--disable-background-timer-throttling --disable-backgrounding-occluded-windows \
		--disable-renderer-backgrounding --enable-logging=stderr \
		--window-size=1280,815 \
		--window-position=$((interactive_native == 1 ? 1360 : 80)),80 \
		--new-window "$browser_url" \
		>"$run_dir/browser.stdout.log" 2>"$run_dir/browser.stderr.log" &
	chrome_pid=$!
	interactive_ready=0
	for _attempt in {1..900}; do
		if ! kill -0 "$chrome_pid" >/dev/null 2>&1; then
			break
		fi
		browser_identity=0
		webrtc_ready=0
		state_ready=0
		rtt_ready=0
		rg -q "RUN_ID id=$run_id role=client transport=webrtc" "$run_dir/browser.stderr.log" 2>/dev/null && browser_identity=1
		rg -q '\[webrtc-channel\].*mode=client.*state=open' "$run_dir/browser.stderr.log" 2>/dev/null && webrtc_ready=1
		rg -q '\[remote-state-rx\].*batches=[1-9][0-9]*' "$run_dir/browser.stderr.log" 2>/dev/null && state_ready=1
		rg -q 'NETWORKHUD .*"rtt_ms":[1-9][0-9]*([.]?[0-9]*)' "$run_dir/browser.stderr.log" 2>/dev/null && rtt_ready=1
		if (( browser_identity == 1 && webrtc_ready == 1 && state_ready == 1 && rtt_ready == 1 )); then
			interactive_ready=1
			break
		fi
		sleep 0.1
	done
	if (( interactive_ready == 0 )); then
		echo "interactive readiness failed run_id=$run_id browser_identity=${browser_identity:-0} webrtc=${webrtc_ready:-0} first_state_batch=${state_ready:-0} nonzero_rtt=${rtt_ready:-0}" >&2
		exit 1
	fi
	peer_mode="browser-only"
	if [[ "$interactive_native" == "1" ]]; then
		peer_mode="macos-enet-direct+browser-webrtc-turn"
	fi
	echo "PLAYABLE_READY run_id=$run_id profile=$profile one_way=${CAR_FIGHT_SHAPE_LATENCY_MS}ms peers=$peer_mode driver=$driver_mode capsule=radius1.05_length3.40 presentation=$presentation_mode state_divisor=${state_rate_divisor:-legacy} forced_turn=1 arena_half=$((network_test_arena == 1 ? 240 : 84)) client_cruise=$client_cruise_enabled motion_trace=$motion_trace_enabled local_presentation=$local_presentation_enabled"
	echo "mode will remain $presentation_mode until you explicitly change it; close Chrome to stop"
	wait "$chrome_pid"
	exit $?
fi
set +e
node "$project_root/scripts/web_network_smoke.mjs" "$browser_url" \
	"$run_dir/browser-report.json" "$run_dir/browser.png" \
	2>&1 | tee "$run_dir/browser.log"
browser_status=${pipestatus[1]}
set -e

ssh "$turn_ssh" "pid=\$(docker inspect -f '{{.State.Pid}}' '$turn_container'); sudo nsenter -t \"\$pid\" -n tc -s qdisc show dev eth0" \
	> "$run_dir/netem-after.txt"
ssh "$turn_ssh" "docker logs '$turn_container' 2>&1" > "$run_dir/turn.log"
ssh "$server_ssh" "cat '$remote_log'" > "$run_dir/server.log"

if [[ ! -s "$run_dir/browser-report.json" ]]; then
	echo "browser monitor stopped before producing its report; evidence: $run_dir" >&2
	exit "$((browser_status == 0 ? 1 : browser_status))"
fi

netem_packets="$(awk '/Sent [0-9]+ bytes [0-9]+ pkt/ { print $4; exit }' "$run_dir/netem-after.txt")"
netem_drops="$(sed -n 's/.*(dropped \([0-9][0-9]*\),.*/\1/p' "$run_dir/netem-after.txt" | head -1)"
netem_packets="${netem_packets:-0}"
netem_drops="${netem_drops:-0}"
browser_queue_max="$(node -e 'const fs=require("fs"); const r=JSON.parse(fs.readFileSync(process.argv[1], "utf8")); process.stdout.write(String(r.webrtc_buffered_bytes?.maximum ?? -1))' "$run_dir/browser-report.json")"
browser_queue_final="$(node -e 'const fs=require("fs"); const r=JSON.parse(fs.readFileSync(process.argv[1], "utf8")); process.stdout.write(String(r.webrtc_buffered_bytes?.final ?? -1))' "$run_dir/browser-report.json")"
browser_fps_average="$(node -e 'const fs=require("fs"); const r=JSON.parse(fs.readFileSync(process.argv[1], "utf8")); process.stdout.write(String(r.steady_fps?.average ?? 0))' "$run_dir/browser-report.json")"
browser_errors="$(node -e 'const fs=require("fs"); const r=JSON.parse(fs.readFileSync(process.argv[1], "utf8")); process.stdout.write(String(r.errors?.length ?? 0))' "$run_dir/browser-report.json")"
browser_soak_observed="$(node -e 'const fs=require("fs"); const r=JSON.parse(fs.readFileSync(process.argv[1], "utf8")); process.stdout.write(String(r.soak_seconds_observed ?? 0))' "$run_dir/browser-report.json")"
browser_recoveries="$(node -e 'const fs=require("fs"); const r=JSON.parse(fs.readFileSync(process.argv[1], "utf8")); process.stdout.write(String(r.network_health?.recoveries ?? -1))' "$run_dir/browser-report.json")"
browser_worst_correction="$(node -e 'const fs=require("fs"); const r=JSON.parse(fs.readFileSync(process.argv[1], "utf8")); process.stdout.write(String(r.network_health?.worst_correction ?? -1))' "$run_dir/browser-report.json")"
browser_stale_warnings="$(node -e 'const fs=require("fs"); const r=JSON.parse(fs.readFileSync(process.argv[1], "utf8")); process.stdout.write(String(r.stale_rollback_warnings ?? -1))' "$run_dir/browser-report.json")"
server_queue_max="$(sed -n 's/.*label=ordered.*buffered_bytes=\([0-9][0-9]*\).*/\1/p' "$run_dir/server.log" | sort -n | tail -1)"
server_queue_final="$(sed -n 's/.*label=ordered.*buffered_bytes=\([0-9][0-9]*\).*/\1/p' "$run_dir/server.log" | tail -1)"
server_queue_max="${server_queue_max:-0}"
server_queue_final="${server_queue_final:-0}"
server_stale_warnings="$(rg -c 'Skipping stale rollback origin' "$run_dir/server.log" || true)"
{
	echo "run_id=$run_id"
	echo "profile=$profile"
	echo "stack=$stack_label"
	echo "soak_seconds_requested=$soak_seconds"
	echo "soak_seconds_observed=$browser_soak_observed"
	echo "presentation_mode=$presentation_mode"
	echo "presentation_min_ms=$presentation_min"
	echo "presentation_max_ms=$presentation_max"
	echo "latency_each_direction_ms=$CAR_FIGHT_SHAPE_LATENCY_MS"
	echo "jitter_each_direction_ms=$CAR_FIGHT_SHAPE_JITTER_MS"
	echo "loss_each_direction_pct=$CAR_FIGHT_SHAPE_LOSS_PCT"
	echo "turn_qdisc_packets=$netem_packets"
	echo "turn_qdisc_drops=$netem_drops"
	echo "browser_queue_max=$browser_queue_max"
	echo "browser_queue_final=$browser_queue_final"
	echo "browser_fps_average=$browser_fps_average"
	echo "browser_errors=$browser_errors"
	echo "browser_recoveries=$browser_recoveries"
	echo "browser_worst_correction=$browser_worst_correction"
	echo "browser_stale_warnings=$browser_stale_warnings"
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
shared_players=2
alone_players=1
if [[ -n "$server_driver_arg" ]]; then
	shared_players=3
	alone_players=2
fi
if ! rg -q "CLIENT_TICK .*players=$shared_players world=[^|]+\\|[^ ]+" "$run_dir/native.log"; then
	echo "native ENet survivor did not share the mux world with the browser" >&2
	exit 1
fi
first_shared_line="$(rg -n "CLIENT_TICK .*players=$shared_players world=[^|]+\\|[^ ]+" \
	"$run_dir/native.log" | head -1 | cut -d: -f1 || true)"
alone_line="$(rg -n "CLIENT_TICK .*players=$alone_players world=" "$run_dir/native.log" \
	| cut -d: -f1 | awk -v after="${first_shared_line:-0}" '$1 > after {print; exit}' || true)"
last_shared_line="$(rg -n "CLIENT_TICK .*players=$shared_players world=[^|]+\\|[^ ]+" \
	"$run_dir/native.log" | tail -1 | cut -d: -f1 || true)"
if [[ -z "$first_shared_line" || -z "$alone_line" || -z "$last_shared_line" ]] \
		|| (( first_shared_line >= alone_line || alone_line >= last_shared_line )); then
	echo "native ENet survivor did not observe browser leave/rejoin topology; see $run_dir" >&2
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
if (( soak_seconds > 0 )); then
	if ! awk -v observed="$browser_soak_observed" -v requested="$soak_seconds" \
		'BEGIN { exit !(observed >= requested) }'; then
		echo "browser soak ended early: observed=${browser_soak_observed}s requested=${soak_seconds}s" >&2
		exit 1
	fi
	if (( browser_recoveries < 0 || browser_recoveries > 4 \
			|| browser_stale_warnings < 0 || browser_stale_warnings > 4 )); then
		echo "browser recovery was not bounded: recoveries=$browser_recoveries stale_warnings=$browser_stale_warnings" >&2
		exit 1
	fi
	if ! awk -v correction="$browser_worst_correction" \
		'BEGIN { exit !(correction >= 0 && correction <= 2.0) }'; then
		echo "browser correction exceeded the existing 2-unit ceiling: $browser_worst_correction" >&2
		exit 1
	fi
fi

if (( browser_status != 0 )); then
	echo "browser acceptance failed under '$profile'; evidence: $run_dir" >&2
	exit "$browser_status"
fi

echo "WEBRTC_SHAPE PASS profile=$profile qdisc_packets=$netem_packets drops=$netem_drops soak=${browser_soak_observed}s"
echo "evidence: $run_dir"
