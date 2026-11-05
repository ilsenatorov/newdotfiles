#!/usr/bin/env bash
# Make files sent with Taildrop land in ~/Downloads without running
# `tailscale file get` by hand. Opt-in per machine, safe to re-run.
set -euo pipefail

command -v tailscale >/dev/null || {
	echo "tailscale is not installed" >&2
	exit 1
}

# Reading the inbox needs root or being the tailscale operator.
sudo tailscale set --operator="$USER"
# Without linger a user service only runs while that user is logged in.
sudo loginctl enable-linger "$USER"

units="${XDG_CONFIG_HOME:-$HOME/.config}/systemd/user"
mkdir -p "$units"
cat >"$units/taildrop-receive.service" <<-'UNIT'
	[Unit]
	Description=Move incoming Taildrop files to ~/Downloads

	[Service]
	ExecStartPre=/usr/bin/mkdir -p %h/Downloads
	ExecStart=/usr/bin/tailscale file get --wait --loop --conflict=rename %h/Downloads
	Restart=always
	RestartSec=30

	[Install]
	WantedBy=default.target
UNIT
systemctl --user daemon-reload
systemctl --user enable --now taildrop-receive.service
systemctl --user restart taildrop-receive.service

echo "Taildrop files now land in ~/Downloads"
