# dotfiles

Making it easy to set up a new machine with a consistent shell, tools, and terminal.

## What comes with setup?

1. [Homebrew & Cask](https://brew.sh)
2. [Oh My Zsh](https://ohmyz.sh)
   1. [Powerlevel10k](https://github.com/romkatv/powerlevel10k) zsh theme
   2. [zsh-syntax-highlighting](https://github.com/zsh-users/zsh-syntax-highlighting) plugin
   3. [zsh-history-substring-search](https://github.com/zsh-users/zsh-history-substring-search) plugin
   4. [zsh-autosuggestions](https://github.com/zsh-users/zsh-autosuggestions) plugin
   5. [zsh-eza](https://github.com/z-shell/zsh-eza) plugin
3. [eza](https://github.com/eza-community/eza) (with Catppuccin Latte color theme)
4. [mise](https://mise.jdx.dev) (with Node LTS and pnpm as defaults)
5. [Ghostty](https://ghostty.org) (with built-in Catppuccin Latte theme)
6. Git configuration
   1. Prompt global user name
   2. Prompt global email
   3. Set pull strategy to rebase as default

## Installation

> **WARNING:**
>
> **This project was created to be used in a machine with zero configuration.**\
> **No backups are made. Use at your own risk.**

On a fresh machine, run the following command. It will install Xcode CLT, clone this repo, and run the full setup:

```sh
curl -fsSL https://raw.githubusercontent.com/lucasfeliciano/dotfiles/main/bootstrap.sh | bash
```

If you've already cloned the repo, run the setup directly:

```sh
./setup.sh
```

### Selective module execution

Run only specific modules by passing their names:

```sh
./setup.sh brew git       # Run only brew and git setup
./setup.sh zsh             # Run only zsh setup
```

Available modules: `brew`, `zsh`, `eza`, `mise`, `ghostty`, `git`

### Configuration files

Configuration files are added to the right places with symbolic links. This keeps track of your environment changes so you can easily commit them.

#### Symbolic links

| File                      | Symbolic Link Location         | Description                       |
| ------------------------- | ------------------------------ | --------------------------------- |
| config/zsh/.zshrc         | ~/.zshrc                       | Main Zsh configuration file       |
| config/zsh/.p10k.zsh      | ~/.p10k.zsh                    | Powerlevel10k theme configuration |
| config/zsh/.aliases       | ~/.aliases                     | Custom terminal command shortcuts |
| config/ghostty/config     | ~/.config/ghostty/config       | Ghostty terminal configuration    |
| config/eza/theme.yml      | ~/.config/eza/theme.yml        | eza color theme (Catppuccin Latte)|
| config/mise/config.toml   | ~/.config/mise/config.toml     | mise runtime manager configuration|

> `~/.zshrc_private` is copied from `config/zsh/.zshrc_private.template` on first run and kept local (not symlinked, not tracked).

### Repository structure

```
dotfiles/
├── bootstrap.sh          # Fresh machine entry point (curl-able)
├── setup.sh              # Main entry point: ./setup.sh [module...]
├── Brewfile              # Homebrew dependencies
├── util/
│   └── log.sh            # Logging and formatting helpers
├── lib/
│   ├── brew.sh           # setup_brew()
│   ├── zsh.sh            # setup_zsh()
│   ├── eza.sh            # setup_eza()
│   ├── git.sh            # setup_git()
│   ├── ghostty.sh        # setup_ghostty()
│   └── mise.sh           # setup_mise()
└── config/
    ├── eza/               # eza color theme (Catppuccin Latte)
    ├── ghostty/           # Ghostty terminal config
    ├── mise/              # mise runtime manager config
    └── zsh/               # Zsh dotfiles (.zshrc, .aliases, etc.)
```

---

Inspired by [phoinixi/dotfiles](https://github.com/phoinixi/dotfiles)
