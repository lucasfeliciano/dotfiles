#!/bin/bash
set -euo pipefail

DOTFILES_REPO="https://github.com/lucasfeliciano/dotfiles.git"
DOTFILES_DIR="${DOTFILES_DIR:-$HOME/.dotfiles}"
DRY_RUN=false

bootstrap_run() {
  if [[ "$DRY_RUN" == "true" ]]; then
    local printable
    printf -v printable '%q ' "$@"
    printf '\033[1;34m[dry-run]\033[0m %s\n' "${printable% }"
  else
    "$@"
  fi
}

bootstrap_detect_platform() {
  local kernel os_release_file os_id os_version machine
  kernel="${DOTFILES_KERNEL_OVERRIDE:-$(uname -s)}"

  case "$kernel" in
    Darwin)
      printf 'macos\n'
      ;;
    Linux)
      os_release_file="${DOTFILES_OS_RELEASE_FILE:-/etc/os-release}"
      [[ -r "$os_release_file" ]] || {
        printf 'Cannot identify Linux distribution: %s is not readable.\n' "$os_release_file" >&2
        return 1
      }
      os_id="$(sed -n 's/^ID=//p' "$os_release_file" | tr -d '"')"
      os_version="$(sed -n 's/^VERSION_ID=//p' "$os_release_file" | tr -d '"')"
      machine="${DOTFILES_ARCH_OVERRIDE:-$(uname -m)}"
      if [[ "$os_id" != "ubuntu" || "$os_version" != "26.04" || "$machine" != "x86_64" ]]; then
        printf 'Ubuntu 26.04 amd64 is required (found %s %s %s).\n' \
          "${os_id:-unknown}" "${os_version:-unknown}" "${machine:-unknown}" >&2
        return 1
      fi
      printf 'ubuntu\n'
      ;;
    *)
      printf 'Unsupported operating system: %s\n' "$kernel" >&2
      return 1
      ;;
  esac
}

bootstrap_main() {
  local arg platform
  for arg in "$@"; do
    [[ "$arg" == "--dry-run" ]] && DRY_RUN=true
  done

  printf '\n\033[1;4;32m🚀 Bootstrapping your machine...\033[0m\n\n'
  platform="$(bootstrap_detect_platform)"
  case "$platform" in
    macos)
      if ! xcode-select -p >/dev/null 2>&1; then
        printf '\033[1;32m▸ Installing Xcode Command Line Tools...\033[0m\n'
        bootstrap_run xcode-select --install
        if [[ "$DRY_RUN" != "true" ]]; then
          printf '\033[1;33m⏳ Complete the installer, then press any key to continue.\033[0m\n'
          read -r -n 1 </dev/tty
        fi
      else
        printf '\033[1;32m✔ Xcode Command Line Tools already installed\033[0m\n'
      fi
      ;;
    ubuntu)
      printf '\033[1;32m▸ Installing Ubuntu bootstrap prerequisites...\033[0m\n'
      bootstrap_run sudo apt-get update
      bootstrap_run sudo apt-get install -y ca-certificates curl git
      ;;
  esac

  if [[ -d "$DOTFILES_DIR/.git" ]]; then
    printf '\033[1;32m✔ Dotfiles already cloned at %s\033[0m\n' "$DOTFILES_DIR"
  elif [[ -e "$DOTFILES_DIR" ]]; then
    printf '\033[1;31m✖ %s exists but is not a Git checkout.\033[0m\n' "$DOTFILES_DIR" >&2
    return 1
  else
    printf '\033[1;32m▸ Cloning dotfiles...\033[0m\n'
    bootstrap_run mkdir -p "$(dirname "$DOTFILES_DIR")"
    bootstrap_run git clone "$DOTFILES_REPO" "$DOTFILES_DIR"
  fi

  if [[ "$DRY_RUN" == "true" ]]; then
    printf '\033[1;34m[dry-run]\033[0m %s/setup.sh' "$DOTFILES_DIR"
    if (($# > 0)); then
      printf ' %q' "$@"
    fi
    printf '\n'
    return 0
  fi

  printf '\n\033[1;4;32mRunning setup\033[0m\n'
  cd "$DOTFILES_DIR"
  ./setup.sh "$@"
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  bootstrap_main "$@"
fi
