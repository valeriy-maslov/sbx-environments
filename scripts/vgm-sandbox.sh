#!/bin/sh
# Create a Docker sandbox with the vgm kits attached.
#
#   curl -fsSL https://raw.githubusercontent.com/valeriy-maslov/sbx-environments/master/scripts/vgm-sandbox.sh | sh
#   curl -fsSL .../vgm-sandbox.sh | sh -s -- codex ~/Projects/thing
#
# Usage: vgm-sandbox.sh [AGENT] [WORKSPACE] [-- EXTRA_SBX_ARGS...]
#
# The kits live in subdirectories of one repository, and sbx only reads a git
# kit reference from a repository root, so this clones the repo and passes the
# kits as local paths.

set -eu

REPO="${VGM_SANDBOX_REPO:-https://github.com/valeriy-maslov/sbx-environments.git}"
BRANCH="${VGM_SANDBOX_BRANCH:-master}"
KITS="${VGM_SANDBOX_KITS:-vgm-python vgm-jvm vgm-node vgm-zsh vgm-ralphex}"

AGENT="${1:-claude}"
[ $# -gt 0 ] && shift || true
WORKSPACE="${1:-$PWD}"
[ $# -gt 0 ] && shift || true

for cmd in sbx git; do
  command -v "$cmd" >/dev/null 2>&1 || {
    echo "vgm-sandbox: $cmd is required but not installed" >&2
    exit 1
  }
done

case "$WORKSPACE" in
  -*) echo "vgm-sandbox: expected a workspace path, got '$WORKSPACE'" >&2; exit 1 ;;
esac
[ -d "$WORKSPACE" ] || { echo "vgm-sandbox: no such directory: $WORKSPACE" >&2; exit 1; }

# printf avoids the trailing newline that tr would otherwise turn into a dash
SLUG="$(printf '%s' "$(basename "$WORKSPACE")" | tr -c 'a-zA-Z0-9_.-' '-')"
case "$SLUG" in
  vgm-*|vgm) NAME="${VGM_SANDBOX_NAME:-$SLUG}" ;;
  *)         NAME="${VGM_SANDBOX_NAME:-vgm-$SLUG}" ;;
esac

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT INT TERM

echo "vgm-sandbox: fetching kits from $REPO ($BRANCH)"
git clone --quiet --depth=1 --branch "$BRANCH" "$REPO" "$TMP/repo"

set -- --name "$NAME"
for kit in $KITS; do
  [ -f "$TMP/repo/kits/$kit/spec.yaml" ] || {
    echo "vgm-sandbox: kit $kit is missing from the repository" >&2
    exit 1
  }
  set -- "$@" --kit "$TMP/repo/kits/$kit"
done

echo "vgm-sandbox: creating sandbox '$NAME' for $AGENT in $WORKSPACE"
echo "vgm-sandbox: installing the kits takes about a minute"
sbx create "$@" "$AGENT" "$WORKSPACE"

cat <<EOF

Sandbox '$NAME' is ready. Attach to it with:

  sbx run --name $NAME

Or open a shell:

  sbx exec -it $NAME zsh
EOF
