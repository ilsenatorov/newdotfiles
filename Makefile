SHELL := /usr/bin/bash
.PHONY: install link unlink check lint fmt doctor

install:
	./install.sh

link:
	./link.sh

unlink:
	./link.sh --unlink

# Lints/validates everything (see check.sh) -- what CI runs too.
check:
	./check.sh

lint: check

fmt:
	shfmt -i 1 -ci -w install.sh link.sh check.sh starship/build.sh \
		sddm/install.sh sddm/sync-wallpaper.sh \
		hypr/scripts/*.sh quickshell/scripts/*.sh

# Compares the PKGS_*/AUR_* arrays in install.sh against what's actually
# installed, and sanity-checks the machine's config state.
doctor:
	@echo "==> missing packages"
	@comm -23 <(./install.sh --list-packages | sort -u) <(pacman -Qq | sort -u) || true
	@echo "==> dangling ~/.config symlinks into this repo"
	@for d in "$$HOME"/.config/*; do \
		[ -L "$$d" ] || continue; \
		t=$$(readlink "$$d"); \
		case "$$t" in "$$HOME"/dotfiles/*) [ -e "$$t" ] || echo "  $$d -> $$t" ;; esac; \
	done
	@echo "==> per-machine files"
	@for f in "$$HOME/.config/dotfiles/local.conf" "$$HOME/.config/dotfiles/local.lua" \
		"$$HOME/.zshrc.local" "$$HOME/.config/git/config.local"; do \
		[ -f "$$f" ] && echo "  OK      $$f" || echo "  MISSING $$f"; \
	done
	@echo "==> hyprpolkitagent user unit"
	@systemctl --user is-enabled hyprpolkitagent.service 2>/dev/null || echo "  not enabled"
