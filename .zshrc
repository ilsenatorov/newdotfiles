ZSH="${ZSH:-$HOME/.oh-my-zsh}"
export ZSH
# No ZSH_THEME: starship is initialised at the bottom of this file and replaces
# whatever oh-my-zsh sets, so setting one here only costs a wasted theme load.
ZSH_THEME=""

plugins=(git
	sudo
	zsh-autosuggestions
	zsh-syntax-highlighting)

# Completion function search path. Must be set BEFORE oh-my-zsh.sh, which runs
# compinit itself (oh-my-zsh.sh:70) -- a second compinit after this file's own
# would just be a wasted uncached run.
fpath+=~/.zfunc

source $ZSH/oh-my-zsh.sh
zstyle ':completion:*' menu select
zstyle ':completion:*' matcher-list 'm:{a-z}={A-Za-z}'

export EDITOR=nvim
export VISUAL=nvim
alias vim=nvim
# Deliberately NOT setting TERM: kitty ships correct terminfo and exports it
# itself. Forcing xterm-256color costs true-colour and undercurl detection.
# For hosts missing the entry, use `kitty +kitten ssh` or
#   infocmp -x | ssh HOST -- tic -x -
export BROWSER=/usr/bin/brave

# History -- oh-my-zsh sets no defaults of its own, so without this a shell
# falls back to zsh's stock 1000-line unshared history.
HISTFILE=~/.zsh_history
HISTSIZE=50000
SAVEHIST=50000
setopt HIST_IGNORE_ALL_DUPS HIST_REDUCE_BLANKS HIST_VERIFY SHARE_HISTORY \
	EXTENDED_HISTORY INC_APPEND_HISTORY HIST_IGNORE_SPACE

# zoxide replaces oh-my-zsh's `z` plugin -- faster, and `--cmd cd` means plain
# `cd` learns to jump on a partial match with no new command to remember.
command -v zoxide >/dev/null && eval "$(zoxide init zsh --cmd cd)"

# fzf in the desktop palette (quickshell/Theme.qml). bat/delta/eza are themed
# below via BAT_THEME / delta's config in git/config, not here.
export FZF_DEFAULT_OPTS="--color=bg+:#1E262B,bg:-1,spinner:#4DD0E1,hl:#EC7875 \
--color=fg:#93A1A1,header:#EC7875,info:#FDD835,pointer:#4DD0E1 \
--color=marker:#61C766,fg+:#CDD6D6,prompt:#FDD835,hl+:#EC7875 \
--color=border:#3C4449 --border=rounded --height=40% --layout=reverse"
if command -v fd >/dev/null; then
	export FZF_DEFAULT_COMMAND="fd --type f --hidden --exclude .git"
	export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"
fi
# Ships in /usr/share/fzf on Arch; not sourced by the fzf package itself.
[ -r /usr/share/fzf/key-bindings.zsh ] && source /usr/share/fzf/key-bindings.zsh
[ -r /usr/share/fzf/completion.zsh ] && source /usr/share/fzf/completion.zsh

# Modern CLI replacements -- each guarded so a machine missing the package
# still gets a working shell, same style as the hyprsunset/cliphist guards in
# hypr/hyprland.lua.
if command -v eza >/dev/null; then
	alias ls='eza --icons --group-directories-first'
	alias ll='eza --icons --group-directories-first -l --git'
	alias la='eza --icons --group-directories-first -la --git'
	alias lt='eza --icons --group-directories-first --tree'
fi
if command -v bat >/dev/null; then
	alias cat='bat --paging=never'
	# ANSI theme -- matches kitty's 16-colour palette (kitty/colors.conf)
	# rather than needing its own matugen template.
	export BAT_THEME=ansi
	export MANPAGER="sh -c 'col -bx | bat -l man -p'"
fi
command -v rg >/dev/null && alias grep='rg'

alias ranger='ranger -r ~/dotfiles/ranger'
alias r='ranger -r ~/dotfiles/ranger --choosedir=$HOME/.rangerdir; LASTDIR=`cat $HOME/.rangerdir`; cd "$LASTDIR"'

export STARSHIP_CONFIG="$HOME/.config/starship/starship.toml"
eval "$(starship init zsh)"

# Transient prompt: once a command is submitted, redraw the prompt it was typed
# at as a bare ❯ (the `transient` profile in starship.base.toml) and drop the
# right prompt, so scrollback is commands and output rather than a rainbow bar
# per line. Starship has no `enable_transience` for zsh -- it ships one for
# fish/bash/cmd/nu/pwsh only -- so the widget is ours.
#
# It must come after the init above (which sets PROMPT/RPROMPT) and after
# oh-my-zsh loads zsh-autosuggestions, which wraps accept-line: `zle -A` keeps
# a callable alias to whatever is bound now instead of dropping that wrapper.
_STARSHIP_PROMPT=$PROMPT
_STARSHIP_RPROMPT=$RPROMPT
# Single-quoted: promptsubst re-runs this at redraw time, so the collapsed ❯
# still reflects the exit status the original prompt was rendered with.
_STARSHIP_TRANSIENT_PROMPT='$('/usr/bin/starship' prompt --profile transient --status="${STARSHIP_CMD_STATUS:-0}" --keymap="${KEYMAP:-}")'

zle -A accept-line _starship_orig_accept_line
_starship_transient_accept_line() {
	# zsh-autosuggestions' grey completion lives in POSTDISPLAY; without this it
	# survives the redraw and is left hanging off the transient line.
	POSTDISPLAY=""
	PROMPT=$_STARSHIP_TRANSIENT_PROMPT RPROMPT=""
	zle .reset-prompt
	PROMPT=$_STARSHIP_PROMPT RPROMPT=$_STARSHIP_RPROMPT
	zle _starship_orig_accept_line
}
zle -N accept-line _starship_transient_accept_line

# Per-machine tail: CLAUDE_OBSIDIAN_VAULT, the NVIDIA VS Code workaround,
# `. ~/.local/bin/env`, anything else that is true on this box but not the
# other two. Lives outside the repo -- install.sh seeds it once, never
# overwrites it, and never tracks it.
[ -r "$HOME/.zshrc.local" ] && . "$HOME/.zshrc.local"

# Pi
export PATH="$HOME/.local/bin:$PATH"
