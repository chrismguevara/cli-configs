#!/usr/bin/env bash
# OpenCode from the official GitHub release (pinned, checksum-verified).
#
# The official installer (`curl -fsSL https://opencode.ai/install | bash`)
# downloads the same release tarball and puts the binary in ~/.opencode/bin.
# This script does the same for the exact version in versions.env, without
# editing ~/.bashrc (dotfiles/bashrc adds ~/.opencode/bin to PATH).
# It never touches OpenCode's config or credentials
# (~/.config/opencode, ~/.local/share/opencode/auth.json).
source "$(dirname "$0")/lib.sh"

case "${ARCH}" in
  x86_64)
    # The x64 build assumes AVX2; OpenCode's installer falls back to -baseline.
    if grep -q avx2 /proc/cpuinfo; then flavor=x64; else flavor=x64-baseline; fi ;;
  aarch64) flavor=arm64 ;;
esac
asset="opencode-linux-${flavor}.tar.gz"
base="https://github.com/anomalyco/opencode/releases/download/${OPENCODE_VERSION}"
install_dir="${OPENCODE_INSTALL_DIR:-$HOME/.opencode/bin}"
want="${OPENCODE_VERSION#v}"

log "opencode ${OPENCODE_VERSION} (${flavor})"
if [[ "$("${install_dir}/opencode" --version 2>/dev/null)" == "${want}" ]]; then
  ok "already installed in ${install_dir}"
else
  tmp="$(mktmp)"
  fetch "${base}/${asset}" "${tmp}/${asset}"
  expected_var="OPENCODE_SHA256_${flavor//-/_}"
  sha256_check "${tmp}/${asset}" "${!expected_var:-}"
  mkdir -p "${install_dir}"
  tar -C "${tmp}" -xzf "${tmp}/${asset}"
  install -m 0755 "${tmp}/opencode" "${install_dir}/opencode"
fi

export PATH="${install_dir}:${PATH}"
export OPENCODE_DISABLE_AUTOUPDATE=1
[[ "$(opencode --version)" == "${want}" ]] || die "opencode on PATH is not ${want}"
ok "opencode $(opencode --version)"

# Herdr's official OpenCode integration: lifecycle/state + session id reporting
# so Herdr can resume the pane with `opencode --session <id>` after a restart.
# It only writes plugin files + tui.jsonc/cli.json entries under ~/.config/opencode.
if command -v herdr >/dev/null || [[ -x "$HOME/.local/bin/herdr" ]]; then
  export PATH="$HOME/.local/bin:${PATH}"
  mkdir -p "$HOME/.config/opencode"      # must exist before install
  log "herdr integration install opencode"
  herdr integration install opencode
  herdr integration status
else
  warn "herdr not installed yet; run install/herdr.sh then re-run this script for the integration"
fi
