check_networking() {
  local command_name
  for command_name in ip ping dig nc tcpdump traceroute mtr whois; do
    verify_command "$command_name" "run './setup.sh --module networking'"
  done
}

setup_networking() {
  apt_install_manifest "$DOTFILES_DIR/platforms/ubuntu/packages/networking.apt"
}
