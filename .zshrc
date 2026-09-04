export ZSH="/home/ilya/.oh-my-zsh"
# No ZSH_THEME: starship is initialised at the bottom of this file and replaces
# whatever oh-my-zsh sets, so setting one here only costs a wasted theme load.
ZSH_THEME=""

plugins=(git
	sudo
	pep8
	web-search
	zsh-autosuggestions
	zsh-syntax-highlighting
	z)

source $ZSH/oh-my-zsh.sh
export EDITOR=vim
# Deliberately NOT setting TERM: alacritty and kitty both ship correct terminfo
# and export it themselves. Forcing xterm-256color costs true-colour and
# undercurl detection. For hosts missing the entry, use `kitty +kitten ssh` or
#   infocmp -x | ssh HOST -- tic -x -
export BROWSER=/usr/bin/brave

# fzf in the desktop palette (quickshell/Theme.qml). bat/delta/eza are not installed
# here, so there is nothing to theme for them yet.
export FZF_DEFAULT_OPTS="--color=bg+:#1E262B,bg:-1,spinner:#4DD0E1,hl:#EC7875 \
--color=fg:#93A1A1,header:#EC7875,info:#FDD835,pointer:#4DD0E1 \
--color=marker:#61C766,fg+:#CDD6D6,prompt:#FDD835,hl+:#EC7875 \
--color=border:#3C4449 --border=rounded --height=40% --layout=reverse"
alias ranger='ranger -r ~/dotfiles/ranger'
alias r='ranger -r ~/dotfiles/ranger --choosedir=$HOME/.rangerdir; LASTDIR=`cat $HOME/.rangerdir`; cd "$LASTDIR"'


fpath+=~/.zfunc; autoload -Uz compinit; compinit

zstyle ':completion:*' menu select

export CLAUDE_OBSIDIAN_VAULT="$HOME/Documents/MyKnowledgeVault"
export STARSHIP_CONFIG="$HOME/.config/starship/starship.toml"
eval "$(starship init zsh)"


# VS Code: native Wayland backend segfaults on this NVIDIA setup; force XWayland
alias code="code --ozone-platform=x11"

