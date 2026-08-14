#!/bin/zsh
set -euo pipefail

project_root="$(cd "$(dirname "$0")/.." && pwd)"
spike="$project_root/scripts/fullscreen_spike.sh"

approaches=(
	opengl-runtime-vsync
	opengl-startup-vsync
	opengl-runtime-cap60
	opengl-runtime-cap30
	opengl-runtime-novsync60
	vulkan-runtime-vsync
)

list_output="$($spike list)"
for approach in "${approaches[@]}"; do
	if [[ "$list_output" != *"$approach"* ]]; then
		echo "FULLSCREEN_SPIKE_TEST FAIL missing list entry: $approach" >&2
		exit 1
	fi
	dry_output="$($spike run "$approach" --dry-run --seconds 12)"
	if [[ "$dry_output" != *"approach=$approach"* \
			|| "$dry_output" != *"--stop-on-precursor"* \
			|| "$dry_output" != *"--post-exit-seconds"* ]]; then
		echo "FULLSCREEN_SPIKE_TEST FAIL incomplete dry run: $approach" >&2
		exit 1
	fi
done

if "$spike" run opengl-runtime-vsync --seconds 12 \
		>/dev/null 2>&1; then
	echo "FULLSCREEN_SPIKE_TEST FAIL risk acknowledgement was optional" >&2
	exit 1
fi
if "$spike" run not-an-approach --dry-run >/dev/null 2>&1; then
	echo "FULLSCREEN_SPIKE_TEST FAIL unknown approach was accepted" >&2
	exit 1
fi

echo "FULLSCREEN_SPIKE_TEST PASS approaches=${#approaches} rendered=0"
