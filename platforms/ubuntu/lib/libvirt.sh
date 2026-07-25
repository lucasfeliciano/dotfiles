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

libvirt_xml_tag_attribute_equals() {
  local tag="$1" requested="${2:-}" expected="${3:-}"
  local name attributes attribute quote value found=false seen_attributes="|"

  name="${tag%% *}"
  name="${name%/}"
  attributes="${tag#"$name"}"
  while [[ "$attributes" == *" " ]]; do
    attributes="${attributes% }"
  done
  if [[ "$attributes" == */ ]]; then
    attributes="${attributes%/}"
  fi

  while [[ -n "$attributes" ]]; do
    [[ "$attributes" == " "* ]] || return 1
    while [[ "$attributes" == " "* ]]; do
      attributes="${attributes# }"
    done
    [[ -n "$attributes" ]] || break
    [[ "$attributes" == *=* ]] || return 1
    attribute="${attributes%%=*}"
    while [[ "$attribute" == *" " ]]; do
      attribute="${attribute% }"
    done
    [[ "$attribute" =~ ^[a-zA-Z_:][a-zA-Z0-9_.:-]*$ ]] || return 1
    [[ "$seen_attributes" != *"|${attribute}|"* ]] || return 1
    seen_attributes="${seen_attributes}${attribute}|"

    attributes="${attributes#*=}"
    while [[ "$attributes" == " "* ]]; do
      attributes="${attributes# }"
    done
    quote="${attributes:0:1}"
    [[ "$quote" == "'" || "$quote" == '"' ]] || return 1
    attributes="${attributes:1}"
    [[ "$attributes" == *"$quote"* ]] || return 1
    value="${attributes%%"$quote"*}"
    attributes="${attributes#*"$quote"}"

    if [[ -n "$requested" && "$attribute" == "$requested" ]]; then
      [[ "$value" == "$expected" ]] || return 1
      found=true
    fi
  done

  [[ -z "$requested" || "$found" == "true" ]]
}

libvirt_xml_direct_child_tag_has_attributes() {
  local xml="$1" tag_name="$2" tag raw_tag name attribute value matches
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
    raw_tag="$tag"
    while [[ "$tag" == *" " ]]; do
      tag="${tag% }"
    done

    case "$tag" in
      '?'*)
        [[ "$raw_tag" == *\? ]] || return 1
        continue
        ;;
      '!'*) return 1 ;;
      '/'*)
        name="${tag#/}"
        name="${name%% *}"
        [[ "$tag" == "/$name" ]] || return 1
        ((depth > 0)) || return 1
        [[ "${elements[$((depth - 1))]}" == "$name" ]] || return 1
        depth=$((depth - 1))
        continue
        ;;
    esac

    name="${tag%% *}"
    name="${name%/}"
    [[ "$name" =~ ^[a-zA-Z_:][a-zA-Z0-9_.:-]*$ ]] || return 1
    libvirt_xml_tag_attribute_equals "$tag" || return 1
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
        if ! libvirt_xml_tag_attribute_equals "$tag" "$attribute" "$value"; then
          matches=false
          break
        fi
      done
      [[ "$matches" == "true" ]] && found=true
    fi

    if [[ "$tag" != */ ]]; then
      elements[depth]="$name"
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

libvirt_xml_matches_isolated_policy() {
  local xml="$1" leading tag raw_tag name matches
  local depth=0 root_seen=false ip_count=0 matching_ip_count=0
  local dhcp_count=0 range_count=0 matching_range_count=0
  local -a elements

  xml="${xml//$'\n'/ }"
  xml="${xml//$'\r'/ }"
  xml="${xml//$'\t'/ }"
  while [[ "$xml" == *"<"* ]]; do
    leading="${xml%%<*}"
    if ((depth == 0)) && [[ ! "$leading" =~ ^[[:space:]]*$ ]]; then
      return 1
    fi
    xml="${xml#*<}"
    [[ "$xml" == *">"* ]] || return 1
    tag="${xml%%>*}"
    xml="${xml#*>}"
    raw_tag="$tag"
    while [[ "$tag" == *" " ]]; do
      tag="${tag% }"
    done

    case "$tag" in
      '?'*)
        [[ "$raw_tag" == *\? ]] || return 1
        [[ "$root_seen" == "false" && "$depth" -eq 0 ]] || return 1
        continue
        ;;
      '!'*) return 1 ;;
      '/'*)
        name="${tag#/}"
        name="${name%% *}"
        [[ "$tag" == "/$name" ]] || return 1
        ((depth > 0)) || return 1
        [[ "${elements[$((depth - 1))]}" == "$name" ]] || return 1
        depth=$((depth - 1))
        continue
        ;;
    esac

    name="${tag%% *}"
    name="${name%/}"
    [[ "$name" =~ ^[a-zA-Z_:][a-zA-Z0-9_.:-]*$ ]] || return 1
    libvirt_xml_tag_attribute_equals "$tag" || return 1
    if [[ "$root_seen" == "false" ]]; then
      [[ "$name" == "network" && "$depth" -eq 0 ]] || return 1
      root_seen=true
    elif ((depth == 0)); then
      return 1
    elif [[ "$depth" -eq 1 ]]; then
      if [[ "$name" == "forward" ]]; then
        return 1
      fi
      if [[ "$name" == "ip" ]]; then
        ip_count=$((ip_count + 1))
        matches=true
        if ! libvirt_xml_tag_attribute_equals "$tag" address 192.168.77.1; then
          matches=false
        fi
        if ! libvirt_xml_tag_attribute_equals "$tag" netmask 255.255.255.0; then
          matches=false
        fi
        [[ "$matches" == "true" ]] && matching_ip_count=$((matching_ip_count + 1))
      fi
    elif [[ "$depth" -eq 2 && "$name" == "dhcp" && "${elements[1]}" == "ip" ]]; then
      dhcp_count=$((dhcp_count + 1))
    elif [[ "$depth" -eq 3 && "$name" == "range" &&
      "${elements[1]}" == "ip" && "${elements[2]}" == "dhcp" ]]; then
      range_count=$((range_count + 1))
      matches=true
      if ! libvirt_xml_tag_attribute_equals "$tag" start 192.168.77.100; then
        matches=false
      fi
      if ! libvirt_xml_tag_attribute_equals "$tag" end 192.168.77.254; then
        matches=false
      fi
      [[ "$matches" == "true" ]] && matching_range_count=$((matching_range_count + 1))
    fi

    if [[ "$tag" != */ ]]; then
      elements[depth]="$name"
      depth=$((depth + 1))
    fi
  done

  [[ "$xml" =~ ^[[:space:]]*$ ]] || return 1
  [[ "$root_seen" == "true" && "$depth" -eq 0 ]] || return 1
  [[ "$ip_count" -eq 1 && "$matching_ip_count" -eq 1 ]] || return 1
  [[ "$dhcp_count" -eq 1 ]] || return 1
  [[ "$range_count" -eq 1 && "$matching_range_count" -eq 1 ]]
}

libvirt_network_matches_isolated_policy() {
  local network="$1" xml
  shift
  xml="$(libvirt_network_xml "$network" "$@")" || return 1
  libvirt_xml_matches_isolated_policy "$xml"
}

libvirt_ensure_network_started() {
  local network="$1"
  shift
  libvirt_network_is_active "$network" "$@" || run "$@" net-start "$network" || return
  libvirt_network_autostarts "$network" "$@" || run "$@" net-autostart "$network" || return
}
