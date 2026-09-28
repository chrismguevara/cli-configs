#!/usr/bin/env bash
# LazyGit. Preferred: DNF via the COPR repository recommended in the official
# README for Fedora/RHEL-family systems (dejan/lazygit), so that
#   sudo dnf install lazygit   /   sudo dnf upgrade
# manage it like any other package. Enterprise Linux hosts must name the
# chroot explicitly (epel-9-<arch>), which `dnf copr enable` accepts.
#
# Fallback (LAZYGIT_INSTALL=release, or when the COPR route fails): the pinned
# GitHub release tarball, verified against the release's checksums.txt, into
# /usr/local/bin/lazygit. The reason for a fallback is logged so it is visible.
source "$(dirname "$0")/lib.sh"

# shellcheck disable=SC1091
. /etc/os-release
el_major="${VERSION_ID%%.*}"
copr_project="${LAZYGIT_COPR:-dejan/lazygit}"
chroot="epel-${el_major}-${ARCH}"

install_from_release() {
  local want="${LAZYGIT_VERSION#v}" tmp asset base
  asset="lazygit_${want}_linux_${LAZYGIT_ARCH}.tar.gz"
  base="https://github.com/jesseduffield/lazygit/releases/download/${LAZYGIT_VERSION}"
  if [[ "$(/usr/local/bin/lazygit --version 2>/dev/null | grep -o 'version=[0-9.]*' | cut -d= -f2)" == "${want}" ]]; then
    ok "release ${want} already installed in /usr/local/bin"
    return
  fi
  tmp="$(mktmp)"
  fetch "${base}/${asset}" "${tmp}/${asset}"
  fetch "${base}/checksums.txt" "${tmp}/checksums.txt"
  sha256_check "${tmp}/${asset}" "$(awk -v a="${asset}" '$2 == a {print $1}' "${tmp}/checksums.txt")"
  tar -C "${tmp}" -xzf "${tmp}/${asset}" lazygit
  ${SUDO} install -m 0755 "${tmp}/lazygit" /usr/local/bin/lazygit
  ok "installed release: $(/usr/local/bin/lazygit --version | tr ',' '\n' | grep version)"
}

install_from_copr() {
  # Called inside an `if`, so errexit is off here: every step must be checked.
  ${SUDO} dnf -y -q install dnf-plugins-core || return 1
  if ! ${SUDO} dnf -q repolist --enabled 2>/dev/null | grep -q "copr:copr.fedorainfracloud.org:${copr_project//\//:}"; then
    log "enabling COPR ${copr_project} (${chroot})"
    ${SUDO} dnf -y copr enable "${copr_project}" "${chroot}" || return 1
  fi
  ${SUDO} dnf -y install lazygit || return 1
  rpm -q lazygit >/dev/null || return 1
  ok "installed from COPR: $(rpm -q lazygit)"
}

log "lazygit (${ARCH}, ${PRETTY_NAME})"
mode="${LAZYGIT_INSTALL:-copr}"
if [[ "${mode}" == "copr" ]]; then
  if install_from_copr; then
    :
  else
    warn "COPR route failed (repository unreachable or no build for ${chroot}); falling back to the pinned GitHub release ${LAZYGIT_VERSION}"
    # Do not leave a broken repo definition behind.
    ${SUDO} dnf -y copr remove "${copr_project}" >/dev/null 2>&1 || true
    install_from_release
  fi
else
  install_from_release
fi

command -v lazygit >/dev/null || die "lazygit not on PATH after install"
ok "$(lazygit --version | tr ',' '\n' | grep -E 'version|os|arch' | tr '\n' ' ')"
