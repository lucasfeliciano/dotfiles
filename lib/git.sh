# Git global configuration.
# Sourced by setup.sh — do not execute directly.

setup_git() {
  if [[ "$DRY_RUN" == "true" ]]; then
    e_dry "prompt for git user.name"
    e_dry "prompt for git user.email"
    e_dry "git config --global pull.rebase true"
    return
  fi

  e_ask "Type the name you would like to display in your git commits: "
  read -r name || true
  if [ -n "$name" ]; then
    git config --global user.name "$name"
  else
    e_warning "name not supplied, skipping.."
  fi

  e_ask "Type your git email: "
  read -r email || true
  if [ -n "$email" ]; then
    git config --global user.email "$email"
  else
    e_warning "email not supplied, skipping.."
  fi

  git config --global pull.rebase true
}
