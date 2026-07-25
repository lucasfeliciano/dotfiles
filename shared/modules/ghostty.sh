# Ghostty terminal configuration.
# Sourced by setup.sh — do not execute directly.

check_ghostty() {
  verify_command ghostty "run './setup.sh --module packages ghostty'"
  verify_symlink "$DOTFILES_DIR/shared/config/ghostty/config" "$HOME/.config/ghostty/config" "run './setup.sh --module ghostty'"
  verify_symlink "$PLATFORM_GHOSTTY_OVERLAY" "$HOME/.config/ghostty/platform" "run './setup.sh --module ghostty'"
}

setup_ghostty() {
  link_config "$DOTFILES_DIR/shared/config/ghostty/config" "$HOME/.config/ghostty/config"
  link_config "$PLATFORM_GHOSTTY_OVERLAY" "$HOME/.config/ghostty/platform"
}
