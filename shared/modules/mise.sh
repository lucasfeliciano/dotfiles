# mise (runtime manager) configuration.
# Sourced by setup.sh — do not execute directly.

preflight_mise() {
  require_command_or_module mise packages \
    "run './setup.sh --profile base' or './setup.sh --module packages mise'"
}

verify_mise_tool() {
  local tool="$1" shell_path shell_real
  shell_path="$(command -v "$tool" 2>/dev/null || true)"
  shell_real="$(realpath "$shell_path" 2>/dev/null || true)"
  if [[ -n "$shell_path" ]] &&
    { [[ "$shell_real" == *"/mise/installs/"* ]] || [[ "$shell_path" == *"/mise/shims/"* ]]; }; then
    verify_pass "${tool} is provided by mise"
  else
    verify_fail "${tool} is not provided by mise; run './setup.sh --module packages mise'"
  fi
}

check_mise() {
  local tool
  if ! command -v mise >/dev/null 2>&1; then
    verify_fail "mise is missing; run './setup.sh --module packages mise'"
    return
  fi

  verify_symlink "$DOTFILES_DIR/shared/config/mise/config.toml" "$HOME/.config/mise/config.toml" \
    "run './setup.sh --module mise'"
  verify_symlink "$DOTFILES_DIR/shared/config/uv/uv.toml" "$HOME/.config/uv/uv.toml" \
    "run './setup.sh --module mise'"
  [[ -d "$PLATFORM_PNPM_HOME" ]] && verify_pass "PNPM home exists at ${PLATFORM_PNPM_HOME}" ||
    verify_fail "PNPM home is missing; run './setup.sh --module mise'"

  for tool in node python pnpm uv; do
    verify_mise_tool "$tool"
  done
}

setup_mise() {
  link_config "$DOTFILES_DIR/shared/config/mise/config.toml" "$HOME/.config/mise/config.toml"
  link_config "$DOTFILES_DIR/shared/config/uv/uv.toml" "$HOME/.config/uv/uv.toml"
  run mkdir -p "$PLATFORM_PNPM_HOME"
  run mise trust "$DOTFILES_DIR/shared/config/mise/config.toml"
  run mise install --yes
}
