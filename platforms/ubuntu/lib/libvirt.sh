libvirt_network_info() {
  local network="$1"
  shift
  "$@" net-info "$network" 2>/dev/null
}

libvirt_network_xml() {
  local network="$1"
  shift
  "$@" net-dumpxml "$network" 2>/dev/null
}

libvirt_network_exists() {
  libvirt_network_info "$@" >/dev/null
}

libvirt_network_is_active() {
  libvirt_network_info "$@" | grep -Eq '^Active:[[:space:]]+yes$'
}

libvirt_network_autostarts() {
  libvirt_network_info "$@" | grep -Eq '^Autostart:[[:space:]]+yes$'
}

libvirt_network_is_nat() {
  local xml
  xml="$(libvirt_network_xml "$@")" || return 1
  [[ "$xml" == *"<forward"* ]] &&
    { [[ "$xml" == *"mode='nat'"* ]] || [[ "$xml" == *'mode="nat"'* ]]; }
}

libvirt_network_matches_isolated_policy() {
  local network="$1" xml
  shift
  xml="$(libvirt_network_xml "$network" "$@")" || return 1
  { [[ "$xml" == *"address='192.168.77.1'"* ]] || [[ "$xml" == *'address="192.168.77.1"'* ]]; } || return 1
  { [[ "$xml" == *"netmask='255.255.255.0'"* ]] || [[ "$xml" == *'netmask="255.255.255.0"'* ]]; } || return 1
  [[ "$xml" != *"<forward"* ]]
}

libvirt_ensure_network_started() {
  local network="$1"
  shift
  libvirt_network_is_active "$network" "$@" || run "$@" net-start "$network"
  libvirt_network_autostarts "$network" "$@" || run "$@" net-autostart "$network"
}
