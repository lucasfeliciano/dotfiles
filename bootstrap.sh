#!/bin/sh

DOTFILES_REPO="https://github.com/lucasfeliciano/dotfiles.git"
DOTFILES_DIR="$(pwd)/dotfiles"

printf "\n\033[1;4;32m🚀 Bootstrapping your machine...\033[0m\n\n"

# Install Homebrew
if test ! $(which brew); then
  printf "\033[1;32m▸ Installing Homebrew...\033[0m\n"
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> ~/.zprofile
  eval "$(/opt/homebrew/bin/brew shellenv)"
else
  printf "\033[1;32m✔ Homebrew already installed\033[0m\n"
fi

# Install Git via Homebrew
if ! brew list git &>/dev/null; then
  printf "\033[1;32m▸ Installing Git...\033[0m\n"
  brew install git
else
  printf "\033[1;32m✔ Git already installed\033[0m\n"
fi

# Clone dotfiles
if [ ! -d "$DOTFILES_DIR" ]; then
  printf "\033[1;32m▸ Cloning dotfiles...\033[0m\n"
  git clone "$DOTFILES_REPO" "$DOTFILES_DIR"
else
  printf "\033[1;32m✔ Dotfiles already cloned\033[0m\n"
fi

# Run setup
printf "\033[1;32m▸ Running setup...\033[0m\n"
cd "$DOTFILES_DIR" && sh setup.sh
