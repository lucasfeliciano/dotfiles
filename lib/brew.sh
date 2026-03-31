# Homebrew installation and dependency management.
# Sourced by setup.sh — do not execute directly.

setup_brew() {
  if ! command -v brew &>/dev/null; then
    e_header "Installing Homebrew"
    run /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

    if ! grep -qF 'eval "$(/opt/homebrew/bin/brew shellenv)"' ~/.zprofile 2>/dev/null; then
      run tee -a ~/.zprofile <<< 'eval "$(/opt/homebrew/bin/brew shellenv)"'
    fi
    if [[ "$DRY_RUN" != "true" ]]; then
      eval "$(/opt/homebrew/bin/brew shellenv)"
    fi
  else
    e_header "Updating Homebrew"
    run brew update
  fi

  e_header "Installing dependencies from Brewfile"
  run brew bundle --file="$DOTFILES_DIR/Brewfile"
}
