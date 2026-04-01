# Enable Powerlevel10k instant prompt. Should stay close to the top of ~/.zshrc.
# Initialization code that may require console input (password prompts, [y/n]
# confirmations, etc.) must go above this block; everything else may go below.
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

# Path to your oh-my-zsh installation.
export ZSH="$HOME/.oh-my-zsh"

# Set theme to powerlevel10k
ZSH_THEME="powerlevel10k/powerlevel10k"

# Which plugins would you like to load?
# Standard plugins can be found in $ZSH/plugins/
# Custom plugins may be added to $ZSH_CUSTOM/plugins/
# Example format: plugins=(rails git textmate ruby lighthouse)
# Add wisely, as too many plugins slow down shell startup.
plugins=(git zsh-eza zsh-autosuggestions zsh-syntax-highlighting zsh-history-substring-search)

# Initialize oh-my-zsh
source $ZSH/oh-my-zsh.sh

# eza config
export EZA_CONFIG_DIR="$HOME/.config/eza"
export _EZA_PARAMS=('--git' '--group-directories-first' '--color-scale-mode=fixed' '--icons' '--time-style=long-iso')
# Clear LS_COLORS so eza theme.yml has full control over colors
unset LS_COLORS

# Set aliases
source $HOME/.aliases

# mise
eval "$(mise activate zsh)"

# pnpm global bin dir (managed by mise, PNPM_HOME is for globally installed packages)
export PNPM_HOME="$HOME/Library/pnpm"
case ":$PATH:" in
  *":$PNPM_HOME:"*) ;;
  *) export PATH="$PNPM_HOME:$PATH" ;;
esac

# To customize prompt, run `p10k configure` or edit ~/.p10k.zsh.
[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh

# Load private configuration
if [ -f ~/.zshrc_private ]; then
    source ~/.zshrc_private
fi
