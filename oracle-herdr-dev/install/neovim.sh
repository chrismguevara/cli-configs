#!/usr/bin/env bash
# Neovim from the official GitHub release tarball (pinned, checksum-verified).
#
#   /opt/nvim-<version>/      extracted release
#   /opt/nvim -> /opt/nvim-<version>
#   /usr/local/bin/nvim -> /opt/nvim/bin/nvim
source "$(dirname "$0")/lib.sh"

asset="nvim-linux-${NVIM_ARCH}.tar.gz"
base="https://github.com/neovim/neovim/releases/download/${NEOVIM_VERSION}"
prefix="/opt/nvim-${NEOVIM_VERSION}"

log "neovim ${NEOVIM_VERSION} (${NVIM_ARCH})"
if [[ -x "${prefix}/bin/nvim" ]] && "${prefix}/bin/nvim" --version | head -1 | grep -q "NVIM ${NEOVIM_VERSION}"; then
  ok "already extracted in ${prefix}"
else
  tmp="$(mktmp)"
  fetch "${base}/${asset}" "${tmp}/${asset}"
  # Neovim publishes no checksum file; the SHA-256 is pinned in versions.env.
  expected_var="NEOVIM_SHA256_${ARCH}"
  sha256_check "${tmp}/${asset}" "${!expected_var:-}"
  ${SUDO} rm -rf "${prefix}"
  ${SUDO} mkdir -p "${prefix}"
  ${SUDO} tar -C "${prefix}" --strip-components=1 -xzf "${tmp}/${asset}"
fi

${SUDO} ln -sfn "${prefix}" /opt/nvim
${SUDO} ln -sfn /opt/nvim/bin/nvim /usr/local/bin/nvim

nvim --version | head -1 | grep -q "NVIM ${NEOVIM_VERSION}" || die "nvim on PATH is not ${NEOVIM_VERSION}"
ok "$(nvim --version | head -1) -> $(readlink -f /usr/local/bin/nvim)"
