# Platform detection helpers.
# Sourced by setup.sh — do not execute directly.

detect_platform() {
  local kernel machine os_id os_version os_release_file

  if [[ -n "${DOTFILES_PLATFORM_OVERRIDE:-}" ]]; then
    case "$DOTFILES_PLATFORM_OVERRIDE" in
      macos)
        PLATFORM="macos"
        PLATFORM_VERSION="${DOTFILES_PLATFORM_VERSION_OVERRIDE:-test}"
        ;;
      ubuntu)
        PLATFORM="ubuntu"
        PLATFORM_VERSION="${DOTFILES_PLATFORM_VERSION_OVERRIDE:-26.04}"
        ;;
      *)
        error "Invalid DOTFILES_PLATFORM_OVERRIDE: ${DOTFILES_PLATFORM_OVERRIDE}"
        return 1
        ;;
    esac
    export PLATFORM PLATFORM_VERSION
    return
  fi

  kernel="${DOTFILES_KERNEL_OVERRIDE:-$(uname -s)}"
  case "$kernel" in
    Darwin)
      PLATFORM="macos"
      PLATFORM_VERSION="$(sw_vers -productVersion)"
      ;;
    Linux)
      os_release_file="${DOTFILES_OS_RELEASE_FILE:-/etc/os-release}"
      if [[ ! -r "$os_release_file" ]]; then
        error "Cannot identify Linux distribution: ${os_release_file} is not readable."
        return 1
      fi

      os_id="$(sed -n 's/^ID=//p' "$os_release_file" | tr -d '"')"
      os_version="$(sed -n 's/^VERSION_ID=//p' "$os_release_file" | tr -d '"')"
      if [[ "$os_id" != "ubuntu" ]]; then
        error "Unsupported Linux distribution '${os_id:-unknown}'. Ubuntu 26.04 is required."
        return 1
      fi
      if [[ "$os_version" != "26.04" ]]; then
        error "Unsupported Ubuntu release '${os_version:-unknown}'. Ubuntu 26.04 is required."
        return 1
      fi
      machine="${DOTFILES_ARCH_OVERRIDE:-$(uname -m)}"
      if [[ "$machine" != "x86_64" ]]; then
        error "Unsupported Ubuntu architecture '${machine}'. Ubuntu 26.04 amd64 is required."
        return 1
      fi

      PLATFORM="ubuntu"
      PLATFORM_VERSION="$os_version"
      ;;
    *)
      error "Unsupported operating system: ${kernel}"
      return 1
      ;;
  esac

  export PLATFORM PLATFORM_VERSION
}
