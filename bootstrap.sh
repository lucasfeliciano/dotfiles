#!/bin/bash

DOTFILES_REPO="https://github.com/lucasfeliciano/dotfiles.git"
DOTFILES_DIR="$(pwd)/dotfiles"

printf "\n\033[1;4;32m🚀 Bootstrapping your machine...\033[0m\n\n"

# Install Xcode Command Line Tools (provides git)
if ! xcode-select -p &>/dev/null; then
  printf "\033[1;32m▸ Installing Xcode Command Line Tools...\033[0m\n"
  xcode-select --install
  printf "\033[1;33m⏳ Waiting for Xcode CLT installation to complete. Press any key when done.\033[0m\n"
  read -r -n 1
else
  printf "\033[1;32m✔ Xcode Command Line Tools already installed\033[0m\n"
fi

# Clone dotfiles
if [ ! -d "$DOTFILES_DIR" ]; then
  printf "\033[1;32m▸ Cloning dotfiles...\033[0m\n"
  git clone "$DOTFILES_REPO" "$DOTFILES_DIR"
else
  printf "\033[1;32m✔ Dotfiles already cloned\033[0m\n"
fi

# Source log helpers now that the repo is available
source "$DOTFILES_DIR/util/log.sh"

# Run setup
e_header "Running setup"
cd "$DOTFILES_DIR" && ./setup.sh
