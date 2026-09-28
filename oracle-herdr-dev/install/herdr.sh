#!/usr/bin/env bash
# Herdr from the official GitHub release (pinned, checksum-verified).
#
# The official installer (`curl -fsSL https://herdr.dev/install.sh | sh`) always
# installs the newest version. This script installs the exact version from
# versions.env into the same location the official installer uses
# (~/.local/bin/herdr), verifying the SHA-256 from Herdr's release manifest.
# Upgrade deliberately: bump HERDR_VERSION + HERDR_SHA256_* and re-run.
source "$(dirname "$0")/lib.sh"

asset="herdr-linux-${ARCH}"          # x86_64 | aarch64, bare static binary
base="https://github.com/herdrdev/herdr/releases/download/${HERDR_VERSION}"
install_dir="${HERDR_INSTALL_DIR:-$HOME/.local/bin}"
want="${HERDR_VERSION#v}"

log "herdr ${HERDR_VERSION} (${ARCH})"
if [[ "$("${install_dir}/herdr" --version 2>/dev/null | awk '{print $2}')" == "${want}" ]]; then
  ok "already installed in ${install_dir}"
else
  tmp="$(mktmp)"
  fetch "${base}/${asset}" "${tmp}/${asset}"
  expected_var="HERDR_SHA256_${ARCH}"
  sha256_check "${tmp}/${asset}" "${!expected_var:-}"
  mkdir -p "${install_dir}"
  install -m 0755 "${tmp}/${asset}" "${install_dir}/herdr"
fi

# Config lives in ~/.config/herdr (installed by bin/install-dotfiles).
"${install_dir}/herdr" --version | grep -q "${want}" || die "herdr in ${install_dir} is not ${want}"
ok "$("${install_dir}/herdr" --version)"
