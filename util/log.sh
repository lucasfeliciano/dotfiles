# Logging and formatting helpers for dotfiles setup scripts.
# Sourced by setup.sh — do not execute directly.

# Fonts
bold=$(tput bold)
underline=$(tput sgr 0 1)
reset=$(tput sgr0)

# Colors
purple=$(tput setaf 171)
red=$(tput setaf 1)
green=$(tput setaf 76)
tan=$(tput setaf 3)
blue=$(tput setaf 38)

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
