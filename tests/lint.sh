#!/bin/bash
set -euo pipefail

REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"

if ! command -v shellcheck >/dev/null 2>&1; then
  printf 'shellcheck is required; install it with the platform package module.\n' >&2
  exit 127
fi

while IFS= read -r -d '' script; do
  shellcheck -x -s bash "$script"
done < <(
  find "$REPO_DIR" \
    \( -path "$REPO_DIR/.git" -o -path "$REPO_DIR/.superpowers" -o -path "$REPO_DIR/docs/superpowers" \) -prune -o \
    -type f -name '*.sh' -print0
)
