check_packages() {
  local command_name snap_info
  for command_name in zsh git curl wget gpg cc shellcheck jq fzf rg fdfind batcat eza tmux btop tree unzip 7z ghostty; do
    verify_command "$command_name" "run './setup.sh --module packages'"
  done

  if ! command -v snap >/dev/null 2>&1 || ! snap list code >/dev/null 2>&1; then
    verify_fail "VS Code classic Snap is missing; run './setup.sh --module packages'"
    return
  fi
  snap_info="$(snap info code 2>/dev/null || true)"
  if grep -Eq '^confinement:[[:space:]]+classic$' <<< "$snap_info"; then
    verify_pass "VS Code is installed as a classic Snap"
  else
    verify_fail "VS Code Snap is not classic; reinstall with './setup.sh --module packages'"
  fi
}

setup_packages() {
  apt_install_manifest "$DOTFILES_DIR/platforms/ubuntu/packages/base.apt" || return
  snap_install_manifest "$DOTFILES_DIR/platforms/ubuntu/packages/base.snap" || return
  if ! command -v mise >/dev/null 2>&1; then
    run /bin/bash -o pipefail -c 'curl -fsSL https://mise.run | /bin/sh' || return
  else
    e_note "mise is already installed"
  fi
}
