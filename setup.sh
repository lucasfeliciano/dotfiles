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

