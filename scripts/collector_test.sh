#!/bin/zsh
set -euo pipefail

project_root="$(cd "$(dirname "$0")/.." && pwd)"
test_root="$(mktemp -d "${TMPDIR:-/tmp}/car-fight-collector-test.XXXXXX")"
run_dir="$test_root/run"
diagnostic_root="$test_root/diagnostics"
panic_dir="$diagnostic_root/ProxiedDevice-Bridge"
mkdir -p "$run_dir" "$panic_dir"

touch -t 202001010000 "$run_dir/started.marker"
cat > "$run_dir/metadata.txt" <<'EOF'
start_epoch=1786760848
start_local=
deep_capture=0
windowserver_pid_start=99999
server_pid=99998
client_pid=99997
EOF

cat > "$panic_dir/panic-full-current.ips" <<'EOF'
{"incident_id":"TEST-CURRENT","bug_type":"210","timestamp":"2026-08-15 02:30:22.00 +0000"}
{"macOSPanicString":"Submission on work queue 40 failed due to insufficient space! @IGGuC.cpp:3127 pid 60674: Godot"}
EOF
cat > "$panic_dir/panic-full-old.ips" <<'EOF'
{"incident_id":"TEST-OLD","bug_type":"210","timestamp":"2026-08-15 01:00:00.00 +0000"}
{"macOSPanicString":"old unrelated panic"}
EOF

CAR_FIGHT_DIAGNOSTIC_ROOTS="$diagnostic_root" \
	"$project_root/scripts/collect_crash_run.sh" "$run_dir" >/dev/null

if [[ "$(< "$run_dir/state")" != "kernel-panic" ]]; then
	echo "COLLECTOR_TEST FAIL: kernel panic was not classified" >&2
	exit 1
fi
if [[ ! -f "$run_dir/reports/panic-full-current.ips" \
		|| -f "$run_dir/reports/panic-full-old.ips" ]]; then
	echo "COLLECTOR_TEST FAIL: embedded-time filtering was incorrect" >&2
	exit 1
fi
if ! rg -q 'panic_report_count=1' "$run_dir/metadata.txt" \
		|| ! rg -q 'Submission on work queue 40 failed' \
			"$run_dir/report-summary.txt"; then
	echo "COLLECTOR_TEST FAIL: panic metadata or summary was incomplete" >&2
	exit 1
fi

echo "COLLECTOR_TEST PASS state=kernel-panic reports=1"
