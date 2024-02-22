#!/bin/bash
source ../utils/utils.sh

# Rename .zshrc to .zshrc.tmp to avoid bun adding the same lines to .zshrc
mv -f "$HOME/.zshrc" "$HOME/.zshrc.tmp"

# Install bun
curl -fsSL https://bun.sh/install | bash

# Restore .zshrc
mv -f "$HOME/.zshrc.tmp" "$HOME/.zshrc"

e_warning "The path was already added to .zshrc. Ignore message above."

