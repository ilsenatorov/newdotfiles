#!/usr/bin/env bash
# Push `motd.sh --issues` to ntfy when a problem starts or clears, so a dead service
# doesn't wait for the next login to be noticed. Run by a 5-minute user timer.
#
#   motd-alert.sh           check once and send anything new (what the timer runs)
#   motd-alert.sh --setup   create the topic, install the timer, enable linger
#   motd-alert.sh --test    send a test message
#
# This runs on the box it watches, so it can't report that box being down or offline.
set -uo pipefail
export LC_ALL=C # comm needs the same collation as sort

dots=$(dirname "$(readlink -f "$0")")
url_file="${XDG_CONFIG_HOME:-$HOME/.config}/dotfiles/ntfy-url"
state="${XDG_STATE_HOME:-$HOME/.local/state}/motd-alert"
read -r host </proc/sys/kernel/hostname

# send <title> <priority> <tag> <body>
send() {
	curl -fsS --max-time 15 -o /dev/null \
		-H "Title: $1" -H "Priority: $2" -H "Tags: $3" -d "$4" "$url"
}

if [ "${1:-}" = "--setup" ]; then
	if [ ! -s "$url_file" ]; then
		mkdir -p "$(dirname "$url_file")"
		# ntfy topics have no password: whoever knows the name can read and post.
		secret=$(tr -dc 'a-z0-9' </dev/urandom | head -c 24)
		(umask 077 && echo "https://ntfy.sh/$host-$secret" >"$url_file")
	fi

	units="${XDG_CONFIG_HOME:-$HOME/.config}/systemd/user"
	mkdir -p "$units"
	cat >"$units/motd-alert.service" <<-'UNIT'
		[Unit]
		Description=Push server problems to ntfy

		[Service]
		Type=oneshot
		ExecStart=%h/dotfiles/motd-alert.sh
	UNIT
	cat >"$units/motd-alert.timer" <<-'UNIT'
		[Unit]
		Description=Check for server problems every 5 minutes

		[Timer]
		OnCalendar=*:0/5

		[Install]
		WantedBy=timers.target
	UNIT
	systemctl --user daemon-reload
	systemctl --user enable --now motd-alert.timer

	# Without linger a user timer only runs while that user is logged in.
	sudo loginctl enable-linger "$USER"

	read -r url <"$url_file"
	echo "Subscribe to this topic in the ntfy app, then run: $0 --test"
	echo "  $url"
	exit 0
fi

if [ ! -s "$url_file" ]; then
	echo "no ntfy topic: run $0 --setup" >&2
	exit 1
fi
read -r url <"$url_file"

if [ "${1:-}" = "--test" ]; then
	send "$host: test" default white_check_mark "ntfy alerts from $host are working."
	exit
fi

# sorted, unique, no blank lines
lines() { sed '/^$/d' | sort -u; }
both() { comm -12 <(echo "$1") <(echo "$2") | lines; }
only_first() { comm -23 <(echo "$1") <(echo "$2") | lines; }

# A crash here must not read as "no problems", which would send a false all-clear.
out=$("$dots/motd.sh" --issues) || exit 1
current=$(lines <<<"$out")

mkdir -p "$state"
touch "$state/seen" "$state/alerted"
seen=$(lines <"$state/seen")
alerted=$(lines <"$state/alerted")

# Two checks in a row before alerting: services restarting during an upgrade, or a
# brief load spike, shouldn't reach the phone.
confirmed=$(both "$current" "$seen")
fresh=$(only_first "$confirmed" "$alerted")
cleared=$(only_first "$alerted" "$current")

# State only changes once a send succeeds, so a failed one goes out on a later run.
if [ -n "$fresh" ]; then
	n=$(wc -l <<<"$fresh")
	title="$host: $n problems"
	((n == 1)) && title="$host: 1 problem"
	if send "$title" high rotating_light "$fresh"; then
		alerted=$(printf '%s\n%s\n' "$alerted" "$fresh" | lines)
	fi
fi
if [ -n "$cleared" ]; then
	if send "$host: resolved" default white_check_mark "$cleared"; then
		alerted=$(only_first "$alerted" "$cleared")
	fi
fi

echo "$current" >"$state/seen"
echo "$alerted" >"$state/alerted"
