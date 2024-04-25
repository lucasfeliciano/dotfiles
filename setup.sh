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

# Install pnpm & node lts
e_header "Installing pnpm & node lts"
(cd pnpm ; source index.sh)
e_success "pnpm and node setup done!"

# Install iTerm2
e_header "Installing iTerm2 profile and color scheme "
(cd iterm2 ; source index.sh)
e_success "iterm2 setup done!"

# Configure Git
e_header "Setting up Git"
(cd git ; source index.sh)
e_success "Git setup done!"



e_thanks "Author: https://github.com/lucasfeliciano"
e_note "Inpired by https://github.com/phoinixi/dotfiles"
