# mise (runtime manager) configuration.
# Sourced by setup.sh — do not execute directly.

preflight_mise() {
  require_command_or_module mise packages \
    "run './setup.sh --profile base' or './setup.sh --module packages mise'"
}

setup_mise() {
  link_config "$DOTFILES_DIR/shared/config/mise/config.toml" "$HOME/.config/mise/config.toml"
  link_config "$DOTFILES_DIR/shared/config/uv/uv.toml" "$HOME/.config/uv/uv.toml"
  run mkdir -p "$PLATFORM_PNPM_HOME"
  run mise trust "$DOTFILES_DIR/shared/config/mise/config.toml"
  run mise install --yes
}
