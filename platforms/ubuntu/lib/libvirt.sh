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

libvirt_xml_direct_child_tag_has_attributes() {
  local xml="$1" tag_name="$2" tag name attribute value matches
  local depth=0 index root_seen=false found=false
  local -a expected elements
  shift 2
  expected=("$@")

  xml="${xml//$'\n'/ }"
  xml="${xml//$'\r'/ }"
  xml="${xml//$'\t'/ }"
  while [[ "$xml" == *"<"* ]]; do
    xml="${xml#*<}"
    [[ "$xml" == *">"* ]] || return 1
    tag="${xml%%>*}"
    xml="${xml#*>}"
    while [[ "$tag" == *" " ]]; do
      tag="${tag% }"
    done

    case "$tag" in
      '?'*) continue ;;
      '!'*) return 1 ;;
      '/'*)
        name="${tag#/}"
        name="${name%% *}"
        ((depth > 0)) || return 1
        [[ "${elements[$((depth - 1))]}" == "$name" ]] || return 1
        depth=$((depth - 1))
        continue
        ;;
    esac

    name="${tag%% *}"
    name="${name%/}"
    if [[ "$root_seen" == "false" ]]; then
      [[ "$name" == "network" && "$depth" -eq 0 ]] || return 1
      root_seen=true
    elif ((depth == 0)); then
      return 1
    elif [[ "$depth" -eq 1 && "$name" == "$tag_name" ]]; then
      matches=true
      for ((index = 0; index < ${#expected[@]}; index += 2)); do
        attribute="${expected[$index]}"
        value="${expected[$((index + 1))]}"
        if [[ " $tag" != *" ${attribute}='${value}'"* ]] &&
          [[ " $tag" != *" ${attribute}=\"${value}\""* ]]; then
          matches=false
          break
        fi
      done
      [[ "$matches" == "true" ]] && found=true
    fi

    if [[ "$tag" != */ ]]; then
      elements[$depth]="$name"
      depth=$((depth + 1))
    fi
  done
  [[ "$root_seen" == "true" && "$found" == "true" && "$depth" -eq 0 ]]
}

libvirt_network_is_nat() {
  local xml
  xml="$(libvirt_network_xml "$@")" || return 1
  libvirt_xml_direct_child_tag_has_attributes "$xml" forward mode nat
}

libvirt_network_matches_isolated_policy() {
  local network="$1" xml
  shift
  xml="$(libvirt_network_xml "$network" "$@")" || return 1
  [[ "$xml" != *"<forward"* ]] || return 1
  libvirt_xml_direct_child_tag_has_attributes "$xml" ip \
    address 192.168.77.1 \
    netmask 255.255.255.0
}

libvirt_ensure_network_started() {
  local network="$1"
  shift
  libvirt_network_is_active "$network" "$@" || run "$@" net-start "$network" || return
  libvirt_network_autostarts "$network" "$@" || run "$@" net-autostart "$network" || return
}
