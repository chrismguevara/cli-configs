#!/usr/bin/env bash
# Go from the official distribution (pinned, checksum-verified) into
# /usr/local/go, plus gopls, goimports and staticcheck into $HOME/go/bin.
#
# Change GO_VERSION in versions.env to upgrade, then re-run this script.
source "$(dirname "$0")/lib.sh"

# Official download location; override only for mirrors/offline testing.
GO_DL_BASE="${GO_DL_BASE:-https://go.dev/dl}"
GO_ROOT=/usr/local/go
tarball="go${GO_VERSION}.linux-${GO_ARCH}.tar.gz"

log "go ${GO_VERSION} (${GO_ARCH})"
installed="$("${GO_ROOT}/bin/go" version 2>/dev/null | awk '{print $3}' || true)"
if [[ "${installed}" == "go${GO_VERSION}" ]]; then
  ok "go ${GO_VERSION} already installed in ${GO_ROOT}"
else
  tmp="$(mktmp)"
  fetch "${GO_DL_BASE}/${tarball}" "${tmp}/${tarball}"
  fetch "${GO_DL_BASE}/${tarball}.sha256" "${tmp}/${tarball}.sha256"
  sha256_check "${tmp}/${tarball}" "$(awk '{print $1}' "${tmp}/${tarball}.sha256")"
  ${SUDO} rm -rf "${GO_ROOT}"
  ${SUDO} tar -C /usr/local -xzf "${tmp}/${tarball}"
  ok "installed $("${GO_ROOT}/bin/go" version)"
fi

export PATH="${GO_ROOT}/bin:${HOME}/go/bin:${PATH}"
export GOTOOLCHAIN=local   # never auto-download a different toolchain here

log "go tools (gopls, goimports, staticcheck)"
go install golang.org/x/tools/gopls@latest
go install golang.org/x/tools/cmd/goimports@latest
go install honnef.co/go/tools/cmd/staticcheck@latest

for bin in gopls goimports staticcheck; do
  [[ -x "${HOME}/go/bin/${bin}" ]] || die "missing after install: ${bin}"
done
ok "$(go version) | gopls $(gopls version | head -1) | staticcheck $(staticcheck -version)"
