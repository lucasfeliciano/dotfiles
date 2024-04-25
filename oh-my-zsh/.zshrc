# Path to your oh-my-zsh installation.
export ZSH="$HOME/.oh-my-zsh"

# Set theme to spaceship
ZSH_THEME="spaceship"

# Which plugins would you like to load?
# Standard plugins can be found in $ZSH/plugins/
# Custom plugins may be added to $ZSH_CUSTOM/plugins/
# Example format: plugins=(rails git textmate ruby lighthouse)
# Add wisely, as too many plugins slow down shell startup.
plugins=(git zsh-syntax-highlighting zsh-history-substring-search)

# Initialize oh-my-zsh
source $ZSH/oh-my-zsh.sh

# Set aliases
source $HOME/.aliases

# pnpm
export PNPM_HOME="$HOME/.pnpm"
case ":$PATH:" in
  *":$PNPM_HOME:"*) ;;
  *) export PATH="$PNPM_HOME:$PATH" ;;
esac
# pnpm end

# pnpm completions
source $PNPM_HOME/completion-for-pnpm.zsh
