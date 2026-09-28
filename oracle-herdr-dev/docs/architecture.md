# Architecture

## One server, five workspaces

```
Herdr server (one per user, ~/.config/herdr/herdr.sock)
├── workspace ws1  = git worktree ~/worktrees/1  (branch ws/1)
│   ├── tab 1 nvim      pane: nvim .
│   ├── tab 2 opencode  pane: opencode           (Herdr agent "ws1")
│   ├── tab 3 git       pane: lazygit
│   ├── tab 4 dev       panes: frontend | backend
│   │                          keycloak | database
│   ├── tab 5 shell     pane: bash
│   └── tab 6 scratch   pane: bash
├── workspace ws2  = ~/worktrees/2 …
├── workspace ws3
├── workspace ws4
└── workspace ws5
```

- **workspace = Git worktree.** Each workspace's root directory is one worktree
  of the fixture repository (`~/src/fixture-monorepo`), on its own branch
  `ws/<n>`. Switching workspace (`Ctrl-b w`) switches branch context entirely.
- **tab = activity/tool.** Tabs are numbered so `Ctrl-b 1..6` is muscle memory
  across workspaces. Tab 1 is the editor, 2 the coding agent, 3 the Git TUI,
  4 the running dev processes, 5 a plain shell, 6 a scratch shell.
- **pane = process.** The dev tab is a 2×2 grid of shells labelled frontend,
  backend, keycloak and database, each already in the right directory with the
  right ports; you start the process you need (`pnpm dev`, `go run ./cmd/server`,
  a Keycloak or Postgres container, …).

LazyGit is deliberately *not* embedded in Neovim; it has its own tab.
Herdr replaces tmux entirely (no tmux is installed).

## Environment and ports

Herdr's `--env` applies only to the pane it is given to; sibling tabs and panes
do not inherit it (verified with Herdr 0.9.1). The environment therefore comes
from a file, three ways, all reading the same source:

1. `bin/setup-worktrees` writes `<worktree>/.workspace.env` (ports only, no
   secrets; git-ignored inside the fixture because it differs per worktree).
2. `bin/setup-workspaces` passes every assignment as `--env` on *each*
   `workspace create`, `tab create` and `pane split`, and runs tools through
   `bin/ws-run <worktree> <cmd>`, which sources the file and `exec`s the command.
3. `dotfiles/bashrc` sources the file automatically when an interactive shell
   starts inside `~/worktrees/<n>` (e.g. a tab you open by hand with
   `Ctrl-b c`; Herdr's `new_cwd = "follow"` puts it in the worktree). Only that
   directory tree is trusted for auto-sourcing.

The prompt shows `[ws3]` when a workspace environment is active.

| var             | ws1  | ws2  | ws3  | ws4  | ws5  |
|-----------------|------|------|------|------|------|
| FRONTEND_PORT   | 5173 | 5174 | 5175 | 5176 | 5177 |
| API_PORT        | 8081 | 8082 | 8083 | 8084 | 8085 |
| KEYCLOAK_PORT   | 8181 | 8182 | 8183 | 8184 | 8185 |
| POSTGRES_PORT   | 5433 | 5434 | 5435 | 5436 | 5437 |

`vite.config.ts` reads `FRONTEND_PORT`/`API_PORT` (binds 127.0.0.1, proxies
`/api` to the Go server); `cmd/server/main.go` reads `API_PORT` and binds
127.0.0.1. All five stacks can run at once without port clashes.

## Network and security

- OCI security list: ingress TCP/22 only (optionally from one CIDR), egress all.
- Oracle Linux's firewalld stays at its default (SSH only). No dev port is ever
  opened on the VM's public interface; everything binds to localhost.
- Access to dev services is by SSH local forwarding from Windows Terminal:
  `-L <port>:localhost:<port>` for each port of the workspace you are using.
- SSH is key-only (`cloud-init.yaml` writes a sshd drop-in; password and
  keyboard-interactive auth off, root login off).
- No credential is stored in the repository: OCI API keys stay in `~/.oci`,
  the SSH private key on the client, OpenCode credentials in
  `~/.local/share/opencode/auth.json` (outside the dotfiles).

## Persistence model (Herdr 0.9.1)

- The Herdr server is an ordinary user process started by the first `herdr`
  (or `herdr server`). Detaching (`Ctrl-b q`) or losing the SSH connection
  leaves it and every pane process running; `herdr` reattaches.
- `herdr server stop`, and a VM reboot, stop the server *and* all pane
  processes. The layout (workspaces, tabs, panes, labels, directories, focus)
  is saved to `~/.config/herdr/session.json` and restored on the next start.
  Processes are not restored, except agents with a native resume path: an
  OpenCode pane whose session id was reported by the integration is restarted
  with `opencode --session <id>` (`[session] resume_agents_on_restore = true`).
- `bin/setup-workspaces` is idempotent and is also the "after reboot" command:
  it re-launches nvim / opencode / lazygit only into panes that are back to a
  bare shell, and never creates a second copy of an existing workspace or tab.
- Optional `dotfiles/systemd/herdr-server.service` starts the server at boot.

## Where things live on the VM

| path                               | what                                                   |
|------------------------------------|--------------------------------------------------------|
| `~/cli-configs/oracle-herdr-dev`   | this repository (scripts, config sources)              |
| `~/.config/dev-shell/bashrc`       | symlink → `dotfiles/bashrc`, sourced by `~/.bashrc`    |
| `~/.config/herdr/config.toml`      | symlink → `dotfiles/herdr/config.toml`                 |
| `~/.config/nvim`                   | symlink → `dotfiles/nvim`                              |
| `~/.local/bin`                     | herdr, symlinks to `bin/*`                             |
| `/opt/nvim-<ver>`, `/opt/nvim`, `/usr/local/bin/nvim` | Neovim release                      |
| `/usr/local/bin/tree-sitter`       | tree-sitter CLI (built from source on EL9)             |
| `/usr/local/go`, `~/go/bin`        | Go toolchain, gopls/goimports/staticcheck              |
| `~/.nvm`                           | nvm + Node LTS; global vtsls/typescript/langservers    |
| `~/.opencode/bin/opencode`         | OpenCode (official install location)                   |
| `~/.config/opencode/`              | OpenCode config + Herdr integration plugin files       |
| `~/src/fixture-monorepo`           | fixture repo (branch main); worktrees in `~/worktrees` |

## Decisions worth knowing

- **Oracle Linux 9, not Rocky**: same EL9 base; EPEL comes from Oracle's
  `oracle-epel-release-el9` (repo `ol9_developer_EPEL`) and CRB is
  `ol9_codeready_builder`. The scripts also accept Rocky/Alma (`epel-release`,
  `crb`) but only Oracle Linux was tested.
- **ARM A1.Flex by default**: the x86_64 Always Free shape has 1 GB RAM, too
  little for tsserver + gopls + OpenCode. All tools ship aarch64 builds; the
  install scripts map `uname -m` to each project's naming.
- **TypeScript pinned to 6.x**: TypeScript 7 is the native (Go) port and no
  longer ships `tsserver`, which vtsls requires. 6.0.3 is the last JS release.
- **tree-sitter CLI built from source on EL9**: release binaries ≥ 0.26 are
  linked against glibc 2.39 (EL9 has 2.34) and nvim-treesitter's main branch
  requires ≥ 0.26.1. `install/tree-sitter.sh` tries the official binary first
  and otherwise builds the same version from crates.io with a pinned Rust.
- **Herdr installed from the pinned GitHub release** into the same place the
  official installer uses (`~/.local/bin/herdr`), verified against the SHA-256
  from Herdr's own release manifest. `[update] version_check = false`.
- **OpenCode installed from the pinned release** into `~/.opencode/bin` (the
  official installer's directory) with pinned SHA-256s; `OPENCODE_DISABLE_AUTOUPDATE=1`.
- **LazyGit via DNF when possible**: the README-recommended COPR `dejan/lazygit`
  with the explicit `epel-9-<arch>` chroot, so `dnf upgrade` manages it. If the
  COPR is unreachable or has no EL9 build, the script falls back to the pinned
  GitHub release (checksums.txt verified) and says so.
- **oxfmt is project-local only**: conform is configured with a command
  resolver that only accepts `node_modules/.bin/oxfmt` found upward from the
  file; no PATH fallback, and `lsp_format = "never"` so formatting never
  silently degrades to the language server.
- **No Mason, no mise, no Prettier, no tmux.**
