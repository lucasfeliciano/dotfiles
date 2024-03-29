#!/bin/bash
source ../utils/utils.sh

ZSH="$HOME/.oh-my-zsh"
ZSH_CUSTOM="$ZSH/custom"

if [ -d "$ZSH" ]; then
  e_warning "Oh My Zsh is already installed. skipping.."
else
  sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
fi

# Install spaceship theme
if [ -d "$ZSH_CUSTOM/themes/spaceship-prompt" ]; then
  e_warning "Spaceship theme is already installed. skipping.."
else
  git clone https://github.com/spaceship-prompt/spaceship-prompt.git "$ZSH_CUSTOM/themes/spaceship-prompt" --depth=1
  ln -sf "$ZSH_CUSTOM/themes/spaceship-prompt/spaceship.zsh-theme" "$ZSH_CUSTOM/themes/spaceship.zsh-theme"
fi

# To install ZSH themes & aliases
ln -sf $(pwd)/.aliases ~/.aliases
ln -sf $(pwd)/.zshrc ~/.zshrc
