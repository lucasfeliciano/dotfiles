# dotfiles

Making it easy to setup a new machine with node, bun and Oh My Zsh!

## Getting started 

> **WARNING:**
> 
> **This project was created to be used in a machine with zero configuration.**\
> **No backups are made. Use at your own risk.**

After cloning the repository run the following command in the root of the project.

```sh
$ sh setup.sh
```

## What comes with setup?

1. [Homebrew & Cask](https://brew.sh/)
2. [iterm2](https://iterm2.com/)
   1. default user profile (needs to be manually loaded)
   2. [catppuccin theme](https://github.com/catppuccin/iterm) (needs to be manually loaded)
4. [Oh My Zsh!](https://ohmyz.sh/)
   1. [spaceship-prompt](https://github.com/spaceship-prompt/spaceship-prompt)
   2. [zsh-syntax-highlighting](https://github.com/zsh-users/zsh-syntax-highlighting) plugin
   3. [zsh-history-substring-search](https://github.com/zsh-users/zsh-history-substring-search) plugin
5. [pnpm](https://pnpm.io/) (with Node LTS as default)
6. Setup Git
   1. Prompt global user name
   2. Prompt global email
   3. Set pull strategy to rebase as default

#### Inspired by https://github.com/phoinixi/dotfiles
