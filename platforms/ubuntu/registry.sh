source "$DOTFILES_DIR/platforms/ubuntu/lib/packages.sh"
source "$DOTFILES_DIR/platforms/ubuntu/lib/libvirt.sh"

register_module packages "$DOTFILES_DIR/platforms/ubuntu/modules/packages.sh" setup_packages none none true
register_module zsh "$DOTFILES_DIR/shared/modules/zsh.sh" setup_zsh none preflight_zsh false
register_module eza "$DOTFILES_DIR/shared/modules/eza.sh" setup_eza none none false
register_module mise "$DOTFILES_DIR/shared/modules/mise.sh" setup_mise none preflight_mise false
register_module ghostty "$DOTFILES_DIR/shared/modules/ghostty.sh" setup_ghostty none none false
register_module git "$DOTFILES_DIR/shared/modules/git.sh" setup_git none preflight_git false
register_module networking "$DOTFILES_DIR/platforms/ubuntu/modules/networking.sh" setup_networking none none true
register_module virtualization "$DOTFILES_DIR/platforms/ubuntu/modules/virtualization.sh" setup_virtualization none none true
register_profile base "$DOTFILES_DIR/platforms/ubuntu/profiles/base.sh"
register_profile networking "$DOTFILES_DIR/platforms/ubuntu/profiles/networking.sh"
register_profile virtualization "$DOTFILES_DIR/platforms/ubuntu/profiles/virtualization.sh"
