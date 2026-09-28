# Troubleshooting

## Oracle Cloud

- **"Out of host capacity"** when creating an A1 instance: no free ARM capacity
  in that availability domain right now. Retry later, change
  `availability_domain_index`, or temporarily use `VM.Standard.E2.1.Micro`.
- **A1 instance disabled after the 30-day trial**: the tenancy exceeds the
  Always Free A1 allowance (2 OCPU / 12 GB total). Keep the instance within it
  or upgrade to Pay As You Go.
- **Instance reclaimed as idle**: Always Free instances idle for 7 days
  (<20% CPU/network/memory) can be stopped by Oracle. Start it again from the
  console.
- **Cannot SSH**: only TCP/22 is open; check `ssh_source_cidr`, that you use
  the `opc` user and the key whose public half is in `terraform.tfvars`.

## Install scripts

- **Checksum mismatch**: the upstream asset changed for the same version, or a
  pin in `versions.env` is stale. Recompute with `curl -fsSL <url> | sha256sum`
  only after confirming the release on the project's page.
- **tree-sitter: `GLIBC_2.39 not found`**: expected on EL9; the script falls
  back to building from source (needs `gcc`, network to static.rust-lang.org
  and crates.io). Takes ~1.5 min on 4 cores.
- **LazyGit COPR fails (403 / no match)**: the COPR is unreachable or has no
  `epel-9-<arch>` build. The script falls back to the pinned GitHub release and
  prints `WARN: COPR route failed`. Retry later with
  `LAZYGIT_INSTALL=copr ./install/lazygit.sh`.
- **Corepack `Error when performing the request`**: Node cannot reach
  registry.npmjs.org, usually a TLS-intercepting proxy. Point Node at the
  proxy CA with `NODE_EXTRA_CA_CERTS=/path/to/ca.pem` or fix egress.
- **`herdr integration install opencode` says the config dir is missing**:
  the script creates `~/.config/opencode`; run `install/opencode.sh` again.

## Herdr

- **`herdr` says the server is not running / socket errors**: `herdr status
  server`; start with `herdr server` (or `setup-workspaces`, which does it).
  Logs: `~/.config/herdr/herdr-server.log`.
- **Very long home paths**: the Unix socket path must stay under 108 bytes;
  keep `~/.config/herdr` or set `HERDR_SOCKET_PATH`.
- **Duplicate workspaces after running setup-workspaces twice**: it looks up
  workspaces by label `ws<n>`; if you renamed one, close it or rename it back.
- **A pane lacks `WORKSPACE_NAME` / ports**: shells opened by hand outside
  `~/worktrees/<n>` do not auto-load `.workspace.env`. Use
  `ws-run ~/worktrees/3 bash` or `set -a; . ./.workspace.env; set +a`.
- **After a reboot every pane is a bare shell**: expected; run
  `setup-workspaces` to relaunch nvim/opencode/lazygit into the restored tabs.
- **Panes start `/bin/sh` instead of bash**: `terminal.default_shell` in
  `config.toml` must be `/bin/bash` (it is, in the repo copy); reload with
  `herdr server reload-config`.
- **Agent state stays "unknown" for OpenCode**: `herdr integration status`
  must say `opencode: current`; restart the OpenCode TUI after installing.

## Neovim

- **`checkhealth` says the locale is not UTF-8**: the shell fragment sets
  `LANG=C.UTF-8` when the SSH client did not forward a UTF-8 `LANG`; open a new
  shell.
- **vtsls does not attach**: it starts from the nearest lock file
  (`pnpm-lock.yaml`) or `.git`; run `pnpm install` in the package so
  `node_modules/typescript` exists (TypeScript must be 6.x, TypeScript 7 has no
  tsserver). `:checkhealth vim.lsp` lists enabled configs and their errors.
- **`conform: no node_modules/.bin/oxfmt above …`**: the project has no
  project-local oxfmt (`pnpm add -D oxfmt`). This is intentional; there is no
  global fallback.
- **Parsers missing / highlighting off**: `:TSInstall <lang>` or
  `:lua require('nvim-treesitter').install({...})`; needs `tree-sitter --version`
  ≥ 0.26.1 and a C compiler. `:checkhealth nvim-treesitter`.
- **blink.cmp warns about the fuzzy library**: the prebuilt
  `libblink_cmp_fuzzy.so` could not be downloaded/loaded; it falls back to Lua.
  `:checkhealth blink.cmp`; with Rust installed `cargo build --release` in
  the plugin directory builds it locally.
- **`vim.pack` / lazy warn about `site/pack/core`**: harmless; created by
  Neovim 0.12's built-in package manager health check.

## Ports and forwarding

- **`Address already in use` on Windows**: another workspace's `-L` uses the
  same local port. Each workspace has distinct ports; forward only what you use.
- **Vite shows a different port**: `strictPort` is on, so a clash makes Vite
  exit instead of picking another port; check `FRONTEND_PORT` in the pane.
