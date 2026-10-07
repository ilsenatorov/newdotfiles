#!/usr/bin/env bash
# Interactive per-machine settings, written to ~/.config/dotfiles/local.conf.
#
#   ./configure.sh    (or: make configure)
#
# Pickers for display scaling, keyboard layouts, bar modules and services.
# Only the keys you change are rewritten, in place: comments, ordering and
# every other hand edit in local.conf survive, and the file is backed up to
# local.conf.bak-<timestamp> before the first write. install.sh runs this on a
# first install and with --reconfigure; rerun it any time afterwards.
#
# Who reads what: quickshell/Local.qml watches local.conf and applies UI_SCALE,
# BAR_* and SVC_* live. hypr/hyprland.lua reads KB_LAYOUT and AUTOSTART_*
# (picked up on save via `hyprctl reload`; AUTOSTART_* only at the next login).
# Per-monitor scale is not a local.conf key: it is applied live and stored by
# hypr/scripts/monitor-layout.py with the rest of the remembered display layout
# for the displays connected right now.
set -euo pipefail

CONF="${HOME}/.config/dotfiles/local.conf"
DOTS="${HOME}/dotfiles"

if [ ! -t 0 ] || [ ! -t 1 ]; then
	echo "configure.sh: not a terminal, nothing changed (edit ${CONF} by hand)" >&2
	exit 0
fi
if ! command -v gum >/dev/null; then
	echo "configure.sh: needs gum (pacman -S gum); nothing changed" >&2
	exit 0
fi

mkdir -p "$(dirname "$CONF")"
[ -f "$CONF" ] || printf '# Per-machine overrides -- see configure.sh / install.sh.\n' >"$CONF"

# ---------------------------------------------------------------- state ----
# Pending edits; nothing touches the file or the displays until "Save".
declare -A NEW=()
# Pending monitor rules: connector -> full hl.monitor{} spec with the new scale.
declare -A MON=()

# Current value of $1: a pending edit, else local.conf, else $2.
get() {
	if [ -n "${NEW[$1]+x}" ]; then
		printf '%s' "${NEW[$1]}"
		return
	fi
	# A key that is present but empty stays empty (BAR_CENTER= hides that
	# pill); only an absent key falls back to $2. The "=" prefix tells them apart.
	local v
	v=$(awk -v k="$1" '
		{ line = $0; sub(/^[ \t]+/, "", line) }
		index(line, k "=") == 1 { val = substr(line, length(k) + 2); found = 1 }
		END { if (found) { sub(/[ \t]+$/, "", val); print "=" val } }' "$CONF")
	if [ -n "$v" ]; then printf '%s' "${v#=}"; else printf '%s' "${2:-}"; fi
}

set_() { NEW[$1]="$2"; }

# Apply pending monitor scales and remember them as this display set's layout.
save_monitors() {
	[ "${#MON[@]}" -gt 0 ] || return 0
	local result
	result=$(hyprctl eval "$(printf '%s;' "${MON[@]}")")
	if grep -qi error <<<"$result"; then
		gum log --level error "monitor scale not applied: $result"
		return 0
	fi
	sleep 0.1
	python3 "${DOTS}/hypr/scripts/monitor-layout.py" --remember && echo "applied monitor scale"
}

# Write every pending key: replace KEY=... in place, or append if absent.
save() {
	[ "${#NEW[@]}" -gt 0 ] || return 0
	cp "$CONF" "${CONF}.bak-$(date +%Y%m%d-%H%M%S)"
	local tmp key
	tmp=$(mktemp "${CONF}.XXXXXX")
	cp "$CONF" "$tmp"
	for key in "${!NEW[@]}"; do
		K="$key" V="${NEW[$key]}" awk '
			BEGIN { k = ENVIRON["K"]; v = ENVIRON["V"] }
			{ line = $0; sub(/^[ \t]+/, "", line) }
			index(line, k "=") == 1 { print k "=" v; done = 1; next }
			{ print }
			END { if (!done) print k "=" v }' "$tmp" >"${tmp}.next"
		mv "${tmp}.next" "$tmp"
	done
	mv "$tmp" "$CONF"
	echo "saved ${CONF}"
}

# ---------------------------------------------------------------- helpers ----
# $1 = comma list. Print one item per line.
lines() { tr ',' '\n' <<<"$1" | sed '/^$/d'; }
# stdin lines -> comma list
commas() { paste -sd, -; }

# Options for a multi-pick: the current picks ($1, comma list) first, in their
# order, then the rest (stdin). gum prints picks in option order, so the
# current order survives and new picks land at the end.
current_first() { (
	lines "$1"
	cat
) | awk '!seen[$0]++'; }

# Run a gum picker; a cancelled one (Esc / Ctrl-C) prints nothing and fails,
# so callers can `|| return` and keep the current value.
pick() { gum choose --header.foreground=6 "$@"; }

# ---------------------------------------------------------------- display ----
display() {
	local cur s mons
	cur=$(get UI_SCALE 1.0)
	s=$(pick --header "Shell UI scale (bar, panels, fonts) -- now ${cur}" \
		--selected="$cur" 0.8 0.9 1.0 1.1 1.25 1.5 1.75 2.0) || return 0
	set_ UI_SCALE "$s"

	if ! command -v hyprctl >/dev/null || ! command -v jq >/dev/null ||
		! mons=$(hyprctl monitors all -j 2>/dev/null) || [ -z "$mons" ]; then
		gum log --level warn "Hyprland isn't running -- per-monitor scale skipped"
		return 0
	fi

	local name desc w h hz x y tf live now
	# rows come in on fd 3 so gum keeps the terminal on stdin
	while IFS=$'\t' read -r name desc w h hz x y tf live <&3; do
		# hyprctl reports 1.00 etc; match the menu's spelling.
		now=$(awk -v s="$live" 'BEGIN { printf "%g", s }')
		s=$(pick --header "Scale for ${name} (${desc:-unknown}, ${w}x${h}) -- now ${now}" \
			--selected="$now" 1 1.25 1.5 1.6 2) || continue
		[ "$s" = "$now" ] && continue
		MON[$name]="hl.monitor({output=\"${name}\", mode=\"${w}x${h}@${hz}\", position=\"${x}x${y}\", scale=${s}, transform=${tf}})"
	done 3< <(jq -r '.[] | select(.disabled | not)
		| [.name, (.description // ""), .width, .height, .refreshRate, .x, .y, .transform, .scale] | @tsv' <<<"$mons")
}

# ---------------------------------------------------------------- keyboard ----
keyboard() {
	local cur picked
	cur=$(get KB_LAYOUT "")
	cur=${cur:-us,ru,graphite}
	# graphite is ours (xkb/symbols/graphite); the rest ship with xkeyboard-config.
	picked=$(printf '%s\n' us graphite ru ua de fr es it pl gb | current_first "$cur" |
		pick --no-limit --selected="$cur" \
			--header "Keyboard layouts (x toggles; both Shifts cycle them)" | commas) || return 0
	[ -n "$picked" ] || {
		gum log --level warn "No layout picked -- keeping ${cur}"
		return 0
	}

	local first="${picked%%,*}"
	if [ "$picked" != "$first" ]; then
		first=$(lines "$picked" | pick --selected="$first" \
			--header "First layout -- Hyprland shortcuts follow its key positions") || first="${picked%%,*}"
	fi
	set_ KB_LAYOUT "$( (
		echo "$first"
		lines "$picked" | grep -vxF -- "$first"
	) | commas)"
}

# ---------------------------------------------------------------- bar ----
bar() {
	# The module names quickshell/bar/Bar.qml's registry knows.
	local modules
	modules=$(sed -n '/property var registry/,/})/p' "${DOTS}/quickshell/bar/Bar.qml" |
		grep -oE '[a-z]+: *[a-zA-Z]+C\b' | cut -d: -f1)

	local section key def cur picked
	for section in left center right; do
		case "$section" in
			left) def=workspaces,clock,battery ;;
			center) def=media ;;
			right) def=network,bluetooth,audio,notifications,status,language ;;
		esac
		key="BAR_${section^^}"
		cur=$(get "$key" "$def")
		# current picks the registry no longer knows (retired modules) drop out
		picked=$(current_first "$cur" <<<"$modules" | grep -xF -f <(echo "$modules") |
			pick --no-limit --selected="$cur" \
				--header "Bar ${section} section (x toggles; none = hide that pill)" | commas) || continue
		set_ "$key" "$picked"
	done
}

# ---------------------------------------------------------------- services ----
services() {
	# label|value pairs; value is the local.conf key.
	local opts=(
		"Weather forecast (polls open-meteo)|SVC_WEATHER"
		"Claude usage meter|SVC_CLAUDE_USAGE"
		"GPU stats (nvidia-smi poller)|SVC_GPU"
		"hypridle: idle dim / auto-lock (next login)|AUTOSTART_HYPRIDLE"
		"Wallpaper daemon (next login)|AUTOSTART_WALLPAPER"
	)
	local o key def on=()
	for o in "${opts[@]}"; do
		key=${o#*|}
		def=1
		[ "$key" = AUTOSTART_HYPRIDLE ] && def=0
		case "$(get "$key" "$def")" in 0 | false | FALSE | False) ;; *) on+=("${o%|*}") ;; esac
	done

	local picked
	picked=$(printf '%s\n' "${opts[@]}" | pick --no-limit --label-delimiter='|' \
		--selected="$(
			IFS=,
			echo "${on[*]}"
		)" \
		--header "Services (x toggles)") || return 0
	for o in "${opts[@]}"; do
		key=${o#*|}
		if grep -qxF -- "$key" <<<"$picked"; then set_ "$key" 1; else set_ "$key" 0; fi
	done
}

# ---------------------------------------------------------------- main ----
summary() {
	local k
	gum style --border rounded --padding "0 1" --border-foreground 6 \
		"UI_SCALE      $(get UI_SCALE 1.0)" \
		"MONITORS      $(hyprctl monitors -j 2>/dev/null | jq -r '[.[] | "\(.name)=\(.scale)"] | join(" ")' 2>/dev/null)${MON[*]:+ (scale change pending)}" \
		"KB_LAYOUT     $(get KB_LAYOUT us,ru,graphite)" \
		"BAR           $(get BAR_LEFT workspaces,clock,battery) | $(get BAR_CENTER media) | $(get BAR_RIGHT network,bluetooth,audio,notifications,status,language)" \
		"$(for k in SVC_WEATHER SVC_CLAUDE_USAGE SVC_GPU AUTOSTART_HYPRIDLE AUTOSTART_WALLPAPER; do
			printf '%s=%s ' "${k#*_}" "$(get "$k" -)"
		done)" \
		"pending: $((${#NEW[@]} + ${#MON[@]})) change(s)"
}

while :; do
	clear
	summary
	choice=$(pick --header "$CONF" \
		"Display scaling" "Keyboard layouts" "Bar modules" "Services & autostart" \
		"Save & quit" "Quit without saving") || choice="Quit without saving"
	case "$choice" in
		"Display scaling") display ;;
		"Keyboard layouts") keyboard ;;
		"Bar modules") bar ;;
		"Services & autostart") services ;;
		"Save & quit")
			save_monitors
			save
			if [ -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ] && command -v hyprctl >/dev/null; then
				hyprctl reload >/dev/null && echo "reloaded Hyprland"
			fi
			break
			;;
		*)
			n=$((${#NEW[@]} + ${#MON[@]}))
			if [ "$n" -gt 0 ] && ! gum confirm "Discard ${n} pending change(s)?"; then
				continue
			fi
			break
			;;
	esac
done
