# Check-mode reporting helpers.
# Sourced by setup.sh — do not execute directly.

VERIFY_FAILURES=0
VERIFY_CHECKS=0

verify_pass() {
  VERIFY_CHECKS=$((VERIFY_CHECKS + 1))
  e_success "PASS: $1"
}

verify_fail() {
  VERIFY_CHECKS=$((VERIFY_CHECKS + 1))
  VERIFY_FAILURES=$((VERIFY_FAILURES + 1))
  error "FAIL: $1"
}

verify_na() {
  e_note "N/A: $1"
}

verify_command() {
  local command_name="$1"
  local remediation="$2"

  if command -v "$command_name" >/dev/null 2>&1; then
    verify_pass "${command_name} is installed"
  else
    verify_fail "${command_name} is missing; ${remediation}"
  fi
}

verify_symlink() {
  local source_path="$1"
  local destination="$2"
  local remediation="$3"
  local resolved_source resolved_destination

  resolved_source="$(realpath "$source_path" 2>/dev/null || true)"
  resolved_destination="$(realpath "$destination" 2>/dev/null || true)"
  if [[ -L "$destination" && "$resolved_source" == "$resolved_destination" ]]; then
    verify_pass "${destination} points to managed configuration"
  else
    verify_fail "${destination} is not the managed symlink; ${remediation}"
  fi
}

verify_finish() {
  if ((VERIFY_FAILURES > 0)); then
    error "${VERIFY_FAILURES} of ${VERIFY_CHECKS} checks failed"
    return 1
  fi
  e_success "All ${VERIFY_CHECKS} applicable checks passed"
}
