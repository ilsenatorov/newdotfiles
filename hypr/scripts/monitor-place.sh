#!/usr/bin/env bash
# Place an external display relative to the built-in panel, interactively.
#
# xrandr cannot do this on Hyprland: Xwayland's RandR outputs are a read-only
# reflection of the compositor's layout, so RRSetScreenSize fails with BadMatch.
# Hyprland 0.56 also dropped `hyprctl keyword` for the Lua config parser, so the
# runtime equivalent is `hyprctl eval 'hl.monitor({...})'`.
#
# Usage:
#   monitor-place.sh above            # apply directly (single external display)
#   monitor-place.sh above DP-6       # apply to a named output
#   monitor-place.sh --dry-run above  # print the hl.monitor calls, change nothing
#   monitor-place.sh --query          # JSON: anchor + each output's placement
#
# Picking interactively is quickshell's job now (SUPER+SHIFT+M ->
# quickshell/panels/MonitorPlace.qml). --query is what that panel reads so it
# can draw the tiles without re-deriving any of the geometry below; it still
# resolves only to a (placement, output) pair and hands it straight back.
#
# Placements: left right above below mirror disable
#
# Changes are remembered per connected display set by monitor-layout.py.
# Hyprland restores them after login, config reload and monitor hotplug.

set -euo pipefail

dry_run=0
[ "${1:-}" = "--dry-run" ] && { dry_run=1; shift; }

query=0
[ "${1:-}" = "--query" ] && { query=1; shift; }

placement="${1:-}"
target="${2:-}"

die() {
	notify-send -u critical "Monitor placement" "$1" 2>/dev/null || true
	echo "$1" >&2
	exit 1
}

# Tests inject a fixture here; normally we ask the running compositor. `all` is
# required -- a disabled output disappears from plain `monitors`, and it has to
# stay listed so it can be switched back on.
mons="${MONITOR_PLACE_JSON:-$(hyprctl monitors all -j)}"

# The built-in panel anchors the layout. eDP-1 is the generic DRM connector class
# for a laptop panel; on a desktop there is none, so fall back to the focused
# output and treat that as the thing everything else is placed around.
anchor=$(jq -r 'map(select(.name == "eDP-1")) | .[0].name // empty' <<<"$mons")
[ -z "$anchor" ] && anchor=$(jq -r 'map(select(.focused == true)) | .[0].name // empty' <<<"$mons")
[ -z "$anchor" ] && anchor=$(jq -r 'map(select(.disabled == false)) | .[0].name // empty' <<<"$mons")
[ -z "$anchor" ] && die "No usable output to anchor the layout to."

# "<width> <height> <scale> <x> <y> <disabled> <mirrorOf>"
geom() { jq -r --arg n "$1" '.[] | select(.name == $n) |
	"\(.width) \(.height) \(.scale) \(.x) \(.y) \(.disabled) \(.mirrorOf)"' <<<"$mons"; }

# Logical (post-scale) size -- what the layout coordinate space actually uses.
# Equal to the pixel size only while scale is 1.
logical() { awk -v v="$1" -v s="$2" 'BEGIN { s = (s > 0 ? s : 1); printf "%.0f", v / s }'; }

# A disabled output reports 0x0 at scale 0, which would make left/above offset by
# nothing and stack it on the anchor. Its first availableModes entry
# ("1920x1080@60.00Hz") is the preferred mode, i.e. the size it will come back at.
# A disabled output also reports scale 0, which must not reach the Lua spec.
norm_scale() { awk -v s="$1" 'BEGIN { print (s > 0 ? s : 1) }'; }

preferred_size() {
	jq -r --arg n "$1" '.[] | select(.name == $n) | .availableModes[0] // "0x0@0Hz"' <<<"$mons" |
		sed -E 's/@.*//; s/x/ /'
}

read -r aw ah ascale ax ay _adis _amir < <(geom "$anchor")
ascale=$(norm_scale "$ascale")
alw=$(logical "$aw" "$ascale")
alh=$(logical "$ah" "$ascale")

# --- per-output metrics -----------------------------------------------------

# "<logicalW> <logicalH> <scale> <x> <y> <disabled> <mirrorOf>" for one output,
# substituting the preferred mode when it is currently disabled.
target_metrics() {
	local n=$1 w h s x y dis mir
	read -r w h s x y dis mir < <(geom "$n")
	if [ "$w" -eq 0 ] || [ "$h" -eq 0 ]; then
		read -r w h < <(preferred_size "$n")
	fi
	s=$(norm_scale "$s")
	# Trailing newline matters: `read` returns non-zero at EOF without one,
	# which `set -e` would turn into a silent exit at every call site.
	printf '%s %s %s %s %s %s %s\n' \
		"$(logical "$w" "$s")" "$(logical "$h" "$s")" "$s" "$x" "$y" "$dis" "$mir"
}

# Where an output sits right now, so the picker can mark the active tile.
# Derived from live coordinates rather than the anchor's nominal 0x0, since the
# anchor may have been moved by a previous run or by the position = "auto" rules.
current_placement() {
	local tlw tlh _ts tx ty tdis tmir
	read -r tlw tlh _ts tx ty tdis tmir < <(target_metrics "$1")
	if [ "$tdis" = "true" ]; then
		echo "Disable"
	elif [ -n "$tmir" ] && [ "$tmir" != "none" ]; then
		echo "Mirror"
	elif [ "$tx" -ge $((ax + alw)) ]; then
		echo "Right"
	elif [ $((tx + tlw)) -le "$ax" ]; then
		echo "Left"
	elif [ $((ty + tlh)) -le "$ay" ]; then
		echo "Above"
	elif [ "$ty" -ge $((ay + alh)) ]; then
		echo "Below"
	else
		echo ""
	fi
}

# --- --query ----------------------------------------------------------------

if [ "$query" = 1 ]; then
	targets="[]"
	while IFS=$'\t' read -r name desc; do
		[ -z "$name" ] && continue
		targets=$(jq --arg n "$name" --arg d "$desc" --arg c "$(current_placement "$name")" \
			'. + [{name: $n, description: $d, current: $c}]' <<<"$targets")
	done < <(jq -r --arg a "$anchor" '.[] | select(.name != $a) |
		"\(.name)\t\(.description)"' <<<"$mons")
	jq -n --arg a "$anchor" --argjson t "$targets" '{anchor: $a, targets: $t}'
	exit 0
fi

# --- resolve the output to act on -------------------------------------------

if [ -z "$target" ]; then
	mapfile -t candidates < <(jq -r --arg a "$anchor" '.[] | select(.name != $a) | .name' <<<"$mons")

	case ${#candidates[@]} in
		0) die "No external display connected." ;;
		1) target="${candidates[0]}" ;;
		# No interactive fallback any more: the caller names the output.
		*) die "Several external displays; name one: ${candidates[*]}" ;;
	esac
fi

jq -e --arg n "$target" 'map(select(.name == $n)) | length > 0' <<<"$mons" >/dev/null \
	|| die "No such output: $target"
[ "$target" = "$anchor" ] && die "$target is the anchor display; pick another output."

read -r tlw tlh tscale _tx _ty _tdis _tmir < <(target_metrics "$target")

[ -n "$placement" ] || die "No placement given (want: left right above below mirror disable)"
placement=$(tr '[:upper:]' '[:lower:]' <<<"$placement")

# --- compute the new position ----------------------------------------------

mirror=""
disabled="false"
position="0x0"

case "$placement" in
	right)   position="${alw}x0" ;;
	left)    position="-${tlw}x0" ;;
	above)   position="0x-${tlh}" ;;
	below)   position="0x${alh}" ;;
	mirror)  mirror="$anchor" ;;
	disable) disabled="true" ;;
	*) die "Unknown placement: $placement (want: left right above below mirror disable)" ;;
esac

# --- apply ------------------------------------------------------------------

# Every apply writes a *full* spec. mirror and disabled are sticky in Hyprland,
# so a partial rule would leave "Right" mirroring the panel after a previous
# "Mirror". Clearing them explicitly on every call is what makes the six options
# reachable from each other in any order.
spec() {
	printf 'hl.monitor({output="%s", mode="preferred", position="%s", scale=%s, mirror="%s", disabled=%s})' \
		"$1" "$2" "$3" "$4" "$5"
}

anchor_call=$(spec "$anchor" "0x0" "$ascale" "" "false")
target_call=$(spec "$target" "$position" "$tscale" "$mirror" "$disabled")

if [ "$dry_run" = 1 ]; then
	printf '%s\n%s\n' "$anchor_call" "$target_call"
	exit 0
fi

# Anchor first: it is pinned to 0x0 so the target's coordinates mean what they
# say. Left/Above put the target at negative coordinates, and an anchor left on
# position = "auto" would otherwise re-flow out from under it.
python3 "$(dirname "$0")/monitor-layout.py" --place "$placement" "$target"

case "$placement" in
	mirror)      msg="$target mirroring $anchor" ;;
	disable)     msg="$target disabled" ;;
	above|below) msg="$target placed $placement $anchor" ;;
	*)           msg="$target placed $placement of $anchor" ;;
esac

notify-send "Monitor placement" "$msg" 2>/dev/null || true
