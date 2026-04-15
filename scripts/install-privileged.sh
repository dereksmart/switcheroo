#!/bin/bash
# One-time setup: installs the facade-save helper to /usr/local/bin
# and grants the current user passwordless sudo rights to run it.
# Prompts for your password once, then Facade never prompts again.
set -euo pipefail

cd "$(dirname "$0")"

USER_NAME=$(id -un)
HELPER_SRC="facade-save"
HELPER_DST="/usr/local/bin/facade-save"
SUDOERS_DST="/etc/sudoers.d/facade"

if [[ ! -f "$HELPER_SRC" ]]; then
  echo "error: $HELPER_SRC not found next to this script" >&2
  exit 1
fi

echo "Installing $HELPER_DST (owned by root:wheel, mode 755)…"
sudo install -o root -g wheel -m 755 "$HELPER_SRC" "$HELPER_DST"

echo "Writing $SUDOERS_DST (NOPASSWD for $USER_NAME)…"
SUDOERS_CONTENT="$USER_NAME ALL=(root) NOPASSWD: $HELPER_DST"
# Validate with visudo -c before installing to avoid a broken sudoers
TMP_SUDO=$(mktemp)
trap 'rm -f "$TMP_SUDO"' EXIT
printf '%s\n' "$SUDOERS_CONTENT" > "$TMP_SUDO"
sudo visudo -cf "$TMP_SUDO"
sudo install -o root -g wheel -m 440 "$TMP_SUDO" "$SUDOERS_DST"

echo
echo "Done. Facade can now save without prompting."
echo "(Test by saving a change in Facade — no password prompt should appear.)"
