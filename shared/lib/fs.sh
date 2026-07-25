# Filesystem helpers for safely installing managed configuration.
# Sourced by setup.sh — do not execute directly.

BACKUP_DIR="${BACKUP_DIR:-}"

backup_conflict() {
  local destination="$1"
  local relative_destination backup_destination

  if [[ -z "$BACKUP_DIR" ]]; then
    BACKUP_DIR="${DOTFILES_BACKUP_ROOT:-$HOME/.dotfiles-backup}/$(date '+%Y%m%d-%H%M%S')-$$"
  fi

  relative_destination="${destination#"$HOME"/}"
  backup_destination="$BACKUP_DIR/$relative_destination"

  run mkdir -p "$(dirname "$backup_destination")"
  run mv "$destination" "$backup_destination"
  e_warning "Backed up ${destination} to ${backup_destination}"
}

link_config() {
  local source_path="$1"
  local destination="$2"
  local resolved_destination resolved_source

  if [[ ! -e "$source_path" ]]; then
    error "Cannot link missing configuration: ${source_path}"
    return 1
  fi

  if [[ -L "$destination" ]]; then
    resolved_destination="$(realpath "$destination" 2>/dev/null || true)"
    resolved_source="$(realpath "$source_path")"
    if [[ "$resolved_destination" == "$resolved_source" ]]; then
      e_note "${destination} already points to the managed configuration"
      return
    fi
  fi

  if [[ -e "$destination" || -L "$destination" ]]; then
    backup_conflict "$destination"
  fi

  run mkdir -p "$(dirname "$destination")"
  run ln -s "$source_path" "$destination"
}

ensure_local_copy() {
  local source_path="$1"
  local destination="$2"

  if [[ -f "$destination" && ! -L "$destination" ]]; then
    e_note "${destination} is local and will be left untouched"
    return
  fi

  if [[ -e "$destination" || -L "$destination" ]]; then
    backup_conflict "$destination"
  fi

  run mkdir -p "$(dirname "$destination")"
  run cp "$source_path" "$destination"
}

install_root_text() {
  local destination="$1"
  local mode="$2"
  local content="$3"

  if [[ "$DRY_RUN" == "true" ]]; then
    e_dry "install managed content at ${destination} (mode ${mode})"
    return
  fi

  if printf '%s' "$content" | sudo cmp -s - "$destination" 2>/dev/null; then
    e_note "${destination} already has the requested content"
    return
  fi

  printf '%s' "$content" | sudo tee "$destination" >/dev/null
  sudo chmod "$mode" "$destination"
}
