#!/bin/zsh
# Run on macai2. Installs an isolated boot-persistent server for this project.
set -euo pipefail

label="com.whenjohn.car-fight-server"
plist="/Library/LaunchDaemons/$label.plist"
project_root="$(cd "$(dirname "$0")/.." && pwd)"
log_file="$HOME/Library/Logs/car-fight-server.log"
godot_bin="${GODOT_BIN:-/Applications/Godot47.app/Contents/MacOS/Godot}"
port="${CAR_FIGHT_PORT:-10080}"
transport="${CAR_FIGHT_TRANSPORT:-mux}"
signal_port="${CAR_FIGHT_SIGNAL_PORT:-10181}"

case "${1:-status}" in
	serve)
		cd "$project_root"
		exec "$godot_bin" --headless --path "$project_root" -- --server \
			--transport "$transport" --port "$port" --signal-port "$signal_port"
		;;
	import)
		CAR_FIGHT_IMPORT_QUIET=1 "$project_root/scripts/godot_import_check.sh"
		;;
	install)
		mkdir -p "$(dirname "$log_file")"
		plist_body="$(sed -e "s|__LABEL__|$label|g" -e "s|__ROOT__|$project_root|g" -e "s|__LOG__|$log_file|g" -e "s|__USER__|$(whoami)|g" -e "s|__GODOT__|$godot_bin|g" -e "s|__PORT__|$port|g" "$project_root/deploy/server.plist.template")"
		print -r -- "$plist_body" | sudo tee "$plist" >/dev/null
		sudo chown root:wheel "$plist"
		sudo chmod 644 "$plist"
		"$0" import
		sudo launchctl bootout "system/$label" >/dev/null 2>&1 || true
		sudo launchctl bootstrap system "$plist"
		;;
	restart)
		"$0" import
		sudo launchctl kickstart -k "system/$label"
		;;
	status)
		sudo launchctl print "system/$label" 2>/dev/null \
			| /usr/bin/grep -E 'state =|pid =|program =' \
			|| { echo "$label is not loaded"; exit 1; }
		;;
	*)
		echo "usage: $0 serve|import|install|restart|status" >&2
		exit 2
		;;
esac
