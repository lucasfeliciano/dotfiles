# Oh My Zsh, plugins, theme, and shell config symlinks.
# Sourced by setup.sh — do not execute directly.

setup_zsh() {
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

  if [ -d "$ZSH_CUSTOM/themes/powerlevel10k" ]; then
    e_warning "powerlevel10k theme is already installed. skipping.."
  else
    run git clone --depth=1 https://github.com/romkatv/powerlevel10k.git "$ZSH_CUSTOM/themes/powerlevel10k"
  fi

  run ln -sf "$DOTFILES_DIR/config/zsh/.aliases" ~/.aliases
  run ln -sf "$DOTFILES_DIR/config/zsh/.zshrc" ~/.zshrc
  run ln -sf "$DOTFILES_DIR/config/zsh/.p10k.zsh" ~/.p10k.zsh

  if [[ ! -f ~/.zshrc_private ]]; then
    run cp "$DOTFILES_DIR/config/zsh/.zshrc_private.template" ~/.zshrc_private
  else
    e_warning "~/.zshrc_private already exists. skipping.."
  fi
}
