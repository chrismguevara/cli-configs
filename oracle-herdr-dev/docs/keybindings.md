# Keybindings

## Herdr (prefix `Ctrl-b`)

Configured in `dotfiles/herdr/config.toml`; `Ctrl-b ?` shows the built-in help.

| keys                | action                                   |
|---------------------|------------------------------------------|
| `Ctrl-b w`          | workspace picker (ws1 … ws5)             |
| `Ctrl-b 1` … `9`    | switch to tab n (1 nvim, 2 opencode, 3 git, 4 dev, 5 shell, 6 scratch) |
| `Ctrl-b h/j/k/l`    | focus pane left/down/up/right            |
| `Ctrl-b z`          | zoom / unzoom the focused pane           |
| `Ctrl-b q`          | detach (server and processes keep running) |
| `Ctrl-b n` / `p`    | next / previous tab                      |
| `Ctrl-b c`          | new tab (in the workspace directory)     |
| `Ctrl-b Shift-t`    | rename tab                               |
| `Ctrl-b Shift-x`    | close tab                                |
| `Ctrl-b v`          | split pane right                         |
| `Ctrl-b -`          | split pane down                          |
| `Ctrl-b x`          | close pane                               |
| `Ctrl-b r`          | resize mode                              |
| `Ctrl-b [`          | copy / scrollback mode                   |
| `Ctrl-b b`          | toggle sidebar                           |
| `Ctrl-b Shift-n`    | new workspace                            |
| `Ctrl-b Shift-w`    | rename workspace                         |
| `Ctrl-b Shift-d`    | close workspace                          |
| `Ctrl-b Shift-r`    | reload config.toml                       |

Plain `Ctrl-h/j/k/l` are never consumed by Herdr, so they reach Neovim.

## Neovim (leader = Space)

### Navigation and files
| keys              | action                                    |
|-------------------|-------------------------------------------|
| `Ctrl-h/j/k/l`    | move between Neovim windows               |
| `-`               | Oil: open parent directory (edit the listing like a buffer, `q` closes) |
| `Space ff`        | Telescope find files                      |
| `Space fg`        | Telescope live grep (ripgrep)             |
| `Space fb`        | Telescope buffers                         |
| `Space fh`        | Telescope help tags                       |
| `Space fr`        | Telescope recent files                    |
| `Space fd`        | Telescope diagnostics                     |
| `Space fs`        | Telescope grep word under cursor          |
| `Space /`         | fuzzy search in the current buffer        |
| `Space w`         | write buffer                              |
| `Space bd`        | delete buffer                             |
| `Esc`             | clear search highlight                    |
| `Esc Esc` (terminal) | leave terminal mode                    |

### LSP (buffer-local once a server attaches)
| keys              | action                                    |
|-------------------|-------------------------------------------|
| `gd`              | go to definition (Telescope list when several) |
| `gr`              | references                                |
| `gI`              | go to implementation                      |
| `gy`              | go to type definition                     |
| `gD`              | go to declaration                         |
| `K`               | hover documentation                       |
| `Space rn`        | rename symbol                             |
| `Space ca`        | code action (normal/visual)               |
| `Space ds`        | document symbols                          |
| `Space ws`        | workspace symbols                         |
| `Space th`        | toggle inlay hints                        |
| `[d` / `]d`       | previous / next diagnostic                |
| `Space e`         | line diagnostics in a float               |
| `Space q`         | diagnostics to location list              |

### Formatting (conform.nvim)
| keys              | action                                    |
|-------------------|-------------------------------------------|
| `Space cf`        | format buffer: JS/TS/TSX/JSON/CSS with the project's `node_modules/.bin/oxfmt`; Go with goimports (gofmt fallback). Errors if oxfmt is missing; never falls back to LSP formatting. |

Set `vim.g.format_on_save = true` in `init.lua` to also format on `:w`.

### Git (gitsigns)
| keys              | action                                    |
|-------------------|-------------------------------------------|
| `]c` / `[c`       | next / previous hunk                      |
| `Space hs` / `hr` | stage / reset hunk (also in visual mode)  |
| `Space hp`        | preview hunk                              |
| `Space hb`        | blame line                                |
| `Space hd`        | diff against index                        |
| `Space tb`        | toggle current-line blame                 |

### Completion (blink.cmp, default preset)
`Ctrl-Space` open menu · `Ctrl-n`/`Ctrl-p` next/previous · `Ctrl-y` accept ·
`Ctrl-e` close · `Ctrl-b`/`Ctrl-f` scroll docs (note: inside Neovim's insert
mode `Ctrl-b` is blink's, Herdr only sees `Ctrl-b` as its prefix when the key
is not consumed first; use `Ctrl-b` outside insert mode for Herdr).

### which-key
`Space ?` lists buffer-local mappings; pressing `Space` and waiting shows the
groups (find, code, git hunk, toggle, …).

## LazyGit and OpenCode

Their own defaults apply (`?` in LazyGit; `Ctrl-x` is OpenCode's leader). Both
run in their own Herdr tab, so no key is remapped for them.
