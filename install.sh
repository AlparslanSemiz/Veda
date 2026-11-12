#!/bin/zsh
# One-line install:
#   curl -fsSL https://raw.githubusercontent.com/AlparslanSemiz/Veda/main/install.sh | zsh
# Builds Veda from source on your Mac (so Gatekeeper has nothing to quarantine),
# installs it to ~/Applications and starts it at login.
set -euo pipefail

REPO="https://github.com/AlparslanSemiz/Veda.git"
SRC="$HOME/.local/src/Veda"

if [[ "$(uname)" != "Darwin" ]]; then echo "Veda runs on macOS only."; exit 1; fi
if ! xcode-select -p >/dev/null 2>&1; then
  echo "Veda needs Apple's Command Line Tools to build. Starting the installer…"
  xcode-select --install || true
  echo "Run this script again when the Command Line Tools are installed."; exit 1
fi

echo "→ Getting the source"
if [[ -d "$SRC/.git" ]]; then git -C "$SRC" pull --ff-only --quiet
else mkdir -p "${SRC:h}"; git clone --quiet --depth 1 "$REPO" "$SRC"; fi

echo "→ Building"
"$SRC/build.sh"

echo
echo "Done. One permission is left: System Settings → Privacy & Security → Accessibility → Veda."
open "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility" 2>/dev/null || true
