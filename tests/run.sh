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
    done < <(find "$REPO_DIR/config/zsh" -type f -print0)
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

  DOTFILES_PLATFORM_OVERRIDE="$platform" \
    DOTFILES_PLATFORM_VERSION_OVERRIDE="$version" \
    HOME="$home_dir" \
    "$REPO_DIR/setup.sh" --dry-run |
    sed -n 's/.*Setting up \([a-z]*\).*/\1/p' |
    paste -sd ' ' -
}

test_module_ordering() {
  local ubuntu_order macos_order

  mkdir -p "$TEST_ROOT/order-home"
  ubuntu_order="$(module_order ubuntu 26.04 "$TEST_ROOT/order-home")"
  macos_order="$(module_order macos test "$TEST_ROOT/order-home")"

  assert_equals \
    "apt zsh eza mise ghostty git vscode security virtualization" \
    "$ubuntu_order" \
    "Ubuntu module ordering"
  assert_equals \
    "brew zsh eza mise ghostty git macos" \
    "$macos_order" \
    "macOS module ordering"
  pass "default module order is platform-specific and stable"
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
    ensure_local_copy "$REPO_DIR/config/zsh/.zshrc_private.template" "$HOME/.zshrc_private"
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

test_selective_modules_and_platform_guards() {
  local output

  output="$(
    DOTFILES_PLATFORM_OVERRIDE=ubuntu \
      DOTFILES_PLATFORM_VERSION_OVERRIDE=26.04 \
      HOME="$TEST_ROOT/selective-home" \
      "$REPO_DIR/setup.sh" --dry-run apt mise 2>&1
  )"
  [[ "$output" == *"Setting up apt"* ]] || fail "selective apt module"
  [[ "$output" == *"Setting up mise"* ]] || fail "selective mise module"
  [[ "$output" != *"Setting up zsh"* ]] || fail "unrequested module ran"

  if DOTFILES_PLATFORM_OVERRIDE=macos HOME="$TEST_ROOT/selective-home" \
    "$REPO_DIR/setup.sh" --dry-run apt >/dev/null 2>&1; then
    fail "cross-platform module guard"
  fi
  pass "selective execution and platform module guards work"
}

test_runtime_and_network_policy() {
  grep -q '^python = "latest"$' "$REPO_DIR/config/mise/config.toml" ||
    fail "mise global Python"
  grep -q '^uv = "latest"$' "$REPO_DIR/config/mise/config.toml" ||
    fail "mise global uv"
  grep -q '^idiomatic_version_file_enable_tools = \["node"\]$' \
    "$REPO_DIR/config/mise/config.toml" ||
    fail "mise Python idiomatic-version policy"
  grep -q '^python-preference = "system"$' "$REPO_DIR/config/uv/uv.toml" ||
    fail "uv system Python preference"
  grep -q '^python-downloads = "automatic"$' "$REPO_DIR/config/uv/uv.toml" ||
    fail "uv automatic Python downloads"
  if grep -q '<forward' "$REPO_DIR/config/libvirt/lab-isolated.xml"; then
    fail "isolated network forwarding"
  fi
  grep -q '192.168.77.1' "$REPO_DIR/config/libvirt/lab-isolated.xml" ||
    fail "isolated network subnet"
  pass "mise/uv ownership and isolated-network policies are encoded"
}

test_package_scope() {
  local -a manifests=(
    "$REPO_DIR/packages/ubuntu-base.txt"
    "$REPO_DIR/packages/ubuntu-virtualization.txt"
  )

  grep -qx 'ghostty' "$REPO_DIR/packages/ubuntu-base.txt" || fail "Ghostty APT package"
  grep -qx 'qemu-kvm' "$REPO_DIR/packages/ubuntu-virtualization.txt" || fail "KVM package"
  grep -q 'alias fd="fdfind"' "$REPO_DIR/config/zsh/.aliases" || fail "Ubuntu fd command alias"
  grep -q 'alias bat="batcat"' "$REPO_DIR/config/zsh/.aliases" || fail "Ubuntu bat command alias"
  if grep -Eiq 'docker|podman|openssh-server|kali|metasploit' "${manifests[@]}"; then
    fail "excluded heavyweight or exposed service package"
  fi
  pass "APT manifests contain the intended package scope"
}

test_bash_syntax
test_platform_detection
test_command_rendering_and_failure_status
test_verify_reporter_status
test_module_ordering
test_conflict_backup_and_idempotency
test_private_file_preserved
test_dry_run_has_no_side_effects
test_bootstrap_dry_run
test_selective_modules_and_platform_guards
test_runtime_and_network_policy
test_package_scope

printf '1..%d\n' "$pass_count"
