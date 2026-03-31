# dotfiles

Making it easy to setup a new machine with node, pnpm and Oh My Zsh!

## What comes with setup?

1. [Homebrew & Cask](https://brew.sh)
2. [Oh My Zsh!](https://ohmyz.sh)
   1. [Powerlevel10k](https://github.com/romkatv/powerlevel10k) zsh theme
   2. [zsh-syntax-highlighting](https://github.com/zsh-users/zsh-syntax-highlighting) plugin
   3. [zsh-history-substring-search](https://github.com/zsh-users/zsh-history-substring-search) plugin
3. [mise](https://mise.jdx.dev) (with Node LTS and pnpm as defaults)
4. [Ghostty](https://ghostty.org)
5. Git configuration
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

Available modules: `brew`, `zsh`, `mise`, `ghostty`, `git`

### Configuration files

Configuration files are added to the right places with symbolic links. This keeps track of your environment changes so you can easily commit them.

#### Symbolic links

| File                           | Symbolic Link Location         | Description                                                  |
| ------------------------------ | ------------------------------ | ------------------------------------------------------------ |
| config/zsh/.zshrc              | ~/.zshrc                       | Main Zsh configuration file                                  |
| config/zsh/.p10k.zsh           | ~/.p10k.zsh                    | Powerlevel10k theme configuration                            |
| config/zsh/.aliases            | ~/.aliases                     | Custom terminal command shortcuts                            |
| config/zsh/.zshrc_private      | ~/.zshrc_private               | Private shell config (gitignored)                            |
| config/ghostty/config          | ~/.config/ghostty/config       | Ghostty terminal configuration                               |
| config/ghostty/themes          | ~/.config/ghostty/themes       | Ghostty themes directory                                     |
| config/mise/config.toml        | ~/.config/mise/config.toml     | mise runtime manager configuration                           |

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
│   ├── git.sh            # setup_git()
│   ├── ghostty.sh        # setup_ghostty()
│   └── mise.sh           # setup_mise()
└── config/
    ├── ghostty/           # Ghostty terminal config + themes
    ├── mise/              # mise runtime manager config
    └── zsh/               # Zsh dotfiles (.zshrc, .aliases, etc.)
```

#### Inspired by https://github.com/phoinixi/dotfiles
