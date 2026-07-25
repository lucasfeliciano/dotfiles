PLATFORM_PNPM_HOME="${XDG_DATA_HOME:-$HOME/.local/share}/pnpm"
PLATFORM_GHOSTTY_OVERLAY="$DOTFILES_DIR/platforms/ubuntu/config/ghostty.conf"
PLATFORM_ZSH_FRAGMENT="$DOTFILES_DIR/platforms/ubuntu/config/zsh/platform.zsh"

platform_change_login_shell() {
  run sudo chsh -s "$1" "$USER"
  e_note "Log out and back in for the Zsh login-shell change to take effect"
}
