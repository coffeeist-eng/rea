#!/bin/bash
# SessionStart hook: prepares REA in Claude Code cloud sessions and puts the
# pinned Node.js and `rea` on the session PATH. Local sessions are untouched.
set -euo pipefail

if [ "${CLAUDE_CODE_REMOTE:-}" != "true" ]; then
  exit 0
fi

repo="${CLAUDE_PROJECT_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
node_bin="$("${repo}/.claude/cloud/prepare.sh")"

if [ -n "${CLAUDE_ENV_FILE:-}" ]; then
  path_export="export PATH=\"${node_bin}:\$PATH\""
  grep -qxF "$path_export" "$CLAUDE_ENV_FILE" 2> /dev/null ||
    printf '%s\n' "$path_export" >> "$CLAUDE_ENV_FILE"
fi

printf 'REA %s is built from this checkout; `rea` and Node.js %s are on PATH.\n' \
  "$(PATH="${node_bin}:${PATH}" rea --version)" "$("${node_bin}/node" --version)"
