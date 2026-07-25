register_module packages "$DOTFILES_DIR/platforms/macos/modules/packages.sh" setup_packages check_packages none false
register_module zsh "$DOTFILES_DIR/shared/modules/zsh.sh" setup_zsh check_zsh preflight_zsh false
register_module eza "$DOTFILES_DIR/shared/modules/eza.sh" setup_eza check_eza none false
register_module mise "$DOTFILES_DIR/shared/modules/mise.sh" setup_mise check_mise preflight_mise false
register_module ghostty "$DOTFILES_DIR/shared/modules/ghostty.sh" setup_ghostty check_ghostty none false
register_module git "$DOTFILES_DIR/shared/modules/git.sh" setup_git check_git preflight_git false
register_module system "$DOTFILES_DIR/platforms/macos/modules/system.sh" setup_system none none false
register_profile base "$DOTFILES_DIR/platforms/macos/profiles/base.sh"
