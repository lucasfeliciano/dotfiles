# dotfiles

Making it easy to setup a new machine with node, pnpm and Oh My Zsh!

## Getting started

> **WARNING:**
>
> **This project was created to be used in a machine with zero configuration.**\
> **No backups are made. Use at your own risk.**

After cloning the repository run the following command in the root of the project.

```sh
$ sh setup.sh
```

### Configuration files

Configuration files are added to the right places with symbolic links. This is to keep track of your environemnt changes so you can easily commit them.

#### Symbolic links

| File                | Symbolic Link Location   | Description                                                                                   |
| ------------------- | ------------------------ | --------------------------------------------------------------------------------------------- |
| oh-my-zsh/.zshrc    | ~/.zshrc                 | Main Zsh configuration file, controlling shell behavior and plugins.                          |
| oh-my-zsh/.p10k.zsh | ~/.p10k.zsh              | Configuration file for the Powerlevel10k Zsh theme.                                           |
| oh-my-zsh/.aliases  | ~/.aliases               | File containing custom terminal command shortcuts (aliases).                                  |
| ghostty/config      | ~/.config/ghostty/config | Ghostty terminal configuration file. Manages settings for keybindings, themes, and behaviour. |

## What comes with setup?

1. [Homebrew & Cask](https://brew.sh)
2. [Ghostty](https://ghostty.org)
3. [Oh My Zsh!](https://ohmyz.sh)
   1. [spaceship-prompt](https://github.com/spaceship-prompt/spaceship-prompt)
   2. [zsh-syntax-highlighting](https://github.com/zsh-users/zsh-syntax-highlighting) plugin
   3. [zsh-history-substring-search](https://github.com/zsh-users/zsh-history-substring-search) plugin
4. [pnpm](https://pnpm.io) (with Node LTS as default)
5. Setup Git
   1. Prompt global user name
   2. Prompt global email
   3. Set pull strategy to rebase as default

#### Inspired by https://github.com/phoinixi/dotfiles
