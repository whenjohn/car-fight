#!/bin/zsh
set -uo pipefail

project_root="$(cd "$(dirname "$0")/.." && pwd)"
profiles=(clean latency60 latency120 jitter loss05 loss1 combined)

failures=()
for profile in "${profiles[@]}"; do
	echo "WEBRTC_TURN_MATRIX profile=$profile"
	if ! "$project_root/scripts/webrtc_turn_shape_test.sh" "$profile"; then
		failures+=("$profile")
	fi
done

if (( ${#failures[@]} > 0 )); then
	echo "WEBRTC_TURN_MATRIX FAIL profiles=${failures[*]}" >&2
	exit 1
fi
echo "WEBRTC_TURN_MATRIX PASS profiles=${profiles[*]}"
