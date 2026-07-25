LIBVIRT_SYSTEM_VIRSH=(sudo env LC_ALL=C virsh -c qemu:///system)
LIBVIRT_CHECK_VIRSH=(env LC_ALL=C virsh -c qemu:///system)

check_virtualization() {
  local group

  if command -v kvm-ok >/dev/null 2>&1 && kvm-ok >/dev/null 2>&1; then
    verify_pass "KVM acceleration is available"
  else
    verify_fail "KVM acceleration is unavailable; verify firmware virtualization support"
  fi

  for group in libvirt kvm; do
    if id -nG "$USER" | tr ' ' '\n' | grep -qx "$group"; then
      verify_pass "${USER} belongs to ${group}"
    else
      verify_fail "${USER} is not active in ${group}; run './setup.sh --module virtualization' then log out or reboot"
    fi
  done

  if systemctl is-enabled --quiet libvirtd.service && systemctl is-active --quiet libvirtd.service; then
    verify_pass "libvirtd.service is enabled and active"
  else
    verify_fail "libvirtd.service is not enabled and active; run './setup.sh --module virtualization'"
  fi

  if ! command -v virsh >/dev/null 2>&1; then
    verify_fail "virsh is missing; run './setup.sh --module virtualization'"
    return
  fi

  if libvirt_network_is_active default "${LIBVIRT_CHECK_VIRSH[@]}" &&
    libvirt_network_autostarts default "${LIBVIRT_CHECK_VIRSH[@]}" &&
    libvirt_network_is_nat default "${LIBVIRT_CHECK_VIRSH[@]}"; then
    verify_pass "default libvirt network is active, autostarting, and NAT"
  else
    verify_fail "default libvirt NAT network is not ready; run './setup.sh --module virtualization'"
  fi

  if libvirt_network_is_active vm-isolated "${LIBVIRT_CHECK_VIRSH[@]}" &&
    libvirt_network_autostarts vm-isolated "${LIBVIRT_CHECK_VIRSH[@]}" &&
    libvirt_network_matches_isolated_policy vm-isolated "${LIBVIRT_CHECK_VIRSH[@]}"; then
    verify_pass "vm-isolated is active, autostarting, and isolated on 192.168.77.0/24"
  else
    verify_fail "vm-isolated does not match its required state; run './setup.sh --module virtualization'"
  fi
}

setup_virtualization() {
  local group missing_groups=""

  apt_install_manifest "$DOTFILES_DIR/platforms/ubuntu/packages/virtualization.apt" || return

  if [[ "$DRY_RUN" == "true" ]]; then
    e_dry "add ${USER} to missing libvirt/kvm groups"
    e_dry "enable/start libvirtd.service only when needed"
    run "${LIBVIRT_SYSTEM_VIRSH[@]}" net-define /usr/share/libvirt/networks/default.xml || return
    run "${LIBVIRT_SYSTEM_VIRSH[@]}" net-start default || return
    run "${LIBVIRT_SYSTEM_VIRSH[@]}" net-autostart default || return
    run "${LIBVIRT_SYSTEM_VIRSH[@]}" net-define \
      "$DOTFILES_DIR/platforms/ubuntu/config/libvirt/vm-isolated.xml" || return
    run "${LIBVIRT_SYSTEM_VIRSH[@]}" net-start vm-isolated || return
    run "${LIBVIRT_SYSTEM_VIRSH[@]}" net-autostart vm-isolated || return
    return
  fi

  for group in libvirt kvm; do
    if ! id -nG "$USER" | tr ' ' '\n' | grep -qx "$group"; then
      missing_groups="${missing_groups:+${missing_groups},}${group}"
    fi
  done
  if [[ -n "$missing_groups" ]]; then
    run sudo usermod -aG "$missing_groups" "$USER" || return
    e_note "Log out and back in (or reboot) before using libvirt without sudo"
  else
    e_note "${USER} already belongs to libvirt and kvm"
  fi

  systemctl is-enabled --quiet libvirtd.service || run sudo systemctl enable libvirtd.service || return
  systemctl is-active --quiet libvirtd.service || run sudo systemctl start libvirtd.service || return

  if ! libvirt_network_exists default "${LIBVIRT_SYSTEM_VIRSH[@]}"; then
    [[ -f /usr/share/libvirt/networks/default.xml ]] || {
      error "The packaged libvirt default network definition was not found."
      return 1
    }
    run "${LIBVIRT_SYSTEM_VIRSH[@]}" net-define /usr/share/libvirt/networks/default.xml || return
  elif ! libvirt_network_is_nat default "${LIBVIRT_SYSTEM_VIRSH[@]}"; then
    error "Existing default libvirt network is not NAT; refusing to replace it."
    return 1
  fi
  libvirt_ensure_network_started default "${LIBVIRT_SYSTEM_VIRSH[@]}" || return

  if libvirt_network_exists vm-isolated "${LIBVIRT_SYSTEM_VIRSH[@]}"; then
    libvirt_network_matches_isolated_policy vm-isolated "${LIBVIRT_SYSTEM_VIRSH[@]}" || {
      error "Existing vm-isolated network conflicts with 192.168.77.0/24/no-forwarding policy; refusing to replace it."
      return 1
    }
  else
    run "${LIBVIRT_SYSTEM_VIRSH[@]}" net-define \
      "$DOTFILES_DIR/platforms/ubuntu/config/libvirt/vm-isolated.xml" || return
  fi
  libvirt_ensure_network_started vm-isolated "${LIBVIRT_SYSTEM_VIRSH[@]}" || return

  e_note "No VM or guest image was created or downloaded"
}
