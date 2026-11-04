#!/usr/bin/env bash
# Status board shown on SSH login (from .zshrc) or on demand with `motd`.
#
# Runs as the user at login rather than from /etc/motd, which is static text, so
# everything is live and nothing here needs root or touches /etc. Problems go at
# the top; a healthy box stays quiet.
#
# Services need no config: anything `systemctl enable`d is listed, minus the
# plumbing filtered in the services section. Containers and tailnet peers are
# discovered the same way, and any section whose tool is missing is left out.
#
#   motd.sh                     print the board
#   motd.sh --issues            print only the problems, one per line (motd-alert.sh)
#   motd.sh --refresh-updates   recount pending updates (spawned by the board)
set -uo pipefail

cache="${XDG_CACHE_HOME:-$HOME/.cache}/motd"
updates_file="$cache/updates"
pacman_log=/var/log/pacman.log

# checkupdates hits the network, far too slow for a login, so the board reads the
# last count and this runs detached. A failed check (offline) keeps the old count.
if [ "${1:-}" = "--refresh-updates" ]; then
	mkdir -p "$cache"
	exec 9>"$cache/lock"
	flock -n 9 || exit 0
	out=$(checkupdates)
	case $? in
		0) count=$(wc -l <<<"$out") ;;
		2) count=0 ;; # checkupdates' "nothing to do"
		*) exit 1 ;;
	esac
	echo "$count" >"$updates_file.tmp" && mv "$updates_file.tmp" "$updates_file"
	exit 0
fi

if [[ -t 1 && -z ${NO_COLOR:-} ]]; then
	red=$'\e[31m' green=$'\e[32m' yellow=$'\e[33m' cyan=$'\e[36m'
	bold=$'\e[1m' dim=$'\e[2m' off=$'\e[0m'
else
	red='' green='' yellow='' cyan='' bold='' dim='' off=''
fi

# 72 at most, and narrower on a phone. Everything below lays out against these.
cols=$(stty size 2>/dev/null </dev/tty | cut -d' ' -f2)
[[ ${cols:-} =~ ^[0-9]+$ && $cols -gt 0 ]] || cols=72
((cols > 72)) && cols=72
label_w=9
content_w=$((cols - label_w - 2))
bar_w=16
((cols < 60)) && bar_w=8

printf -v now '%(%s)T' -1
# Fixed wording, no live numbers: motd-alert.sh compares these between runs, so
# "disk 91%" becoming "disk 92%" would read as a new problem. The meters show the
# numbers anyway.
issues=()
rows=()

row() {
	local line
	printf -v line ' %s%-*s%s %s' "$dim" "$label_w" "$1" "$off" "$2"
	rows+=("$line")
}

# row with "state:name" items that wraps at the content width
dots() {
	local label=$1 line="" vis=0 item state name dot w
	shift
	for item in "$@"; do
		state=${item%%:*} name=${item#*:}
		case $state in
			ok) dot="$green●$off" ;;
			warn) dot="$yellow●$off" ;;
			bad) dot="$red●$off" ;;
			*) dot="$dim○$off" ;;
		esac
		w=$((${#name} + 4)) # dot, space, name, two-space gap
		if ((vis > 0 && vis + w - 2 > content_w)); then
			row "$label" "$line"
			label="" line="" vis=0
		fi
		line+="$dot $name  "
		vis=$((vis + w))
	done
	[ -n "$line" ] && row "$label" "$line"
}

# meter <percent>: the bar and percentage, coloured by how full it is
meter() {
	local pct=$1 fill empty colour=$green a b
	fill=$(((pct * bar_w + 50) / 100))
	((pct > 0 && fill == 0)) && fill=1
	((fill > bar_w)) && fill=$bar_w
	empty=$((bar_w - fill))
	((pct >= 70)) && colour=$yellow
	((pct >= 90)) && colour=$red
	printf -v a '%*s' "$fill" ''
	printf -v b '%*s' "$empty" ''
	printf '%s%s%s%s%s%s %s%3d%%%s' "$colour" "${a// /━}" "$off" "$dim" "${b// /─}" "$off" "$colour" "$pct" "$off"
}

human_time() {
	local s=$1
	if ((s >= 86400)); then
		echo "$((s / 86400))d $((s % 86400 / 3600))h"
	elif ((s >= 3600)); then
		echo "$((s / 3600))h $((s % 3600 / 60))m"
	elif ((s >= 60)); then
		echo "$((s / 60))m"
	else
		echo "<1m"
	fi
}

# --- identity ---------------------------------------------------------------
read -r host </proc/sys/kernel/hostname
read -r kernel </proc/sys/kernel/osrelease
# shellcheck source=/dev/null
os=$(. /etc/os-release 2>/dev/null && echo "${PRETTY_NAME:-Linux}")
read -r up _ </proc/uptime
up=${up%.*}
printf -v booted '%(%a %d %b %H:%M)T' "$((now - up))"

# --- cpu, memory, disks -----------------------------------------------------
cores=$(nproc)
read -r load1 load5 load15 _ </proc/loadavg
load_pct=$(awk -v l="$load1" -v c="$cores" 'BEGIN { printf "%d", l / c * 100 + .5 }')
((load_pct > 100)) && load_pct=100
((${load1%.*} >= 2 * cores)) && issues+=("load over twice the $cores cores")

temp=""
for hw in /sys/class/hwmon/hwmon*; do
	[ -r "$hw/name" ] || continue
	read -r hw_name <"$hw/name"
	case $hw_name in
		coretemp | k10temp | zenpower)
			if [ -r "$hw/temp1_input" ]; then
				read -r milli <"$hw/temp1_input"
				deg=$((milli / 1000))
				colour=$dim
				((deg >= 70)) && colour=$yellow
				((deg >= 85)) && colour=$red && issues+=("cpu above 85°C")
				temp="  $colour${deg}°C$off"
			fi
			break
			;;
	esac
done
row cpu "$(meter "$load_pct")  $dim$load1 $load5 $load15$off$temp"

while read -r key value _; do
	case $key in
		MemTotal:) mem_total=$value ;;
		MemAvailable:) mem_avail=$value ;;
	esac
done </proc/meminfo
mem_used=$((mem_total - mem_avail))
mem_pct=$((mem_used * 100 / mem_total))
((mem_pct >= 90)) && issues+=("memory over 90% used")
read -r mem_used_h mem_total_h < <(numfmt --to=iec "$((mem_used * 1024))" "$((mem_total * 1024))" | xargs)
row memory "$(meter "$mem_pct")  $dim$mem_used_h / $mem_total_h$off"

# Sorted so a btrfs volume, which df lists once per subvolume, is shown as "/"
# and not whichever subvolume came first.
declare -A seen_disk
while read -r src size used avail target; do
	[[ $src == /* && -z ${seen_disk[$src]:-} ]] || continue
	seen_disk[$src]=1
	pct=$((used * 100 / (used + avail)))
	((pct >= 90)) && issues+=("$target over 90% full")
	read -r used_h size_h < <(numfmt --to=iec "$used" "$size" | xargs)
	name=$target
	((${#name} > label_w)) && name="…${name: -$((label_w - 1))}"
	row "$name" "$(meter "$pct")  $dim$used_h / $size_h$off"
done < <(timeout 1 df -l -B1 --output=source,size,used,avail,target \
	-x tmpfs -x devtmpfs -x efivarfs -x overlay -x squashfs 2>/dev/null | tail -n +2 | sort -k5)

rows+=("")

# --- services ---------------------------------------------------------------
while read -r unit _; do
	[ -n "$unit" ] && issues+=("$unit failed")
done < <(systemctl list-units --state=failed --plain --no-legend --no-pager 2>/dev/null)

# What `systemctl enable` creates, read directly: list-unit-files takes half a
# second, which is most of a login's wait.
wanted=()
while read -r unit _; do
	case $unit in
		*@.service | systemd-* | getty* | dbus*) ;;
		*) wanted+=("$unit") ;;
	esac
done < <(compgen -G '/etc/systemd/system/*.wants/*.service' | sed 's|.*/||' | sort -u)

services=()
add_service() {
	local name=${id%.service}
	case $active in
		active) services+=("ok:$name") ;;
		activating | reloading) services+=("warn:$name") ;;
		failed) services+=("bad:$name") ;; # already an issue, via --state=failed
		*)
			# A oneshot that finished cleanly isn't down, it's done.
			[[ $type == oneshot && $result == success ]] && return
			services+=("bad:$name")
			issues+=("$name is enabled but not running")
			;;
	esac
}
if ((${#wanted[@]})); then
	id="" type="" active="" result=""
	while IFS='=' read -r key value; do
		case $key in
			Id) id=$value ;;
			Type) type=$value ;;
			ActiveState) active=$value ;;
			Result) result=$value ;;
			"") # a blank line ends each unit's block
				[ -n "$id" ] && add_service
				id="" type="" active="" result=""
				;;
		esac
	done < <(
		systemctl show --property=Id,Type,ActiveState,Result "${wanted[@]}" 2>/dev/null
		echo
	)
fi
((${#services[@]})) && dots services "${services[@]}"

# --- containers -------------------------------------------------------------
if command -v docker >/dev/null && [ "$(systemctl is-active docker 2>/dev/null)" = active ]; then
	if containers=$(timeout 1 docker ps -a --format '{{.Names}}|{{.State}}|{{.Status}}' 2>/dev/null); then
		items=()
		stopped=0
		while IFS='|' read -r name state status; do
			[ -n "$name" ] || continue
			case $state in
				running)
					case $status in
						*"(unhealthy)"*)
							items+=("bad:$name")
							issues+=("container $name is unhealthy")
							;;
						*"(health: starting)"*) items+=("warn:$name") ;;
						*) items+=("ok:$name") ;;
					esac
					;;
				restarting | dead)
					items+=("bad:$name")
					issues+=("container $name is $state")
					;;
				exited)
					# 137 and 143 are what `docker stop` leaves behind: not a crash.
					code=${status#*\(}
					code=${code%%\)*}
					case $code in
						0 | 137 | 143) stopped=$((stopped + 1)) ;;
						*)
							items+=("bad:$name")
							issues+=("container $name exited with code $code")
							;;
					esac
					;;
				*) stopped=$((stopped + 1)) ;;
			esac
		done <<<"$containers"
		((stopped)) && items+=("off:$stopped stopped")
		((${#items[@]})) || items=("off:no containers")
		dots docker "${items[@]}"
	else
		issues+=("docker is not responding")
	fi
fi

# --- tailnet and addresses --------------------------------------------------
declare -A peer_name
tailscale_ip=""
if command -v tailscale >/dev/null && [ "$(systemctl is-active tailscaled 2>/dev/null)" = active ]; then
	if ts=$(timeout 1 tailscale status 2>/dev/null); then
		peers=()
		while read -r ip name _ _ status; do
			[[ $ip =~ ^[0-9] ]] || continue
			peer_name[$ip]=$name
			if [ "$name" = "$host" ]; then
				tailscale_ip=$ip
			elif [[ $status == *offline* ]]; then
				peers+=("off:$name")
			else
				peers+=("ok:$name")
			fi
		done <<<"$ts"
		((${#peers[@]})) && dots tailnet "${peers[@]}"
	else
		issues+=("tailscale is stopped or logged out")
	fi
fi

lan_ip=$(ip -4 route get 1.1.1.1 2>/dev/null | sed -n 's/.* src \([0-9.]*\).*/\1/p')
if [ -n "$lan_ip$tailscale_ip" ]; then
	row network "$lan_ip${tailscale_ip:+  ${dim}ts$off $tailscale_ip}"
fi

# The running kernel's modules go when pacman replaces it, which breaks anything
# that loads a module later on. That makes a missing directory the reboot signal.
if [ ! -d "/usr/lib/modules/$kernel" ]; then
	issues+=("reboot needed: kernel upgraded, still running $kernel")
fi

# Every check has run. The rest is display only, and refreshes the update count.
if [ "${1:-}" = "--issues" ]; then
	((${#issues[@]})) && printf '%s\n' "${issues[@]}"
	exit 0
fi

# --- ssh --------------------------------------------------------------------
peer_label() { echo "${peer_name[$1]:-$1}"; }

ssh_info=""
if [ -n "${SSH_CONNECTION:-}" ]; then
	ssh_info="you: $(peer_label "${SSH_CONNECTION%% *}")"
fi
# Newest first, so during an SSH login the first match is this session.
prev=$(timeout 1 journalctl -u sshd --since=-30d -r -n 2 -g '^Accepted' \
	-o short-unix --no-pager 2>/dev/null | grep Accepted)
[ -n "${SSH_CONNECTION:-}" ] && prev=$(tail -n +2 <<<"$prev")
prev=$(head -n 1 <<<"$prev")
if [ -n "$prev" ]; then
	prev_ts=${prev%%.*}
	prev_ip=${prev##* from }
	prev_ip=${prev_ip%% *}
	ssh_info+="${ssh_info:+$dim  ·  $off}last: $(peer_label "$prev_ip") $(human_time "$((now - prev_ts))") ago"
fi
[ -n "$ssh_info" ] && row ssh "$ssh_info"

# One line per attempt: sshd logs a wrong password for an unknown user twice.
failed=$(timeout 1 journalctl -u sshd --since=-24h -o cat --no-pager \
	-g 'Invalid user|Failed password for (?!invalid)' 2>/dev/null | grep -c .)
if ((${failed:-0} > 0)); then
	row "" "${yellow}$failed failed login attempts$off ${dim}in 24h$off"
fi

# --- packages ---------------------------------------------------------------
if command -v checkupdates >/dev/null; then
	mtime() { stat -c %Y "$1" 2>/dev/null || echo 0; }
	updates_age=$((now - $(mtime "$updates_file")))
	# An upgrade since the last count makes that count wrong, not merely old.
	current=1
	(($(mtime "$pacman_log") > $(mtime "$updates_file"))) && current=0
	if ((! current || updates_age > 6 * 3600)); then
		setsid -f "$0" --refresh-updates >/dev/null 2>&1 </dev/null
	fi

	pkg_info="${dim}checking…$off"
	if ((current)) && read -r count 2>/dev/null <"$updates_file"; then
		if ((count > 0)); then
			pkg_info="$cyan$count pending$off"
		else
			pkg_info="up to date"
		fi
	fi
	last=$(grep -F 'starting full system upgrade' "$pacman_log" 2>/dev/null | tail -n 1)
	if [ -n "$last" ]; then
		last=${last#\[}
		last_ts=$(date -d "${last%%\]*}" +%s 2>/dev/null) || last_ts=""
		if [ -n "$last_ts" ]; then
			last_age=$((now - last_ts))
			colour=$dim
			((last_age > 30 * 86400)) && colour=$yellow
			pkg_info+="$dim  ·  $off${colour}upgraded $(human_time "$last_age") ago$off"
		fi
	fi
	row updates "$pkg_info"
fi

# --- print ------------------------------------------------------------------
if ((${#issues[@]})); then
	n=${#issues[@]}
	verdict_plain="▲ $n need attention"
	((n == 1)) && verdict_plain="▲ 1 needs attention"
	verdict="$red$verdict_plain$off"
else
	verdict_plain="● all normal"
	verdict="$green$verdict_plain$off"
fi

rule_w=$((cols - ${#host} - ${#verdict_plain} - 4))
((rule_w < 1)) && rule_w=1
printf -v rule '%*s' "$rule_w" ''

echo
echo " $bold$cyan$host$off $dim${rule// /─}$off $verdict"
echo " up $bold$(human_time "$up")$off$dim  since $booted$off"
echo " $dim$os  ·  $kernel$off"
echo
if ((${#issues[@]})); then
	for issue in "${issues[@]}"; do
		echo " $red▲$off $issue"
	done
	echo
fi
printf '%s\n' "${rows[@]}"
echo
