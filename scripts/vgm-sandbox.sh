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
KITS="${VGM_SANDBOX_KITS:-vgm-python vgm-jvm vgm-node vgm-zsh vgm-ralphex vgm-context7}"

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

# store secrets host-side before the sandbox exists, so kit install steps see
# them as env vars from the start

if command -v gh >/dev/null 2>&1; then
  if token="$(gh auth token 2>/dev/null)" && [ -n "$token" ]; then
    echo "$token" | sbx secret set github >/dev/null
    echo "vgm-sandbox: stored a GitHub token from gh"
  else
    echo "vgm-sandbox: gh is not logged in, skipping the GitHub secret" >&2
  fi
else
  echo "vgm-sandbox: gh not found, skipping the GitHub secret" >&2
fi

# stdin is the script itself when piped from curl, so the prompt needs its own
# fd onto the tty; opening it is wrapped in the if-condition so a headless
# environment (no controlling terminal) just skips the prompt instead of
# tripping "set -e" on the failed open. The 2>/dev/null is scoped to the { }
# group rather than tacked directly onto exec, because bare "exec ... 2>/dev/null"
# redirects the *whole script's* stderr from then on -- silencing this very
# prompt on the success path where a real tty is attached.
CONTEXT7_API_KEY="${VGM_SANDBOX_CONTEXT7_API_KEY:-}"
if [ -z "$CONTEXT7_API_KEY" ] && { exec 3<"/dev/tty"; } 2>/dev/null; then
  printf '\nvgm-sandbox: optional Context7 API key (get one at https://context7.com/dashboard)\nvgm-sandbox: paste it and press enter, or just press enter to skip\nvgm-sandbox: > ' >&2
  read -r CONTEXT7_API_KEY <&3 || CONTEXT7_API_KEY=""
  exec 3<&-
fi
if [ -n "$CONTEXT7_API_KEY" ]; then
  sbx secret set-custom \
    --host mcp.context7.com --host api.context7.com --host context7.com \
    --env CONTEXT7_API_KEY --value "$CONTEXT7_API_KEY" >/dev/null
  echo "vgm-sandbox: stored the Context7 API key"
fi

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
