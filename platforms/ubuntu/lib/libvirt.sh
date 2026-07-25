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

libvirt_xml_tag_has_attributes() {
  local xml="$1" tag_name="$2" attributes attribute value matches
  local index
  local -a expected
  shift 2
  expected=("$@")

  xml="${xml//$'\n'/ }"
  xml="${xml//$'\r'/ }"
  xml="${xml//$'\t'/ }"
  while [[ "$xml" == *"<${tag_name} "* ]]; do
    attributes="${xml#*"<${tag_name} "}"
    [[ "$attributes" == *">"* ]] || return 1
    xml="${attributes#*>}"
    attributes="${attributes%%>*}"
    matches=true

    for ((index = 0; index < ${#expected[@]}; index += 2)); do
      attribute="${expected[$index]}"
      value="${expected[$((index + 1))]}"
      if [[ " $attributes" != *" ${attribute}='${value}'"* ]] &&
        [[ " $attributes" != *" ${attribute}=\"${value}\""* ]]; then
        matches=false
        break
      fi
    done
    [[ "$matches" == "true" ]] && return 0
  done
  return 1
}

libvirt_network_is_nat() {
  local xml
  xml="$(libvirt_network_xml "$@")" || return 1
  libvirt_xml_tag_has_attributes "$xml" forward mode nat
}

libvirt_network_matches_isolated_policy() {
  local network="$1" xml
  shift
  xml="$(libvirt_network_xml "$network" "$@")" || return 1
  [[ "$xml" != *"<forward"* ]] || return 1
  libvirt_xml_tag_has_attributes "$xml" ip \
    address 192.168.77.1 \
    netmask 255.255.255.0
}

libvirt_ensure_network_started() {
  local network="$1"
  shift
  libvirt_network_is_active "$network" "$@" || run "$@" net-start "$network"
  libvirt_network_autostarts "$network" "$@" || run "$@" net-autostart "$network"
}
