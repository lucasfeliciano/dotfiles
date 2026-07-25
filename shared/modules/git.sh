# Git global configuration.
# Sourced by setup.sh — do not execute directly.

check_git() {
  local value
  verify_command git "run './setup.sh --module packages git'"

  value="$(git config --global --get user.name 2>/dev/null || true)"
  if [[ -n "$value" ]]; then
    verify_pass "Git user.name is configured"
  else
    verify_fail "Git user.name is missing; run './setup.sh --module git'"
  fi

  value="$(git config --global --get user.email 2>/dev/null || true)"
  if [[ -n "$value" ]]; then
    verify_pass "Git user.email is configured"
  else
    verify_fail "Git user.email is missing; run './setup.sh --module git'"
  fi

  value="$(git config --global --get pull.rebase 2>/dev/null || true)"
  if [[ "$value" == "true" ]]; then
    verify_pass "Git pull.rebase is true"
  else
    verify_fail "Git pull.rebase is not true; run './setup.sh --module git'"
  fi
}

setup_git() {
  local name email pull_rebase

  name="$(git config --global --get user.name 2>/dev/null || true)"
  if [[ -z "$name" ]]; then
    if [[ "$DRY_RUN" == "true" ]]; then
      e_dry "prompt for missing git user.name"
    else
      e_ask "Type the name you would like to display in your git commits: "
      read -r name || true
      if [[ -n "$name" ]]; then
        run git config --global user.name "$name"
      else
        e_warning "name not supplied, skipping"
      fi
    fi
  fi

  email="$(git config --global --get user.email 2>/dev/null || true)"
  if [[ -z "$email" ]]; then
    if [[ "$DRY_RUN" == "true" ]]; then
      e_dry "prompt for missing git user.email"
    else
      e_ask "Type your git email: "
      read -r email || true
      if [[ -n "$email" ]]; then
        run git config --global user.email "$email"
      else
        e_warning "email not supplied, skipping"
      fi
    fi
  fi

  pull_rebase="$(git config --global --get pull.rebase 2>/dev/null || true)"
  if [[ "$pull_rebase" != "true" ]]; then
    run git config --global pull.rebase true
  else
    e_note "Git pull.rebase is already true"
  fi
}

preflight_git() {
  require_command_or_module git packages \
    "run './setup.sh --profile base' or './setup.sh --module packages git'"
}
