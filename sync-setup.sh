#!/usr/bin/env bash
# Keep files matched between machines with Syncthing over Tailscale, through the
# always-on homeserver as the hub. Clients only ever link to the hub.
#
#   sync-setup.sh <peer-name> <peer-id> <peer-ip>   link a peer, share the folders; safe to re-run
#   sync-setup.sh --check                           refresh big-file ignores, count conflict files
#
# `syncthing device-id` prints a machine's id. Machine-only ignore patterns go in
# <folder>/.stignore-local. Undo: systemctl --user disable --now syncthing sync-check.timer
set -euo pipefail
export LC_ALL=C # the same ignore lists on every machine, whatever the locale

big_mb=100 # files over this stay on the machine that made them, unless git tracks them
# ponytail: inspected by the find below, not by Syncthing, which can't filter by size.
# A new big file can sync if it lands within the watcher's delay of a --check run.

# Regenerated per machine, and each machine's copies wouldn't work on the others.
skip_dirs=(.venv venv node_modules __pycache__ .next .ruff_cache .mypy_cache .pytest_cache
	.snakemake .zmk .qmk wandb .wrangler)
# SYNC_FOLDERS: "id:path id:path", to try this on a scratch folder first.
read -ra folders <<<"${SYNC_FOLDERS:-projects:$HOME/Projects documents:$HOME/Documents pictures:$HOME/Pictures videos:$HOME/Videos claude-projects:$HOME/.claude/projects}"
state="${XDG_STATE_HOME:-$HOME/.local/state}/sync-check"

prune=()
for d in "${skip_dirs[@]}"; do prune+=(-name "$d" -o); done
prune+=(-name .git)

check() {
	local entry path file rel top tmp conflicts=0
	for entry in "${folders[@]}"; do
		path=${entry#*:}
		[ -d "$path" ] || continue
		tmp=$(mktemp)
		while IFS= read -r -d '' file; do
			# Skipping a file git tracks would show it as deleted on the other machines.
			top=$(git -C "${file%/*}" rev-parse --show-toplevel 2>/dev/null) &&
				git -C "$top" ls-files --error-unmatch -- "$file" >/dev/null 2>&1 && continue
			rel=${file#"$path"}
			printf '%s\n' "$rel" | sed -E 's/[][*?{}\\!]/\\&/g' >>"$tmp"
		done < <(find "$path" -xdev \( "${prune[@]}" \) -prune -o -type f -size +"$big_mb"M -print0)
		sort -o "$tmp" "$tmp"
		# Only on change: Syncthing rescans the folder when its ignores change.
		if cmp -s "$tmp" "$path/.stignore-big"; then rm -f "$tmp"; else mv "$tmp" "$path/.stignore-big"; fi
		# Conflicts inside .git are the ones that matter, so this one looks there too.
		conflicts=$((conflicts + $(find "$path" -xdev -name '*.sync-conflict-*' -not -path '*/node_modules/*' | wc -l)))
	done
	mkdir -p "$state"
	echo "$conflicts" >"$state/conflicts"
}

if [ "${1:-}" = "--check" ]; then
	check
	exit
fi

if [ $# -ne 3 ]; then
	sed -n '5,6p' "$0" >&2
	exit 1
fi
peer_name=$1 peer_id=$2 peer_ip=$3

for tool in syncthing git curl; do
	command -v "$tool" >/dev/null || {
		echo "$tool is not installed" >&2
		exit 1
	}
done

# Ignores first, so nothing big or disposable can start syncing before they exist.
for entry in "${folders[@]}"; do
	path=${entry#*:}
	mkdir -p "$path"
	touch "$path/.stignore-local"
	{
		echo '// Written by sync-setup.sh. Machine-only patterns go in .stignore-local.'
		echo '#include .stignore-big'
		echo '#include .stignore-local'
		echo '.stignore-*'
		for d in "${skip_dirs[@]}"; do echo "(?d)$d"; done
		# Git's short-lived locks. Not plain *.lock: uv.lock and friends must sync.
		echo '(?d).git/*.lock'
		echo '(?d).git/**/*.lock'
		echo '(?d)**/.git/*.lock'
		echo '(?d)**/.git/**/*.lock'
	} >"$path/.stignore"
done
check

# Without linger a user service only runs while that user is logged in.
[ "$(loginctl show-user "$USER" -p Linger --value)" = yes ] || sudo loginctl enable-linger "$USER"
systemctl --user enable --now syncthing.service
for _ in {1..30}; do
	syncthing cli config gui apikey get >/dev/null 2>&1 && break
	sleep 1
done

cfg=(syncthing cli config)
# Tailscale only: no relays, no discovery servers, nothing reported home.
for opt in global-ann-enabled local-ann-enabled relays-enabled natenabled; do
	"${cfg[@]}" options "$opt" set false
done
"${cfg[@]}" options uraccepted set -- -1
key=$("${cfg[@]}" gui apikey get)
curl -fsS -o /dev/null -X PATCH -H "X-API-Key: $key" -d '{"crashReportingEnabled":false}' \
	http://127.0.0.1:8384/rest/config/options

"${cfg[@]}" devices list | grep -x "$peer_id" >/dev/null ||
	"${cfg[@]}" devices add --device-id "$peer_id" --name "$peer_name" --addresses "tcp://$peer_ip:22000"
for entry in "${folders[@]}"; do
	id=${entry%%:*} path=${entry#*:}
	"${cfg[@]}" folders list | grep -x "$id" >/dev/null ||
		"${cfg[@]}" folders add --id "$id" --label "$id" --path "$path"
	# The watcher misses edits in a folder that was deleted and recreated, and git can
	# do that to .git/objects/xx. Rescans bound the delay; a walk of 90k files takes ~2s.
	"${cfg[@]}" folders "$id" rescan-intervals set 120
	# SYNC_FOLDER_TYPE: sendonly or receiveonly for a one-way first sync. Set before sharing.
	"${cfg[@]}" folders "$id" type set "${SYNC_FOLDER_TYPE:-sendreceive}"
	"${cfg[@]}" folders "$id" devices list | grep -x "$peer_id" >/dev/null ||
		"${cfg[@]}" folders "$id" devices add --device-id "$peer_id"
done

units="${XDG_CONFIG_HOME:-$HOME/.config}/systemd/user"
mkdir -p "$units"
cat >"$units/sync-check.service" <<-'UNIT'
	[Unit]
	Description=Refresh Syncthing big-file ignores and count conflict files

	[Service]
	Type=oneshot
	ExecStart=%h/dotfiles/sync-setup.sh --check
UNIT
cat >"$units/sync-check.timer" <<-'UNIT'
	[Unit]
	Description=Run sync-check every 15 minutes

	[Timer]
	OnCalendar=*:0/15
	Persistent=true

	[Install]
	WantedBy=timers.target
UNIT
systemctl --user daemon-reload
systemctl --user enable --now sync-check.timer

echo "Linked to $peer_name. This machine's id, for the other side:"
syncthing device-id
