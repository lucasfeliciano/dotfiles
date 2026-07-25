# eza configuration and theme.
# Sourced by setup.sh — do not execute directly.

check_eza() {
  verify_command eza "run './setup.sh --module packages eza'"
  verify_symlink "$DOTFILES_DIR/shared/config/eza/theme.yml" "$HOME/.config/eza/theme.yml" "run './setup.sh --module eza'"
}

setup_eza() {
  link_config "$DOTFILES_DIR/shared/config/eza/theme.yml" "$HOME/.config/eza/theme.yml"
}
