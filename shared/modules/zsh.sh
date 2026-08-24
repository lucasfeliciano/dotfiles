# Oh My Zsh, plugins, Starship, and shell config symlinks.
# Sourced by setup.sh — do not execute directly.

retire_powerlevel10k_config() {
  local destination="$HOME/.p10k.zsh"
  local managed_target="$DOTFILES_DIR/shared/config/zsh/.p10k.zsh"

  [[ -L "$destination" ]] || return 0

  if [[ "$(readlink "$destination")" == "$managed_target" ]]; then
    run unlink "$destination"
    e_note "Retired the managed Powerlevel10k configuration at ${destination}"
  else
    e_warning "Leaving ${destination} untouched because it is not the managed Powerlevel10k symlink"
  fi
}

preflight_zsh() {
  local command_name
  for command_name in curl git zsh eza starship; do
    require_command_or_module "$command_name" packages \
      "run './setup.sh --profile base' or include 'packages' in --module" || return
  done
}

check_zsh() {
  verify_command zsh "run './setup.sh --module packages zsh'"
  verify_command eza "run './setup.sh --module packages zsh'"
  verify_command starship "run './setup.sh --module packages zsh'"
  verify_symlink "$DOTFILES_DIR/shared/config/zsh/.zshrc" "$HOME/.zshrc" "run './setup.sh --module zsh'"
  verify_symlink "$DOTFILES_DIR/shared/config/zsh/.aliases" "$HOME/.aliases" "run './setup.sh --module zsh'"
  verify_symlink "$DOTFILES_DIR/shared/config/starship/starship.toml" "$HOME/.config/starship.toml" "run './setup.sh --module zsh'"
  verify_symlink "$PLATFORM_ZSH_FRAGMENT" "$HOME/.config/zsh/platform.zsh" "run './setup.sh --module zsh'"
  if [[ -L "$HOME/.p10k.zsh" && "$(readlink "$HOME/.p10k.zsh")" == "$DOTFILES_DIR/shared/config/zsh/.p10k.zsh" ]]; then
    verify_fail "$HOME/.p10k.zsh still points to the retired managed Powerlevel10k configuration; run './setup.sh --module zsh'"
  else
    verify_pass "the managed Powerlevel10k configuration is retired"
  fi
  if [[ -f "$HOME/.zshrc_private" && ! -L "$HOME/.zshrc_private" ]]; then
    verify_pass "$HOME/.zshrc_private is a local file"
  else
    verify_fail "$HOME/.zshrc_private must be a local file; run './setup.sh --module zsh'"
  fi
}

setup_zsh() {
  local ZSH="$HOME/.oh-my-zsh"
  local ZSH_CUSTOM="$ZSH/custom"
  local zsh_path

  zsh_path="$(command -v zsh)"

  if [ -d "$ZSH" ]; then
    e_warning "Oh My Zsh is already installed. skipping.."
  else
    run env RUNZSH=no CHSH=no /bin/bash -o pipefail -c \
      'curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh | /bin/sh' || return
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

  link_config "$DOTFILES_DIR/shared/config/zsh/.aliases" "$HOME/.aliases"
  link_config "$DOTFILES_DIR/shared/config/zsh/.zshrc" "$HOME/.zshrc"
  link_config "$DOTFILES_DIR/shared/config/starship/starship.toml" "$HOME/.config/starship.toml"
  link_config "$PLATFORM_ZSH_FRAGMENT" "$HOME/.config/zsh/platform.zsh"
  ensure_local_copy "$DOTFILES_DIR/shared/config/zsh/.zshrc_private.template" "$HOME/.zshrc_private"
  retire_powerlevel10k_config

  if [[ "${SHELL:-}" == "$zsh_path" ]]; then
    e_note "Zsh is already the login shell"
  else
    platform_change_login_shell "$zsh_path"
  fi
}
