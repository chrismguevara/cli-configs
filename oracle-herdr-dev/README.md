# oracle-herdr-dev

A reproducible, terminal-only remote development environment on an **Oracle Cloud
Always Free** VM running **Oracle Linux 9**:

Windows Terminal → SSH → **Herdr** (persistent workspaces) → **Neovim** + **OpenCode** + **LazyGit**,
five Git worktrees, Vite + TypeScript frontend, Go backend, **oxfmt** formatting.

Everything needed to rebuild the machine is in this directory, except secrets
(OCI API key, SSH private key, OpenCode provider credentials).

```
oracle-herdr-dev/
├── versions.env            # every pinned version (+ checksums) actually tested
├── infra/terraform/        # OCI VCN + SSH-only security list + OL9 instance (+ cloud-init)
├── infra/scripts/          # same thing with the OCI CLI
├── install/                # base, neovim, tree-sitter, lazygit, golang, node, herdr, opencode, all
├── dotfiles/               # bashrc fragment, herdr/config.toml, nvim/ (lazy.nvim), systemd unit
├── bin/                    # install-dotfiles, setup-worktrees, setup-workspaces, ws-run, verify-environment
├── test/fixture-monorepo/  # Vite+React+TS frontend + Go backend used by the checks
└── docs/                   # architecture, installation, keybindings, troubleshooting
```

## From zero to a working environment

1. **Provision the VM** (free tier, SSH only). From a machine with Terraform
   and an OCI API key (`oci setup config`):
   ```
   cd infra/terraform && cp terraform.tfvars.example terraform.tfvars   # edit
   terraform init && terraform apply && terraform output ssh_command
   ```
   Or `infra/scripts/oci-cli-provision.sh` with the OCI CLI. Details:
   `docs/installation.md`.
2. **SSH in** from Windows Terminal (workspace 1 ports forwarded; add more `-L`
   flags for other workspaces, see the port table below):
   ```
   ssh -L 5173:localhost:5173 -L 8081:localhost:8081 -L 8181:localhost:8181 -L 5433:localhost:5433 opc@<public-ip>
   ```
3. **Clone this repository on the VM and install everything**:
   ```
   sudo dnf -y install git
   git clone https://github.com/chrismguevara/cli-configs.git ~/cli-configs
   cd ~/cli-configs/oracle-herdr-dev
   ./install/all.sh          # base pkgs, neovim, tree-sitter, lazygit, go, node, herdr, opencode
   ./bin/install-dotfiles    # ~/.config/dev-shell/bashrc, ~/.config/herdr, ~/.config/nvim, ~/.local/bin
   exec bash                 # pick up PATH, nvm, aliases
   ```
4. **Create the fixture worktrees and the five Herdr workspaces**:
   ```
   setup-worktrees           # ~/src/fixture-monorepo + ~/worktrees/1..5 (+ pnpm install)
   setup-workspaces          # herdr server + ws1..ws5, tabs nvim/opencode/git/dev/shell/scratch
   verify-environment        # versions, headless Neovim/LSP/format checks, herdr, fixture
   ```
5. **Work**: `herdr`, then `Ctrl-b w` to pick a worktree and `Ctrl-b 1..6` for
   nvim / opencode / git / dev / shell / scratch. `Ctrl-b q` detaches.

Optional: give OpenCode a provider (`opencode auth login`); credentials stay
in `~/.local/share/opencode/auth.json`, never in this repository.

## Daily workflow

```
ssh -L ... opc@vm          # forward the ports of the workspace(s) you use
herdr                      # attaches to the running server (or starts one)
Ctrl-b w                   # workspace picker (ws1 … ws5 = ~/worktrees/1 … 5)
Ctrl-b 1  nvim             Ctrl-b 4  dev (frontend | backend / keycloak | database)
Ctrl-b 2  opencode         Ctrl-b 5  shell
Ctrl-b 3  lazygit          Ctrl-b 6  scratch
Ctrl-b h/j/k/l  panes      Ctrl-b z  zoom      Ctrl-b q  detach
```

Every pane starts in the worktree with its `.workspace.env` loaded
(`WORKSPACE_NAME`, `FRONTEND_PORT`, `API_PORT`, `KEYCLOAK_PORT`, `POSTGRES_PORT`),
so in the dev tab `pnpm dev` / `go run ./cmd/server` bind the right localhost port:

| workspace | worktree       | Vite | API  | Keycloak | Postgres |
|-----------|----------------|------|------|----------|----------|
| ws1       | ~/worktrees/1  | 5173 | 8081 | 8181     | 5433     |
| ws2       | ~/worktrees/2  | 5174 | 8082 | 8182     | 5434     |
| ws3       | ~/worktrees/3  | 5175 | 8083 | 8183     | 5435     |
| ws4       | ~/worktrees/4  | 5176 | 8084 | 8184     | 5436     |
| ws5       | ~/worktrees/5  | 5177 | 8085 | 8185     | 5437     |

Nothing but SSH is reachable from the Internet; services bind to 127.0.0.1 and
are reached through SSH local port forwarding.

## What survives what

| event                              | Herdr server | nvim/opencode/lazygit/dev processes | layout |
|------------------------------------|--------------|-------------------------------------|--------|
| `Ctrl-b q` (detach)                | keeps running| keep running                        | kept   |
| SSH connection dropped / client killed | keeps running | keep running                     | kept   |
| `herdr server stop`                | stops        | stop                                | saved  |
| **VM reboot**                      | stops        | stop                                | saved  |

After a reboot run `herdr` (restores workspaces, tabs, panes and directories
from `~/.config/herdr/session.json`) and then `setup-workspaces` (relaunches
nvim / opencode / lazygit into the restored tabs). OpenCode panes whose session
id was reported by the Herdr integration come back with `opencode --session <id>`.
To have the server (and layout) up before you log in, see "Start Herdr at boot"
in `docs/installation.md`.

## Upgrading deliberately

Nothing updates itself. Change the pin in `versions.env`, re-run the matching
`install/<tool>.sh`, then `verify-environment`:

| tool            | pin / mechanism                                   | script                 |
|-----------------|---------------------------------------------------|------------------------|
| Neovim          | `NEOVIM_VERSION` + `NEOVIM_SHA256_*`              | `install/neovim.sh`    |
| tree-sitter CLI | `TREE_SITTER_VERSION` (+ `RUST_TOOLCHAIN`)        | `install/tree-sitter.sh` |
| Herdr           | `HERDR_VERSION` + `HERDR_SHA256_*`                | `install/herdr.sh`     |
| OpenCode        | `OPENCODE_VERSION` + `OPENCODE_SHA256_*`          | `install/opencode.sh`  |
| Go              | `GO_VERSION` (checksum fetched from go.dev)       | `install/golang.sh`    |
| Node / pnpm     | `NODE_VERSION`, `PNPM_VERSION`, `NVM_VERSION`     | `install/node.sh`      |
| LazyGit         | `sudo dnf upgrade lazygit` (COPR) or `LAZYGIT_VERSION` fallback | `install/lazygit.sh` |
| Neovim plugins  | `:Lazy update` then commit `dotfiles/nvim/lazy-lock.json` | –              |
| Base packages   | `sudo dnf upgrade`                                | `install/base.sh`      |

## Tested versions

See `versions.env` for the exact pins and checksums. Summary of what
`verify-environment` reported on the Oracle Linux 9.8 test system (x86_64):
Neovim v0.12.5, tree-sitter 0.27.0, Herdr 0.9.1 (OpenCode integration v12),
OpenCode 1.18.32, LazyGit 0.65.1, Go 1.27.1 (gopls v0.23.0, staticcheck 2026.2.1),
Node v24.21.0 (npm 11.19.0, pnpm 12.6.0, TypeScript 6.0.3, vtsls 0.3.0,
vscode-langservers-extracted 4.10.0), oxfmt 0.70.0, git 2.52.0, ripgrep 15.2.0,
fd 10.4.2, fzf 0.58.0.

## Validation status (2026-09-28)

No Oracle Cloud credentials or CLI were available where this repository was
built, so the VM itself was **not** provisioned; `infra/terraform` passed
`terraform fmt -check` and `terraform validate` against provider `oracle/oci`
9.3.0, and the OCI CLI script is untested. Everything else was executed in a
fresh `oraclelinux:9` (9.8, x86_64) container with an `opc` user, sudo and
sshd, following the README procedure exactly:

- `install/all.sh` → `verify-environment`: 43 checks passed, 0 failed
  (versions, pins, headless Neovim: lazy.nvim restore, treesitter parsers,
  vtsls + eslint attach on `App.tsx`, go-to-definition and references,
  project-local oxfmt formatting, gopls attach on `main.go`, definition and
  references, goimports/gofmt formatting, telescope-fzf-native, blink.cmp
  prebuilt matcher, Herdr create/list workspaces, five `ws<n>` workspaces,
  OpenCode integration current, fixture `tsc`/`oxfmt --check`/`go vet`).
- `setup-workspaces` created ws1…ws5 (6 tabs, 9 panes each; nvim, opencode as
  Herdr agents `ws<n>` in state `idle`, lazygit running; `.workspace.env`
  visible inside panes) and a second run changed nothing.
- SSH: attach, detach with `Ctrl-b q`, hard-kill of the SSH client, reconnect
  and reattach; the server and all pane processes survived. (In one of the
  two containers the ws1 OpenCode tab had returned to a shell by the time the
  SSH test took its snapshot; it could not be reproduced afterwards, a
  re-run of `setup-workspaces` relaunches it, see docs/troubleshooting.md.)
- Server stop/start (reboot stand-in): layout restored, processes gone as
  documented, `setup-workspaces` relaunched the tools into the restored tabs.

Sandbox differences from a real VM (each only affected *how* a step was
tested, not the scripts): `go.dev` and `dl.google.com` were blocked, so
`install/golang.sh` was run against a local mirror of the official
`go1.27.1.linux-amd64` toolchain (`GO_DL_BASE` override); the COPR host was
blocked, so LazyGit's COPR path could only be tested up to the repository
request and the pinned-release fallback was exercised instead; GitHub
`archive/` downloads were blocked, so nvim-treesitter's parser sources were
fetched with a `curl` shim that uses `git` (the parsers themselves were
compiled normally); Node needed the sandbox proxy CA. aarch64 assets are
pinned and checksummed but were not executed. The systemd unit needs a real
systemd host.

## Documentation

- `docs/architecture.md` – workspace = worktree, tab = activity, pane = process; env and port design; why each choice
- `docs/installation.md` – provisioning, SSH/Windows Terminal setup, every script, updates, autostart
- `docs/keybindings.md` – Herdr and Neovim mappings
- `docs/troubleshooting.md` – known problems and fixes
