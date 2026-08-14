#!/bin/zsh
set -euo pipefail

project_root="$(cd "$(dirname "$0")/.." && pwd)"
monitor_root="${CAR_FIGHT_FULLSCREEN_SPIKE_ROOT:-$project_root/.fullscreen-spike-runs}"
spike_port="${CAR_FIGHT_FULLSCREEN_SPIKE_PORT:-10082}"
action="${1:-list}"

print_approaches() {
	cat <<'EOF'
True-fullscreen approaches (one variable changes at a time):

  opengl-runtime-vsync        OpenGL, VSync, windowed for 5s then true fullscreen
  opengl-startup-vsync        OpenGL, VSync, true fullscreen from process launch
  opengl-runtime-cap60        OpenGL, VSync, 60 FPS cap, runtime fullscreen
  opengl-runtime-cap30        OpenGL, VSync, 30 FPS cap, runtime fullscreen
  opengl-runtime-novsync60    OpenGL, VSync disabled, 60 FPS cap, runtime fullscreen
  vulkan-runtime-vsync        Vulkan/MoltenVK Mobile, VSync, runtime fullscreen

ANGLE is deliberately omitted because its fullscreen comparison already
reproduced the precursor. The two OpenGL controls remain last in the order only
to compare entry mechanisms after a candidate mitigation succeeds.
EOF
}

usage() {
	cat <<'EOF'
Usage:
  ./scripts/fullscreen_spike.sh list
  ./scripts/fullscreen_spike.sh run APPROACH --accept-crash-risk [--seconds N]
  ./scripts/fullscreen_spike.sh run APPROACH --dry-run [--seconds N]

Every real run may crash WindowServer even after Godot exits. Reboot the whole
Mac before the first probe, close unrelated work, and run one approach per boot.
EOF
}

if [[ "$action" == "list" ]]; then
	print_approaches
	exit 0
fi
if [[ "$action" != "run" || $# -lt 2 ]]; then
	usage >&2
	exit 2
fi

approach="$2"
shift 2
accept_risk=0
dry_run=0
run_seconds=30
while (( $# > 0 )); do
	case "$1" in
		--accept-crash-risk)
			accept_risk=1
			shift
			;;
		--dry-run)
			dry_run=1
			shift
			;;
		--seconds)
			run_seconds="${2:?--seconds requires a value}"
			shift 2
			;;
		*)
			echo "unknown option: $1" >&2
			exit 2
			;;
	esac
done

if [[ "$run_seconds" != <-> ]] || (( run_seconds < 10 || run_seconds > 120 )); then
	echo "--seconds must be an integer from 10 through 120" >&2
	exit 2
fi
if (( dry_run == 0 && accept_risk == 0 )); then
	echo "refusing rendered fullscreen probe without --accept-crash-risk" >&2
	echo "use --dry-run to inspect the command without opening a window" >&2
	exit 2
fi

typeset -a approach_args
approach_args=(
	--deep-capture
	--stop-on-precursor
	--post-exit-seconds 120
	--run-seconds "$run_seconds"
)
case "$approach" in
	opengl-runtime-vsync)
		approach_args+=(--driver opengl3 --runtime-fullscreen-after 5)
		;;
	opengl-startup-vsync)
		approach_args+=(--driver opengl3 --fullscreen)
		;;
	opengl-runtime-cap60)
		approach_args+=(--driver opengl3 --max-fps 60 --runtime-fullscreen-after 5)
		;;
	opengl-runtime-cap30)
		approach_args+=(--driver opengl3 --max-fps 30 --runtime-fullscreen-after 5)
		;;
	opengl-runtime-novsync60)
		approach_args+=(--driver opengl3 --disable-vsync --max-fps 60 \
			--runtime-fullscreen-after 5)
		;;
	vulkan-runtime-vsync)
		approach_args+=(--driver vulkan --rendering-method mobile \
			--runtime-fullscreen-after 5)
		;;
	*)
		echo "unknown fullscreen approach: $approach" >&2
		print_approaches >&2
		exit 2
		;;
esac

typeset -a command
command=("$project_root/scripts/play_monitored.sh" "${approach_args[@]}")
echo "approach=$approach"
echo "duration_seconds=$run_seconds"
echo "monitor_root=$monitor_root"
echo "command=${(q-)command}"
if (( dry_run == 1 )); then
	exit 0
fi

mkdir -p "$monitor_root"
{
	echo "approach=$approach"
	echo "requested_local=$(date '+%Y-%m-%d %H:%M:%S')"
	echo "commit=$(git -C "$project_root" rev-parse HEAD)"
	echo "windowserver_pid=$(pgrep -x WindowServer | head -1 || true)"
	echo "boot_time=$(sysctl -n kern.boottime 2>/dev/null || true)"
} > "$monitor_root/last-request.txt"

set +e
CAR_FIGHT_MONITOR_ROOT="$monitor_root" \
	CAR_FIGHT_PORT="$spike_port" \
	CAR_FIGHT_FULLSCREEN_SPIKE_APPROACH="$approach" \
	"${command[@]}"
run_status=$?
set -e

if [[ -f "$monitor_root/last_run" ]]; then
	run_dir="$(< "$monitor_root/last_run")"
	"$project_root/scripts/collect_crash_run.sh" "$run_dir" || true
	echo "run_state=$(< "$run_dir/state")"
	echo "evidence=$run_dir"
	echo "summary=$run_dir/report-summary.txt"
fi
exit "$run_status"
