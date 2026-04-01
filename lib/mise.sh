# mise (runtime manager) configuration.
# Sourced by setup.sh — do not execute directly.

setup_mise() {
  run mkdir -p ~/.config/mise
  run ln -sf "$DOTFILES_DIR/config/mise/config.toml" ~/.config/mise/config.toml
  run mise trust "$DOTFILES_DIR/config/mise/config.toml"

  run mise use --global node@lts
  run mise use --global pnpm@latest

  run mkdir -p "$HOME/Library/pnpm"
}
