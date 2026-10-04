# Installation

## 1. Oracle Cloud VM (Always Free, Oracle Linux 9)

What gets created: one VCN (10.42.0.0/16), one public subnet, an internet
gateway and route table, a security list allowing **only TCP/22 inbound**, and
one instance from the latest *Oracle Linux 9* platform image with
`infra/terraform/cloud-init.yaml` (key-only sshd drop-in, git/curl/tar).

Free-tier shape choice (see `infra/terraform/variables.tf`):

| shape                    | arch    | size                        | note                                   |
|--------------------------|---------|-----------------------------|----------------------------------------|
| `VM.Standard.A1.Flex`    | aarch64 | 2 OCPU / 12 GB (default)    | Always Free ceiling as published 2026-09; capacity errors are common, retry / other AD |
| `VM.Standard.E2.1.Micro` | x86_64  | 1/8 OCPU / 1 GB             | always available, but 1 GB is too small for tsserver + gopls + OpenCode |

Always Free compute must be in the tenancy's home region. Oracle reclaims
instances that stay idle (<20% CPU/network/memory for 7 days).

### Terraform

```
cd infra/terraform
cp terraform.tfvars.example terraform.tfvars      # region, compartment OCID, your SSH public key
terraform init
terraform plan
terraform apply
terraform output ssh_command
```

Authentication: `~/.oci/config` profile `DEFAULT` (from `oci setup config`) or
`TF_VAR_tenancy_ocid` / `TF_VAR_user_ocid` / `TF_VAR_fingerprint` /
`TF_VAR_private_key_path`. State and tfvars are git-ignored.

### OCI CLI

```
export OCI_COMPARTMENT_OCID=ocid1.tenancy.oc1..…   SSH_PUBLIC_KEY_FILE=~/.ssh/id_ed25519.pub
infra/scripts/oci-cli-provision.sh                  # optional: SHAPE, SHAPE_OCPUS, SHAPE_MEMORY_GB, AD_INDEX
```

Both paths are idempotent by display name and print the SSH command.

## 2. Windows Terminal + SSH

Generate a key once (`ssh-keygen -t ed25519`) and put its `.pub` contents in
`terraform.tfvars`. Add a host entry to `%USERPROFILE%\.ssh\config` so a
Windows Terminal profile can just run `ssh dev`:

```
Host dev
  HostName <public-ip>
  User opc
  IdentityFile ~/.ssh/id_ed25519
  ServerAliveInterval 30
  # workspace 1
  LocalForward 5173 localhost:5173
  LocalForward 8081 localhost:8081
  LocalForward 8181 localhost:8181
  LocalForward 5433 localhost:5433
  # add the other workspaces' ports when you use them (see README table)
```

Equivalent one-liner:

```
ssh -L 5173:localhost:5173 -L 8081:localhost:8081 -L 8181:localhost:8181 -L 5433:localhost:5433 opc@<public-ip>
```

Then `http://localhost:5173` on Windows is the Vite dev server of workspace 1.
Do **not** open those ports in the OCI security list or firewalld.

## 3. Install scripts (on the VM)

```
sudo dnf -y install git
git clone https://github.com/chrismguevara/cli-configs.git ~/cli-configs
cd ~/cli-configs/oracle-herdr-dev
./install/all.sh
```

`install/all.sh` runs the scripts below in order. Each is idempotent (re-run
after editing `versions.env`), verifies checksums where the upstream publishes
or where a pin is recorded, and never edits `~/.bashrc` (that is
`bin/install-dotfiles`' job).

| script                   | installs                                                                                   |
|--------------------------|--------------------------------------------------------------------------------------------|
| `install/base.sh`        | `oracle-epel-release-el9` + enables `ol9_developer_EPEL` and `ol9_codeready_builder`; git curl wget jq unzip tar gzip gcc gcc-c++ make cmake ripgrep fd-find fzf … via dnf |
| `install/neovim.sh`      | Neovim release tarball → `/opt/nvim-<ver>`, `/opt/nvim` symlink, `/usr/local/bin/nvim` (pinned SHA-256, Neovim publishes none) |
| `install/tree-sitter.sh` | tree-sitter CLI → `/usr/local/bin/tree-sitter`; official binary if it runs, else built from crates.io with rustup (`RUST_TOOLCHAIN`) because EL9's glibc 2.34 < 2.39 |
| `install/lazygit.sh`     | `dnf copr enable dejan/lazygit epel-9-<arch>` + `dnf install lazygit`; falls back to the pinned GitHub release (checksums.txt) and says why |
| `install/golang.sh`      | Go from go.dev (`.sha256` verified) → `/usr/local/go`; `go install` gopls, goimports, staticcheck → `~/go/bin` |
| `install/node.sh`        | nvm (pinned tag, `PROFILE=/dev/null`) → Node LTS → Corepack pnpm; global `typescript@6`, `@vtsls/language-server`, `vscode-langservers-extracted` |
| `install/herdr.sh`       | Herdr release binary → `~/.local/bin/herdr` (SHA-256 from Herdr's manifest)                |
| `install/opencode.sh`    | OpenCode release tarball → `~/.opencode/bin/opencode` (pinned SHA-256, AVX2/baseline aware); then `herdr integration install opencode` |

Language servers live at the OS/user level on purpose (no Mason):
`vtsls`, `vscode-eslint-language-server`, `vscode-html-language-server`,
`vscode-css-language-server`, `vscode-json-language-server` under nvm's global
bin; `gopls` in `~/go/bin`. oxfmt, TypeScript, ESLint and Vite are project
dependencies of each frontend.

### Ansible instead of the scripts

`ansible/site.yml` performs sections 3 to 5 (and the sshd drop-in) from a
control node over SSH, or on the VM with `-i inventory/localhost.yml`. Roles use
native modules for packages and release downloads (checksums from
`versions.env`) and call the repository's scripts where they hold the logic
(nvm, tree-sitter source build, worktrees, Herdr workspaces, verification).
Installing Ansible on Windows (WSL), macOS, Linux or the VM, and all variables:
`ansible/README.md`.

## 4. Dotfiles

```
./bin/install-dotfiles
exec bash
```

Symlinks (repo → home): `dotfiles/bashrc → ~/.config/dev-shell/bashrc` (one
marked `source` line is appended to `~/.bashrc`), `dotfiles/herdr/config.toml
→ ~/.config/herdr/config.toml`, `dotfiles/nvim → ~/.config/nvim`, and every
executable in `bin/` into `~/.local/bin`. Existing non-symlink files are backed
up once as `*.pre-dev-shell`.

The first interactive `nvim` (or `verify-environment`) bootstraps lazy.nvim,
installs the plugins pinned in `dotfiles/nvim/lazy-lock.json`, downloads
blink.cmp's prebuilt fuzzy matcher, builds telescope-fzf-native with `make`,
and compiles the tree-sitter parsers with the C compiler + tree-sitter CLI.

## 5. Worktrees and workspaces

```
setup-worktrees      # copies test/fixture-monorepo → ~/src/fixture-monorepo (git init, branch main),
                     # adds worktrees ~/worktrees/1..5 on branches ws/1..5, writes .workspace.env,
                     # runs pnpm install --frozen-lockfile in each frontend
setup-workspaces     # starts `herdr server` if needed and builds ws1..ws5 (idempotent)
verify-environment   # full check; exit code 0 = everything passed
```

`setup-workspaces` uses only Herdr's JSON CLI output (`herdr workspace list`,
`tab list`, `pane list`, `pane process-info`): a workspace is looked up by
label, a tab by label within the workspace, panes by count/labels, and a tool
is launched only into a pane whose foreground process is still the bare shell.
OpenCode is started with `herdr agent start ws<n> --kind opencode`, so Herdr
tracks its state (`herdr agent list`) and, with the integration, its session id.

## 6. Start Herdr at boot (optional)

The Herdr server is a user process; after a reboot nothing runs until you type
`herdr`. To have the server (and the restored layout) waiting:

```
sudo loginctl enable-linger opc
mkdir -p ~/.config/systemd/user
cp ~/cli-configs/oracle-herdr-dev/dotfiles/systemd/herdr-server.service ~/.config/systemd/user/
systemctl --user daemon-reload
systemctl --user enable --now herdr-server
```

Then `herdr` attaches and `setup-workspaces` relaunches the tools. This unit
was not exercised by the container-based validation (no systemd there).

## 7. Updating

Pins live in `versions.env`; "latest on every login" is deliberately not part
of the workflow (`[update] version_check = false` in Herdr,
`OPENCODE_DISABLE_AUTOUPDATE=1`, lazy.nvim `checker.enabled = false`).

- **Herdr**: set `HERDR_VERSION` and the two `HERDR_SHA256_*` values from
  `https://herdr.dev/latest.json` (`releases["<ver>"].sha256`), run
  `install/herdr.sh`, then `herdr server stop` and `herdr` to restart the server
  on the new binary (or `herdr update --handoff`). Re-run `install/opencode.sh`
  if `herdr integration status` reports the OpenCode integration as outdated.
- **Neovim**: set `NEOVIM_VERSION` and `NEOVIM_SHA256_*`
  (`curl -fsSL <asset-url> | sha256sum`), run `install/neovim.sh`.
- **Neovim plugins**: `:Lazy update`, test, commit `dotfiles/nvim/lazy-lock.json`.
  Fresh machines then get exactly those commits via `:Lazy restore`.
- **tree-sitter CLI**: set `TREE_SITTER_VERSION` (+ SHA-256s), run
  `install/tree-sitter.sh`, then `:TSUpdate` in Neovim.
- **LazyGit**: `sudo dnf upgrade lazygit` when installed from COPR. If the
  fallback was used, bump `LAZYGIT_VERSION` and run `install/lazygit.sh`
  (or `LAZYGIT_INSTALL=copr` once the repository is reachable).
- **Go**: set `GO_VERSION`, run `install/golang.sh` (re-installs gopls/goimports/staticcheck).
- **Node**: set `NODE_VERSION` (and `PNPM_VERSION`, `NVM_VERSION`), run
  `install/node.sh`; `nvm alias default` moves to the new version.
- **OpenCode**: set `OPENCODE_VERSION` + `OPENCODE_SHA256_*`, run `install/opencode.sh`.
- **OS packages**: `sudo dnf upgrade`.

After any upgrade: `verify-environment`.
