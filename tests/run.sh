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

contains_forbidden_scope() {
  grep -Eirq \
    '(^|[^[:alnum:]_])kali(-lab)?([^[:alnum:]_]|$)|metasploit|lab-isolated|baseline snapshot|guest-agent|guest agent|usb passthrough|shared host director|ufw|unattended-upgrades|apt(-get)?[[:space:]]+upgrade|mokutil|cryptsetup|secure boot|full-disk encryption|packages\.microsoft\.com|vscode\.sources|packages\.microsoft\.gpg' \
    "$@"
}

list_shipped_root_directories() {
  local root="$1"
  find "$root" -mindepth 1 -maxdepth 1 -type d \
    ! -name .git ! -name .superpowers ! -name docs -exec basename {} \; | sort
}

find_shipped_bash_scripts() {
  local root="$1"
  find "$root" \
    \( -path "$root/.git" -o -path "$root/.superpowers" -o -path "$root/docs" \) -prune -o \
    -type f -name '*.sh' -print0
}

test_forbidden_scope_term_boundaries() {
  local author_reference="$TEST_ROOT/allowed-author-reference"
  local forbidden_reference="$TEST_ROOT/forbidden-purpose-reference"
  local forbidden_lab_reference="$TEST_ROOT/forbidden-lab-reference"

  printf '%s\n' 'https://github.com/ekalinin/nodeenv' > "$author_reference"
  printf '%s\n' 'Install Kali tooling' > "$forbidden_reference"
  printf '%s\n' 'Prepare a Kali-lab' > "$forbidden_lab_reference"

  if contains_forbidden_scope "$author_reference"; then
    fail "author name containing kali was rejected"
  fi
  if ! contains_forbidden_scope "$forbidden_reference"; then
    fail "standalone Kali scope was accepted"
  fi
  if ! contains_forbidden_scope "$forbidden_lab_reference"; then
    fail "Kali-lab scope was accepted"
  fi
  pass "forbidden scope detects standalone and Kali-lab terms without author-name collisions"
}

test_shipped_root_directories_ignore_optional_design_roots() {
  local fixture_root="$TEST_ROOT/shipped-root-directories"
  local expected=$'platforms\nshared\ntests'

  mkdir -p "$fixture_root/platforms" "$fixture_root/shared" "$fixture_root/tests"
  assert_equals "$expected" "$(list_shipped_root_directories "$fixture_root")" \
    "shipped roots without optional design directories"

  mkdir -p "$fixture_root/.git" "$fixture_root/.superpowers" "$fixture_root/docs/superpowers"
  assert_equals "$expected" "$(list_shipped_root_directories "$fixture_root")" \
    "shipped roots with optional design directories"
  pass "ignored design roots are optional outside the shipped structure"
}

test_gitignore_has_no_tracked_files() {
  local tracked_ignored

  tracked_ignored="$(git -C "$REPO_DIR" ls-files --cached --ignored --exclude-standard)"
  if [[ -n "$tracked_ignored" ]]; then
    printf 'tracked files matching .gitignore:\n%s\n' "$tracked_ignored" >&2
    fail "tracked files bypass .gitignore"
  fi
  pass ".gitignore excludes every ignored artifact from the index"
}

test_shipped_bash_discovery_ignores_design_artifacts() {
  local fixture_root="$TEST_ROOT/shipped-bash-discovery" discovered="" script

  mkdir -p "$fixture_root/.git" "$fixture_root/.superpowers" \
    "$fixture_root/docs/superpowers" "$fixture_root/shared"
  printf '%s\n' '#!/bin/bash' > "$fixture_root/.git/ignored.sh"
  printf '%s\n' 'not valid Bash (' > "$fixture_root/.superpowers/ignored.sh"
  printf '%s\n' 'not valid Bash (' > "$fixture_root/docs/superpowers/ignored.sh"
  printf '%s\n' '#!/bin/bash' > "$fixture_root/shared/valid.sh"

  while IFS= read -r -d '' script; do
    discovered="${discovered}${discovered:+$'\n'}${script}"
  done < <(find_shipped_bash_scripts "$fixture_root")
  assert_equals "$fixture_root/shared/valid.sh" "$discovered" \
    "shipped Bash discovery"
  pass "shipped Bash discovery prunes ignored design artifacts"
}

# Child-script fixtures are single-quoted so their variables expand in the child.
# shellcheck disable=SC2016
test_lint_contract() {
  local fake_bin="$TEST_ROOT/lint-bin" missing_bin="$TEST_ROOT/lint-missing-bin"
  local lint_log="$TEST_ROOT/lint-invocations" expected actual output status
  local -a expected_scripts=(
    "$REPO_DIR/bootstrap.sh"
    "$REPO_DIR/platforms/macos/adapter.sh"
    "$REPO_DIR/platforms/macos/modules/packages.sh"
    "$REPO_DIR/platforms/macos/modules/system.sh"
    "$REPO_DIR/platforms/macos/profiles/base.sh"
    "$REPO_DIR/platforms/macos/registry.sh"
    "$REPO_DIR/platforms/ubuntu/adapter.sh"
    "$REPO_DIR/platforms/ubuntu/lib/libvirt.sh"
    "$REPO_DIR/platforms/ubuntu/lib/packages.sh"
    "$REPO_DIR/platforms/ubuntu/modules/networking.sh"
    "$REPO_DIR/platforms/ubuntu/modules/packages.sh"
    "$REPO_DIR/platforms/ubuntu/modules/virtualization.sh"
    "$REPO_DIR/platforms/ubuntu/profiles/base.sh"
    "$REPO_DIR/platforms/ubuntu/profiles/networking.sh"
    "$REPO_DIR/platforms/ubuntu/profiles/virtualization.sh"
    "$REPO_DIR/platforms/ubuntu/registry.sh"
    "$REPO_DIR/setup.sh"
    "$REPO_DIR/shared/lib/command.sh"
    "$REPO_DIR/shared/lib/fs.sh"
    "$REPO_DIR/shared/lib/log.sh"
    "$REPO_DIR/shared/lib/platform.sh"
    "$REPO_DIR/shared/lib/verify.sh"
    "$REPO_DIR/shared/modules/eza.sh"
    "$REPO_DIR/shared/modules/ghostty.sh"
    "$REPO_DIR/shared/modules/git.sh"
    "$REPO_DIR/shared/modules/mise.sh"
    "$REPO_DIR/shared/modules/zsh.sh"
    "$REPO_DIR/tests/lint.sh"
    "$REPO_DIR/tests/run.sh"
  )

  mkdir -p "$fake_bin" "$missing_bin"
  printf '%s\n' \
    '#!/bin/sh' \
    '[ "$#" -eq 4 ] && [ "$1" = "-x" ] && [ "$2" = "-s" ] && [ "$3" = "bash" ] || exit 90' \
    'printf "%s\\n" "$4" >> "$LINT_LOG"' > "$fake_bin/shellcheck"
  chmod +x "$fake_bin/shellcheck"

  LINT_LOG="$lint_log" PATH="$fake_bin:$PATH" "$REPO_DIR/tests/lint.sh"
  expected="$(printf '%s\n' "${expected_scripts[@]}" | sort)"
  actual="$(sort "$lint_log")"
  assert_equals "$expected" "$actual" "lint discovers each shipped Bash script exactly once"

  printf '%s\n' \
    '#!/bin/sh' \
    'case "$1" in' \
    '  */*) printf "%s\\n" "${1%/*}" ;;' \
    '  *) printf ".\\n" ;;' \
    'esac' > "$missing_bin/dirname"
  chmod +x "$missing_bin/dirname"
  set +e
  output="$(PATH="$missing_bin" "$REPO_DIR/tests/lint.sh" 2>&1)"
  status=$?
  set -e
  assert_equals "127" "$status" "lint missing-ShellCheck status"
  [[ "$output" == *"shellcheck is required"* ]] || fail "lint missing-ShellCheck guidance"
  pass "lint covers exactly shipped Bash and preserves its missing-tool contract"
}

# These patterns intentionally match literal source-code variable references.
# shellcheck disable=SC2016
test_final_repository_structure_and_scope() {
  local expected_root_files actual_root_files expected_root_directories actual_root_directories
  local path source_path platform resolved_path
  local -a required_paths=(
    bootstrap.sh setup.sh README.md
    shared/lib/log.sh shared/lib/command.sh shared/lib/fs.sh shared/lib/platform.sh shared/lib/verify.sh
    shared/modules/zsh.sh shared/modules/eza.sh shared/modules/git.sh shared/modules/mise.sh shared/modules/ghostty.sh
    shared/config/zsh/.zshrc shared/config/starship/starship.toml
    shared/config/eza/theme.yml shared/config/mise/config.toml
    shared/config/uv/uv.toml shared/config/ghostty/config
    platforms/macos/adapter.sh platforms/macos/registry.sh platforms/macos/profiles/base.sh
    platforms/macos/modules/packages.sh platforms/macos/modules/system.sh platforms/macos/packages/Brewfile
    platforms/macos/config/zsh/platform.zsh platforms/macos/config/ghostty.conf
    platforms/ubuntu/adapter.sh platforms/ubuntu/registry.sh platforms/ubuntu/README.md
    platforms/ubuntu/profiles/base.sh platforms/ubuntu/profiles/networking.sh platforms/ubuntu/profiles/virtualization.sh
    platforms/ubuntu/modules/packages.sh platforms/ubuntu/modules/networking.sh platforms/ubuntu/modules/virtualization.sh
    platforms/ubuntu/lib/packages.sh platforms/ubuntu/lib/libvirt.sh
    platforms/ubuntu/packages/base.apt platforms/ubuntu/packages/base.snap
    platforms/ubuntu/packages/networking.apt platforms/ubuntu/packages/virtualization.apt
    platforms/ubuntu/config/zsh/platform.zsh platforms/ubuntu/config/ghostty.conf
    platforms/ubuntu/config/libvirt/vm-isolated.xml tests/run.sh tests/lint.sh
  )

  expected_root_files=$'.gitignore\nLICENSE\nREADME.md\nbootstrap.sh\nsetup.sh'
  actual_root_files="$(find "$REPO_DIR" -mindepth 1 -maxdepth 1 -type f -exec basename {} \; | sort)"
  assert_equals "$expected_root_files" "$actual_root_files" "root file ownership"

  expected_root_directories=$'platforms\nshared\ntests'
  actual_root_directories="$(list_shipped_root_directories "$REPO_DIR")"
  assert_equals "$expected_root_directories" "$actual_root_directories" "root directory ownership"

  for path in "${required_paths[@]}"; do
    [[ -f "$REPO_DIR/$path" ]] || fail "required final path: $path"
  done
  for path in \
    lib util config packages scripts docs/ubuntu-lab.md \
    shared/config/zsh/.p10k.zsh \
    platforms/ubuntu/modules/security.sh platforms/ubuntu/modules/vscode.sh; do
    [[ ! -e "$REPO_DIR/$path" ]] || fail "legacy path remains: $path"
  done

  while IFS= read -r source_path; do
    source_path="${source_path#source \"\$DOTFILES_DIR/}"
    source_path="${source_path%\"}"
    if [[ "$source_path" == *'${PLATFORM}'* ]]; then
      for platform in macos ubuntu; do
        resolved_path="${source_path//'${PLATFORM}'/$platform}"
        [[ -f "$REPO_DIR/$resolved_path" ]] || fail "sourced production path exists: $resolved_path"
      done
      continue
    fi
    [[ -f "$REPO_DIR/$source_path" ]] || fail "sourced production path exists: $source_path"
  done < <(
    grep -Eho 'source "\$DOTFILES_DIR/[^${][^"]*"' \
      "$REPO_DIR/bootstrap.sh" "$REPO_DIR/setup.sh" \
      "$REPO_DIR/shared"/*.sh "$REPO_DIR/shared/modules"/*.sh \
      "$REPO_DIR/platforms"/*/*.sh "$REPO_DIR/platforms"/*/*/*.sh 2>/dev/null || true
  )

  if contains_forbidden_scope \
    "$REPO_DIR/README.md" "$REPO_DIR/bootstrap.sh" "$REPO_DIR/setup.sh" \
    "$REPO_DIR/shared" "$REPO_DIR/platforms"; then
    fail "removed or purpose-specific scope remains"
  fi

  if grep -Eirn 'macos|ubuntu|apt|snap|brew|libvirt|OSTYPE|/Library|/usr' \
    "$REPO_DIR/shared/modules" >/dev/null; then
    fail "platform knowledge remains in shared modules"
  fi
  assert_equals "1" "$(grep -R -h '^pass() {' "$REPO_DIR/tests" "$REPO_DIR/shared" "$REPO_DIR/platforms" | wc -l | tr -d ' ')" \
    "test-only TAP pass helper"
  assert_equals "1" "$(grep -R -h '^fail() {' "$REPO_DIR/tests" "$REPO_DIR/shared" "$REPO_DIR/platforms" | wc -l | tr -d ' ')" \
    "test-only TAP fail helper"
  pass "final paths and generic capability scope are enforced"
}

test_bash_syntax() {
  local script

  while IFS= read -r -d '' script; do
    bash -n "$script"
  done < <(find_shipped_bash_scripts "$REPO_DIR")
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

test_ubuntu_adapter_finds_mise_installed_later_in_same_process() {
  local home_dir="$TEST_ROOT/ubuntu-mise-path-home" output

  output="$(
    HOME="$home_dir" PATH=/usr/bin:/bin REPO_DIR="$REPO_DIR" bash -c '
      DOTFILES_DIR="$REPO_DIR"
      source "$REPO_DIR/platforms/ubuntu/adapter.sh"
      mkdir -p "$HOME/.local/bin"
      printf "#!/bin/sh\nexit 0\n" > "$HOME/.local/bin/mise"
      chmod +x "$HOME/.local/bin/mise"
      command -v mise || printf "missing\n"
    '
  )"
  assert_equals "$home_dir/.local/bin/mise" "$output" \
    "Ubuntu adapter discovers mise installed during setup"
  pass "Ubuntu setup discovers a standard mise install without restarting the shell"
}

test_ubuntu_adapter_path_is_idempotent() {
  local home_dir="$TEST_ROOT/ubuntu-adapter-path-home" output

  output="$(
    HOME="$home_dir" PATH=/usr/bin:/bin REPO_DIR="$REPO_DIR" bash -c '
      DOTFILES_DIR="$REPO_DIR"
      source "$REPO_DIR/platforms/ubuntu/adapter.sh"
      path_after_first_source="$PATH"
      source "$REPO_DIR/platforms/ubuntu/adapter.sh"
      [[ "$PATH" == "$path_after_first_source" ]]
      printf "%s\n" "$PATH"
    '
  )"
  assert_equals "$home_dir/.local/bin:/usr/bin:/bin" "$output" \
    "Ubuntu adapter user-local PATH idempotency"
  pass "Ubuntu adapter adds its standard user-local bin directory once"
}

main_detection() {
  REPO_DIR="$REPO_DIR" bash -c '
    set -e
    source "$REPO_DIR/shared/lib/log.sh"
    source "$REPO_DIR/shared/lib/platform.sh"
    detect_platform
    printf "%s %s\\n" "$PLATFORM" "$PLATFORM_VERSION"
  '
}

bootstrap_detection() {
  REPO_DIR="$REPO_DIR" bash -c '
    source "$REPO_DIR/bootstrap.sh"
    bootstrap_detect_platform
  '
}

assert_detection_case() {
  local name="$1" kernel="$2" os_id="$3" version="$4" arch="$5" expected_status="$6"
  local release_file="$TEST_ROOT/os-release-${name}" main_output bootstrap_output main_status bootstrap_status
  printf 'ID=%s\nVERSION_ID="%s"\n' "$os_id" "$version" > "$release_file"

  set +e
  main_output="$(
    DOTFILES_KERNEL_OVERRIDE="$kernel" DOTFILES_ARCH_OVERRIDE="$arch" \
      DOTFILES_OS_RELEASE_FILE="$release_file" main_detection 2>/dev/null
  )"
  main_status=$?
  bootstrap_output="$(
    DOTFILES_KERNEL_OVERRIDE="$kernel" DOTFILES_ARCH_OVERRIDE="$arch" \
      DOTFILES_OS_RELEASE_FILE="$release_file" bootstrap_detection 2>/dev/null
  )"
  bootstrap_status=$?
  set -e

  assert_equals "$expected_status" "$main_status" "${name} main detector status"
  assert_equals "$expected_status" "$bootstrap_status" "${name} bootstrap detector status"
  if [[ "$expected_status" == "0" ]]; then
    if [[ "$kernel" == "Darwin" ]]; then
      assert_equals "macos" "${main_output%% *}" "${name} main platform"
      assert_equals "macos" "$bootstrap_output" "${name} bootstrap platform"
    else
      assert_equals "ubuntu 26.04" "$main_output" "${name} main platform"
      assert_equals "ubuntu" "$bootstrap_output" "${name} bootstrap platform"
    fi
  fi
}

test_bootstrap_detector_parity() {
  local fake_bin="$TEST_ROOT/detector-bin"
  mkdir -p "$fake_bin"
  printf '#!/bin/sh\nprintf "15.0\\n"\n' > "$fake_bin/sw_vers"
  chmod +x "$fake_bin/sw_vers"

  PATH="$fake_bin:$PATH" assert_detection_case ubuntu-supported Linux ubuntu 26.04 x86_64 0
  PATH="$fake_bin:$PATH" assert_detection_case ubuntu-old Linux ubuntu 24.04 x86_64 1
  PATH="$fake_bin:$PATH" assert_detection_case debian Linux debian 26.04 x86_64 1
  PATH="$fake_bin:$PATH" assert_detection_case ubuntu-arm Linux ubuntu 26.04 aarch64 1
  PATH="$fake_bin:$PATH" assert_detection_case macos Darwin ignored ignored ignored 0
  pass "bootstrap and setup detectors accept the same supported platforms"
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

check_output() {
  local platform="$1" version="$2" home_dir="$3"
  shift 3
  set +e
  DOTFILES_PLATFORM_OVERRIDE="$platform" \
    DOTFILES_PLATFORM_VERSION_OVERRIDE="$version" \
    HOME="$home_dir" \
    "$REPO_DIR/setup.sh" --check "$@" 2>&1
  set -e
}

repository_snapshot() {
  find "$REPO_DIR" -path "$REPO_DIR/.git" -prune -o -type f -exec cksum {} \; | sort
}

# The fake mise script expands its variables only when the fixture runs.
# shellcheck disable=SC2016
prepare_mise_tool_fixture() {
  local fixture_root="$1" executable
  mkdir -p \
    "$fixture_root/control" \
    "$fixture_root/mise/shims" \
    "$fixture_root/mise/installs/node/old/bin" \
    "$fixture_root/mise/installs/node/current/bin"
  printf '#!/bin/sh\nif [ "$1" = which ] && [ "$2" = node ] && [ -n "${MISE_WHICH_RESULT:-}" ]; then\n  printf "%%s\\n" "$MISE_WHICH_RESULT"\n  exit 0\nfi\nexit 1\n' > "$fixture_root/control/mise"
  for executable in \
    "$fixture_root/mise/shims/node" \
    "$fixture_root/mise/installs/node/old/bin/node" \
    "$fixture_root/mise/installs/node/current/bin/node"; do
    printf '#!/bin/sh\nexit 0\n' > "$executable"
    chmod +x "$executable"
  done
  chmod +x "$fixture_root/control/mise"
}

run_mise_tool_check() {
  local fixture_root="$1" command_dir="$2" which_result="$3"
  set +e
  MISE_TOOL_OUTPUT="$(
    PATH="$command_dir:$fixture_root/control:$PATH" \
      MISE_WHICH_RESULT="$which_result" \
      REPO_DIR="$REPO_DIR" \
      bash -c '
        source "$REPO_DIR/shared/lib/log.sh"
        source "$REPO_DIR/shared/lib/verify.sh"
        source "$REPO_DIR/shared/modules/mise.sh"
        verify_mise_tool node
        verify_finish
      ' 2>&1
  )"
  MISE_TOOL_STATUS=$?
  set -e
}

test_mise_tool_rejects_stale_shim() {
  local fixture_root="$TEST_ROOT/mise-stale-shim"
  prepare_mise_tool_fixture "$fixture_root"

  run_mise_tool_check "$fixture_root" "$fixture_root/mise/shims" ""

  assert_equals "1" "$MISE_TOOL_STATUS" "stale mise shim status"
  [[ "$MISE_TOOL_OUTPUT" == *"FAIL: node is not provided by mise"* ]] ||
    fail "stale mise shim result"
  pass "mise ownership rejects stale shims"
}

test_mise_tool_rejects_mismatched_active_install() {
  local fixture_root="$TEST_ROOT/mise-mismatched-install"
  prepare_mise_tool_fixture "$fixture_root"

  run_mise_tool_check \
    "$fixture_root" \
    "$fixture_root/mise/installs/node/old/bin" \
    "$fixture_root/mise/installs/node/current/bin/node"

  assert_equals "1" "$MISE_TOOL_STATUS" "mismatched mise install status"
  [[ "$MISE_TOOL_OUTPUT" == *"FAIL: node is not provided by mise"* ]] ||
    fail "mismatched mise install result"
  pass "mise ownership rejects inactive install paths"
}

test_mise_tool_accepts_active_direct_install_and_shim() {
  local fixture_root="$TEST_ROOT/mise-active-install"
  prepare_mise_tool_fixture "$fixture_root"

  run_mise_tool_check \
    "$fixture_root" \
    "$fixture_root/mise/installs/node/current/bin" \
    "$fixture_root/mise/installs/node/current/bin/node"
  assert_equals "0" "$MISE_TOOL_STATUS" "active direct mise install status"
  [[ "$MISE_TOOL_OUTPUT" == *"PASS: node is provided by mise"* ]] ||
    fail "active direct mise install result"

  run_mise_tool_check \
    "$fixture_root" \
    "$fixture_root/mise/shims" \
    "$fixture_root/mise/installs/node/current/bin/node"
  assert_equals "0" "$MISE_TOOL_STATUS" "active mise shim status"
  [[ "$MISE_TOOL_OUTPUT" == *"PASS: node is provided by mise"* ]] ||
    fail "active mise shim result"
  pass "mise ownership accepts active direct installs and shims"
}

# Fake command scripts expand marker variables only when the fixtures run.
# shellcheck disable=SC2016
test_check_mode_selection_and_safety() {
  local home_dir fake_bin sudo_marker package_marker system_marker after created_path output repo_before repo_after
  home_dir="$TEST_ROOT/check-home"
  fake_bin="$TEST_ROOT/check-bin"
  sudo_marker="$TEST_ROOT/check-sudo-ran"
  package_marker="$TEST_ROOT/check-package-mutated"
  system_marker="$TEST_ROOT/check-system-mutated"
  mkdir -p "$home_dir" "$fake_bin"
  printf '#!/bin/sh\ntouch "$CHECK_SUDO_MARKER"\nexit 99\n' > "$fake_bin/sudo"
  printf '#!/bin/sh\ntouch "$CHECK_PACKAGE_MARKER"\nexit 99\n' > "$fake_bin/apt-get"
  printf '#!/bin/sh\ncase "$1 $2 $3" in\n  "list code ") exit 0 ;;\n  "info --verbose code") printf "  confinement:       classic\\n"; exit 0 ;;\n  *) touch "$CHECK_PACKAGE_MARKER"; exit 99 ;;\nesac\n' > "$fake_bin/snap"
  printf '#!/bin/sh\ncase "$1 $2" in\n  "bundle check") exit 0 ;;\n  *) touch "$CHECK_PACKAGE_MARKER"; exit 99 ;;\nesac\n' > "$fake_bin/brew"
  printf '#!/bin/sh\ntouch "$CHECK_SYSTEM_MARKER"\nexit 99\n' > "$fake_bin/chsh"
  printf '#!/bin/sh\ntouch "$CHECK_SYSTEM_MARKER"\nexit 99\n' > "$fake_bin/usermod"
  printf '#!/bin/sh\ncase "$1" in\n  is-enabled | is-active) exit 1 ;;\n  *) touch "$CHECK_SYSTEM_MARKER"; exit 99 ;;\nesac\n' > "$fake_bin/systemctl"
  printf '#!/bin/sh\ncase "$3" in\n  net-info | net-dumpxml) exit 1 ;;\n  *) touch "$CHECK_SYSTEM_MARKER"; exit 99 ;;\nesac\n' > "$fake_bin/virsh"
  chmod +x \
    "$fake_bin/sudo" "$fake_bin/apt-get" "$fake_bin/snap" "$fake_bin/brew" \
    "$fake_bin/chsh" "$fake_bin/usermod" "$fake_bin/systemctl" "$fake_bin/virsh"
  repo_before="$(repository_snapshot)"
  output="$(PATH="$fake_bin:$PATH" CHECK_SUDO_MARKER="$sudo_marker" CHECK_PACKAGE_MARKER="$package_marker" \
    CHECK_SYSTEM_MARKER="$system_marker" \
    check_output ubuntu 26.04 "$home_dir" --profile networking)"
  [[ "$output" == *"Checking packages"* ]] || fail "base package check selection"
  [[ "$output" == *"PASS: VS Code is installed as a classic Snap"* ]] || \
    fail "classic VS Code Snap check"
  [[ "$output" == *"Checking networking"* ]] || fail "networking check selection"
  [[ "$output" != *"N/A: networking has no meaningful automated check"* ]] || \
    fail "networking check implementation"
  [[ "$output" != *"Checking virtualization"* ]] || fail "unselected virtualization check"

  output="$(PATH="$fake_bin:$PATH" CHECK_PACKAGE_MARKER="$package_marker" \
    check_output macos test "$home_dir" --module packages)"
  [[ "$output" == *"Checking packages"* ]] || fail "macOS package check selection"
  [[ ! -e "$package_marker" ]] || fail "check mode mutated package state"

  output="$(PATH="$fake_bin:$PATH" CHECK_SUDO_MARKER="$sudo_marker" CHECK_PACKAGE_MARKER="$package_marker" \
    CHECK_SYSTEM_MARKER="$system_marker" \
    check_output ubuntu 26.04 "$home_dir" --profile virtualization networking)"
  [[ "$output" == *"Checking networking"* && "$output" == *"Checking virtualization"* ]] || \
    fail "composed profile checks"
  output="$(check_output macos test "$home_dir" --module system)"
  [[ "$output" == *"N/A: system has no meaningful automated check"* ]] || \
    fail "explicit not-applicable system check"

  after="$(find "$home_dir" -mindepth 1 -print | sort)"
  repo_after="$(repository_snapshot)"
  while IFS= read -r created_path; do
    [[ -n "$created_path" ]] || continue
    case "$created_path" in
      "$home_dir/.local" | \
      "$home_dir/.local/share" | \
      "$home_dir/.local/share/mise" | \
      "$home_dir/.local/share/mise/migrations" | \
      "$home_dir/.local/share/mise/migrations/"* | \
      "$home_dir/.cache" | \
      "$home_dir/.cache/mise" | \
      "$home_dir/.cache/mise/"* | \
      "$home_dir/Library" | \
      "$home_dir/Library/Caches" | \
      "$home_dir/Library/Caches/mise" | \
      "$home_dir/Library/Caches/mise/"*) ;;
      *) fail "check mode mutated unrelated HOME path: $created_path" ;;
    esac
  done <<< "$after"
  assert_equals "$repo_before" "$repo_after" "check mode repository state"
  [[ ! -e "$sudo_marker" ]] || fail "check mode requested privilege"
  [[ ! -e "$package_marker" ]] || fail "check mode mutated package state"
  [[ ! -e "$system_marker" ]] || fail "check mode mutated system configuration"
  pass "check mode uses profile resolution and avoids protected mutations"
}

test_production_helper_ownership() {
  assert_equals "1" "$(grep -R -h '^run() {' "$REPO_DIR/shared" "$REPO_DIR/platforms" | wc -l | tr -d ' ')" "single run helper"
  assert_equals "1" "$(grep -R -h '^verify_pass() {' "$REPO_DIR/shared" "$REPO_DIR/platforms" | wc -l | tr -d ' ')" "single verify reporter"
  assert_equals "1" "$(grep -R -h '^link_config() {' "$REPO_DIR/shared" "$REPO_DIR/platforms" | wc -l | tr -d ' ')" "single link helper"
  pass "production helpers have one owner"
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

test_composed_optional_profiles() {
  local order
  order="$(module_order ubuntu 26.04 "$TEST_ROOT/composed-home" \
    --profile virtualization networking virtualization)"
  assert_equals \
    "packages zsh eza mise ghostty git networking virtualization" \
    "$order" \
    "profile union, deduplication, and canonical order"
  pass "optional profiles compose independently of CLI order"
}

test_virtualization_profile_selects_concrete_qemu_provider() {
  local home_dir output virtualization_install

  home_dir="$TEST_ROOT/virtualization-provider-home"
  mkdir -p "$home_dir"
  output="$(
    DOTFILES_PLATFORM_OVERRIDE=ubuntu \
      DOTFILES_PLATFORM_VERSION_OVERRIDE=26.04 \
      HOME="$home_dir" \
      "$REPO_DIR/setup.sh" --dry-run --profile virtualization
  )"
  virtualization_install="$(grep 'sudo apt-get install -y' <<< "$output" | tail -n 1)"

  [[ " $virtualization_install " == *" qemu-system-x86 "* ]] ||
    fail "virtualization install command does not select qemu-system-x86"
  [[ " $virtualization_install " != *" qemu-kvm "* ]] ||
    fail "virtualization install command retains ambiguous qemu-kvm package"
  pass "virtualization profile selects a concrete QEMU provider"
}

test_libvirt_policy_inspection() {
  REPO_DIR="$REPO_DIR" bash -c '
    set -euo pipefail
    source "$REPO_DIR/shared/lib/log.sh"
    source "$REPO_DIR/shared/lib/command.sh"
    source "$REPO_DIR/platforms/ubuntu/lib/libvirt.sh"

    fake_isolated() {
      case "$1 $2" in
        "net-info vm-isolated") printf "Active: yes\nAutostart: yes\n" ;;
        "net-dumpxml vm-isolated") printf "%s\n" \
          "<network><ip address=\"192.168.77.1\" netmask=\"255.255.255.0\"><dhcp><range start=\"192.168.77.100\" end=\"192.168.77.254\"/></dhcp></ip></network>" ;;
        *) return 1 ;;
      esac
    }
    fake_shipped_isolated() {
      cat "$REPO_DIR/platforms/ubuntu/config/libvirt/vm-isolated.xml"
    }
    fake_forwarded() {
      printf "%s\n" \
        "<network><forward mode=\"nat\"/><ip address=\"192.168.77.1\" netmask=\"255.255.255.0\"/></network>"
    }
    fake_wrong_subnet() {
      printf "%s\n" \
        "<network><ip address=\"192.168.88.1\" netmask=\"255.255.255.0\"/></network>"
    }
    fake_split_subnet() {
      printf "%s\n" \
        "<network><ip address=\"192.168.77.1\"/><ip address=\"192.168.88.1\" netmask=\"255.255.255.0\"/></network>"
    }
    fake_metadata_isolated() {
      printf "%s\n" \
        "<network><metadata><ip xmlns=\"urn:example\" address=\"192.168.77.1\" netmask=\"255.255.255.0\"><dhcp><range start=\"192.168.77.100\" end=\"192.168.77.254\"/></dhcp></ip></metadata></network>"
    }
    fake_missing_dhcp() {
      printf "%s\n" \
        "<network><ip address=\"192.168.77.1\" netmask=\"255.255.255.0\"/></network>"
    }
    fake_wrong_range() {
      printf "%s\n" \
        "<network><ip address=\"192.168.77.1\" netmask=\"255.255.255.0\"><dhcp><range start=\"192.168.77.2\" end=\"192.168.77.99\"/></dhcp></ip></network>"
    }
    fake_extra_subnet() {
      printf "%s\n" \
        "<network><ip address=\"192.168.77.1\" netmask=\"255.255.255.0\"><dhcp><range start=\"192.168.77.100\" end=\"192.168.77.254\"/></dhcp></ip><ip address=\"192.168.88.1\" netmask=\"255.255.255.0\"/></network>"
    }
    fake_nested_range() {
      printf "%s\n" \
        "<network><ip address=\"192.168.77.1\" netmask=\"255.255.255.0\"><metadata><dhcp><range start=\"192.168.77.100\" end=\"192.168.77.254\"/></dhcp></metadata></ip></network>"
    }
    fake_extra_range() {
      printf "%s\n" \
        "<network><ip address=\"192.168.77.1\" netmask=\"255.255.255.0\"><dhcp><range start=\"192.168.77.100\" end=\"192.168.77.254\"/><range start=\"192.168.77.2\" end=\"192.168.77.99\"/></dhcp></ip></network>"
    }
    fake_attribute_impersonation() {
      printf "%s\n" \
        "<network><ip note=\" address='\''192.168.77.1'\''\" data=\" netmask='\''255.255.255.0'\''\"><dhcp><range start=\"192.168.77.100\" end=\"192.168.77.254\"/></dhcp></ip></network>"
    }
    fake_duplicate_attribute() {
      printf "%s\n" \
        "<network><ip address=\"192.168.77.1\" address=\"192.168.88.1\" netmask=\"255.255.255.0\"><dhcp><range start=\"192.168.77.100\" end=\"192.168.77.254\"/></dhcp></ip></network>"
    }
    fake_malformed() {
      printf "%s\n" \
        "<network><ip address=\"192.168.77.1\" netmask=\"255.255.255.0\"><dhcp><range start=\"192.168.77.100\" end=\"192.168.77.254\"/></ip></dhcp></network>"
    }
    fake_malformed_closing_tag() {
      printf "%s\n" \
        "<network><ip address=\"192.168.77.1\" netmask=\"255.255.255.0\"><dhcp><range start=\"192.168.77.100\" end=\"192.168.77.254\"/></dhcp ignored></ip></network>"
    }
    fake_adjacent_attributes() {
      printf "%s\n" \
        "<network><ip address=\"192.168.77.1\"netmask=\"255.255.255.0\"><dhcp><range start=\"192.168.77.100\" end=\"192.168.77.254\"/></dhcp></ip></network>"
    }
    fake_unterminated_xml_declaration() {
      printf "%s\n" \
        "<?xml version=\"1.0\"><network><ip address=\"192.168.77.1\" netmask=\"255.255.255.0\"><dhcp><range start=\"192.168.77.100\" end=\"192.168.77.254\"/></dhcp></ip></network>"
    }
    fake_separated_xml_declaration_terminator() {
      printf "%s\n" \
        "<?xml version=\"1.0\"? ><network><ip address=\"192.168.77.1\" netmask=\"255.255.255.0\"><dhcp><range start=\"192.168.77.100\" end=\"192.168.77.254\"/></dhcp></ip></network>"
    }
    fake_valid_xml_declaration() {
      printf "%s\n" \
        "<?xml version=\"1.0\"?><network><ip address=\"192.168.77.1\" netmask=\"255.255.255.0\"><dhcp><range start=\"192.168.77.100\" end=\"192.168.77.254\"/></dhcp></ip></network>"
    }
    fake_xml_spaces_around_equals() {
      printf "%s\n" \
        "<network><ip address = \"192.168.77.1\" netmask= '\''255.255.255.0'\''><dhcp><range start = \"192.168.77.100\" end= '\''192.168.77.254'\''/></dhcp></ip></network>"
    }
    fake_nat() {
      printf "%s\n" "<network><forward mode=\"nat\"/></network>"
    }
    fake_unterminated_nat_declaration() {
      printf "%s\n" "<?xml version=\"1.0\"><network><forward mode=\"nat\"/></network>"
    }
    fake_disjoint_nat() {
      printf "%s\n" \
        "<network><forward mode=\"route\"/><metadata mode=\"nat\"/></network>"
    }
    fake_metadata_nat() {
      printf "%s\n" \
        "<network><forward mode=\"route\"/><metadata><forward xmlns=\"urn:example\" mode=\"nat\"/></metadata></network>"
    }

    assert_isolated_rejected() {
      if libvirt_network_matches_isolated_policy vm-isolated "$1"; then
        printf "accepted invalid isolated-network fixture: %s\n" "$1" >&2
        return 1
      fi
    }

    libvirt_network_matches_isolated_policy vm-isolated fake_isolated
    libvirt_network_matches_isolated_policy vm-isolated fake_shipped_isolated
    assert_isolated_rejected fake_forwarded
    assert_isolated_rejected fake_wrong_subnet
    assert_isolated_rejected fake_split_subnet
    assert_isolated_rejected fake_metadata_isolated
    assert_isolated_rejected fake_missing_dhcp
    assert_isolated_rejected fake_wrong_range
    assert_isolated_rejected fake_extra_subnet
    assert_isolated_rejected fake_nested_range
    assert_isolated_rejected fake_extra_range
    assert_isolated_rejected fake_attribute_impersonation
    assert_isolated_rejected fake_duplicate_attribute
    assert_isolated_rejected fake_malformed
    assert_isolated_rejected fake_malformed_closing_tag
    residual_failures=0
    if libvirt_network_matches_isolated_policy vm-isolated fake_adjacent_attributes; then
      printf "accepted invalid isolated-network fixture: fake_adjacent_attributes\n" >&2
      residual_failures=$((residual_failures + 1))
    fi
    if libvirt_network_matches_isolated_policy vm-isolated fake_unterminated_xml_declaration; then
      printf "accepted invalid isolated-network fixture: fake_unterminated_xml_declaration\n" >&2
      residual_failures=$((residual_failures + 1))
    fi
    if libvirt_network_matches_isolated_policy vm-isolated fake_separated_xml_declaration_terminator; then
      printf "accepted invalid isolated-network fixture: fake_separated_xml_declaration_terminator\n" >&2
      residual_failures=$((residual_failures + 1))
    fi
    if ! libvirt_network_matches_isolated_policy vm-isolated fake_valid_xml_declaration; then
      printf "rejected valid isolated-network fixture: fake_valid_xml_declaration\n" >&2
      residual_failures=$((residual_failures + 1))
    fi
    if ! libvirt_network_matches_isolated_policy vm-isolated fake_xml_spaces_around_equals; then
      printf "rejected valid isolated-network fixture: fake_xml_spaces_around_equals\n" >&2
      residual_failures=$((residual_failures + 1))
    fi
    if libvirt_network_is_nat default fake_unterminated_nat_declaration; then
      printf "accepted invalid NAT-network fixture: fake_unterminated_nat_declaration\n" >&2
      residual_failures=$((residual_failures + 1))
    fi
    if ((residual_failures > 0)); then
      exit 1
    fi
    libvirt_network_is_nat default fake_nat
    if libvirt_network_is_nat default fake_disjoint_nat; then
      exit 1
    fi
    if libvirt_network_is_nat default fake_metadata_nat; then
      exit 1
    fi
  ' || fail "libvirt isolated-network policy inspection"

  grep -q '<name>vm-isolated</name>' "$REPO_DIR/platforms/ubuntu/config/libvirt/vm-isolated.xml" || fail "neutral network name"
  grep -q '192.168.77.1' "$REPO_DIR/platforms/ubuntu/config/libvirt/vm-isolated.xml" || fail "isolated subnet"
  if grep -q '<forward' "$REPO_DIR/platforms/ubuntu/config/libvirt/vm-isolated.xml"; then
    fail "isolated network forwarding"
  fi
  pass "libvirt inspection rejects forwarding and subnet conflicts"
}

test_libvirt_state_checks_consume_complete_output() {
  REPO_DIR="$REPO_DIR" bash -c '
    set -euo pipefail
    source "$REPO_DIR/platforms/ubuntu/lib/libvirt.sh"

    verbose_net_info() {
      local field="$1" index
      printf "%s: yes\n" "$field"
      for ((index = 0; index < 4096; index++)); do
        printf "Trailing: %08d xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx\n" "$index"
      done
    }
    verbose_active() { verbose_net_info Active; }
    verbose_autostart() { verbose_net_info Autostart; }

    libvirt_network_is_active default verbose_active
    libvirt_network_autostarts default verbose_autostart
  ' || fail "libvirt state checks consume complete output"

  pass "libvirt state checks avoid successful-match SIGPIPE failures"
}

test_libvirt_network_start_race_converges() {
  local trace_file="$TEST_ROOT/libvirt-start-race-trace"

  REPO_DIR="$REPO_DIR" TRACE_FILE="$trace_file" bash -c '
    set -euo pipefail
    source "$REPO_DIR/shared/lib/log.sh"
    source "$REPO_DIR/shared/lib/command.sh"
    source "$REPO_DIR/platforms/ubuntu/lib/libvirt.sh"

    DRY_RUN=false
    fake_virsh() {
      printf "%s\n" "$*" >> "$TRACE_FILE"
      case "$1 $2" in
        "net-info default")
          if grep -qx "net-start default" "$TRACE_FILE"; then
            printf "Active: yes\nAutostart: no\n"
          else
            printf "Active: no\nAutostart: no\n"
          fi
          ;;
        "net-start default") return 55 ;;
        "net-autostart default") return 0 ;;
        *) return 1 ;;
      esac
    }

    output="$(libvirt_ensure_network_started default fake_virsh)"

    [[ "$output" != *"Command failed"* ]]
    grep -qx "net-autostart default" "$TRACE_FILE"
  ' || fail "libvirt start race convergence"

  pass "libvirt accepts a network that becomes active during start"
}

test_virtualization_stops_after_failed_default_start() {
  local trace_file="$TEST_ROOT/virtualization-failure-trace"

  REPO_DIR="$REPO_DIR" TRACE_FILE="$trace_file" bash -c '
    set -euo pipefail
    source "$REPO_DIR/shared/lib/log.sh"
    source "$REPO_DIR/shared/lib/command.sh"
    source "$REPO_DIR/setup.sh"
    source "$REPO_DIR/platforms/ubuntu/lib/libvirt.sh"
    source "$REPO_DIR/platforms/ubuntu/modules/virtualization.sh"

    DRY_RUN=false
    DOTFILES_DIR="$REPO_DIR"
    USER=tester
    apt_install_manifest() { :; }
    id() { printf "libvirt kvm\n"; }
    systemctl() { return 0; }
    e_note() { printf "note:%s\n" "$1" >> "$TRACE_FILE"; }
    fake_virsh() {
      printf "%s\n" "$*" >> "$TRACE_FILE"
      case "$1 $2" in
        "net-info default") printf "Active: no\nAutostart: no\n" ;;
        "net-dumpxml default") printf "%s\n" \
          "<network><forward mode=\"nat\"/></network>" ;;
        "net-start default") return 42 ;;
        "net-info vm-isolated") return 1 ;;
        *) return 0 ;;
      esac
    }
    LIBVIRT_SYSTEM_VIRSH=(fake_virsh)

    set +e
    run_guarded_function setup_virtualization
    set -e

    [[ "$GUARDED_FUNCTION_STATUS" -eq 42 ]]
    grep -qx "net-start default" "$TRACE_FILE"
    ! grep -Eq "net-autostart default|vm-isolated|No VM or guest image" "$TRACE_FILE"
  ' >/dev/null 2>&1 || fail "virtualization stops after failed default network start"

  pass "virtualization stops before later mutations after a failed default network start"
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

test_composed_networking_profile_refreshes_apt_once() {
  local home_dir output update_count

  home_dir="$TEST_ROOT/networking-refresh-home"
  mkdir -p "$home_dir"
  output="$(
    DOTFILES_PLATFORM_OVERRIDE=ubuntu \
      DOTFILES_PLATFORM_VERSION_OVERRIDE=26.04 \
      HOME="$home_dir" \
      "$REPO_DIR/setup.sh" --dry-run --profile networking
  )"
  update_count="$(grep -c 'sudo apt-get update' <<< "$output")"
  assert_equals "1" "$update_count" "composed networking profile refreshes APT once"
  pass "composed networking profile shares an APT metadata refresh"
}

test_guarded_function_restores_err_context() {
  local case_name output case_exit

  for case_name in success ordinary_failure missing_function; do
    set +e
    output="$(
      REPO_DIR="$REPO_DIR" bash -c '
        set -euo pipefail
        source "$REPO_DIR/setup.sh"
        trap ":" ERR
        set -E
        before_flags="$-"
        before_trap="$(trap -p ERR)"
        succeeds() { :; }
        fails_mid_function() { false; printf "continued\\n"; }
        case "$1" in
          success) run_guarded_function succeeds ;;
          ordinary_failure) run_guarded_function fails_mid_function ;;
          missing_function) run_guarded_function missing_guarded_function ;;
        esac
        after_flags="$-"
        after_trap="$(trap -p ERR)"
        [[ "$before_flags" == "$after_flags" ]] || exit 1
        [[ "$before_trap" == "$after_trap" ]] || exit 1
        printf "restored %s\\n" "$1"
      ' _ "$case_name" 2>/dev/null
    )"
    case_exit=$?
    set -e
    assert_equals "0" "$case_exit" "guard restores ERR context after $case_name"
    assert_equals "restored $case_name" "$output" "guard restores ERR context after $case_name"
  done
  pass "guarded functions restore caller ERR trap and errtrace state"
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

test_powerlevel10k_config_retirement_safety() {
  local home_dir foreign_target legacy_target

  home_dir="$TEST_ROOT/p10k-retirement-home"
  foreign_target="$TEST_ROOT/foreign-p10k.zsh"
  legacy_target="$REPO_DIR/shared/config/zsh/.p10k.zsh"
  mkdir -p "$home_dir"
  printf 'foreign\n' > "$foreign_target"

  ln -s "$legacy_target" "$home_dir/.p10k.zsh"
  HOME="$home_dir" REPO_DIR="$REPO_DIR" bash -c '
    set -euo pipefail
    DRY_RUN=false
    DOTFILES_DIR="$REPO_DIR"
    source "$REPO_DIR/shared/lib/log.sh"
    source "$REPO_DIR/shared/lib/command.sh"
    source "$REPO_DIR/shared/modules/zsh.sh"
    retire_powerlevel10k_config
  ' >/dev/null
  [[ ! -L "$home_dir/.p10k.zsh" ]] || fail "managed Powerlevel10k symlink retirement"

  ln -s "$foreign_target" "$home_dir/.p10k.zsh"
  HOME="$home_dir" REPO_DIR="$REPO_DIR" bash -c '
    set -euo pipefail
    DRY_RUN=false
    DOTFILES_DIR="$REPO_DIR"
    source "$REPO_DIR/shared/lib/log.sh"
    source "$REPO_DIR/shared/lib/command.sh"
    source "$REPO_DIR/shared/modules/zsh.sh"
    retire_powerlevel10k_config
  ' >/dev/null
  assert_equals "$foreign_target" "$(readlink "$home_dir/.p10k.zsh")" \
    "foreign Powerlevel10k symlink preservation"
  pass "Powerlevel10k retirement removes only the former managed symlink"
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
  local bootstrap_home fake_bin output

  bootstrap_home="$TEST_ROOT/bootstrap-home"
  fake_bin="$TEST_ROOT/bootstrap-dry-run-bin"
  mkdir -p "$bootstrap_home" "$fake_bin"
  printf '#!/bin/sh\nexit 0\n' > "$fake_bin/xcode-select"
  chmod +x "$fake_bin/xcode-select"
  output="$(
    HOME="$bootstrap_home" \
      DOTFILES_KERNEL_OVERRIDE=Darwin \
      DOTFILES_DIR="$bootstrap_home/.dotfiles" \
      PATH="$fake_bin:$PATH" \
      "$REPO_DIR/bootstrap.sh" --dry-run
  )"

  [[ "$output" == *"git clone"* ]] || fail "bootstrap dry-run clone plan"
  [[ "$output" != *"--branch"* ]] || fail "default bootstrap branch override"
  [[ "$output" != *"--single-branch"* ]] || fail "default bootstrap single-branch clone"
  [[ ! -e "$bootstrap_home/.dotfiles" ]] || fail "bootstrap dry-run created checkout"
  pass "bootstrap dry-run is side-effect-free before cloning"
}

test_bootstrap_branch_dry_run() {
  local bootstrap_home="$TEST_ROOT/bootstrap-branch-home"
  local fake_bin="$TEST_ROOT/bootstrap-branch-bin" output
  mkdir -p "$bootstrap_home" "$fake_bin"
  printf '#!/bin/sh\nexit 0\n' > "$fake_bin/xcode-select"
  chmod +x "$fake_bin/xcode-select"

  output="$(
    HOME="$bootstrap_home" \
      DOTFILES_KERNEL_OVERRIDE=Darwin \
      DOTFILES_DIR="$bootstrap_home/.dotfiles" \
      DOTFILES_BRANCH=feat/ubuntu-support \
      PATH="$fake_bin:$PATH" \
      "$REPO_DIR/bootstrap.sh" --dry-run
  )"

  [[ "$output" == *"git clone --branch feat/ubuntu-support --single-branch"* ]] ||
    fail "bootstrap selected branch clone plan"
  [[ ! -e "$bootstrap_home/.dotfiles" ]] || fail "branch bootstrap dry-run created checkout"
  pass "bootstrap dry-run selects an optional branch without side effects"
}

test_bootstrap_runs_from_stdin() {
  local bootstrap_home="$TEST_ROOT/bootstrap-stdin-home"
  local fake_bin="$TEST_ROOT/bootstrap-stdin-bin" output status
  mkdir -p "$bootstrap_home" "$fake_bin"
  printf '#!/bin/sh\nexit 0\n' > "$fake_bin/xcode-select"
  chmod +x "$fake_bin/xcode-select"

  set +e
  output="$(
    HOME="$bootstrap_home" \
      DOTFILES_KERNEL_OVERRIDE=Darwin \
      DOTFILES_DIR="$bootstrap_home/.dotfiles" \
      DOTFILES_BRANCH=feat/ubuntu-support \
      PATH="$fake_bin:$PATH" \
      bash -s -- --dry-run < "$REPO_DIR/bootstrap.sh" 2>&1
  )"
  status=$?
  set -e

  assert_equals "0" "$status" "bootstrap stdin execution status"
  [[ "$output" == *"git clone --branch feat/ubuntu-support --single-branch"* ]] ||
    fail "bootstrap stdin branch clone plan"
  [[ ! -e "$bootstrap_home/.dotfiles" ]] || fail "bootstrap stdin dry-run created checkout"
  pass "bootstrap executes safely from stdin with nounset enabled"
}

# The fake setup script expands its answer and output path when bootstrap runs it.
# shellcheck disable=SC2016
test_bootstrap_routes_setup_input() {
  local checkout="$TEST_ROOT/bootstrap-input-checkout"
  local home_dir="$TEST_ROOT/bootstrap-input-home"
  local fake_bin="$TEST_ROOT/bootstrap-input-bin"
  local terminal_input="$TEST_ROOT/bootstrap-terminal-input"
  local captured_input="$TEST_ROOT/bootstrap-captured-input"
  local missing_terminal="$TEST_ROOT/bootstrap-missing-terminal"
  local status

  mkdir -p "$checkout/.git" "$home_dir" "$fake_bin"
  printf '#!/bin/sh\nexit 0\n' > "$fake_bin/xcode-select"
  chmod +x "$fake_bin/xcode-select"
  printf '#!/bin/bash\nif IFS= read -r answer; then\n  printf "%%s\\n" "$answer"\nelse\n  printf "EOF\\n"\nfi > "$BOOTSTRAP_INPUT_FILE"\n' > "$checkout/setup.sh"
  chmod +x "$checkout/setup.sh"
  printf 'n\n' > "$terminal_input"

  HOME="$home_dir" DOTFILES_KERNEL_OVERRIDE=Darwin DOTFILES_DIR="$checkout" \
    DOTFILES_TTY_PATH="$terminal_input" BOOTSTRAP_INPUT_FILE="$captured_input" \
    PATH="$fake_bin:$PATH" bash -s < "$REPO_DIR/bootstrap.sh" >/dev/null
  assert_equals "n" "$(< "$captured_input")" \
    "bootstrap-from-stdin terminal input"

  printf 'piped\n' |
    HOME="$home_dir" DOTFILES_KERNEL_OVERRIDE=Darwin DOTFILES_DIR="$checkout" \
      DOTFILES_TTY_PATH="$terminal_input" BOOTSTRAP_INPUT_FILE="$captured_input" \
      PATH="$fake_bin:$PATH" "$REPO_DIR/bootstrap.sh" >/dev/null
  assert_equals "piped" "$(< "$captured_input")" \
    "file bootstrap piped input"

  set +e
  HOME="$home_dir" DOTFILES_KERNEL_OVERRIDE=Darwin DOTFILES_DIR="$checkout" \
    DOTFILES_TTY_PATH="$missing_terminal" BOOTSTRAP_INPUT_FILE="$captured_input" \
    PATH="$fake_bin:$PATH" bash -s < "$REPO_DIR/bootstrap.sh" >/dev/null
  status=$?
  set -e
  assert_equals "0" "$status" "bootstrap stdin without terminal status"
  assert_equals "EOF" "$(< "$captured_input")" \
    "bootstrap stdin without terminal fallback"
  pass "bootstrap routes setup input according to its invocation"
}

# The fake setup script expands argv and its output path when bootstrap runs it.
# shellcheck disable=SC2016
test_bootstrap_forwards_argv() {
  local checkout="$TEST_ROOT/bootstrap-checkout" fake_bin="$TEST_ROOT/bootstrap-bin"
  local argv_file="$TEST_ROOT/bootstrap-argv" output
  mkdir -p "$checkout/.git" "$fake_bin"
  printf '#!/bin/sh\nexit 0\n' > "$fake_bin/xcode-select"
  chmod +x "$fake_bin/xcode-select"
  printf '#!/bin/bash\nprintf "%%s\\n" "$@" > "$BOOTSTRAP_ARGV_FILE"\n' > "$checkout/setup.sh"
  chmod +x "$checkout/setup.sh"

  output="$(
    DOTFILES_KERNEL_OVERRIDE=Darwin DOTFILES_DIR="$checkout" \
      DOTFILES_BRANCH=feat/ignored-for-existing-checkout \
      BOOTSTRAP_ARGV_FILE="$argv_file" PATH="$fake_bin:$PATH" \
      "$REPO_DIR/bootstrap.sh" --check --profile virtualization networking
  )"

  [[ "$output" == *"Dotfiles already cloned"* ]] || fail "existing checkout detection"
  [[ "$output" != *"Cloning dotfiles"* ]] || fail "existing checkout branch clone"
  assert_equals $'--check\n--profile\nvirtualization\nnetworking' "$(sed -n '1,4p' "$argv_file")" \
    "bootstrap argv forwarding"
  pass "bootstrap forwards setup selectors unchanged"
}

# The fake setup script expands argv and marker paths when bootstrap runs it.
# shellcheck disable=SC2016
test_bootstrap_dry_run_forwards_argv_with_checkout() {
  local checkout="$TEST_ROOT/bootstrap-dry-run-checkout" fake_bin="$TEST_ROOT/bootstrap-dry-run-checkout-bin"
  local argv_file="$TEST_ROOT/bootstrap-dry-run-argv" execution_file="$TEST_ROOT/bootstrap-dry-run-executions"
  mkdir -p "$checkout/.git" "$fake_bin"
  printf '#!/bin/sh\nexit 0\n' > "$fake_bin/xcode-select"
  chmod +x "$fake_bin/xcode-select"
  printf '#!/bin/bash\nprintf "%%s\\n" "$@" > "$BOOTSTRAP_ARGV_FILE"\nprintf "executed\\n" >> "$BOOTSTRAP_EXECUTION_FILE"\n' > "$checkout/setup.sh"
  chmod +x "$checkout/setup.sh"

  DOTFILES_KERNEL_OVERRIDE=Darwin DOTFILES_DIR="$checkout" BOOTSTRAP_ARGV_FILE="$argv_file" \
    BOOTSTRAP_EXECUTION_FILE="$execution_file" PATH="$fake_bin:$PATH" "$REPO_DIR/bootstrap.sh" \
    --dry-run --profile virtualization networking >/dev/null

  [[ -e "$argv_file" ]] || fail "bootstrap dry-run did not execute setup in an existing checkout"
  assert_equals $'--dry-run\n--profile\nvirtualization\nnetworking' "$(sed -n '1,4p' "$argv_file")" \
    "bootstrap dry-run argv forwarding"
  assert_equals "1" "$(wc -l < "$execution_file" | tr -d ' ')" "bootstrap dry-run setup executions"
  pass "bootstrap dry-run forwards selectors through an existing checkout"
}

# The fake mise script expands its arguments only when zsh starts up.
# shellcheck disable=SC2016
test_mise_shims_precede_legacy_user_tools() {
  local home_dir="$TEST_ROOT/mise-shim-precedence-home"
  local fake_bin="$TEST_ROOT/mise-shim-precedence-bin"
  local output expected

  mkdir -p \
    "$home_dir/.local/bin" \
    "$home_dir/.local/share/mise/shims" \
    "$home_dir/.oh-my-zsh" \
    "$home_dir/.config/zsh" \
    "$fake_bin"
  printf '%s\n' '#!/bin/sh' 'exit 0' > "$home_dir/.local/bin/uv"
  printf '%s\n' '#!/bin/sh' 'exit 0' > "$home_dir/.local/bin/local-helper"
  printf '%s\n' '#!/bin/sh' 'exit 0' > "$home_dir/.local/share/mise/shims/uv"
  printf '%s\n' \
    '#!/bin/sh' \
    '[ "$#" -eq 2 ] && [ "$1" = "activate" ] && [ "$2" = "zsh" ] || exit 90' \
    'exit 0' > "$fake_bin/mise"
  printf '%s\n' \
    '#!/bin/sh' \
    '[ "$#" -eq 2 ] && [ "$1" = "init" ] && [ "$2" = "zsh" ] || exit 90' \
    'exit 0' > "$fake_bin/starship"
  chmod +x \
    "$home_dir/.local/bin/uv" \
    "$home_dir/.local/bin/local-helper" \
    "$home_dir/.local/share/mise/shims/uv" \
    "$fake_bin/mise" "$fake_bin/starship"
  : > "$home_dir/.oh-my-zsh/oh-my-zsh.sh"
  : > "$home_dir/.aliases"
  : > "$home_dir/.config/zsh/platform.zsh"

  output="$(
    HOME="$home_dir" PATH="$fake_bin:/usr/bin:/bin" REPO_DIR="$REPO_DIR" zsh -dfc '
      source "$REPO_DIR/shared/config/zsh/.zshrc"
      source "$REPO_DIR/shared/config/zsh/.zshrc"
      printf "uv=%s\n" "$(command -v uv)"
      printf "local=%s\n" "$(command -v local-helper)"
      shim_count=0
      for entry in "${path[@]}"; do
        [[ "$entry" == "$HOME/.local/share/mise/shims" ]] && ((shim_count += 1))
      done
      printf "shim-count=%s\n" "$shim_count"
    '
  )"
  expected="$(printf 'uv=%s\nlocal=%s\nshim-count=1' \
    "$home_dir/.local/share/mise/shims/uv" \
    "$home_dir/.local/bin/local-helper")"

  assert_equals "$expected" "$output" "mise shim PATH precedence"
  pass "mise shims precede legacy user tools without hiding unrelated commands"
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
  grep -qx 'starship' "$REPO_DIR/platforms/ubuntu/packages/base.apt" || fail "Starship Ubuntu package"
  grep -qx 'brew "starship"' "$REPO_DIR/platforms/macos/packages/Brewfile" || fail "Starship Homebrew package"
  if grep -Eq '^(iproute2|iputils-ping|dnsutils|netcat-openbsd|tcpdump|traceroute|mtr-tiny|whois|qemu-kvm|qemu-system-x86|libvirt)' \
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
  # These patterns intentionally match literal prompt variables and command substitution.
  # shellcheck disable=SC2016
  grep -Fqx 'eval "$(starship init zsh)"' "$REPO_DIR/shared/config/zsh/.zshrc" ||
    fail "Starship Zsh initialization"
  grep -Fqx 'success_symbol = "[❯](pink)"' \
    "$REPO_DIR/shared/config/starship/starship.toml" || fail "Starship Pure preset character"
  grep -Fqx 'palette = "catppuccin_latte"' \
    "$REPO_DIR/shared/config/starship/starship.toml" || fail "Starship Catppuccin Latte palette"
  grep -Fqx 'mauve = "#8839ef"' \
    "$REPO_DIR/shared/config/starship/starship.toml" || fail "Starship Catppuccin Latte colors"
  # shellcheck disable=SC2016
  if grep -Eq '\$(aws|azure|gcloud|kubernetes|terraform)' \
    "$REPO_DIR/shared/config/starship/starship.toml"; then
    fail "cloud context leaked into the Starship Pure preset"
  fi
  if grep -Eq 'powerlevel10k\.git|ZSH_THEME="powerlevel10k|source .*\.p10k\.zsh' \
    "$REPO_DIR/shared/modules/zsh.sh" "$REPO_DIR/shared/config/zsh/.zshrc"; then
    fail "Powerlevel10k remains active"
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

# Fake downloader/client scripts expand markers only in their child processes.
# shellcheck disable=SC2016
test_remote_installers_fail_on_download_errors() {
  local fake_bin="$TEST_ROOT/remote-installer-bin"
  local ubuntu_curl_marker="$TEST_ROOT/ubuntu-installer-curl"
  local ubuntu_continuation="$TEST_ROOT/ubuntu-installer-continued"
  local zsh_curl_marker="$TEST_ROOT/zsh-installer-curl"
  local zsh_continuation="$TEST_ROOT/zsh-installer-continued"
  local brew_curl_marker="$TEST_ROOT/brew-installer-curl"
  local brew_continuation="$TEST_ROOT/brew-installer-continued"
  local status

  mkdir -p "$fake_bin" "$TEST_ROOT/remote-ubuntu-home" \
    "$TEST_ROOT/remote-zsh-home" "$TEST_ROOT/remote-brew-home"
  printf '%s\n' \
    '#!/bin/sh' \
    ': > "$CURL_MARKER"' \
    'exit 23' > "$fake_bin/curl"
  printf '%s\n' '#!/bin/sh' 'exit 0' > "$fake_bin/zsh"
  printf '%s\n' \
    '#!/bin/sh' \
    ': > "$CONTINUATION_MARKER"' \
    'exit 0' > "$fake_bin/git"
  chmod +x "$fake_bin/curl" "$fake_bin/zsh" "$fake_bin/git"

  set +e
  PATH="$fake_bin:$PATH" REPO_DIR="$REPO_DIR" HOME="$TEST_ROOT/remote-ubuntu-home" \
    CURL_MARKER="$ubuntu_curl_marker" CONTINUATION_MARKER="$ubuntu_continuation" bash -c '
      source "$REPO_DIR/shared/lib/log.sh"
      source "$REPO_DIR/shared/lib/command.sh"
      source "$REPO_DIR/platforms/ubuntu/modules/packages.sh"
      DRY_RUN=false
      DOTFILES_DIR="$REPO_DIR"
      apt_install_manifest() { :; }
      snap_install_manifest() { :; }
      command() {
        if [[ "$1" == "-v" && "$2" == "mise" ]]; then
          return 1
        fi
        builtin command "$@"
      }
      setup_packages
      status=$?
      [[ "$status" -ne 0 ]] || : > "$CONTINUATION_MARKER"
      exit "$status"
    ' >/dev/null 2>&1
  status=$?
  set -e
  assert_equals "23" "$status" "Ubuntu mise installer preserves curl failure"
  [[ -e "$ubuntu_curl_marker" ]] || fail "Ubuntu mise download failure was not exercised"
  [[ ! -e "$ubuntu_continuation" ]] || fail "Ubuntu package setup continued after mise download failure"

  set +e
  PATH="$fake_bin:$PATH" REPO_DIR="$REPO_DIR" HOME="$TEST_ROOT/remote-zsh-home" \
    CURL_MARKER="$zsh_curl_marker" CONTINUATION_MARKER="$zsh_continuation" bash -c '
      source "$REPO_DIR/shared/lib/log.sh"
      source "$REPO_DIR/shared/lib/command.sh"
      source "$REPO_DIR/shared/modules/zsh.sh"
      DRY_RUN=false
      DOTFILES_DIR="$REPO_DIR"
      PLATFORM_ZSH_FRAGMENT="$REPO_DIR/platforms/ubuntu/config/zsh/platform.zsh"
      SHELL=""
      link_config() { :; }
      ensure_local_copy() { :; }
      platform_change_login_shell() { :; }
      setup_zsh
      status=$?
      [[ "$status" -ne 0 ]] || : > "$CONTINUATION_MARKER"
      exit "$status"
    ' >/dev/null 2>&1
  status=$?
  set -e
  assert_equals "23" "$status" "Zsh installer preserves curl failure"
  [[ -e "$zsh_curl_marker" ]] || fail "Zsh download failure was not exercised"
  [[ ! -e "$zsh_continuation" ]] || fail "Zsh setup continued after installer download failure"

  set +e
  PATH="$fake_bin:$PATH" REPO_DIR="$REPO_DIR" HOME="$TEST_ROOT/remote-brew-home" \
    CURL_MARKER="$brew_curl_marker" CONTINUATION_MARKER="$brew_continuation" bash -c '
      source "$REPO_DIR/shared/lib/log.sh"
      source "$REPO_DIR/platforms/macos/modules/packages.sh"
      DRY_RUN=false
      DOTFILES_DIR="$REPO_DIR"
      command() {
        if [[ "$1" == "-v" && "$2" == "brew" ]]; then
          return 1
        fi
        builtin command "$@"
      }
      run() {
        if [[ "$1" == "/bin/bash" ]]; then
          "$@"
        else
          : > "$CONTINUATION_MARKER"
        fi
      }
      setup_packages
      status=$?
      [[ "$status" -ne 0 ]] || : > "$CONTINUATION_MARKER"
      exit "$status"
    ' >/dev/null 2>&1
  status=$?
  set -e
  assert_equals "23" "$status" "Homebrew installer preserves curl failure"
  [[ -e "$brew_curl_marker" ]] || fail "Homebrew download failure was not exercised"
  [[ ! -e "$brew_continuation" ]] || fail "macOS package setup continued after Homebrew download failure"
  pass "remote installers stop immediately when curl fails"
}

test_git_offers_optional_identity_choice() {
  local configured_home="$TEST_ROOT/git-configured-home"
  local dry_home="$TEST_ROOT/git-dry-home"
  local output
  mkdir -p "$configured_home" "$dry_home"
  HOME="$configured_home" git config --global user.name "Configured Name"
  HOME="$configured_home" git config --global user.email "configured@example.com"

  output="$(
    HOME="$configured_home" REPO_DIR="$REPO_DIR" bash -c '
      source "$REPO_DIR/shared/lib/log.sh"
      source "$REPO_DIR/shared/lib/command.sh"
      source "$REPO_DIR/shared/modules/git.sh"
      DRY_RUN=true
      setup_git
    '
  )"
  [[ "$output" != *"Configure a global Git commit identity?"* ]] ||
    fail "complete Git identity choice prompt"

  output="$(
    HOME="$dry_home" REPO_DIR="$REPO_DIR" bash -c '
      source "$REPO_DIR/shared/lib/log.sh"
      source "$REPO_DIR/shared/lib/command.sh"
      source "$REPO_DIR/shared/modules/git.sh"
      DRY_RUN=true
      setup_git
    '
  )"
  [[ "$output" == *"prompt to configure a global Git commit identity"* ]] ||
    fail "missing Git identity dry-run choice"
  [[ ! -e "$dry_home/.gitconfig" ]] || fail "Git identity dry-run mutation"
  pass "Git setup offers one optional identity choice without dry-run mutation"
}

test_git_persists_opt_out_and_prompts_only_for_missing_values() {
  local opt_out_home="$TEST_ROOT/git-opt-out-home"
  local partial_home="$TEST_ROOT/git-partial-home"
  local output
  mkdir -p "$opt_out_home" "$partial_home"

  output="$(
    printf 'n\n' |
      HOME="$opt_out_home" REPO_DIR="$REPO_DIR" bash -c '
        source "$REPO_DIR/shared/lib/log.sh"
        source "$REPO_DIR/shared/lib/command.sh"
        source "$REPO_DIR/shared/modules/git.sh"
        DRY_RUN=false
        setup_git
      '
  )"
  assert_equals "true" "$(HOME="$opt_out_home" git config --global --get user.useConfigOnly)" \
    "Git identity opt-out persistence"
  assert_equals "true" "$(HOME="$opt_out_home" git config --global --get pull.rebase)" \
    "Git pull.rebase after identity opt-out"

  output="$(
    HOME="$opt_out_home" REPO_DIR="$REPO_DIR" bash -c '
      source "$REPO_DIR/shared/lib/log.sh"
      source "$REPO_DIR/shared/lib/command.sh"
      source "$REPO_DIR/shared/modules/git.sh"
      DRY_RUN=false
      setup_git </dev/null
    '
  )"
  [[ "$output" != *"Configure a global Git commit identity?"* ]] ||
    fail "persisted Git identity opt-out prompted again"

  HOME="$partial_home" git config --global user.name "Configured Name"
  output="$(
    printf '\nconfigured@example.com\n' |
      HOME="$partial_home" REPO_DIR="$REPO_DIR" bash -c '
        source "$REPO_DIR/shared/lib/log.sh"
        source "$REPO_DIR/shared/lib/command.sh"
        source "$REPO_DIR/shared/modules/git.sh"
        DRY_RUN=false
        setup_git
      '
  )"
  [[ "$output" == *"Configure a global Git commit identity?"* ]] ||
    fail "partial Git identity choice prompt"
  [[ "$output" != *"Type the name"* ]] || fail "configured Git name prompted again"
  [[ "$output" == *"Type your git email"* ]] || fail "missing Git email prompt"
  assert_equals "Configured Name" "$(HOME="$partial_home" git config --global --get user.name)" \
    "preserved Git name"
  assert_equals "configured@example.com" \
    "$(HOME="$partial_home" git config --global --get user.email)" "configured Git email"
  pass "Git setup persists opt-out and prompts only for missing identity values"
}

run_git_check() {
  local home_dir="$1"
  HOME="$home_dir" REPO_DIR="$REPO_DIR" bash -c '
    source "$REPO_DIR/shared/lib/log.sh"
    source "$REPO_DIR/shared/lib/verify.sh"
    source "$REPO_DIR/shared/modules/git.sh"
    check_git
    verify_finish
  ' 2>&1
}

test_git_check_accepts_identity_or_explicit_opt_out() {
  local identity_home="$TEST_ROOT/git-check-identity-home"
  local opt_out_home="$TEST_ROOT/git-check-opt-out-home"
  local invalid_home="$TEST_ROOT/git-check-invalid-home"
  local output status home_dir
  mkdir -p "$identity_home" "$opt_out_home" "$invalid_home"

  for home_dir in "$identity_home" "$opt_out_home" "$invalid_home"; do
    HOME="$home_dir" git config --global pull.rebase true
  done
  HOME="$identity_home" git config --global user.name "Configured Name"
  HOME="$identity_home" git config --global user.email "configured@example.com"
  HOME="$opt_out_home" git config --global user.useConfigOnly true
  HOME="$invalid_home" git config --global user.name "Incomplete Name"

  output="$(run_git_check "$identity_home")"
  [[ "$output" == *"PASS: Git commit identity is configured"* ]] ||
    fail "complete Git identity check"

  set +e
  output="$(run_git_check "$opt_out_home")"
  status=$?
  set -e
  assert_equals "0" "$status" "Git identity opt-out check status"
  [[ "$output" == *"PASS: Git identity guessing is disabled"* ]] ||
    fail "Git identity opt-out check"

  set +e
  output="$(run_git_check "$invalid_home")"
  status=$?
  set -e
  assert_equals "1" "$status" "incomplete Git identity check status"
  [[ "$output" == *"FAIL: Git commit identity is incomplete and user.useConfigOnly is not true"* ]] ||
    fail "incomplete Git identity check guidance"
  pass "Git check accepts complete identity or explicit opt-out"
}

test_forbidden_scope_term_boundaries
test_shipped_root_directories_ignore_optional_design_roots
test_gitignore_has_no_tracked_files
test_shipped_bash_discovery_ignores_design_artifacts
test_lint_contract
test_final_repository_structure_and_scope
test_bash_syntax
test_platform_detection
test_ubuntu_adapter_finds_mise_installed_later_in_same_process
test_ubuntu_adapter_path_is_idempotent
test_bootstrap_detector_parity
test_command_rendering_and_failure_status
test_verify_reporter_status
test_mise_tool_rejects_mismatched_active_install
test_mise_tool_rejects_stale_shim
test_mise_tool_accepts_active_direct_install_and_shim
test_check_mode_selection_and_safety
test_production_helper_ownership
test_module_ordering
test_networking_profile
test_composed_optional_profiles
test_virtualization_profile_selects_concrete_qemu_provider
test_remote_installers_fail_on_download_errors
test_libvirt_policy_inspection
test_libvirt_state_checks_consume_complete_output
test_libvirt_network_start_race_converges
test_virtualization_stops_after_failed_default_start
test_apt_refreshes_once_across_manifests
test_composed_networking_profile_refreshes_apt_once
test_guarded_function_restores_err_context
test_selector_contract
test_conflict_backup_and_idempotency
test_private_file_preserved
test_powerlevel10k_config_retirement_safety
test_dry_run_has_no_side_effects
test_bootstrap_dry_run
test_bootstrap_branch_dry_run
test_bootstrap_runs_from_stdin
test_bootstrap_routes_setup_input
test_bootstrap_forwards_argv
test_bootstrap_dry_run_forwards_argv_with_checkout
test_mise_shims_precede_legacy_user_tools
test_runtime_and_network_policy
test_package_scope
test_manifest_parsing
test_failure_propagation
test_git_offers_optional_identity_choice
test_git_persists_opt_out_and_prompts_only_for_missing_values
test_git_check_accepts_identity_or_explicit_opt_out

printf '1..%d\n' "$pass_count"
