#!/usr/bin/env bash
# tree-sitter CLI, pinned to the version in versions.env, installed as
# /usr/local/bin/tree-sitter. nvim-treesitter (main branch) needs >= 0.26.1.
#
# 1. Preferred: the official GitHub release binary (checksum-verified).
# 2. Fallback:  the official crates.io source, built with cargo.
#    Needed on Oracle Linux 9 / RHEL 9: release binaries >= 0.26 are linked
#    against glibc 2.39 and EL9 ships glibc 2.34 ("version GLIBC_2.39 not
#    found"). The EPEL package (0.25.x) is too old for nvim-treesitter main.
source "$(dirname "$0")/lib.sh"

want="${TREE_SITTER_VERSION#v}"
dest=/usr/local/bin/tree-sitter

log "tree-sitter ${TREE_SITTER_VERSION} (${TS_ARCH})"
if [[ "$("${dest}" --version 2>/dev/null | awk '{print $2}')" == "${want}" ]]; then
  ok "already installed: $("${dest}" --version)"
  exit 0
fi

tmp="$(mktmp)"
asset="tree-sitter-linux-${TS_ARCH}.gz"
base="https://github.com/tree-sitter/tree-sitter/releases/download/${TREE_SITTER_VERSION}"

# --- 1. official release binary ------------------------------------------------
fetch "${base}/${asset}" "${tmp}/${asset}"
expected_var="TREE_SITTER_SHA256_${ARCH}"
sha256_check "${tmp}/${asset}" "${!expected_var:-}"
gunzip -f "${tmp}/${asset}"
chmod +x "${tmp}/tree-sitter-linux-${TS_ARCH}"
if "${tmp}/tree-sitter-linux-${TS_ARCH}" --version >/dev/null 2>&1; then
  ${SUDO} install -m 0755 "${tmp}/tree-sitter-linux-${TS_ARCH}" "${dest}"
  ok "installed release binary: $("${dest}" --version)"
  exit 0
fi
warn "release binary does not run here ($("${tmp}/tree-sitter-linux-${TS_ARCH}" --version 2>&1 | grep -o "GLIBC_[0-9.]* not found" | sort -u | tr '\n' ' ')): building from source"

# --- 2. build from the official crates.io source ------------------------------
export PATH="${HOME}/.cargo/bin:${PATH}"
if ! command -v cargo >/dev/null || [[ "$(rustc --version 2>/dev/null | awk '{print $2}')" != "${RUST_TOOLCHAIN}" ]]; then
  log "rust ${RUST_TOOLCHAIN} via rustup (minimal profile, no shell profile edits)"
  fetch "https://static.rust-lang.org/rustup/dist/${ARCH}-unknown-linux-gnu/rustup-init" "${tmp}/rustup-init"
  chmod +x "${tmp}/rustup-init"
  "${tmp}/rustup-init" -y --no-modify-path --profile minimal --default-toolchain "${RUST_TOOLCHAIN}"
fi
rustc --version | grep -q "${RUST_TOOLCHAIN}" || die "rustc is not ${RUST_TOOLCHAIN}"

log "cargo install --locked tree-sitter-cli@${want}"
cargo install --locked --root "${tmp}/ts" "tree-sitter-cli@${want}"
${SUDO} install -m 0755 "${tmp}/ts/bin/tree-sitter" "${dest}"
"${dest}" --version | grep -q "${want}" || die "tree-sitter on PATH is not ${want}"
ok "built from source: $("${dest}" --version)"
