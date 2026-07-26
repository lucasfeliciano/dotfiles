# Sourced adapter outputs consumed by shared modules.
# User-local executables installed outside APT, including mise.
case ":$PATH:" in
  *":$HOME/.local/bin:"*) ;;
  *) export PATH="$HOME/.local/bin:$PATH" ;;
esac

# shellcheck disable=SC2034
PLATFORM_PNPM_HOME="${XDG_DATA_HOME:-$HOME/.local/share}/pnpm"
# shellcheck disable=SC2034
PLATFORM_GHOSTTY_OVERLAY="$DOTFILES_DIR/platforms/ubuntu/config/ghostty.conf"
# shellcheck disable=SC2034
PLATFORM_ZSH_FRAGMENT="$DOTFILES_DIR/platforms/ubuntu/config/zsh/platform.zsh"

platform_change_login_shell() {
  run sudo chsh -s "$1" "$USER"
  e_note "Log out and back in for the Zsh login-shell change to take effect"
}
