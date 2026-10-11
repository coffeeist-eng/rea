#!/bin/bash
# Starts the REA MCP server from this checkout. In Claude Code cloud sessions
# it first runs the shared preparation, because project MCP servers can start
# before the SessionStart hook has built the runtime. MCP stdout is reserved
# for protocol messages, so preparation output goes to stderr.
set -euo pipefail

repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

if [ "${CLAUDE_CODE_REMOTE:-}" = "true" ]; then
  node_bin="$("${repo}/.claude/cloud/prepare.sh")"
  export PATH="${node_bin}:${PATH}"
fi

exec node "${repo}/scripts/rea.mjs" mcp
