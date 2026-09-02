#!/bin/zsh
set -euo pipefail

# Git cannot populate licensed assets/local content in a new worktree because
# it is intentionally ignored. Find an existing Car Fight worktree that has the
# accepted runtime art and make an independent physical copy without replacing
# any local files already present in the target.

project_root="$(cd "$(dirname "$0")/.." && pwd)"
mode="${1:-sync}"
if [[ "$mode" != "sync" && "$mode" != "--check" ]]; then
	echo "usage: $0 [--check]" >&2
	exit 2
fi

required_paths=(
	"city_audition/extracted/city_district.tscn"
	"lowpoly_tree_collection_01/LowPoly_Tree_Collection_01_fbx.FBX"
)
asset_families=(
	"city_audition"
	"lowpoly_tree_collection_01"
)

assets_present() {
	local root="$1"
	local required
	for required in "${required_paths[@]}"; do
		[[ -f "$root/assets/local/$required" ]] || return 1
	done
}

if assets_present "$project_root"; then
	echo "LOCAL_ASSETS PASS city=present trees=present"
	exit 0
fi

if [[ "$mode" == "--check" ]]; then
	echo "LOCAL_ASSETS FAIL required city/tree art is missing from $project_root" >&2
	exit 1
fi

donor_root="${CAR_FIGHT_LOCAL_ASSET_SOURCE:-}"
if [[ -n "$donor_root" ]] && ! assets_present "$donor_root"; then
	echo "Configured local-asset donor is incomplete: $donor_root" >&2
	exit 1
fi
if [[ -z "$donor_root" ]]; then
	while IFS= read -r line; do
		[[ "$line" == worktree\ * ]] || continue
		candidate="${line#worktree }"
		if [[ "$candidate" != "$project_root" ]] && assets_present "$candidate"; then
			donor_root="$candidate"
			break
		fi
	done < <(git -C "$project_root" worktree list --porcelain)
fi

if [[ -z "$donor_root" ]]; then
	echo "No registered Car Fight worktree contains the required local city/tree art." >&2
	echo "Set CAR_FIGHT_LOCAL_ASSET_SOURCE to a complete donor and rerun." >&2
	exit 1
fi

mkdir -p "$project_root/assets/local"
for family in "${asset_families[@]}"; do
	mkdir -p "$project_root/assets/local/$family"
	rsync -a --ignore-existing --exclude='*.import' \
		"$donor_root/assets/local/$family/" \
		"$project_root/assets/local/$family/"
done

if ! assets_present "$project_root"; then
	echo "Local-asset copy completed but required runtime files are still missing." >&2
	exit 1
fi

echo "LOCAL_ASSETS PASS donor=$donor_root city=copied trees=copied"
