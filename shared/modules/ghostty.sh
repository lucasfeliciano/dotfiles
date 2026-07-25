# Ghostty terminal configuration.
# Sourced by setup.sh — do not execute directly.

setup_ghostty() {
  link_config "$DOTFILES_DIR/shared/config/ghostty/config" "$HOME/.config/ghostty/config"
  link_config "$PLATFORM_GHOSTTY_OVERLAY" "$HOME/.config/ghostty/platform"
}
