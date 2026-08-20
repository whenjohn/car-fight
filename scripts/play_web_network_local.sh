#!/bin/zsh
# Human localhost cross-play: one safe-windowed native ENet client and one
# browser WebRTC client in the same isolated mux world.
set -euo pipefail
unsetopt BG_NICE

project_root="$(cd "$(dirname "$0")/.." && pwd)"
godot_bin="${GODOT_BIN:-/Applications/Godot47.app/Contents/MacOS/Godot}"
chrome_bin="${CHROME_BIN:-/Applications/Google Chrome.app/Contents/MacOS/Google Chrome}"
enet_port="${CAR_FIGHT_LOCAL_MUX_ENET_PORT:-12580}"
signal_port="${CAR_FIGHT_LOCAL_MUX_SIGNAL_PORT:-12581}"
web_port="${CAR_FIGHT_LOCAL_WEB_PORT:-18089}"
stamp="$(date '+%Y%m%d-%H%M%S')"
run_root="$project_root/.crash-runs/web-network-local-$stamp"
chrome_profile="$(mktemp -d "${TMPDIR:-/tmp}/car-fight-web-network-profile.XXXXXX")"
web_pid=""
server_pid=""
native_runner_pid=""
chrome_pid=""

cleanup() {
	for process_id in "$chrome_pid" "$native_runner_pid" "$server_pid" "$web_pid"; do
		if [[ "$process_id" == <-> ]] && (( process_id > 1 )); then
			kill "$process_id" >/dev/null 2>&1 || true
		fi
	done
	wait 2>/dev/null || true
	rm -rf "$chrome_profile"
}
trap cleanup EXIT INT TERM

mkdir -p "$run_root/native"
"$project_root/scripts/web_network_build.sh" release >"$run_root/web-build.log" 2>&1
CAR_FIGHT_WEB_PORT="$web_port" CAR_FIGHT_WEB_OUTPUT="$project_root/build/web-network" \
	"$project_root/scripts/web_serve.sh" >"$run_root/web-server.log" 2>&1 &
web_pid=$!
for _attempt in {1..100}; do
	if curl -fs -o /dev/null "http://127.0.0.1:$web_port/"; then
		break
	fi
	sleep 0.05
done
curl -fs -o /dev/null "http://127.0.0.1:$web_port/"

"$godot_bin" --headless --path "$project_root" -- --server --transport mux \
	--port "$enet_port" --signal-port "$signal_port" \
	>"$run_root/server.log" 2>&1 &
server_pid=$!
sleep 0.8
CAR_FIGHT_PORT="$enet_port" CAR_FIGHT_MONITOR_ROOT="$run_root/native" \
	CAR_FIGHT_SESSION_LABEL="browser-networking" \
	"$project_root/scripts/play_monitored.sh" --host 127.0.0.1 --name native-enet \
	--position 80,80 >"$run_root/native-runner.log" 2>&1 &
native_runner_pid=$!
sleep 1

browser_url="http://127.0.0.1:$web_port/?signal=ws%3A%2F%2F127.0.0.1%3A$signal_port&name=browser"
"$chrome_bin" --user-data-dir="$chrome_profile" --no-first-run \
	--no-default-browser-check --disable-extensions --window-size=1280,815 \
	--window-position=1360,80 --new-window "$browser_url" \
	>"$run_root/browser.stdout.log" 2>"$run_root/browser.stderr.log" &
chrome_pid=$!

echo "mixed local run: $run_root"
echo "native: ENet udp://127.0.0.1:$enet_port"
echo "browser: WebRTC via ws://127.0.0.1:$signal_port signaling"
echo "Both clients share one authoritative mux world. Close the native window to finish."

set +e
wait "$native_runner_pid"
native_status=$?
native_runner_pid=""
set -e
exit "$native_status"
