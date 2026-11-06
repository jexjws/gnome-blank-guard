#!/usr/bin/env bash
#
# gnome-blank-guard uninstaller
#
#   sudo ./uninstall.sh [username]

set -euo pipefail

BIN_NAME="gnome-blank-guard"
UNIT_NAME="${BIN_NAME}@.service"
PREFIX="/usr/local/bin"
UNIT_DIR="/etc/systemd/system"

die() { printf 'error: %s\n' "$*" >&2; exit 1; }

[[ $EUID -eq 0 ]] || die "run this script with sudo"

TARGET_USER="${1:-${SUDO_USER:-}}"

if [[ -n "$TARGET_USER" ]]; then
    echo "==> stopping and disabling ${BIN_NAME}@${TARGET_USER}.service"
    systemctl disable --now "${BIN_NAME}@${TARGET_USER}.service" || true
fi

echo "==> removing $UNIT_DIR/$UNIT_NAME"
rm -f "$UNIT_DIR/$UNIT_NAME"

echo "==> removing $PREFIX/$BIN_NAME"
rm -f "$PREFIX/$BIN_NAME"

systemctl daemon-reload

echo
echo "Done. Your config (~/.config/$BIN_NAME.conf) was left in place; delete it manually if you want."
