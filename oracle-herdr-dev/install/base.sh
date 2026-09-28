#!/usr/bin/env bash
# Base packages for Oracle Linux 9 (also works on Rocky/Alma 9).
#
# Enables:
#   Oracle Linux 9 : ol9_developer_EPEL (via oracle-epel-release-el9) + ol9_codeready_builder
#   Rocky/Alma 9   : epel-release + crb
#
# ripgrep, fd-find and fzf come from EPEL; everything else from BaseOS/AppStream.
source "$(dirname "$0")/lib.sh"

# shellcheck disable=SC1091
. /etc/os-release

log "base packages on ${PRETTY_NAME} (${ARCH})"

${SUDO} dnf -y -q install dnf-plugins-core

case "${ID}" in
  ol)
    ${SUDO} dnf -y -q install oracle-epel-release-el9
    ${SUDO} dnf config-manager --set-enabled ol9_developer_EPEL ol9_codeready_builder
    ;;
  rocky|almalinux|rhel|centos)
    ${SUDO} dnf -y -q install epel-release
    ${SUDO} dnf config-manager --set-enabled crb
    ;;
  *)
    die "unsupported distribution: ${ID} (expected Oracle Linux 9 or an EL9 clone)"
    ;;
esac

PACKAGES=(
  git curl wget jq unzip tar gzip
  gcc gcc-c++ make cmake
  ripgrep fd-find fzf
  openssl ca-certificates python3
  procps-ng which findutils
)
${SUDO} dnf -y install "${PACKAGES[@]}"

for bin in git curl wget jq unzip tar gzip gcc make cmake rg fd fzf; do
  command -v "${bin}" >/dev/null || die "missing after install: ${bin}"
done
ok "git $(git --version | awk '{print $3}') rg $(rg --version | head -1 | awk '{print $2}') fd $(fd --version | awk '{print $2}') fzf $(fzf --version | awk '{print $1}')"
