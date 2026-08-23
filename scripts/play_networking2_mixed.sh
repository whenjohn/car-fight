#!/bin/zsh
# Human Networking-2 cross-transport test: one safe-windowed native ENet player
# plus one Chrome WebRTC player forced through the 120 ms TURN path.
set -euo pipefail

project_root="$(cd "$(dirname "$0")/.." && pwd)"

echo "NETWORKING_2_MIXED configuration: macOS ENet direct to macai2 + Chrome WebRTC forced TURN at 120 ms one-way"
echo "NETWORKING_2_MIXED fixed mode: G2 divisor 1, proxy 75-150 ms, slow lane fixture, capsule radius 1.05/length 3.40"
echo "Harness arena is 480x480 with parallel 460-unit starting straightaways."
echo "Networking-2 local hull/camera reconciliation is enabled; physics and input remain raw."
echo "Press P in either client to toggle client-generated full-speed/non-burst cruise."
echo "Networking-2 diagnostic hotkey L (motion trace) is disabled."
echo "Both windows remain human clients. No mode changes occur automatically; close Chrome to stop."

CAR_FIGHT_INTERACTIVE_BROWSER=1 \
CAR_FIGHT_INTERACTIVE_NATIVE=1 \
CAR_FIGHT_SERVER_DRIVER_LANE=1 \
CAR_FIGHT_PLAYER_CAPSULE=1 \
CAR_FIGHT_NETWORK_TEST_ARENA=1 \
CAR_FIGHT_CLIENT_CRUISE=1 \
CAR_FIGHT_LOCAL_PRESENTATION_SMOOTHING=1 \
CAR_FIGHT_G2_STACK=1 \
CAR_FIGHT_STATE_RATE_DIVISOR=1 \
CAR_FIGHT_REMOTE_INTERP_MODE=proxy \
CAR_FIGHT_REMOTE_INTERP_MS=75 \
CAR_FIGHT_REMOTE_INTERP_MAX_MS=150 \
CAR_FIGHT_NETWORK_HUD=1 \
	"$project_root/scripts/webrtc_turn_shape_test.sh" latency120
