# ansible/

The same environment as `install/*.sh` + `bin/*`, driven by Ansible: one
playbook, one role per tool, every pin read from `../versions.env`. Use it to
build (or rebuild) the VM from your workstation over SSH, or run it on the VM
itself. Only `ansible.builtin` modules are used, so no collections need to be
installed (`ansible-galaxy` is not required).

```
ansible/
├── ansible.cfg
├── site.yml                 # roles in dependency order, tagged
├── group_vars/all.yml       # repo location, versions.env parsing, options
├── inventory/
│   ├── hosts.yml.example    # copy to hosts.yml (git-ignored) with the VM's IP
│   └── localhost.yml        # run on the VM itself (connection: local)
└── roles/
    ├── common       facts, EL9 check, repository checkout on the target
    ├── sshd         key-only sshd drop-in (same content as cloud-init)
    ├── base         EPEL + CRB, git curl wget jq unzip tar gzip gcc make cmake ripgrep fd fzf …
    ├── neovim       release tarball -> /opt/nvim-<ver>, /opt/nvim, /usr/local/bin/nvim (pinned SHA-256)
    ├── tree_sitter  release binary if it runs on this glibc, else install/tree-sitter.sh (cargo build)
    ├── lazygit      dnf copr enable dejan/lazygit + dnf install; rescue -> pinned release (checksums.txt)
    ├── golang       go.dev tarball (.sha256 verified) -> /usr/local/go; gopls, goimports, staticcheck
    ├── node         install/node.sh (nvm, Node LTS, Corepack pnpm, vtsls + langservers)
    ├── herdr        pinned static binary -> ~/.local/bin/herdr (SHA-256 from Herdr's manifest)
    ├── opencode     pinned tarball -> ~/.opencode/bin; herdr integration install opencode
    ├── dotfiles     symlinks + ~/.bashrc block (same layout as bin/install-dotfiles)
    ├── worktrees    bin/setup-worktrees
    ├── workspaces   bin/setup-workspaces
    └── verify       bin/verify-environment (fails the play if a check fails)
```

Where a step is pure package/file management the role uses native modules
(`dnf`, `get_url` with `checksum:`, `unarchive`, `file`, `blockinfile`). Where
the shell script already encodes non-trivial logic (nvm's installer, the
tree-sitter source build, Herdr's JSON-driven workspace bootstrap) the role runs
that script and derives *changed* from its output, so there is one
implementation of that logic, not two.

## Installing Ansible

Ansible runs on a Linux/macOS *control node* and talks to the VM over SSH.
Windows cannot be a control node natively; use WSL.

**Windows (WSL2, Ubuntu)** — one time:
```
wsl --install -d Ubuntu            # from an elevated PowerShell, then open Ubuntu
sudo apt update && sudo apt install -y pipx openssh-client
pipx ensurepath && exec bash
pipx install --include-deps ansible      # or the smaller: pipx install ansible-core
ansible --version
# make the same key Windows Terminal uses available inside WSL:
mkdir -p ~/.ssh && cp /mnt/c/Users/<you>/.ssh/id_ed25519 ~/.ssh/ && chmod 600 ~/.ssh/id_ed25519
```

**macOS**: `brew install ansible` (or `pipx install --include-deps ansible`).

**Linux**: `pipx install --include-deps ansible`, or the distro package
(`sudo dnf install ansible-core` on Fedora/EL, `sudo apt install ansible` on Debian/Ubuntu).

**On the VM itself** (no control node): Oracle Linux 9 AppStream ships
`ansible-core` 2.14, which is enough for this playbook:
```
sudo dnf -y install ansible-core
```

`pip install --user ansible-core` works too, but keep it out of the system
Python (`python3 -m venv ~/.venvs/ansible && ~/.venvs/ansible/bin/pip install ansible-core`).
Tested with ansible-core 2.19 (control node) and 2.14 (on the VM).

## Running it

From the control node, after `terraform apply`:
```
cd oracle-herdr-dev/ansible
cp inventory/hosts.yml.example inventory/hosts.yml   # set ansible_host to `terraform output public_ip`
ansible dev -m ping                                  # connectivity + Python on the target
ansible-playbook site.yml                            # everything, ~5-10 min on a fresh VM
```

On the VM itself (after `git clone … ~/cli-configs`):
```
cd ~/cli-configs/oracle-herdr-dev/ansible
ansible-playbook -i inventory/localhost.yml site.yml
```

Useful variations:
```
ansible-playbook site.yml --tags herdr,opencode      # one or two roles
ansible-playbook site.yml --skip-tags verify,workspaces
ansible-playbook site.yml -e lazygit_install=release # skip the COPR attempt
ansible-playbook site.yml -e run_workspaces=false    # do not touch the Herdr server
ansible-playbook site.yml --check --diff             # dry run (script-backed roles report "skipped")
```

Behind a proxy or with a corporate CA, set `install_env` (applied to every
task on the target): `-e '{"install_env": {"HTTPS_PROXY": "http://proxy:3128"}}'`.

## Variables (group_vars/all.yml)

| variable                 | default                                   | meaning                                            |
|--------------------------|-------------------------------------------|----------------------------------------------------|
| `manage_repo_checkout`   | `true`                                    | clone/update this repository on the target (`false` in localhost.yml) |
| `repo_url`, `repo_version` | this GitHub repo, branch                | what to check out                                  |
| `repo_dir`               | `~/cli-configs/oracle-herdr-dev`          | where scripts and dotfiles are read from on the target |
| `go_dl_base`             | `https://go.dev/dl`                       | Go download base (mirrors/offline)                 |
| `lazygit_install`        | `copr`                                    | `copr` (dnf) or `release` (pinned tarball)         |
| `manage_sshd`            | `true`                                    | install the key-only sshd drop-in                  |
| `run_worktrees`, `run_workspaces`, `run_verify` | `true`             | run the corresponding `bin/` script                |
| `install_env`            | `{}`                                      | extra environment for all tasks                    |

Versions are **not** variables here on purpose: they are parsed from
`versions.env` so the scripts and the playbook can never disagree. To upgrade a
tool, change `versions.env` (and its checksum) and re-run the playbook with that
role's tag.

## Idempotency

A second run reports `changed=0` for every native role. Script-backed roles
report *changed* only when their output shows work was done (`creating
worktree`, `created w…`, `Downloading and installing node`, …), and
`verify` never reports changed.

Secrets: the playbook never asks for or stores any. OCI keys stay on the
workstation, the SSH key is referenced by path, OpenCode credentials live in
`~/.local/share/opencode/auth.json` which no role touches.
