#!/bin/sh
source utils/utils.sh

# Install Homebrew
if test ! $(which brew); then
  e_header "Installing Homebrew"
  (cd brew ; source index.sh)
else
  e_header "Updating Homebrew"
  brew update
fi
e_success "brew updated done!"

# Install Brew dependencies
e_header "Installing dependencies from Brewfile"
brew tap Homebrew/bundle
brew bundle
e_success "dependencies installed!"

# Install Oh my zsh
e_header "Installing Oh my zsh"
(cd oh-my-zsh ; source index.sh)
e_success "Oh my zsh installed!"

# Install mise, node & pnpm
e_header "Installing mise, node & pnpm"
(cd mise ; source index.sh)
e_success "mise, node and pnpm setup done!"

# Configure Ghostty terminal
e_header "Setting up Ghostty terminal"
(cd ghostty ; source index.sh)
e_success "Ghostty setup done!"

# Configure Git
e_header "Setting up Git"
(cd git ; source index.sh)
e_success "Git setup done!"



e_thanks "Author: https://github.com/lucasfeliciano"
e_note "Inpired by https://github.com/phoinixi/dotfiles"
