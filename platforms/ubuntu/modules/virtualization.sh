LIBVIRT_SYSTEM_VIRSH=(sudo env LC_ALL=C virsh -c qemu:///system)

setup_virtualization() {
  local group missing_groups=""

  apt_install_manifest "$DOTFILES_DIR/platforms/ubuntu/packages/virtualization.apt"

  if [[ "$DRY_RUN" == "true" ]]; then
    e_dry "add ${USER} to missing libvirt/kvm groups"
    e_dry "enable/start libvirtd.service only when needed"
    run "${LIBVIRT_SYSTEM_VIRSH[@]}" net-define /usr/share/libvirt/networks/default.xml
    run "${LIBVIRT_SYSTEM_VIRSH[@]}" net-start default
    run "${LIBVIRT_SYSTEM_VIRSH[@]}" net-autostart default
    run "${LIBVIRT_SYSTEM_VIRSH[@]}" net-define \
      "$DOTFILES_DIR/platforms/ubuntu/config/libvirt/vm-isolated.xml"
    run "${LIBVIRT_SYSTEM_VIRSH[@]}" net-start vm-isolated
    run "${LIBVIRT_SYSTEM_VIRSH[@]}" net-autostart vm-isolated
    return
  fi

  for group in libvirt kvm; do
    if ! id -nG "$USER" | tr ' ' '\n' | grep -qx "$group"; then
      missing_groups="${missing_groups:+${missing_groups},}${group}"
    fi
  done
  if [[ -n "$missing_groups" ]]; then
    run sudo usermod -aG "$missing_groups" "$USER"
    e_note "Log out and back in (or reboot) before using libvirt without sudo"
  else
    e_note "${USER} already belongs to libvirt and kvm"
  fi

  systemctl is-enabled --quiet libvirtd.service || run sudo systemctl enable libvirtd.service
  systemctl is-active --quiet libvirtd.service || run sudo systemctl start libvirtd.service

  if ! libvirt_network_exists default "${LIBVIRT_SYSTEM_VIRSH[@]}"; then
    [[ -f /usr/share/libvirt/networks/default.xml ]] || {
      error "The packaged libvirt default network definition was not found."
      return 1
    }
    run "${LIBVIRT_SYSTEM_VIRSH[@]}" net-define /usr/share/libvirt/networks/default.xml
  elif ! libvirt_network_is_nat default "${LIBVIRT_SYSTEM_VIRSH[@]}"; then
    error "Existing default libvirt network is not NAT; refusing to replace it."
    return 1
  fi
  libvirt_ensure_network_started default "${LIBVIRT_SYSTEM_VIRSH[@]}"

  if libvirt_network_exists vm-isolated "${LIBVIRT_SYSTEM_VIRSH[@]}"; then
    libvirt_network_matches_isolated_policy vm-isolated "${LIBVIRT_SYSTEM_VIRSH[@]}" || {
      error "Existing vm-isolated network conflicts with 192.168.77.0/24/no-forwarding policy; refusing to replace it."
      return 1
    }
  else
    run "${LIBVIRT_SYSTEM_VIRSH[@]}" net-define \
      "$DOTFILES_DIR/platforms/ubuntu/config/libvirt/vm-isolated.xml"
  fi
  libvirt_ensure_network_started vm-isolated "${LIBVIRT_SYSTEM_VIRSH[@]}"

  e_note "No VM or guest image was created or downloaded"
}
