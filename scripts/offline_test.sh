#!/bin/zsh
set -euo pipefail

project_root="$(cd "$(dirname "$0")/.." && pwd)"
godot_bin="${GODOT_BIN:-/Applications/Godot47.app/Contents/MacOS/Godot}"
log_file="$(mktemp "${TMPDIR:-/tmp}/car-fight-offline.XXXXXX")"

"$godot_bin" --headless --path "$project_root" -- \
	--offline --script burst-right --ticks 240 >"$log_file" 2>&1

if ! rg -q 'OFFLINE_READY id=1 players=1 balls=1 map=0' "$log_file"; then
	echo "offline world did not seed its local player and ball; log: $log_file" >&2
	tail -100 "$log_file" >&2
	exit 1
fi
if ! rg -q 'RESULT players=1 .*boosting=1' "$log_file"; then
	echo "offline player did not gather and simulate local drive input; log: $log_file" >&2
	tail -100 "$log_file" >&2
	exit 1
fi
result_line="$(rg 'RESULT players=1' "$log_file" | tail -1)"
result_fields="$(printf '%s\n' "$result_line" \
	| sed -E 's/^.*RESULT //; s/=[^ ]+//g')"
expected_fields="players minpair contact escapes bumps ballmax maxy landed grounded rebound tilt maxtilt minx cloaked shields boosting tractorgrabs tractorticks shots hits ballhits droneshots dets impacthits shieldhits impactmax rcshots rcdets rchits coursemaps courseoff gatetransitions"
if [[ "$result_fields" != "$expected_fields" ]]; then
	echo "offline RESULT schema changed; log: $log_file" >&2
	echo "expected: $expected_fields" >&2
	echo "actual:   $result_fields" >&2
	exit 1
fi
if rg -q 'Could not connect|Could not listen|SCRIPT ERROR|Parse Error|Compile Error|stale rollback origin' \
		"$log_file"; then
	echo "offline world attempted transport/rollback startup or produced a script error; log: $log_file" >&2
	rg 'Could not connect|Could not listen|SCRIPT ERROR|Parse Error|Compile Error|stale rollback origin' \
		"$log_file" >&2
	exit 1
fi

echo "OFFLINE_TEST PASS"
echo "log: $log_file"
