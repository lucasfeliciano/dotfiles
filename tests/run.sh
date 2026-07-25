#!/bin/bash
set -euo pipefail

REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"
TEST_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/dotfiles-tests.XXXXXX")"
trap 'rm -rf "$TEST_ROOT"' EXIT

pass_count=0

pass() {
  pass_count=$((pass_count + 1))
  printf 'ok %d - %s\n' "$pass_count" "$1"
}

fail() {
  printf 'not ok - %s\n' "$1" >&2
  exit 1
}

assert_equals() {
  local expected="$1"
  local actual="$2"
  local message="$3"

  [[ "$actual" == "$expected" ]] || {
    printf 'expected: %s\nactual:   %s\n' "$expected" "$actual" >&2
    fail "$message"
  }
}

test_bash_syntax() {
  local script

  while IFS= read -r -d '' script; do
    bash -n "$script"
  done < <(find "$REPO_DIR" -type f -name '*.sh' -not -path '*/.git/*' -print0)
  pass "all Bash scripts parse"

  if command -v zsh >/dev/null 2>&1; then
    while IFS= read -r -d '' script; do
      zsh -n "$script"
    done < <(find "$REPO_DIR/shared/config/zsh" "$REPO_DIR/platforms/macos/config/zsh" "$REPO_DIR/platforms/ubuntu/config/zsh" -type f -print0)
    pass "all Zsh configuration parses"
  fi
}

test_platform_detection() {
  local ubuntu_release bad_release result

  ubuntu_release="$TEST_ROOT/os-release-ubuntu"
  bad_release="$TEST_ROOT/os-release-bad"
  printf 'ID=ubuntu\nVERSION_ID="26.04"\n' > "$ubuntu_release"
  printf 'ID=ubuntu\nVERSION_ID="24.04"\n' > "$bad_release"

  result="$(
    DOTFILES_KERNEL_OVERRIDE=Linux \
      DOTFILES_ARCH_OVERRIDE=x86_64 \
      DOTFILES_OS_RELEASE_FILE="$ubuntu_release" \
      bash -c 'source "$1/shared/lib/log.sh"; source "$1/shared/lib/platform.sh"; detect_platform; printf "%s %s" "$PLATFORM" "$PLATFORM_VERSION"' \
      _ "$REPO_DIR"
  )"
  assert_equals "ubuntu 26.04" "$result" "Ubuntu 26.04 detection"

  if DOTFILES_KERNEL_OVERRIDE=Linux DOTFILES_ARCH_OVERRIDE=x86_64 \
    DOTFILES_OS_RELEASE_FILE="$bad_release" \
    bash -c 'source "$1/shared/lib/log.sh"; source "$1/shared/lib/platform.sh"; detect_platform' \
    _ "$REPO_DIR" >/dev/null 2>&1; then
    fail "unsupported Ubuntu version rejection"
  fi
  if DOTFILES_KERNEL_OVERRIDE=Linux DOTFILES_ARCH_OVERRIDE=aarch64 \
    DOTFILES_OS_RELEASE_FILE="$ubuntu_release" \
    bash -c 'source "$1/shared/lib/log.sh"; source "$1/shared/lib/platform.sh"; detect_platform' \
    _ "$REPO_DIR" >/dev/null 2>&1; then
    fail "unsupported Ubuntu architecture rejection"
  fi
  pass "platform detection accepts Ubuntu 26.04 amd64 and rejects other profiles"
}

test_command_rendering_and_failure_status() {
  local rendered output status

  rendered="$(
    REPO_DIR="$REPO_DIR" bash -c '
      source "$REPO_DIR/shared/lib/log.sh"
      source "$REPO_DIR/shared/lib/command.sh"
      quote_command printf "%s\\n" "hello world"
    '
  )"
  assert_equals 'printf %s\\n hello\ world' "$rendered" "quoted argv rendering"

  set +e
  output="$(
    REPO_DIR="$REPO_DIR" bash -c '
      DRY_RUN=false
      source "$REPO_DIR/shared/lib/log.sh"
      source "$REPO_DIR/shared/lib/command.sh"
      run sh -c "exit 7"
    ' 2>&1
  )"
  status=$?
  set -e
  assert_equals "7" "$status" "failed command status"
  [[ "$output" == *"Command failed: sh -c exit\\ 7"* ]] || fail "failed operation rendering"
  pass "commands are quoted and preserve failure status"
}

test_verify_reporter_status() {
  local output status

  set +e
  output="$(
    REPO_DIR="$REPO_DIR" bash -c '
      source "$REPO_DIR/shared/lib/log.sh"
      source "$REPO_DIR/shared/lib/verify.sh"
      verify_pass "configured"
      verify_na "no meaningful check"
      verify_fail "run ./setup.sh --module mise"
      verify_finish
    ' 2>&1
  )"
  status=$?
  set -e

  assert_equals "1" "$status" "verification failure status"
  [[ "$output" == *"PASS: configured"* ]] || fail "verification pass output"
  [[ "$output" == *"N/A: no meaningful check"* ]] || fail "verification not-applicable output"
  [[ "$output" == *"FAIL: run ./setup.sh --module mise"* ]] || fail "verification failure output"
  pass "verification reporter aggregates failures"
}

module_order() {
  local platform="$1"
  local version="$2"
  local home_dir="$3"
  shift 3

  DOTFILES_PLATFORM_OVERRIDE="$platform" \
    DOTFILES_PLATFORM_VERSION_OVERRIDE="$version" \
    HOME="$home_dir" \
    "$REPO_DIR/setup.sh" --dry-run "$@" |
    sed -n 's/.*Setting up \([a-z]*\).*/\1/p' |
    paste -sd ' ' -
}

test_module_ordering() {

  mkdir -p "$TEST_ROOT/order-home"
  assert_equals \
    "packages zsh eza mise ghostty git system" \
    "$(module_order macos test "$TEST_ROOT/order-home")" \
    "macOS base canonical order"
  assert_equals \
    "packages zsh eza mise ghostty git" \
    "$(module_order ubuntu 26.04 "$TEST_ROOT/order-home")" \
    "Ubuntu base canonical order"
  assert_equals \
    "mise ghostty git" \
    "$(module_order ubuntu 26.04 "$TEST_ROOT/order-home" --module git ghostty mise)" \
    "direct modules use canonical order"
  pass "base profiles and direct modules use canonical order"
}

test_networking_profile() {
  local base_order networking_order
  base_order="$(module_order ubuntu 26.04 "$TEST_ROOT/network-home")"
  networking_order="$(module_order ubuntu 26.04 "$TEST_ROOT/network-home" --profile networking)"

  assert_equals "packages zsh eza mise ghostty git" "$base_order" "Ubuntu base excludes networking"
  assert_equals "packages zsh eza mise ghostty git networking" "$networking_order" "networking profile composition"

  local expected='iproute2
iputils-ping
dnsutils
netcat-openbsd
tcpdump
traceroute
mtr-tiny
whois'
  assert_equals "$expected" "$(sed '/^[[:space:]]*#/d; /^[[:space:]]*$/d' "$REPO_DIR/platforms/ubuntu/packages/networking.apt")" \
    "networking manifest inventory"
  pass "networking is additive and owns all diagnostics"
}

test_apt_refreshes_once_across_manifests() {
  local output update_count
  output="$(
    REPO_DIR="$REPO_DIR" bash -c '
      source "$REPO_DIR/shared/lib/log.sh"
      source "$REPO_DIR/platforms/ubuntu/lib/packages.sh"
      DRY_RUN=true
      run() { printf "%s\\n" "$*"; }
      apt_install_manifest "$REPO_DIR/platforms/ubuntu/packages/base.apt"
      apt_install_manifest "$REPO_DIR/platforms/ubuntu/packages/networking.apt"
    '
  )"
  update_count="$(grep -c '^sudo apt-get update$' <<< "$output")"
  assert_equals "1" "$update_count" "single APT metadata refresh"
  pass "APT metadata refresh is shared across profile manifests"
}

assert_command_fails_with() {
  local expected="$1"
  shift
  local output status

  set +e
  output="$("$@" 2>&1)"
  status=$?
  set -e
  ((status != 0)) || fail "command unexpectedly succeeded: $*"
  [[ "$output" == *"$expected"* ]] || {
    printf 'expected output containing: %s\nactual: %s\n' "$expected" "$output" >&2
    fail "failure output"
  }
}

test_selector_contract() {
  local setup=(env DOTFILES_PLATFORM_OVERRIDE=ubuntu DOTFILES_PLATFORM_VERSION_OVERRIDE=26.04 HOME="$TEST_ROOT/selectors-home" "$REPO_DIR/setup.sh")

  assert_command_fails_with "requires at least one name" "${setup[@]}" --profile
  assert_command_fails_with "requires at least one name" "${setup[@]}" --module --dry-run
  assert_command_fails_with "mutually exclusive" "${setup[@]}" --profile base --module mise
  assert_command_fails_with "cannot be combined" "${setup[@]}" --dry-run --check
  assert_command_fails_with "Positional module syntax was removed" "${setup[@]}" mise
  assert_command_fails_with "Module 'system' is not available on ubuntu" "${setup[@]}" --dry-run --module system
  assert_command_fails_with "Profile 'networking' is not available on macos" \
    env DOTFILES_PLATFORM_OVERRIDE=macos HOME="$TEST_ROOT/selectors-home" "$REPO_DIR/setup.sh" --dry-run --profile networking
  assert_command_fails_with "Required command 'mise' is missing" \
    env PATH=/usr/bin:/bin DOTFILES_PLATFORM_OVERRIDE=ubuntu DOTFILES_PLATFORM_VERSION_OVERRIDE=26.04 \
      HOME="$TEST_ROOT/selectors-home" "$REPO_DIR/setup.sh" --module mise
  [[ -z "$(find "$TEST_ROOT/selectors-home" -mindepth 1 -print -quit 2>/dev/null)" ]] || \
    fail "selector or prerequisite failure mutated HOME"
  pass "selectors validate names, modes, and platform ownership before execution"
}

test_conflict_backup_and_idempotency() {
  local home_dir source_file backup_file backup_count backup_run_count relative_link wrong_link directory_conflict

  home_dir="$TEST_ROOT/link-home"
  source_file="$TEST_ROOT/managed-zshrc"
  mkdir -p "$home_dir"
  printf 'managed\n' > "$source_file"
  printf 'unmanaged\n' > "$home_dir/.zshrc"
  wrong_link="$home_dir/.config/eza/theme.yml"
  directory_conflict="$home_dir/.managed-directory"
  mkdir -p "$(dirname "$wrong_link")" "$directory_conflict"
  ln -s "$TEST_ROOT/not-managed" "$wrong_link"
  printf 'directory content\n' > "$directory_conflict/child.txt"

  HOME="$home_dir" SOURCE_FILE="$source_file" WRONG_LINK="$wrong_link" DIRECTORY_CONFLICT="$directory_conflict" REPO_DIR="$REPO_DIR" bash -c '
    set -euo pipefail
    DRY_RUN=false
    export DRY_RUN
    source "$REPO_DIR/shared/lib/log.sh"
    source "$REPO_DIR/shared/lib/command.sh"
    source "$REPO_DIR/shared/lib/fs.sh"
    link_config "$SOURCE_FILE" "$HOME/.zshrc"
    link_config "$SOURCE_FILE" "$HOME/.zshrc"
    link_config "$SOURCE_FILE" "$WRONG_LINK"
    link_config "$SOURCE_FILE" "$DIRECTORY_CONFLICT"
  ' >/dev/null

  [[ -L "$home_dir/.zshrc" ]] || fail "conflicting file replaced with symlink"
  assert_equals "$source_file" "$(readlink "$home_dir/.zshrc")" "managed symlink target"
  backup_file="$(find "$home_dir/.dotfiles-backup" -type f -name .zshrc -print -quit)"
  [[ -n "$backup_file" ]] || fail "conflicting destination backup"
  assert_equals "unmanaged" "$(sed -n '1p' "$backup_file")" "backup content"
  backup_count="$(find "$home_dir/.dotfiles-backup" -type f | wc -l | tr -d ' ')"
  assert_equals "2" "$backup_count" "idempotent symlink rerun"
  backup_run_count="$(find "$home_dir/.dotfiles-backup" -mindepth 1 -maxdepth 1 -type d | wc -l | tr -d ' ')"
  assert_equals "1" "$backup_run_count" "one backup tree per setup process"
  [[ -L "$(find "$home_dir/.dotfiles-backup" -path '*/.config/eza/theme.yml' -print -quit)" ]] || fail "incorrect symlink backup"
  [[ -f "$(find "$home_dir/.dotfiles-backup" -path '*/.managed-directory/child.txt' -print -quit)" ]] || fail "directory backup"

  relative_link="$home_dir/.relative-managed"
  ln -s "../managed-zshrc" "$relative_link"
  HOME="$home_dir" SOURCE_FILE="$source_file" RELATIVE_LINK="$relative_link" REPO_DIR="$REPO_DIR" bash -c '
    set -euo pipefail
    DRY_RUN=false
    export DRY_RUN
    source "$REPO_DIR/shared/lib/log.sh"
    source "$REPO_DIR/shared/lib/command.sh"
    source "$REPO_DIR/shared/lib/fs.sh"
    link_config "$SOURCE_FILE" "$RELATIVE_LINK"
  ' >/dev/null
  assert_equals "../managed-zshrc" "$(readlink "$relative_link")" "relative correct symlink preservation"
  pass "conflicts are backed up and correct absolute/relative symlinks are idempotent"
}

test_private_file_preserved() {
  local home_dir

  home_dir="$TEST_ROOT/private-home"
  mkdir -p "$home_dir"
  printf 'secret-local-setting\n' > "$home_dir/.zshrc_private"

  HOME="$home_dir" REPO_DIR="$REPO_DIR" bash -c '
    set -euo pipefail
    DRY_RUN=false
    export DRY_RUN
    source "$REPO_DIR/shared/lib/log.sh"
    source "$REPO_DIR/shared/lib/command.sh"
    source "$REPO_DIR/shared/lib/fs.sh"
    ensure_local_copy "$REPO_DIR/shared/config/zsh/.zshrc_private.template" "$HOME/.zshrc_private"
  ' >/dev/null

  assert_equals "secret-local-setting" "$(sed -n '1p' "$home_dir/.zshrc_private")" "private config preservation"
  [[ ! -e "$home_dir/.dotfiles-backup" ]] || fail "private local file should not be backed up"
  pass ".zshrc_private remains local and untouched"
}

test_dry_run_has_no_side_effects() {
  local home_dir fake_bin marker before after

  home_dir="$TEST_ROOT/dry-home"
  fake_bin="$TEST_ROOT/fake-bin"
  marker="$TEST_ROOT/curl-ran"
  mkdir -p "$home_dir" "$fake_bin"
  printf '#!/bin/sh\ntouch "%s"\nexit 99\n' "$marker" > "$fake_bin/curl"
  chmod +x "$fake_bin/curl"

  before="$(find "$home_dir" -mindepth 1 -print | sort)"
  DOTFILES_PLATFORM_OVERRIDE=ubuntu \
    DOTFILES_PLATFORM_VERSION_OVERRIDE=26.04 \
    HOME="$home_dir" \
    PATH="$fake_bin:$PATH" \
    "$REPO_DIR/setup.sh" --dry-run >/dev/null
  after="$(find "$home_dir" -mindepth 1 -print | sort)"

  assert_equals "$before" "$after" "dry-run filesystem state"
  [[ ! -e "$marker" ]] || fail "dry-run executed a hidden curl download"
  pass "dry-run performs no writes or hidden downloads"
}

test_bootstrap_dry_run() {
  local bootstrap_home output

  bootstrap_home="$TEST_ROOT/bootstrap-home"
  mkdir -p "$bootstrap_home"
  output="$(
    HOME="$bootstrap_home" \
      DOTFILES_DIR="$bootstrap_home/.dotfiles" \
      "$REPO_DIR/bootstrap.sh" --dry-run
  )"

  [[ "$output" == *"git clone"* ]] || fail "bootstrap dry-run clone plan"
  [[ ! -e "$bootstrap_home/.dotfiles" ]] || fail "bootstrap dry-run created checkout"
  pass "bootstrap dry-run is side-effect-free before cloning"
}

test_runtime_and_network_policy() {
  grep -q '^python = "latest"$' "$REPO_DIR/shared/config/mise/config.toml" ||
    fail "mise global Python"
  grep -q '^uv = "latest"$' "$REPO_DIR/shared/config/mise/config.toml" ||
    fail "mise global uv"
  grep -q '^idiomatic_version_file_enable_tools = \["node"\]$' \
    "$REPO_DIR/shared/config/mise/config.toml" ||
    fail "mise Python idiomatic-version policy"
  grep -q '^python-preference = "system"$' "$REPO_DIR/shared/config/uv/uv.toml" ||
    fail "uv system Python preference"
  grep -q '^python-downloads = "automatic"$' "$REPO_DIR/shared/config/uv/uv.toml" ||
    fail "uv automatic Python downloads"
  pass "mise and uv ownership policies are encoded"
}

test_package_scope() {
  grep -qx 'code --classic' "$REPO_DIR/platforms/ubuntu/packages/base.snap" || fail "VS Code classic Snap"
  grep -qx 'ghostty' "$REPO_DIR/platforms/ubuntu/packages/base.apt" || fail "Ghostty base package"
  if grep -Eq '^(iproute2|iputils-ping|dnsutils|netcat-openbsd|tcpdump|traceroute|mtr-tiny|whois|qemu-kvm|libvirt)' \
    "$REPO_DIR/platforms/ubuntu/packages/base.apt"; then
    fail "optional packages leaked into Ubuntu base"
  fi
  grep -q '^config-file = platform$' "$REPO_DIR/shared/config/ghostty/config" || fail "Ghostty overlay include"
  if grep -q '^theme =' "$REPO_DIR/shared/config/ghostty/config"; then
    fail "shared Ghostty theme ownership"
  fi
  grep -q '^theme = Catppuccin Latte$' "$REPO_DIR/platforms/macos/config/ghostty.conf" || fail "macOS Ghostty theme"
  if grep -q '^theme =' "$REPO_DIR/platforms/ubuntu/config/ghostty.conf"; then
    fail "Ubuntu must retain Ghostty's default theme"
  fi
  if grep -Eq 'macos|ubuntu|OSTYPE|Library/pnpm|fdfind|batcat' "$REPO_DIR/shared/modules/"*.sh "$REPO_DIR/shared/config/zsh/.zshrc"; then
    fail "hidden platform branch in shared behavior"
  fi
  pass "base manifests and platform overlays own platform-specific behavior"
}

test_manifest_parsing() {
  local invalid_apt="$TEST_ROOT/invalid.apt" invalid_snap="$TEST_ROOT/invalid.snap"
  local valid_then_invalid_snap="$TEST_ROOT/valid-then-invalid.snap"
  local marker="$TEST_ROOT/manifest-command-ran" output
  printf 'curl | sh\n' > "$invalid_apt"
  printf 'code --classic unexpected\n' > "$invalid_snap"
  printf 'code --classic\ncode --classic unexpected\n' > "$valid_then_invalid_snap"

  if REPO_DIR="$REPO_DIR" MANIFEST="$invalid_apt" MARKER="$marker" bash -c '
    source "$REPO_DIR/shared/lib/log.sh"
    source "$REPO_DIR/platforms/ubuntu/lib/packages.sh"
    run() { touch "$MARKER"; }
    DRY_RUN=true
    apt_install_manifest "$MANIFEST"
  ' >/dev/null 2>&1; then
    fail "invalid APT manifest acceptance"
  fi
  [[ ! -e "$marker" ]] || fail "invalid APT entry reached command execution"

  if REPO_DIR="$REPO_DIR" MANIFEST="$invalid_snap" MARKER="$marker" bash -c '
    source "$REPO_DIR/shared/lib/log.sh"
    source "$REPO_DIR/platforms/ubuntu/lib/packages.sh"
    run() { touch "$MARKER"; }
    DRY_RUN=true
    snap_install_manifest "$MANIFEST"
  ' >/dev/null 2>&1; then
    fail "invalid Snap manifest acceptance"
  fi
  [[ ! -e "$marker" ]] || fail "invalid Snap entry reached command execution"

  if REPO_DIR="$REPO_DIR" MANIFEST="$valid_then_invalid_snap" MARKER="$marker" bash -c '
    source "$REPO_DIR/shared/lib/log.sh"
    source "$REPO_DIR/platforms/ubuntu/lib/packages.sh"
    run() { touch "$MARKER"; }
    DRY_RUN=true
    snap_install_manifest "$MANIFEST"
  ' >/dev/null 2>&1; then
    fail "mixed Snap manifest acceptance"
  fi
  [[ ! -e "$marker" ]] || fail "invalid Snap manifest reached a fake sudo call"

  output="$(
    REPO_DIR="$REPO_DIR" bash -c '
      source "$REPO_DIR/shared/lib/log.sh"
      source "$REPO_DIR/platforms/ubuntu/lib/packages.sh"
      run() { printf "%s " "$@"; }
      DRY_RUN=true
      snap_install_manifest "$REPO_DIR/platforms/ubuntu/packages/base.snap"
    '
  )"
  [[ "$output" == *"sudo snap install code --classic"* ]] || fail "classic Snap parsing"

  output="$(
    REPO_DIR="$REPO_DIR" bash -c '
      source "$REPO_DIR/shared/lib/log.sh"
      source "$REPO_DIR/platforms/ubuntu/lib/packages.sh"
      DRY_RUN=false
      snap() { [[ "$1 $2" == "list code" ]]; }
      run() { printf "unexpected mutation: %s\n" "$*"; return 1; }
      snap_install_manifest "$REPO_DIR/platforms/ubuntu/packages/base.snap"
    '
  )"
  [[ "$output" != *"unexpected mutation"* ]] || fail "installed Snap reinstallation"
  pass "APT and Snap manifests validate before command execution and preserve classic confinement"
}

test_failure_propagation() {
  local marker="$TEST_ROOT/setup-packages-continued" download_marker="$TEST_ROOT/setup-packages-download"
  local package_root="$TEST_ROOT/snap-install-failure" install_marker="$TEST_ROOT/snap-install-called"
  local continuation_marker="$TEST_ROOT/snap-install-continued"

  if REPO_DIR="$REPO_DIR" bash -c '
    source "$REPO_DIR/shared/lib/log.sh"
    source "$REPO_DIR/setup.sh"
    source "$REPO_DIR/shared/modules/zsh.sh"
    DRY_RUN=false
    require_command_or_module() { [[ "$1" != "curl" ]]; }
    preflight_zsh
  ' >/dev/null 2>&1; then
    fail "early Zsh prerequisite failure was masked"
  fi

  if REPO_DIR="$REPO_DIR" bash -c '
    set -euo pipefail
    source "$REPO_DIR/shared/lib/log.sh"
    source "$REPO_DIR/shared/lib/command.sh"
    source "$REPO_DIR/setup.sh"
    REGISTRY_MODULE_SETUP=(setup_broken)
    RESOLVED_MODULES=(broken)
    module_index() { printf "0\n"; }
    setup_broken() { run false; printf "continued\n"; }
    execute_setup_plan
  ' >/dev/null 2>&1; then
    fail "mid-module command failure was masked"
  fi

  if REPO_DIR="$REPO_DIR" MARKER="$marker" bash -c '
    source "$REPO_DIR/shared/lib/log.sh"
    source "$REPO_DIR/platforms/ubuntu/modules/packages.sh"
    apt_install_manifest() { return 1; }
    snap_install_manifest() { touch "$MARKER"; }
    command() {
      if [[ "$1" == "-v" && "$2" == "mise" ]]; then
        return 0
      fi
      builtin command "$@"
    }
    setup_packages
  ' >/dev/null 2>&1; then
    fail "setup_packages masked an earlier helper failure"
  fi
  [[ ! -e "$marker" ]] || fail "setup_packages continued after a helper failure"

  if REPO_DIR="$REPO_DIR" MARKER="$download_marker" bash -c '
    source "$REPO_DIR/shared/lib/log.sh"
    source "$REPO_DIR/platforms/ubuntu/modules/packages.sh"
    apt_install_manifest() { :; }
    snap_install_manifest() { return 1; }
    command() {
      if [[ "$1" == "-v" && "$2" == "mise" ]]; then
        return 1
      fi
      builtin command "$@"
    }
    run() { touch "$MARKER"; }
    setup_packages
  ' >/dev/null 2>&1; then
    fail "setup_packages masked a Snap helper failure"
  fi
  [[ ! -e "$download_marker" ]] || fail "setup_packages downloaded after a Snap helper failure"

  mkdir -p "$package_root/platforms/ubuntu/packages"
  printf 'unused\n' > "$package_root/platforms/ubuntu/packages/base.apt"
  printf 'code --classic\n' > "$package_root/platforms/ubuntu/packages/base.snap"
  if REPO_DIR="$REPO_DIR" DOTFILES_DIR="$package_root" INSTALL_MARKER="$install_marker" CONTINUATION_MARKER="$continuation_marker" bash -c '
    source "$REPO_DIR/shared/lib/log.sh"
    source "$REPO_DIR/platforms/ubuntu/lib/packages.sh"
    source "$REPO_DIR/platforms/ubuntu/modules/packages.sh"
    DRY_RUN=false
    apt_install_manifest() { :; }
    snap() { return 1; }
    command() {
      if [[ "$1" == "-v" && "$2" == "mise" ]]; then
        return 0
      fi
      builtin command "$@"
    }
    run() {
      if [[ "$1 $2 $3" == "sudo snap install" ]]; then
        touch "$INSTALL_MARKER"
        return 1
      fi
      touch "$CONTINUATION_MARKER"
    }
    e_note() { touch "$CONTINUATION_MARKER"; }
    setup_packages
  ' >/dev/null 2>&1; then
    fail "setup_packages masked a failed Snap installation"
  fi
  [[ -e "$install_marker" ]] || fail "failed Snap installation was not exercised"
  [[ ! -e "$continuation_marker" ]] || fail "setup_packages continued after a failed Snap installation"
  pass "preflight and setup failures stop their plans immediately"
}

test_git_prompts_only_for_missing_identity() {
  local home_dir="$TEST_ROOT/git-home" output
  mkdir -p "$home_dir"
  HOME="$home_dir" git config --global user.name "Configured Name"

  output="$(
    HOME="$home_dir" REPO_DIR="$REPO_DIR" bash -c '
      source "$REPO_DIR/shared/lib/log.sh"
      source "$REPO_DIR/shared/lib/command.sh"
      source "$REPO_DIR/shared/modules/git.sh"
      DRY_RUN=true
      setup_git
    '
  )"
  [[ "$output" != *"missing git user.name"* ]] || fail "configured Git name prompt"
  [[ "$output" == *"missing git user.email"* ]] || fail "missing Git email prompt"
  pass "Git setup prompts only for missing identity values"
}

test_bash_syntax
test_platform_detection
test_command_rendering_and_failure_status
test_verify_reporter_status
test_module_ordering
test_networking_profile
test_apt_refreshes_once_across_manifests
test_selector_contract
test_conflict_backup_and_idempotency
test_private_file_preserved
test_dry_run_has_no_side_effects
test_bootstrap_dry_run
test_runtime_and_network_policy
test_package_scope
test_manifest_parsing
test_failure_propagation
test_git_prompts_only_for_missing_identity

printf '1..%d\n' "$pass_count"
