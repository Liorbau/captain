#!/usr/bin/env bash
#
# Captain bootstrap - installs the `cptn` command onto your PATH.
#
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/Liorbau/captain/main/bootstrap.sh | bash
#
# Supported: macOS and Linux. Windows users: run this inside WSL or Git Bash.

set -euo pipefail

CAPTAIN_REF="${CAPTAIN_REF:-main}"
BASE_URL="https://raw.githubusercontent.com/Liorbau/captain/${CAPTAIN_REF}"
INSTALL_DIR="${CAPTAIN_INSTALL_DIR:-$HOME/.local/bin}"
TARGET="$INSTALL_DIR/cptn"

command -v curl >/dev/null 2>&1 || { echo "bootstrap: curl is required" >&2; exit 1; }

case "$(uname -s)" in
  Darwin|Linux) ;;
  *)
    echo "bootstrap: only macOS and Linux are supported directly." >&2
    echo "Windows: run this inside WSL or Git Bash (see the README)." >&2
    exit 1
    ;;
esac

mkdir -p "$INSTALL_DIR"

echo "Downloading cptn to $TARGET ..."
curl -fsSL "$BASE_URL/bin/cptn" -o "$TARGET"
chmod +x "$TARGET"

# Make sure the install dir is on PATH; add it to the user's shell rc if not.
case ":$PATH:" in
  *":$INSTALL_DIR:"*)
    ;;
  *)
    line="export PATH=\"$INSTALL_DIR:\$PATH\""
    rc=""
    case "${SHELL:-}" in
      */zsh)  rc="$HOME/.zshrc" ;;
      */bash) rc="$HOME/.bashrc" ;;
    esac
    if [ -n "$rc" ]; then
      if ! grep -qsF "$INSTALL_DIR" "$rc"; then
        printf '\n# Added by captain bootstrap\n%s\n' "$line" >> "$rc"
      fi
      echo ""
      echo "Added $INSTALL_DIR to your PATH in $rc"
      echo "Run:  source $rc   (or open a new terminal)"
    else
      echo ""
      echo "Add this line to your shell profile to use cptn:"
      echo "  $line"
    fi
    ;;
esac

echo ""
echo "Captain is aboard. Try:  cptn help"
