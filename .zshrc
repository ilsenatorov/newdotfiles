# Enable Powerlevel10k instant prompt. Should stay close to the top of ~/.zshrc.
# Initialization code that may require console input (password prompts, [y/n]
# confirmations, etc.) must go above this block; everything else may go below.
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

export ZSH="/home/ilya/.oh-my-zsh"
# No ZSH_THEME: powerlevel10k is sourced at the bottom of this file and replaces
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

# fzf in the desktop palette (waybar/style.css). bat/delta/eza are not installed
# here, so there is nothing to theme for them yet.
export FZF_DEFAULT_OPTS="--color=bg+:#1E262B,bg:-1,spinner:#4DD0E1,hl:#EC7875 \
--color=fg:#93A1A1,header:#EC7875,info:#FDD835,pointer:#4DD0E1 \
--color=marker:#61C766,fg+:#CDD6D6,prompt:#FDD835,hl+:#EC7875 \
--color=border:#3C4449 --border=rounded --height=40% --layout=reverse"
alias ranger='ranger -r ~/dotfiles/ranger'
alias r='ranger -r ~/dotfiles/ranger --choosedir=$HOME/.rangerdir; LASTDIR=`cat $HOME/.rangerdir`; cd "$LASTDIR"'


# >>> conda initialize >>>
# !! Contents within this block are managed by 'conda init' !!
__conda_setup="$('/home/ilya/miniconda3/bin/conda' 'shell.zsh' 'hook' 2> /dev/null)"
if [ $? -eq 0 ]; then
    eval "$__conda_setup"
else
    if [ -f "/home/ilya/miniconda3/etc/profile.d/conda.sh" ]; then
        . "/home/ilya/miniconda3/etc/profile.d/conda.sh"
    else
        export PATH="/home/ilya/miniconda3/bin:$PATH"
    fi
fi
unset __conda_setup
# <<< conda initialize <<<

source ~/powerlevel10k/powerlevel10k.zsh-theme

# To customize prompt, run `p10k configure` or edit ~/.p10k.zsh.
[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh


# The next line updates PATH for the Google Cloud SDK.
if [ -f '/home/ilya/google-cloud-sdk/path.zsh.inc' ]; then . '/home/ilya/google-cloud-sdk/path.zsh.inc'; fi

# The next line enables shell command completion for gcloud.
if [ -f '/home/ilya/google-cloud-sdk/completion.zsh.inc' ]; then . '/home/ilya/google-cloud-sdk/completion.zsh.inc'; fi

fpath+=~/.zfunc; autoload -Uz compinit; compinit

zstyle ':completion:*' menu select

# claude-obsidian: single shared knowledge vault across all projects
export CLAUDE_OBSIDIAN_VAULT="$HOME/Documents/MyKnowledgeVault"
