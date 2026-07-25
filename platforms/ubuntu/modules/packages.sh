setup_packages() {
  apt_install_manifest "$DOTFILES_DIR/platforms/ubuntu/packages/base.apt" || return
  snap_install_manifest "$DOTFILES_DIR/platforms/ubuntu/packages/base.snap" || return
  if ! command -v mise >/dev/null 2>&1; then
    run /bin/sh -c 'curl -fsSL https://mise.run | sh' || return
  else
    e_note "mise is already installed"
  fi
}
