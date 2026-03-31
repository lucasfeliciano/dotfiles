# macOS system preferences.
# Sourced by setup.sh — do not execute directly.

setup_macos() {
  # ── Dock ──────────────────────────────────────────────────────────────────
  # Auto-hide the Dock
  run defaults write com.apple.dock autohide -bool true

  # Don't show recently used apps section in the Dock
  run defaults write com.apple.dock show-recents -bool false

  # Remove open-app indicator dots
  run defaults write com.apple.dock show-process-indicators -bool false

  # ── Desktop ───────────────────────────────────────────────────────────────
  # Disable widgets on desktop
  run defaults write com.apple.WindowManager StandardHideWidgets -bool true

  # ── Menu Bar ──────────────────────────────────────────────────────────────
  # Show volume in menu bar (18 = always show in menu bar)
  run defaults -currentHost write com.apple.controlcenter Sound -int 18

  run killall Dock
  run killall SystemUIServer 2>/dev/null || true
}
