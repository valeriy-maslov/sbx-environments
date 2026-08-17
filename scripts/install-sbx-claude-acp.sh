#!/bin/sh
# Install or update scripts/sbx-claude-acp.sh into ~/bin.
#
#   curl -fsSL https://raw.githubusercontent.com/valeriy-maslov/sbx-environments/master/scripts/install-sbx-claude-acp.sh | sh
#
# Fetches the file fresh from the repo every run, so re-running this is how
# you pick up changes to the bridge script -- it always overwrites whatever is
# already at the destination.

set -eu

REPO_RAW="${VGM_SANDBOX_REPO_RAW:-https://raw.githubusercontent.com/valeriy-maslov/sbx-environments}"
BRANCH="${VGM_SANDBOX_BRANCH:-master}"
BIN_DIR="${VGM_SANDBOX_BIN_DIR:-$HOME/bin}"
DEST="$BIN_DIR/sbx-claude-acp.sh"

command -v curl >/dev/null 2>&1 || {
  echo "install-sbx-claude-acp: curl is required but not installed" >&2
  exit 1
}

mkdir -p "$BIN_DIR"

TMP="$(mktemp)"
trap 'rm -f "$TMP"' EXIT INT TERM

curl -fsSL "$REPO_RAW/$BRANCH/scripts/sbx-claude-acp.sh" -o "$TMP"

if [ -f "$DEST" ]; then
  ACTION="updated"
else
  ACTION="installed"
fi

# mv rather than cp over the existing file, so a process with the old file
# already open (e.g. Zed mid-session) keeps its own inode instead of seeing a
# half-written one
chmod +x "$TMP"
mv "$TMP" "$DEST"
trap - EXIT INT TERM

echo "install-sbx-claude-acp: $ACTION $DEST"

cat <<EOF

Point Zed's settings.json at it:

  {
    "agent_servers": {
      "sbx-claude": {
        "type": "custom",
        "command": "$DEST"
      }
    }
  }
EOF
