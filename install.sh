#!/usr/bin/env bash
#
# gnome-blank-guard installer
#
#   sudo ./install.sh [username]
#
# Installs the daemon to /usr/local/bin, installs the systemd template unit and
# enables it for the given user (default: $SUDO_USER, i.e. the caller of sudo).

set -euo pipefail

BIN_NAME="gnome-blank-guard"
UNIT_NAME="${BIN_NAME}@.service"
PREFIX="/usr/local/bin"
UNIT_DIR="/etc/systemd/system"

die() { printf 'error: %s\n' "$*" >&2; exit 1; }

[[ $EUID -eq 0 ]] || die "run this script with sudo"

TARGET_USER="${1:-${SUDO_USER:-}}"
[[ -n "$TARGET_USER" ]] || die "cannot determine the target user; pass it explicitly: sudo ./install.sh <username>"
id "$TARGET_USER" >/dev/null 2>&1 || die "user '$TARGET_USER' does not exist"

SRC_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "==> installing $BIN_NAME to $PREFIX"
install -Dm755 "$SRC_DIR/$BIN_NAME" "$PREFIX/$BIN_NAME"

echo "==> installing $UNIT_NAME to $UNIT_DIR"
install -Dm644 "$SRC_DIR/$UNIT_NAME" "$UNIT_DIR/$UNIT_NAME"

echo "==> installing example config for $TARGET_USER"
USER_HOME="$(getent passwd "$TARGET_USER" | cut -d: -f6)"
CONF_DIR="$USER_HOME/.config"
CONF_FILE="$CONF_DIR/$BIN_NAME.conf"
if [[ -e "$CONF_FILE" ]]; then
    echo "    $CONF_FILE already exists, leaving it untouched"
else
    install -d -o "$TARGET_USER" -g "$TARGET_USER" "$CONF_DIR"
    install -m644 -o "$TARGET_USER" -g "$TARGET_USER" \
        "$SRC_DIR/$BIN_NAME.conf.example" "$CONF_FILE"
    echo "    wrote $CONF_FILE"
fi

echo "==> enabling ${BIN_NAME}@${TARGET_USER}.service"
systemctl daemon-reload
systemctl enable --now "${BIN_NAME}@${TARGET_USER}.service"

echo
echo "Done. Check the status with:"
echo "  systemctl status ${BIN_NAME}@${TARGET_USER}.service"
echo "  journalctl -u ${BIN_NAME}@${TARGET_USER}.service -f"
