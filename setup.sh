#!/bin/bash
set -euo pipefail

DOTFILES_DIR="$(cd "$(dirname "$0")" && pwd)"
export DOTFILES_DIR

DRY_RUN=false
export DRY_RUN

# Parse flags
modules=()
for arg in "$@"; do
  case "$arg" in
    --dry-run) DRY_RUN=true ;;
    -*) echo "Unknown flag: $arg" >&2; exit 1 ;;
    *) modules+=("$arg") ;;
  esac
done

# Source libraries
source "$DOTFILES_DIR/util/log.sh"
source "$DOTFILES_DIR/lib/brew.sh"
source "$DOTFILES_DIR/lib/zsh.sh"
source "$DOTFILES_DIR/lib/git.sh"
source "$DOTFILES_DIR/lib/ghostty.sh"
source "$DOTFILES_DIR/lib/mise.sh"

ALL_MODULES=(brew zsh mise ghostty git)

run_module() {
  local module="$1"
  local func="setup_${module}"

  if declare -f "$func" > /dev/null; then
    e_header "Setting up ${module}"
    "$func"
    e_success "${module} setup done!"
  else
    error "Unknown module: ${module}"
    exit 1
  fi
}

if [[ ${#modules[@]} -eq 0 ]]; then
  modules=("${ALL_MODULES[@]}")
fi

if [[ "$DRY_RUN" == "true" ]]; then
  e_note "Dry run mode — no changes will be made"
fi

for module in "${modules[@]}"; do
  run_module "$module"
done

e_thanks "Author: https://github.com/lucasfeliciano"
e_note "Inspired by https://github.com/phoinixi/dotfiles"
