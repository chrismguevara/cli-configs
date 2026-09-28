#!/usr/bin/env bash
# Node.js via nvm (pinned), pnpm via Corepack, and the JS/TS language servers.
#
# Installs into $HOME (no root needed). Shell integration is provided by
# dotfiles/bashrc, so the nvm installer is told not to touch ~/.bashrc.
source "$(dirname "$0")/lib.sh"

export NVM_DIR="${NVM_DIR:-$HOME/.nvm}"
export COREPACK_ENABLE_DOWNLOAD_PROMPT=0

log "nvm ${NVM_VERSION}"
if [[ -s "${NVM_DIR}/nvm.sh" ]] && grep -q "\"${NVM_VERSION}\"" "${NVM_DIR}/nvm.sh" 2>/dev/null; then
  ok "nvm ${NVM_VERSION} already installed"
else
  tmp="$(mktmp)"
  fetch "https://raw.githubusercontent.com/nvm-sh/nvm/${NVM_VERSION}/install.sh" "${tmp}/nvm-install.sh"
  # PROFILE=/dev/null: do not edit ~/.bashrc; dotfiles/bashrc sources nvm.
  PROFILE=/dev/null NVM_DIR="${NVM_DIR}" bash "${tmp}/nvm-install.sh"
fi
load_nvm
command -v nvm >/dev/null || die "nvm did not load from ${NVM_DIR}/nvm.sh"

log "node ${NODE_VERSION}"
if nvm ls "${NODE_VERSION}" >/dev/null 2>&1; then
  ok "node ${NODE_VERSION} already installed"
else
  nvm install "${NODE_VERSION}"
fi
nvm alias default "${NODE_VERSION}" >/dev/null
nvm use --silent default
ok "node $(node --version) npm $(npm --version)"

log "pnpm ${PNPM_VERSION} via corepack"
if ! command -v corepack >/dev/null; then
  die "corepack is not bundled with node $(node --version); pick a Node LTS that ships it"
fi
corepack enable
corepack prepare "pnpm@${PNPM_VERSION}" --activate
ok "pnpm $(pnpm --version)"

log "language servers (global npm, under nvm)"
# TypeScript is pinned to 6.x on purpose: TypeScript 7 (the native port) no
# longer ships tsserver, which vtsls requires. Projects pin their own copy too;
# Neovim prefers the workspace copy (vtsls autoUseWorkspaceTsdk).
npm install -g --no-fund --no-audit \
  "typescript@${TYPESCRIPT_VERSION}" \
  "@vtsls/language-server@${VTSLS_VERSION}" \
  "vscode-langservers-extracted@${VSCODE_LANGSERVERS_VERSION}"

for bin in vtsls vscode-eslint-language-server vscode-html-language-server vscode-css-language-server vscode-json-language-server tsc; do
  command -v "${bin}" >/dev/null || die "missing after install: ${bin}"
done
ok "vtsls $(npm ls -g @vtsls/language-server --depth=0 2>/dev/null | grep -o '@vtsls/language-server@[0-9.]*')"
