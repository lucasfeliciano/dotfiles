# Ghostty terminal configuration.
# Sourced by setup.sh — do not execute directly.

setup_ghostty() {
  run mkdir -p ~/.config/ghostty

  run ln -sf "$DOTFILES_DIR/config/ghostty/config" ~/.config/ghostty/config
  run ln -sf "$DOTFILES_DIR/config/ghostty/themes" ~/.config/ghostty/themes
}
