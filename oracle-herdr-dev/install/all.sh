#!/usr/bin/env bash
# Run every install script in dependency order. Each one is idempotent, so this
# is also the way to re-apply versions.env after changing a pin.
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
for s in base neovim tree-sitter lazygit golang node herdr opencode; do
  printf '\n\033[1;35m##### install/%s.sh #####\033[0m\n' "${s}"
  "${HERE}/${s}.sh"
done
printf '\n\033[1;32mAll install scripts finished. Next: bin/install-dotfiles, then open a new shell.\033[0m\n'
