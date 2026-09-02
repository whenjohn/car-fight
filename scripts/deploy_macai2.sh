#!/bin/zsh
# Explicit deployment helper. Preview is the safe default; apply must be named.
set -euo pipefail

project_root="$(cd "$(dirname "$0")/.." && pwd)"
remote_host="${CAR_FIGHT_SSH_HOST:-macai2-ts}"
remote_root="${CAR_FIGHT_REMOTE_ROOT:-/Users/macai2/Projects/car-fight}"
mode="${1:-preview}"
preview_log="$(mktemp "${TMPDIR:-/tmp}/car-fight-deploy-preview.XXXXXX")"
rsync_args=(-az --delete --itemize-changes
	--exclude='.git/'
	--exclude='.godot/'
	--exclude='.crash-runs/'
	--exclude='.network-runs/'
	--exclude='build/'
	--exclude='assets/local/')

cleanup() {
	rm -f "$preview_log"
}
trap cleanup EXIT INT TERM

case "$mode" in
	preview|apply)
		;;
	*)
		echo "usage: $0 [preview|apply]" >&2
		exit 2
		;;
esac

if [[ "$mode" == "preview" ]] \
		&& ! ssh "$remote_host" "test -d '$remote_root'"; then
	echo "Remote project does not exist for preview: $remote_host:$remote_root" >&2
	exit 1
fi

if [[ "$mode" == "apply" ]]; then
	current_branch="$(git -C "$project_root" branch --show-current)"
	if [[ "$current_branch" != "master" ]]; then
		echo "Refusing deployment from branch '$current_branch'; merge to master first." >&2
		exit 1
	fi
	if [[ -n "$(git -C "$project_root" status --short)" ]]; then
		echo "Refusing deployment from a dirty worktree." >&2
		exit 1
	fi
	ssh "$remote_host" "mkdir -p '$remote_root'"
fi

rsync "${rsync_args[@]}" --dry-run "$project_root/" "$remote_host:$remote_root/" \
	>"$preview_log"
delete_entry_count="$(rg -c '^\*deleting ' "$preview_log" || true)"
delete_entry_count="${delete_entry_count:-0}"
delete_dir_count="$(rg -c '^\*deleting .*/$' "$preview_log" || true)"
delete_dir_count="${delete_dir_count:-0}"
delete_file_count=$((delete_entry_count - delete_dir_count))
echo "DEPLOY_PREVIEW host=$remote_host root=$remote_root files=$delete_file_count dirs=$delete_dir_count entries=$delete_entry_count"
if (( delete_entry_count > 0 )); then
	rg '^\*deleting ' "$preview_log"
else
	echo "No remote files would be deleted."
fi

if [[ "$mode" == "preview" ]]; then
	echo "Preview only. Review deletions, then run: $0 apply"
	exit 0
fi

rsync "${rsync_args[@]}" "$project_root/" "$remote_host:$remote_root/"
ssh "$remote_host" "cd '$remote_root' && chmod +x scripts/*.sh && ./scripts/server_daemon.sh install"
echo "DEPLOY_APPLY PASS host=$remote_host root=$remote_root files=$delete_file_count dirs=$delete_dir_count udp=10080 signal=10181"
