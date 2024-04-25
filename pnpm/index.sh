#!/bin/bash
source ../utils/utils.sh

# Rename .zshrc to .zshrc.tmp to avoid pnpm expose the path
mv -f "$HOME/.zshrc" "$HOME/.zshrc.tmp"

# Install pnpm
export PNPM_HOME="$HOME/.pnpm"
curl -fsSL https://get.pnpm.io/install.sh | sh -

# Install pnpm completions
pnpm completion zsh > "$PNPM_HOME/completion-for-pnpm.zsh"

# Install node lts
pnpm env use --global lts

# Restore .zshrc
mv -f "$HOME/.zshrc.tmp" "$HOME/.zshrc"
