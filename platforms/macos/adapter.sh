PLATFORM_PNPM_HOME="$HOME/Library/pnpm"
PLATFORM_GHOSTTY_OVERLAY="$DOTFILES_DIR/platforms/macos/config/ghostty.conf"
PLATFORM_ZSH_FRAGMENT="$DOTFILES_DIR/platforms/macos/config/zsh/platform.zsh"

platform_change_login_shell() {
  run chsh -s "$1"
}
