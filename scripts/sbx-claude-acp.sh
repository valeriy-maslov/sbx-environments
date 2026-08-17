#!/bin/sh
# ACP bridge for Zed's Agent Panel that resolves the sandbox from the current
# directory instead of a hardcoded name, so one Zed agent_servers entry works
# for every project.
#
# Zed spawns this as the "command" of a custom agent_servers entry; see the
# README for the full settings.json snippet. It assumes Zed launches the
# command with its cwd set to the project root -- undocumented on Zed's side,
# but that is what "sbx ls --json" workspaces are matched against.

set -eu

SANDBOX="$(sbx ls --json | jq -r --arg d "$PWD" \
  '.sandboxes[] | select(.workspaces[]? == $d) | .name' | head -n1)"

if [ -z "$SANDBOX" ]; then
  echo "sbx-claude-acp: no sandbox found for $PWD" >&2
  exit 1
fi

# no --cli: that flag bypasses ACP entirely and gateways raw stdin straight
# into an interactive claude session instead of speaking JSON-RPC, so any
# protocol message from Zed lands as literal chat input and the panel hangs
# on "loading" waiting for a response that will never come. Plain invocation
# is the real ACP server, and it still reuses the sandbox's already
# authenticated claude session (authMethods comes back empty).
exec sbx exec -i "$SANDBOX" sh -c \
  'mkdir -p /usr/local/share/npm-global/lib && exec npx -y @agentclientprotocol/claude-agent-acp'
