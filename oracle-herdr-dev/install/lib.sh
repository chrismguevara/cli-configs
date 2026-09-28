#!/usr/bin/env bash
# Shared helpers for the install scripts. Source this file; do not run it.
#
#   source "$(dirname "$0")/lib.sh"
#
# Every install script is meant to be re-runnable: it checks the installed
# version against versions.env and does nothing when they already match.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export REPO_ROOT

# shellcheck source=../versions.env
source "$REPO_ROOT/versions.env"

log()  { printf '\033[1;34m==> %s\033[0m\n' "$*"; }
ok()   { printf '\033[1;32m    ok: %s\033[0m\n' "$*"; }
warn() { printf '\033[1;33mWARN: %s\033[0m\n' "$*" >&2; }
die()  { printf '\033[1;31mERROR: %s\033[0m\n' "$*" >&2; exit 1; }

if [[ ${EUID} -eq 0 ]]; then SUDO=""; else SUDO="sudo"; fi

# Architecture names differ per upstream project.
ARCH="$(uname -m)"
case "${ARCH}" in
  x86_64)
    GO_ARCH=amd64        # go1.x.linux-amd64.tar.gz
    NVIM_ARCH=x86_64     # nvim-linux-x86_64.tar.gz
    TS_ARCH=x64          # tree-sitter-linux-x64.gz
    LAZYGIT_ARCH=x86_64  # lazygit_x.y.z_linux_x86_64.tar.gz
    ;;
  aarch64)
    GO_ARCH=arm64
    NVIM_ARCH=arm64
    TS_ARCH=arm64
    LAZYGIT_ARCH=arm64
    ;;
  *) die "unsupported architecture: ${ARCH}" ;;
esac
export ARCH GO_ARCH NVIM_ARCH TS_ARCH LAZYGIT_ARCH

# fetch URL DEST  -- download with retries, fail loudly.
fetch() {
  local url="$1" dest="$2"
  curl -fsSL --retry 3 --retry-delay 2 --connect-timeout 20 -o "${dest}" "${url}" \
    || die "download failed: ${url}"
}

# sha256_check FILE EXPECTED_HEX
sha256_check() {
  local file="$1" expected="$2"
  [[ -n "${expected}" ]] || die "empty checksum for ${file}"
  echo "${expected}  ${file}" | sha256sum -c --quiet - \
    || die "checksum mismatch for ${file}"
  ok "checksum verified: $(basename "${file}")"
}

# WORK_DIR -- per-script scratch directory, removed when the script exits.
WORK_DIR="$(mktemp -d)"
trap 'rm -rf "${WORK_DIR}"' EXIT
mktmp() { echo "${WORK_DIR}"; }

# Load nvm into the current shell if it is installed (Node scripts need it).
load_nvm() {
  export NVM_DIR="${NVM_DIR:-$HOME/.nvm}"
  # shellcheck disable=SC1091
  [[ -s "${NVM_DIR}/nvm.sh" ]] && . "${NVM_DIR}/nvm.sh"
}
