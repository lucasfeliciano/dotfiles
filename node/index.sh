#!/bin/bash
source ../utils/utils.sh

FNM_DIR="$HOME/.fnm"

curl -fsSL https://fnm.vercel.app/install | bash -s -- --install-dir "$FNM_DIR" --skip-shell

fnm install --lts --fnm-dir "$FNM_DIR"
fnm default lts-latest