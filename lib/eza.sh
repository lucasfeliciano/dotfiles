# eza configuration and theme.
# Sourced by setup.sh — do not execute directly.

setup_eza() {
  run mkdir -p ~/.config/eza
  run ln -sf "$DOTFILES_DIR/config/eza/theme.yml" ~/.config/eza/theme.yml
}
