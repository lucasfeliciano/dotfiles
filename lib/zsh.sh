# Oh My Zsh, plugins, theme, and shell config symlinks.
# Sourced by setup.sh — do not execute directly.

ZSH_REQUIRED_BINS=(eza)

setup_zsh() {
  for bin in "${ZSH_REQUIRED_BINS[@]}"; do
    if ! command -v "$bin" &>/dev/null; then
      error "$bin is not installed. Run './setup.sh brew' first."
      return 1
    fi
  done

  local ZSH="$HOME/.oh-my-zsh"
  local ZSH_CUSTOM="$ZSH/custom"

  if [ -d "$ZSH" ]; then
    e_warning "Oh My Zsh is already installed. skipping.."
  else
    run env RUNZSH=no CHSH=no sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
  fi

  if [ -d "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting" ]; then
    e_warning "zsh-syntax-highlighting is already installed. skipping.."
  else
    run git clone https://github.com/zsh-users/zsh-syntax-highlighting.git "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting"
  fi

  if [ -d "$ZSH_CUSTOM/plugins/zsh-history-substring-search" ]; then
    e_warning "zsh-history-substring-search is already installed. skipping.."
  else
    run git clone https://github.com/zsh-users/zsh-history-substring-search "$ZSH_CUSTOM/plugins/zsh-history-substring-search"
  fi

  if [ -d "$ZSH_CUSTOM/plugins/zsh-autosuggestions" ]; then
    e_warning "zsh-autosuggestions is already installed. skipping.."
  else
    run git clone https://github.com/zsh-users/zsh-autosuggestions.git "$ZSH_CUSTOM/plugins/zsh-autosuggestions"
  fi

  if [ -d "$ZSH_CUSTOM/plugins/zsh-eza" ]; then
    e_warning "zsh-eza is already installed. skipping.."
  else
    run git clone https://github.com/z-shell/zsh-eza.git "$ZSH_CUSTOM/plugins/zsh-eza"
  fi

  if [ -d "$ZSH_CUSTOM/themes/powerlevel10k" ]; then
    e_warning "powerlevel10k theme is already installed. skipping.."
  else
    run git clone --depth=1 https://github.com/romkatv/powerlevel10k.git "$ZSH_CUSTOM/themes/powerlevel10k"
  fi

  run ln -sf "$DOTFILES_DIR/config/zsh/.aliases" ~/.aliases
  run ln -sf "$DOTFILES_DIR/config/zsh/.zshrc" ~/.zshrc
  run ln -sf "$DOTFILES_DIR/config/zsh/.p10k.zsh" ~/.p10k.zsh

  if [[ -f ~/.zshrc_private || -L ~/.zshrc_private ]]; then
    e_warning "~/.zshrc_private already exists. skipping.."
  else
    run cp "$DOTFILES_DIR/config/zsh/.zshrc_private.template" ~/.zshrc_private
  fi
}
