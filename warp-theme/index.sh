#!/bin/bash
source ../utils/utils.sh

mkdir -p ~/.warp/themes/
curl --silent --output-dir ~/.warp/themes -LO https://raw.githubusercontent.com/catppuccin/warp/main/dist/catppuccin_latte.yml 

e_warning "Change the theme in WarpTerminal settings to Catppuccin Latte"
