# Homebrew installation and dependency management.
# Sourced by setup.sh — do not execute directly.

check_packages() {
  if ! command -v brew >/dev/null 2>&1; then
    verify_fail "Homebrew is missing; run './setup.sh --module packages'"
  elif brew bundle check --file="$DOTFILES_DIR/platforms/macos/packages/Brewfile" >/dev/null 2>&1; then
    verify_pass "Homebrew bundle is satisfied"
  else
    verify_fail "Homebrew bundle is incomplete; run './setup.sh --module packages'"
  fi
}

setup_packages() {
  local brew_bin shellenv_line

  if ! command -v brew &>/dev/null; then
    e_header "Installing Homebrew"
    run /bin/bash -o pipefail -c \
      'curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh | /bin/bash' || return

    if [[ -x /opt/homebrew/bin/brew ]]; then
      brew_bin="/opt/homebrew/bin/brew"
    elif [[ -x /usr/local/bin/brew ]]; then
      brew_bin="/usr/local/bin/brew"
    elif [[ "$DRY_RUN" == "true" ]]; then
      brew_bin="/opt/homebrew/bin/brew"
    else
      error "Homebrew installation completed but brew was not found."
      return 1
    fi

    shellenv_line="eval \"\$(${brew_bin} shellenv)\""
    if ! grep -qF "$shellenv_line" "$HOME/.zprofile" 2>/dev/null; then
      if [[ "$DRY_RUN" == "true" ]]; then
        e_dry "append Homebrew shellenv to ${HOME}/.zprofile"
      else
        printf '%s\n' "$shellenv_line" >> "$HOME/.zprofile"
      fi
    fi

    if [[ "$DRY_RUN" != "true" ]]; then
      eval "$("$brew_bin" shellenv)"
    fi
  else
    brew_bin="$(command -v brew)"
    e_header "Updating Homebrew"
    run "$brew_bin" update
  fi

  e_header "Installing dependencies from Brewfile"
  run "$brew_bin" bundle --file="$DOTFILES_DIR/platforms/macos/packages/Brewfile"
}
