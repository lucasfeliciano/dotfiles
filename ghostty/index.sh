#!/bin/bash
source ../utils/utils.sh

mkdir -p ~/.config/ghostty

# Link config file
ln -sf $(pwd)/config ~/.config/ghostty/config
ln -sf $(pwd)/themes ~/.config/ghostty/themes
