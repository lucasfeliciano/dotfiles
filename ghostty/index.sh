#!/bin/bash
source ../utils/utils.sh

mkdir -p ~/.config/ghostty

# Link config file
ln -sf $(pwd)/config ~/.config/ghostty/config
