#!/bin/zsh
set -euo pipefail

project_root="$(cd "$(dirname "$0")/.." && pwd)"
manifest="${1:-$project_root/scripts/test.sh}"
test_root="${2:-$project_root/tests}"

if [[ ! -f "$manifest" ]]; then
	echo "Test manifest not found: $manifest" >&2
	exit 2
fi
if [[ ! -d "$test_root" ]]; then
	echo "Test directory not found: $test_root" >&2
	exit 2
fi

manifest_errors=()
test_count=0
while IFS= read -r test_file; do
	(( test_count += 1 ))
	relative_path="${test_file#$project_root/}"
	manifest_entry="res://$relative_path"
	entry_count="$(/usr/bin/grep -Fc "$manifest_entry" "$manifest" || true)"
	if [[ "$entry_count" != "1" ]]; then
		manifest_errors+=("$manifest_entry expected once, found $entry_count")
	fi
done < <(find "$test_root" -maxdepth 1 -type f -name '*_test.gd' | sort)

if (( ${#manifest_errors[@]} > 0 )); then
	echo "GDScript full-suite manifest errors:" >&2
	printf '  %s\n' "${manifest_errors[@]}" >&2
	exit 1
fi

if [[ "${CAR_FIGHT_MANIFEST_QUIET:-0}" != "1" ]]; then
	echo "TEST_MANIFEST_CHECK PASS tests=$test_count"
fi
