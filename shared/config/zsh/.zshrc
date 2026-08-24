# User-installed tools.
export PATH="$HOME/.local/bin:$PATH"

# Path to your oh-my-zsh installation.
export ZSH="$HOME/.oh-my-zsh"

# Starship owns the prompt after Oh My Zsh has initialized.
ZSH_THEME=""

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
source "$HOME/.config/zsh/platform.zsh"

# mise
path=("$HOME/.local/share/mise/shims" ${path:#"$HOME/.local/share/mise/shims"})
export PATH
eval "$(mise activate zsh)"

# Load private configuration
if [ -f ~/.zshrc_private ]; then
    source ~/.zshrc_private
fi

# Initialize the prompt last so earlier shell setup cannot override it.
eval "$(starship init zsh)"

# Collapse completed prompts to the character while keeping the active prompt full.
if [[ -o interactive ]]; then
  dotfiles_starship_transient_prompt() {
    local prompt_status="${STARSHIP_CMD_STATUS:-0}"
    local saved_prompt="$PROMPT"
    local saved_rprompt="$RPROMPT"

    PROMPT="$(starship module character --status="$prompt_status")"
    RPROMPT=
    zle reset-prompt
    PROMPT="$saved_prompt"
    RPROMPT="$saved_rprompt"
  }

  autoload -Uz add-zle-hook-widget
  add-zle-hook-widget line-finish dotfiles_starship_transient_prompt
fi
