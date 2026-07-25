#!/bin/bash
set -euo pipefail

DOTFILES_DIR="$(cd "$(dirname "$0")" && pwd)"
export DOTFILES_DIR

DRY_RUN=false
CHECK_MODE=false
SELECTOR_MODE=""
SELECTED_PROFILES=()
SELECTED_MODULES=()
RESOLVED_MODULES=()
REGISTRY_MODULE_NAMES=()
REGISTRY_MODULE_FILES=()
REGISTRY_MODULE_SETUP=()
REGISTRY_MODULE_CHECK=()
REGISTRY_MODULE_PREFLIGHT=()
REGISTRY_MODULE_PRIVILEGED=()
REGISTRY_PROFILE_NAMES=()
REGISTRY_PROFILE_FILES=()

register_module() {
  REGISTRY_MODULE_NAMES+=("$1")
  REGISTRY_MODULE_FILES+=("$2")
  REGISTRY_MODULE_SETUP+=("$3")
  REGISTRY_MODULE_CHECK+=("$4")
  REGISTRY_MODULE_PREFLIGHT+=("$5")
  REGISTRY_MODULE_PRIVILEGED+=("$6")
}

register_profile() {
  REGISTRY_PROFILE_NAMES+=("$1")
  REGISTRY_PROFILE_FILES+=("$2")
}

selector_error() {
  printf 'Error: %s\n' "$1" >&2
  return 1
}

parse_args() {
  local count

  while (($# > 0)); do
    case "$1" in
      --dry-run)
        DRY_RUN=true
        shift
        ;;
      --check)
        CHECK_MODE=true
        shift
        ;;
      --profile)
        [[ -z "$SELECTOR_MODE" || "$SELECTOR_MODE" == "profile" ]] ||
          selector_error "--profile and --module are mutually exclusive" || return
        SELECTOR_MODE=profile
        shift
        count=0
        while (($# > 0)) && [[ "$1" != -* ]]; do
          SELECTED_PROFILES+=("$1")
          count=$((count + 1))
          shift
        done
        ((count > 0)) || selector_error "--profile requires at least one name" || return
        ;;
      --module)
        [[ -z "$SELECTOR_MODE" || "$SELECTOR_MODE" == "module" ]] ||
          selector_error "--profile and --module are mutually exclusive" || return
        SELECTOR_MODE=module
        shift
        count=0
        while (($# > 0)) && [[ "$1" != -* ]]; do
          SELECTED_MODULES+=("$1")
          count=$((count + 1))
          shift
        done
        ((count > 0)) || selector_error "--module requires at least one name" || return
        ;;
      -*)
        selector_error "Unknown flag: $1" || return
        ;;
      *)
        selector_error "Positional module syntax was removed; use --module <name...>" || return
        ;;
    esac
  done

  if [[ "$DRY_RUN" == "true" && "$CHECK_MODE" == "true" ]]; then
    selector_error "--dry-run cannot be combined with --check"
  fi
}

module_index() {
  local requested="$1" index=0
  while ((index < ${#REGISTRY_MODULE_NAMES[@]})); do
    if [[ "$requested" == "${REGISTRY_MODULE_NAMES[$index]}" ]]; then
      printf '%s\n' "$index"
      return 0
    fi
    index=$((index + 1))
  done
  return 1
}

profile_index() {
  local requested="$1" index=0
  while ((index < ${#REGISTRY_PROFILE_NAMES[@]})); do
    if [[ "$requested" == "${REGISTRY_PROFILE_NAMES[$index]}" ]]; then
      printf '%s\n' "$index"
      return 0
    fi
    index=$((index + 1))
  done
  return 1
}

array_contains() {
  local requested="$1" item
  shift
  for item in "$@"; do
    [[ "$requested" == "$item" ]] && return 0
  done
  return 1
}

append_profile_modules() {
  local requested="$1" index module_name
  index="$(profile_index "$requested")" || {
    error "Profile '${requested}' is not available on ${PLATFORM}. Available profiles: ${REGISTRY_PROFILE_NAMES[*]}"
    return 1
  }

  PROFILE_NAME=""
  PROFILE_MODULES=()
  source "${REGISTRY_PROFILE_FILES[$index]}"
  [[ "$PROFILE_NAME" == "$requested" ]] || {
    error "Profile file ${REGISTRY_PROFILE_FILES[$index]} registered '${PROFILE_NAME}', expected '${requested}'."
    return 1
  }
  ((${#PROFILE_MODULES[@]} > 0)) || {
    error "Profile '${requested}' has no modules."
    return 1
  }
  for module_name in "${PROFILE_MODULES[@]}"; do
    module_index "$module_name" >/dev/null || {
      error "Profile '${requested}' references unavailable module '${module_name}'."
      return 1
    }
    CANDIDATE_MODULES+=("$module_name")
  done
}

resolve_selection() {
  local requested canonical index
  CANDIDATE_MODULES=()
  RESOLVED_MODULES=()

  if [[ "$SELECTOR_MODE" == "module" ]]; then
    for requested in "${SELECTED_MODULES[@]}"; do
      module_index "$requested" >/dev/null || {
        error "Module '${requested}' is not available on ${PLATFORM}. Available modules: ${REGISTRY_MODULE_NAMES[*]}"
        return 1
      }
      CANDIDATE_MODULES+=("$requested")
    done
  else
    profile_index base >/dev/null || {
      error "Platform ${PLATFORM} has no base profile."
      return 1
    }
    if ((${#SELECTED_PROFILES[@]} > 0)); then
      for requested in "${SELECTED_PROFILES[@]}"; do
        profile_index "$requested" >/dev/null || {
          error "Profile '${requested}' is not available on ${PLATFORM}. Available profiles: ${REGISTRY_PROFILE_NAMES[*]}"
          return 1
        }
      done
    fi

    append_profile_modules base
    if ((${#SELECTED_PROFILES[@]} > 0)); then
      for requested in "${SELECTED_PROFILES[@]}"; do
        [[ "$requested" == "base" ]] || append_profile_modules "$requested"
      done
    fi
  fi

  index=0
  while ((index < ${#REGISTRY_MODULE_NAMES[@]})); do
    canonical="${REGISTRY_MODULE_NAMES[$index]}"
    if array_contains "$canonical" "${CANDIDATE_MODULES[@]}"; then
      RESOLVED_MODULES+=("$canonical")
    fi
    index=$((index + 1))
  done
  ((${#RESOLVED_MODULES[@]} > 0)) || {
    error "The selected plan contains no modules."
    return 1
  }
}

source_resolved_modules() {
  local module_name index
  for module_name in "${RESOLVED_MODULES[@]}"; do
    index="$(module_index "$module_name")"
    source "${REGISTRY_MODULE_FILES[$index]}"
  done
}

module_is_planned() {
  local requested="$1" module_name
  for module_name in "${RESOLVED_MODULES[@]}"; do
    [[ "$requested" == "$module_name" ]] && return 0
  done
  return 1
}

require_command_or_module() {
  local command_name="$1" provider_module="$2" remediation="$3"
  command -v "$command_name" >/dev/null 2>&1 && return 0
  module_is_planned "$provider_module" && return 0
  if [[ "$DRY_RUN" == "true" ]]; then
    e_dry "verify required command ${command_name}; ${remediation}"
    return 0
  fi
  error "Required command '${command_name}' is missing; ${remediation}."
  return 1
}

preflight_resolved_modules() {
  local module_name index preflight_function
  for module_name in "${RESOLVED_MODULES[@]}"; do
    index="$(module_index "$module_name")"
    preflight_function="${REGISTRY_MODULE_PREFLIGHT[$index]}"
    if [[ "$preflight_function" != "none" ]]; then
      "$preflight_function" || {
        error "Preflight failed for module '${module_name}'."
        return 1
      }
    fi
  done
}

plan_needs_privilege() {
  local module_name index
  for module_name in "${RESOLVED_MODULES[@]}"; do
    index="$(module_index "$module_name")"
    [[ "${REGISTRY_MODULE_PRIVILEGED[$index]}" == "true" ]] && return 0
  done
  return 1
}

execute_setup_plan() {
  local module_name index setup_function
  for module_name in "${RESOLVED_MODULES[@]}"; do
    index="$(module_index "$module_name")"
    setup_function="${REGISTRY_MODULE_SETUP[$index]}"
    e_header "Setting up ${module_name}"
    "$setup_function" || {
      error "Module '${module_name}' failed; subsequent modules were not run."
      return 1
    }
    e_success "${module_name} setup done!"
  done
}

execute_check_plan() {
  local module_name index check_function
  for module_name in "${RESOLVED_MODULES[@]}"; do
    index="$(module_index "$module_name")"
    check_function="${REGISTRY_MODULE_CHECK[$index]}"
    e_header "Checking ${module_name}"
    if [[ "$check_function" == "none" ]]; then
      verify_na "${module_name} has no meaningful automated check"
    else
      "$check_function"
    fi
  done
  verify_finish
}

main() {
  parse_args "$@"

  source "$DOTFILES_DIR/shared/lib/log.sh"
  source "$DOTFILES_DIR/shared/lib/command.sh"
  source "$DOTFILES_DIR/shared/lib/fs.sh"
  source "$DOTFILES_DIR/shared/lib/platform.sh"
  source "$DOTFILES_DIR/shared/lib/verify.sh"

  detect_platform
  source "$DOTFILES_DIR/platforms/${PLATFORM}/adapter.sh"
  source "$DOTFILES_DIR/platforms/${PLATFORM}/registry.sh"
  resolve_selection
  source_resolved_modules

  e_note "Detected platform: ${PLATFORM}${PLATFORM_VERSION:+ ${PLATFORM_VERSION}}"
  if [[ "$CHECK_MODE" == "true" ]]; then
    e_note "Check plan: ${RESOLVED_MODULES[*]}"
    execute_check_plan
    return
  fi

  preflight_resolved_modules
  e_note "Execution plan: ${RESOLVED_MODULES[*]}"
  if [[ "$DRY_RUN" == "true" ]]; then
    e_note "Dry run mode — no changes will be made"
  elif plan_needs_privilege; then
    run sudo -v
  fi
  execute_setup_plan
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  main "$@"
fi
