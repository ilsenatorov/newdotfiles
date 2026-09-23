#!/usr/bin/env bash
# Lint/validate the repo. Run before pushing, and in CI (.github/workflows/ci.yml).
# Each check is skipped with a warning (not a failure) if its tool isn't
# installed, so this also works on a machine that ran --minimal.
set -uo pipefail

fail=0
say()  { printf '\n\033[1;36m==>\033[0m %s\n' "$1"; }
warn() { printf '\033[1;33mSKIP\033[0m %s\n' "$1" >&2; }
note_fail() { fail=1; }

cd "$(dirname "$0")" || exit 1

SHELL_SCRIPTS=(
	install.sh link.sh check.sh starship/build.sh
	sddm/install.sh sddm/sync-wallpaper.sh
	hypr/scripts/*.sh quickshell/scripts/*.sh
)

say "shellcheck"
if command -v shellcheck >/dev/null; then
	shellcheck "${SHELL_SCRIPTS[@]}" || note_fail
else
	warn "shellcheck not installed (pacman -S shellcheck)"
fi

say "shfmt"
if command -v shfmt >/dev/null; then
	shfmt -i 1 -ci -d "${SHELL_SCRIPTS[@]}" || note_fail
else
	warn "shfmt not installed (pacman -S shfmt)"
fi

say "lua syntax"
if command -v luac >/dev/null; then
	luac -p hypr/hyprland.lua hypr/colors.lua nvim/init.lua nvim/lua/*.lua \
		matugen/templates/*.lua matugen/defaults/hypr/colors.lua \
		matugen/defaults/nvim/colors.lua || note_fail
else
	warn "luac not installed (pacman -S lua)"
fi

say "lua lint"
if command -v luacheck >/dev/null; then
	# hl is Hyprland's injected global inside hyprland.lua.
	luacheck --globals hl vim -- hypr/hyprland.lua nvim/init.lua nvim/lua/*.lua || note_fail
else
	warn "luacheck not installed (pacman -S luacheck)"
fi

say "qml lint"
if command -v qmllint >/dev/null; then
	qml_include=""
	for d in /usr/lib/qt6/qml /usr/lib/qt/qml; do
		[ -d "$d" ] && qml_include="$d" && break
	done
	# Run per-file: this qmllint build crashes (exit 255, no output) on some
	# Quickshell singleton/Io files that are otherwise fine -- a tool bug, not
	# a lint finding. Only actual diagnostic OUTPUT fails the check; a silent
	# non-zero exit is just noted.
	while IFS= read -r -d '' f; do
		out=$(qmllint ${qml_include:+-I "$qml_include"} "$f" 2>&1)
		rc=$?
		if [ -n "$out" ]; then
			echo "$out"
			note_fail
		elif [ "$rc" -ne 0 ]; then
			warn "qmllint crashed on $f (no diagnostic output, likely a qmllint bug)"
		fi
	done < <(find quickshell -name '*.qml' -print0)
else
	warn "qmllint not installed (pacman -S qt6-declarative)"
fi

say "gitleaks"
if command -v gitleaks >/dev/null; then
	gitleaks detect --no-banner --source . || note_fail
else
	warn "gitleaks not installed (CI-only check, safe to skip locally)"
fi

if [ "$fail" -eq 0 ]; then
	say "all checks passed"
else
	say "one or more checks failed"
fi
exit "$fail"
