#!/bin/zsh
# Explicit deployment helper. This is not run automatically.
set -euo pipefail

project_root="$(cd "$(dirname "$0")/.." && pwd)"
remote_host="${CAR_FIGHT_SSH_HOST:-macai2-ts}"
remote_root="${CAR_FIGHT_REMOTE_ROOT:-/Users/macai2/Projects/car-fight}"

ssh "$remote_host" "mkdir -p '$remote_root'"
rsync -az --exclude='.git/' --exclude='.godot/' "$project_root/" "$remote_host:$remote_root/"
ssh "$remote_host" "cd '$remote_root' && chmod +x scripts/*.sh && ./scripts/server_daemon.sh install"
echo "deployed car-fight to $remote_host:$remote_root on UDP 10080"

