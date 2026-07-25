# Quoted command execution and dry-run rendering.
# Sourced by setup.sh — do not execute directly.

quote_command() {
  local printable

  printf -v printable '%q ' "$@"
  printf '%s' "${printable% }"
}

run() {
  local status

  if [[ "${DRY_RUN:-false}" == "true" ]]; then
    e_dry "$(quote_command "$@")"
    return 0
  fi

  "$@" || {
    status=$?
    error "Command failed: $(quote_command "$@")"
    return "$status"
  }
}
