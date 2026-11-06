#!/usr/bin/env bash
# Encrypted restic backups to the USB drive on the homeserver. Every machine uses the same
# repo, so a file that's on two of them is stored once.
#
#   backup.sh --setup <repo> [hourly|daily]   init the repo if needed, install the timer
#   backup.sh                                 back up, then thin out this machine's old snapshots
#   backup.sh --maintain                      prune and verify the repo (the server, weekly)
#
# <repo> is /mnt/backup/restic on the server, sftp:ilya@<server>:/mnt/backup/restic elsewhere.
# Per machine, in ~/.config/dotfiles: backup-repo, backup-paths (one per line), restic-pass.
# The drive is on the server, so a fire or theft at home takes the backup too.
set -euo pipefail

conf="$HOME/.config/dotfiles"
state="$HOME/.local/state/backup"
mount=/mnt/backup
dots=$(dirname "$(readlink -f "$0")")
export RESTIC_PASSWORD_FILE="$conf/restic-pass"

setup() {
	local repo=$1 every=${2:-daily}
	[ -s "$RESTIC_PASSWORD_FILE" ] || {
		echo "no $RESTIC_PASSWORD_FILE: every machine needs the same password" >&2
		exit 1
	}
	chmod 600 "$RESTIC_PASSWORD_FILE"
	[ -s "$conf/backup-paths" ] || {
		echo "no $conf/backup-paths: list what to back up, one path per line" >&2
		exit 1
	}
	echo "$repo" >"$conf/backup-repo"
	restic -r "$repo" cat config >/dev/null 2>&1 || restic -r "$repo" init

	if [[ $repo == /* ]]; then
		# A system unit: restic stays unprivileged but can read everything, such as /etc.
		sudo tee /etc/systemd/system/backup.service >/dev/null <<-UNIT
			[Unit]
			Description=Back up to the USB drive
			RequiresMountsFor=$mount

			[Service]
			Type=oneshot
			User=$USER
			AmbientCapabilities=CAP_DAC_READ_SEARCH
			ExecStart=$dots/backup.sh
		UNIT
		sudo tee /etc/systemd/system/backup.timer >/dev/null <<-UNIT
			[Unit]
			Description=Back up $every

			[Timer]
			OnCalendar=$every
			Persistent=true

			[Install]
			WantedBy=timers.target
		UNIT
		sudo tee /etc/systemd/system/backup-maintain.service >/dev/null <<-UNIT
			[Unit]
			Description=Prune and verify the backup repo
			RequiresMountsFor=$mount

			[Service]
			Type=oneshot
			User=$USER
			ExecStart=$dots/backup.sh --maintain
		UNIT
		sudo tee /etc/systemd/system/backup-maintain.timer >/dev/null <<-UNIT
			[Unit]
			Description=Prune and verify the backup repo weekly

			[Timer]
			OnCalendar=Sun 04:30
			Persistent=true

			[Install]
			WantedBy=timers.target
		UNIT
		sudo systemctl daemon-reload
		sudo systemctl enable --now backup.timer backup-maintain.timer
	else
		local units="${XDG_CONFIG_HOME:-$HOME/.config}/systemd/user"
		mkdir -p "$units"
		cat >"$units/backup.service" <<-UNIT
			[Unit]
			Description=Back up to the USB drive on the server

			[Service]
			Type=oneshot
			ExecStart=$dots/backup.sh
		UNIT
		cat >"$units/backup.timer" <<-UNIT
			[Unit]
			Description=Back up $every

			[Timer]
			OnCalendar=$every
			Persistent=true

			[Install]
			WantedBy=timers.target
		UNIT
		systemctl --user daemon-reload
		systemctl --user enable --now backup.timer
	fi
}

if [ "${1:-}" = "--setup" ]; then
	shift
	setup "$@"
	exit
fi

read -r repo <"$conf/backup-repo"
export RESTIC_REPOSITORY=$repo
# An empty mountpoint would otherwise fail confusingly, or in the worst case fill the SSD.
if [[ $repo == "$mount"/* ]] && ! mountpoint -q "$mount"; then
	echo "$mount is not mounted" >&2
	exit 1
fi

if [ "${1:-}" = "--maintain" ]; then
	restic prune --retry-lock 2h
	# ponytail: a sample each week, not all of it, because a full read takes hours over USB.
	restic check --retry-lock 2h --read-data-subset=5%
	exit
fi

read -r host </proc/sys/kernel/hostname
# Disposable, and the same list sync-setup.sh skips, plus Syncthing's own trash.
excludes=(.venv venv node_modules __pycache__ .next .ruff_cache .mypy_cache .pytest_cache
	.snakemake .zmk .qmk wandb .wrangler .stversions)
args=()
for e in "${excludes[@]}"; do args+=(--exclude "$e"); done

# A crashed run's lock would block us for the full 2h and hold up every later backup.
# Without --remove-all this only clears locks that are stale, never a running job's.
restic unlock --quiet

code=0
restic backup --retry-lock 2h --host "$host" --files-from "$conf/backup-paths" "${args[@]}" --quiet || code=$?
# 3 means some files couldn't be read, usually ones that changed mid-run; the snapshot is
# still good, and it's the next hourly or daily run that picks them up.
if [ "$code" -ne 0 ] && [ "$code" -ne 3 ]; then
	exit "$code"
fi
# Again, in case another machine crashed while this backup ran: forget needs the repo alone.
restic unlock --quiet
restic forget --retry-lock 2h --host "$host" --quiet --keep-tag pre-cleanup \
	--keep-hourly 24 --keep-daily 14 --keep-weekly 8 --keep-monthly 24

mkdir -p "$state"
date +%s >"$state/last-success"
exit 0
