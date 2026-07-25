APT_METADATA_REFRESHED=false

read_apt_manifest() {
  local manifest="$1" line
  MANIFEST_PACKAGES=()
  while IFS= read -r line || [[ -n "$line" ]]; do
    [[ "$line" =~ ^[[:space:]]*$ ]] && continue
    [[ "$line" =~ ^[[:space:]]*# ]] && continue
    [[ "$line" =~ ^[a-z0-9][a-z0-9+.-]*$ ]] || {
      error "Invalid APT package entry in ${manifest}: ${line}"
      return 1
    }
    MANIFEST_PACKAGES+=("$line")
  done < "$manifest"
  ((${#MANIFEST_PACKAGES[@]} > 0)) || {
    error "APT manifest is empty: ${manifest}"
    return 1
  }
}

apt_refresh_once() {
  if [[ "$APT_METADATA_REFRESHED" != "true" ]]; then
    run sudo apt-get update || return
    APT_METADATA_REFRESHED=true
  fi
}

apt_install_manifest() {
  local manifest="$1" package
  local -a missing=()
  read_apt_manifest "$manifest" || return

  if [[ "$DRY_RUN" == "true" ]]; then
    apt_refresh_once || return
    run sudo apt-get install -y "${MANIFEST_PACKAGES[@]}" || return
    return
  fi

  for package in "${MANIFEST_PACKAGES[@]}"; do
    dpkg-query -W -f='${Status}' "$package" 2>/dev/null | grep -qx 'install ok installed' || missing+=("$package")
  done
  ((${#missing[@]} == 0)) && {
    e_note "APT packages from ${manifest} are already installed"
    return
  }
  apt_refresh_once || return
  run sudo apt-get install -y "${missing[@]}" || return
}

read_snap_manifest() {
  local manifest="$1" line package confinement extra
  SNAP_PACKAGES=()
  SNAP_CONFINEMENTS=()
  while IFS= read -r line || [[ -n "$line" ]]; do
    [[ "$line" =~ ^[[:space:]]*$ ]] && continue
    [[ "$line" =~ ^[[:space:]]*# ]] && continue
    package=""; confinement=""; extra=""
    read -r package confinement extra <<EOF
$line
EOF
    [[ "$package" =~ ^[a-z0-9][a-z0-9+.-]*$ ]] &&
      [[ -z "$extra" ]] &&
      { [[ -z "$confinement" ]] || [[ "$confinement" == "--classic" ]]; } || {
        error "Invalid Snap manifest entry in ${manifest}: ${line}"
        return 1
      }
    SNAP_PACKAGES+=("$package")
    SNAP_CONFINEMENTS+=("$confinement")
  done < "$manifest"
  ((${#SNAP_PACKAGES[@]} > 0)) || {
    error "Snap manifest is empty: ${manifest}"
    return 1
  }
}

snap_install_manifest() {
  local manifest="$1" package confinement index=0
  read_snap_manifest "$manifest" || return
  while ((index < ${#SNAP_PACKAGES[@]})); do
    package="${SNAP_PACKAGES[$index]}"
    confinement="${SNAP_CONFINEMENTS[$index]}"
    if [[ "$DRY_RUN" != "true" ]] && snap list "$package" >/dev/null 2>&1; then
      e_note "Snap ${package} is already installed"
    elif [[ -n "$confinement" ]]; then
      run sudo snap install "$package" "$confinement" || return
    else
      run sudo snap install "$package" || return
    fi
    index=$((index + 1))
  done
}
