#!/bin/bash
# Prepares REA in a Claude Code cloud container: the toolchain pinned by
# .nvmrc and package.json#packageManager, locked dependencies, the built
# CLI/MCP runtime, and a `rea` command beside the pinned Node.js.
#
# The SessionStart hook and the MCP launcher can start concurrently, so the
# whole preparation runs under one lock and is idempotent. Progress goes to
# stderr; stdout carries only the pinned Node.js bin directory.
set -euo pipefail

repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$repo"

log() { printf 'rea cloud prepare: %s\n' "$*" >&2; }

mkdir -p .cache
exec 9> .cache/claude-cloud-prepare.lock
flock 9

# The cloud image puts an older Node.js first on PATH, so install the pinned
# release beside it and prepend it for every command below.
node_version="$(tr -d '[:space:]' < .nvmrc)"
case "$(uname -m)" in
  x86_64) node_arch=x64 ;;
  aarch64 | arm64) node_arch=arm64 ;;
  *)
    log "unsupported architecture $(uname -m)"
    exit 1
    ;;
esac
node_dist="node-v${node_version}-linux-${node_arch}"
node_home="/opt/${node_dist}"

if [ ! -x "${node_home}/bin/node" ]; then
  log "installing Node.js ${node_version}"
  download="$(mktemp -d)"
  trap 'rm -rf "$download"' EXIT
  origin="https://nodejs.org/dist/v${node_version}"
  curl -fsSL --retry 4 -o "${download}/SHASUMS256.txt" "${origin}/SHASUMS256.txt"
  curl -fsSL --retry 4 -o "${download}/${node_dist}.tar.xz" "${origin}/${node_dist}.tar.xz"
  (cd "$download" && grep "  ${node_dist}.tar.xz\$" SHASUMS256.txt | sha256sum --check --strict - >&2)
  tar -xJf "${download}/${node_dist}.tar.xz" -C "$download"
  rm -rf "${node_home}"
  mv "${download}/${node_dist}" "${node_home}"
fi
export PATH="${node_home}/bin:${PATH}"
export npm_config_update_notifier=false

npm_version="$(node -p 'require("./package.json").packageManager.replace(/^npm@/, "")')"
if [ "$(npm --version)" != "$npm_version" ]; then
  log "installing npm ${npm_version}"
  npm install --global --no-audit --no-fund "npm@${npm_version}" >&2
fi

if ! node scripts/check-dependency-install.mjs 2> /dev/null; then
  log "installing locked dependencies"
  npm ci --no-audit --no-fund >&2
fi

log "building the REA runtime"
npm run build:cached >&2

ln -sfn "${repo}/scripts/rea.mjs" "${node_home}/bin/rea"

printf '%s\n' "${node_home}/bin"
