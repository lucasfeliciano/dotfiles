#!/bin/bash
source ../utils/utils.sh

ZSH="$HOME/.oh-my-zsh"
ZSH_CUSTOM="$ZSH/custom"

if [ -d "$ZSH" ]; then
  e_warning "Oh My Zsh is already installed. skipping.."
else
  sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
fi

# Install zsh-syntax-highlighting
if [ -d "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting" ]; then
  e_warning "zsh-syntax-highlighting is already installed. skipping.."
else
  git clone https://github.com/zsh-users/zsh-syntax-highlighting.git ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting
fi

# Install zsh-history-substring-search
if [ -d "$ZSH_CUSTOM/plugins/zsh-history-substring-search" ]; then
  e_warning "zsh-history-substring-search is already installed. skipping.."
else
  git clone https://github.com/zsh-users/zsh-history-substring-search ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-history-substring-search
fi

# Install powerlevel10k theme
if [ -d "$ZSH_CUSTOM/themes/powerlevel10k" ]; then
  e_warning "powerlevel10k theme is already installed. skipping.."
else
  git clone --depth=1 https://github.com/romkatv/powerlevel10k.git ${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/themes/powerlevel10k
fi

# To install ZSH themes & aliases
ln -sf $(pwd)/.aliases ~/.aliases
ln -sf $(pwd)/.zshrc ~/.zshrc
ln -sf $(pwd)/.p10k.zsh ~/.p10k.zsh
ln -sf $(pwd)/.zshrc_private ~/.zshrc_private
