# dotfiles

Consistent development-shell configuration composed from shared capabilities and platform-specific profiles.

## Supported platforms

| Platform | Supported target | Base profile |
| --- | --- | --- |
| macOS | Current macOS on the existing Intel/Apple Silicon Homebrew paths | `packages zsh eza mise ghostty git system` |
| Ubuntu | Ubuntu 26.04 amd64 only | `packages zsh eza mise ghostty git` |

## Quick start

On a new machine, run the bootstrap:

```sh
curl -fsSL https://raw.githubusercontent.com/lucasfeliciano/dotfiles/main/bootstrap.sh | bash
```

From an existing checkout, run:

```sh
./setup.sh
```

The bootstrap installs only the prerequisites needed to clone the repository and hand off to setup. Review a dry-run before applying optional profiles.

## Profiles and modules

A module is one focused operation. A profile is an ordered, complete-machine composition of modules.

| Platform | Profile | Membership |
| --- | --- | --- |
| macOS | `base` | `packages zsh eza mise ghostty git system` |
| Ubuntu | `base` | `packages zsh eza mise ghostty git` |
| Ubuntu | `networking` | `networking`, composed after `base` |
| Ubuntu | `virtualization` | `virtualization`, composed after `base` |

Optional profiles always include `base`. Multiple optional profiles form a deduplicated union in canonical module order. Direct module selection adds no dependencies; include every prerequisite module you need.

## Command reference

These are the supported command forms:

```sh
./setup.sh
./setup.sh --profile networking
./setup.sh --profile virtualization
./setup.sh --profile virtualization networking
./setup.sh --module mise ghostty
./setup.sh --dry-run --profile virtualization
./setup.sh --check
./setup.sh --check --profile networking
./setup.sh --check --profile virtualization networking
```

`--profile` and `--module` are mutually exclusive. Positional modules are unsupported.

## Managed configuration

| Repository file | Destination |
| --- | --- |
| `shared/config/zsh/.zshrc` | `~/.zshrc` |
| `shared/config/zsh/.p10k.zsh` | `~/.p10k.zsh` |
| `shared/config/zsh/.aliases` | `~/.aliases` |
| `platforms/<platform>/config/zsh/platform.zsh` | `~/.config/zsh/platform.zsh` |
| `shared/config/eza/theme.yml` | `~/.config/eza/theme.yml` |
| `shared/config/ghostty/config` | `~/.config/ghostty/config` |
| `platforms/<platform>/config/ghostty.conf` | `~/.config/ghostty/platform` |
| `shared/config/mise/config.toml` | `~/.config/mise/config.toml` |
| `shared/config/uv/uv.toml` | `~/.config/uv/uv.toml` |

Managed configuration is linked from the checkout so repository changes remain visible at their destinations.

## Backups, reruns, and dry-run

A correct managed symlink is left untouched. If a destination is an unmanaged file, directory, or different symlink, setup moves it under one run-specific timestamped tree while preserving its home-relative path:

```text
~/.dotfiles-backup/20260725-143015-12345/.config/eza/theme.yml
```

This backup-tree behavior makes reruns safe and idempotent without silently destroying local configuration.

`~/.zshrc_private` is different: setup copies the template only when the file is absent. It remains an untracked local regular file and is never replaced on reruns.

Dry-run renders quoted command arguments and planned file operations without changing the home directory, repository, privileged state, or network resources.

After setup changes the login shell or group membership, log out and back in. A reboot applies both changes as well.

## Git identity

On both macOS and Ubuntu, Git setup asks whether to configure a global commit
identity when `user.name` or `user.email` is missing. Accepting prompts only for
the missing values. Declining sets `user.useConfigOnly=true`, which prevents Git
from guessing an identity from the local account and hostname and records the
choice for future setup runs.

Existing identity values are never removed. To revisit an opt-out while the
identity is incomplete, run:

```sh
git config --global --unset user.useConfigOnly
./setup.sh --module git
```

Git identity is commit metadata, not authentication. This setup does not
configure Git credentials, remotes, or SSH keys. Both identity choices retain
the managed `pull.rebase=true` default and pass check mode.

## Check mode

Check mode resolves the same base, optional-profile, or direct-module selection as setup, then performs read-only verification. It does not request privilege, install packages, alter configuration, or repair failed checks. A failed check exits nonzero and prints the setup action that can remediate it.

## Runtime ownership

Mise owns the global user-level executables for Node LTS, stable Python, pnpm, and uv on both platforms. Shell activation places mise's Python ahead of the operating-system Python without replacing or linking over it.

Uv owns Python project environments and dependencies:

- `uv sync` creates and updates `.venv`.
- `uv.lock`, `uv run`, and `uvx` remain uv responsibilities.
- Uv prefers external interpreters, so it selects a compatible mise Python first.
- When a project's `.python-version` or `requires-python` needs another version, uv may download that version for the project.
- A project-specific downloaded runtime is not promoted to the shell's global Python.

The global uv policy is:

```toml
python-preference = "system"
python-downloads = "automatic"
```

Mise enables idiomatic version-file handling for Node only. It does not auto-install Python from `.python-version`, which keeps mise and uv from competing for project-specific Python versions. Do not run `uv python install --default`, because it can create global `python` and `python3` aliases outside this ownership boundary.

---

Inspired by [phoinixi/dotfiles](https://github.com/phoinixi/dotfiles).
