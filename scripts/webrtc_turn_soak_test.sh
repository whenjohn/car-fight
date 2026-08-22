#!/bin/zsh
# Long forced-TURN durability/reconnect gate for the accepted Networking-1
# configuration. This is intentionally separate from the ordinary local suite:
# it uses macai2, macmini TURN/netem, and a rendered automated Chrome client.
set -euo pipefail

project_root="$(cd "$(dirname "$0")/.." && pwd)"
soak_seconds="${CAR_FIGHT_WEBRTC_SOAK_SECONDS:-600}"
if [[ "$soak_seconds" != <-> ]] || (( soak_seconds < 60 )); then
	echo "CAR_FIGHT_WEBRTC_SOAK_SECONDS must be an integer of at least 60" >&2
	exit 2
fi

echo "WEBRTC_TURN_SOAK configuration: forced TURN, 120 ms one-way, G2 divisor 1, proxy 75-150 ms, capsule radius 1.05/length 3.40, slow lane fixture"
echo "WEBRTC_TURN_SOAK observation: ${soak_seconds}s after one browser leave/rejoin; mode will not change"

CAR_FIGHT_WEBRTC_SOAK_SECONDS="$soak_seconds" \
CAR_FIGHT_SHAPE_FAILSAFE_SECONDS="$((soak_seconds + 300))" \
CAR_FIGHT_INTERACTIVE_BROWSER=0 \
CAR_FIGHT_SERVER_DRIVER_LANE=1 \
CAR_FIGHT_PLAYER_CAPSULE=1 \
CAR_FIGHT_G2_STACK=1 \
CAR_FIGHT_STATE_RATE_DIVISOR=1 \
CAR_FIGHT_REMOTE_INTERP_MODE=proxy \
CAR_FIGHT_REMOTE_INTERP_MS=75 \
CAR_FIGHT_REMOTE_INTERP_MAX_MS=150 \
CAR_FIGHT_NETWORK_HUD=1 \
	"$project_root/scripts/webrtc_turn_shape_test.sh" latency120

echo "WEBRTC_TURN_SOAK PASS duration=${soak_seconds}s"
