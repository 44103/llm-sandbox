#!/usr/bin/env bash
set -euo pipefail

INSTALL_DIR="${INSTALL_DIR:-$HOME/.local/bin}"
mkdir -p "$INSTALL_DIR"

OS="$(uname -s)"
case "$OS" in
  Linux)
    if systemctl --version &>/dev/null; then
      SRC="sandbox-systemd.sh"
    else
      SRC="sandbox-docker.sh"
    fi
    ;;
  Darwin)
    SRC="sandbox-macos.sh"
    ;;
  *)
    SRC="sandbox-docker.sh"
    ;;
esac

SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
ln -sf "$SCRIPT_DIR/$SRC" "$INSTALL_DIR/sandbox"
echo "Installed: $INSTALL_DIR/sandbox -> $SCRIPT_DIR/$SRC"
