# Sourced adapter outputs consumed by shared modules.
# shellcheck disable=SC2034
PLATFORM_PNPM_HOME="$HOME/Library/pnpm"
# shellcheck disable=SC2034
PLATFORM_GHOSTTY_OVERLAY="$DOTFILES_DIR/platforms/macos/config/ghostty.conf"
# shellcheck disable=SC2034
PLATFORM_ZSH_FRAGMENT="$DOTFILES_DIR/platforms/macos/config/zsh/platform.zsh"

platform_change_login_shell() {
  run chsh -s "$1"
}
