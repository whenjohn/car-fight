#!/bin/zsh
set -uo pipefail

project_root="$(cd "$(dirname "$0")/.." && pwd)"
profiles=(clean latency60 latency120 jitter loss05 loss1 combined)

failures=()
for profile in "${profiles[@]}"; do
	echo "NETWORK_MATRIX profile=$profile"
	if ! "$project_root/scripts/network_test.sh" "$profile"; then
		failures+=("$profile")
	fi
done

if (( ${#failures[@]} > 0 )); then
	echo "NETWORK_MATRIX FAIL profiles=${failures[*]}" >&2
	exit 1
fi
echo "NETWORK_MATRIX PASS profiles=${profiles[*]}"
