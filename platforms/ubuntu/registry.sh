source "$DOTFILES_DIR/platforms/ubuntu/lib/packages.sh"
source "$DOTFILES_DIR/platforms/ubuntu/lib/libvirt.sh"

register_module packages "$DOTFILES_DIR/platforms/ubuntu/modules/packages.sh" setup_packages check_packages none true
register_module zsh "$DOTFILES_DIR/shared/modules/zsh.sh" setup_zsh check_zsh preflight_zsh false
register_module eza "$DOTFILES_DIR/shared/modules/eza.sh" setup_eza check_eza none false
register_module mise "$DOTFILES_DIR/shared/modules/mise.sh" setup_mise check_mise preflight_mise false
register_module ghostty "$DOTFILES_DIR/shared/modules/ghostty.sh" setup_ghostty check_ghostty none false
register_module git "$DOTFILES_DIR/shared/modules/git.sh" setup_git check_git preflight_git false
register_module networking "$DOTFILES_DIR/platforms/ubuntu/modules/networking.sh" setup_networking check_networking none true
register_module virtualization "$DOTFILES_DIR/platforms/ubuntu/modules/virtualization.sh" setup_virtualization check_virtualization none true
register_profile base "$DOTFILES_DIR/platforms/ubuntu/profiles/base.sh"
register_profile networking "$DOTFILES_DIR/platforms/ubuntu/profiles/networking.sh"
register_profile virtualization "$DOTFILES_DIR/platforms/ubuntu/profiles/virtualization.sh"
