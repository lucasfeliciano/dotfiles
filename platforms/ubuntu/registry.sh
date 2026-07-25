source "$DOTFILES_DIR/platforms/ubuntu/lib/packages.sh"

register_module packages "$DOTFILES_DIR/platforms/ubuntu/modules/packages.sh" setup_packages none none true
register_module zsh "$DOTFILES_DIR/shared/modules/zsh.sh" setup_zsh none preflight_zsh false
register_module eza "$DOTFILES_DIR/shared/modules/eza.sh" setup_eza none none false
register_module mise "$DOTFILES_DIR/shared/modules/mise.sh" setup_mise none preflight_mise false
register_module ghostty "$DOTFILES_DIR/shared/modules/ghostty.sh" setup_ghostty none none false
register_module git "$DOTFILES_DIR/shared/modules/git.sh" setup_git none preflight_git false
register_profile base "$DOTFILES_DIR/platforms/ubuntu/profiles/base.sh"
