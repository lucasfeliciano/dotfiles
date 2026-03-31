#!/bin/bash
source ../utils/utils.sh

# Link mise config
mkdir -p ~/.config/mise
ln -sf $(pwd)/config.toml ~/.config/mise/config.toml

# Install Node LTS as global default
mise use --global node@lts

# Install pnpm as global default
mise use --global pnpm@latest
