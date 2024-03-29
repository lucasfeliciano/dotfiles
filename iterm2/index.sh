#!/bin/bash
source ../utils/utils.sh

mkdir -p ~/.iterm2

# Link profile and color scheme
ln -sf $(pwd)/catppuccin-latte.itermcolors ~/.iterm2
ln -sf $(pwd)/iterm2-profile.json ~/.iterm2

e_warning "Load profile and color scheme on iTerm2 settings"
