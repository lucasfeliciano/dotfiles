setup_packages() {
  apt_install_manifest "$DOTFILES_DIR/platforms/ubuntu/packages/base.apt"
  snap_install_manifest "$DOTFILES_DIR/platforms/ubuntu/packages/base.snap"
  if ! command -v mise >/dev/null 2>&1; then
    run /bin/sh -c 'curl -fsSL https://mise.run | sh'
  else
    e_note "mise is already installed"
  fi
}
