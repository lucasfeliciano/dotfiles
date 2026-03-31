# Logging and formatting helpers for dotfiles setup scripts.
# Sourced by setup.sh — do not execute directly.

# Fonts
bold=$'\033[1m'
underline=$'\033[4m'
reset=$'\033[0m'

# Colors — Catppuccin Latte
purple=$'\033[38;2;136;57;239m'   # Mauve
red=$'\033[38;2;210;15;57m'       # Red
green=$'\033[38;2;64;160;43m'     # Green
tan=$'\033[38;2;254;100;11m'      # Peach
blue=$'\033[38;2;4;165;229m'      # Sky

e_ask() {
  printf "\n${bold}%s${reset}" "$@"
}

e_thanks() {
  printf "\n${bold}${purple}%s${reset}\n" "$@"
}

e_header() {
  printf "\n${underline}${bold}${green}%s${reset}\n" "$@"
}

e_success() {
  printf "\n${green}✔ %s${reset}\n" "$@"
}

error() {
  printf "\n${red}✖ %s${reset}\n" "$@"
}

e_warning() {
  printf "\n${tan}ᐅ %s${reset}\n" "$@"
}

e_note() {
  printf "\n${underline}${bold}${blue}Note:${reset} ${blue}%s${reset}\n" "$@"
}

e_dry() {
  printf "\n${blue}[dry-run]${reset} %s\n" "$@"
}

# Run a command, or print it in dry-run mode.
run() {
  if [[ "${DRY_RUN:-false}" == "true" ]]; then
    e_dry "$*"
  else
    "$@"
  fi
}
