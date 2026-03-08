Jason's dotfiles
================

This repository stores personal shell/editor/tooling config and Windows setup assets.

## Windows backups

Use `windows/backup/export.ps1` to snapshot common Windows app and terminal config into this repo.

```powershell
powershell -ExecutionPolicy Bypass -File .\windows\backup\export.ps1
```

The script is safe to re-run. It only copies files that exist and skips missing targets.

## Linux apt packages

Use `linux/backup/export-apt-packages.sh` to snapshot manual apt packages into this repo.

```bash
bash ./linux/backup/export-apt-packages.sh
```

Use `linux/backup/install-apt-packages.sh` to install from `linux/apt-packages.txt`.

## Commit messages

Use `docs/commit-message-guide.md` for commit message conventions in this repo.

## Consolidation planning

- `docs/config-matrix.md` captures what is shared vs platform-specific vs persona-specific.
- `docs/drift-exceptions.md` tracks intentional differences between systems and why they exist.
- `docs/chezmoi-profiles.md` explains `work` vs `personal` profile usage.

## Prompt snippets

Reusable prompt snippets live in `docs/prompts/`.

Use `scripts/oprompt.ps1` to print or copy one:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\oprompt.ps1 commit
powershell -ExecutionPolicy Bypass -File .\scripts\oprompt.ps1 pr-update -Copy
```

`scripts/aprompt.ps1` is kept as a backward-compatible wrapper to `scripts/oprompt.ps1`.

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\aprompt.ps1 commit
```

For WSL/macOS/Linux, use `scripts/oprompt.sh`:

```bash
./scripts/oprompt.sh commit
./scripts/oprompt.sh pr-update --copy
```

After reloading your shell, you can also call `oprompt` from anywhere:

```bash
oprompt commit
oprompt pr-update --copy
```

`aprompt` remains as a backward-compatible alias.

## Neovim AI terminal integration

Neovim uses a profile-aware terminal command for AI CLI workflows:

- `work` profile sets `AI_TERM_CMD=agent`
- `personal` profile sets `AI_TERM_CMD=opencode`

This is defined in `dot_bash_profile.tmpl` and `dot_zshrc.tmpl`.

### Files

- `dot_config/nvim/init.lua` imports `custom.plugins`.
- `dot_config/nvim/lua/custom/plugins/ai_cli.lua` configures `toggleterm.nvim` and the AI terminal commands/keymaps.

### Keymaps and commands

- `<leader>at`: toggle AI terminal
- `<leader>al`: send current line
- `<leader>as`: send visual selection
- `<leader>ah`: send context (file path, cursor, diagnostics, nearby code)
- `<leader>af`: send current file (line-numbered, capped)
- `<leader>ad`: send git diff for current file
- `<leader>aD`: send staged git diff for current file
- `<leader>ax`: send diagnostics only
- `<leader>ai`: show AI command/terminal status
- `:AiSend {text}`: send ad-hoc text
- `:AiHere [request]`: send context with optional request text
- `:AiFile [request]`: send current file with optional request
- `:AiDiag [request]`: send diagnostics with optional request
- `:AiDiff [request]`: send working-tree diff for current file
- `:AiDiffStaged [request]`: send staged diff for current file
- `:AiStatus`: show configured command and availability

### Notes

- The default command is `agent` if `AI_TERM_CMD` is not set.
- `toggleterm.nvim` must be installed via Lazy (run `:Lazy sync` after config changes).
- Visual selection handling normalizes reversed selections to avoid `E5108` (`start_col must be <= end_col`).
- Optional tuning env vars:
  - `AI_CONTEXT_LINES` (default `7`)
  - `AI_FILE_LINES` (default `300`)
  - `AI_DIFF_LINES` (default `300`)

## Neovim version and install notes

This Neovim config tracks newer APIs and plugins, and may not work with distro `apt` packages on some Ubuntu releases.

- Prefer Neovim `0.11+` (or current stable/nightly).
- If `apt install neovim` is too old for this config, build Neovim from source.
- Confirm your active binary/version with:

```bash
command -v nvim
nvim --version | head -n 1
```

### Building from source with Zig via mise

If your distro `apt` package for `mise` is outdated, install/update `mise` via `cargo` first:

```bash
cargo install mise
```

Install Rust/Cargo first if needed: https://rust-lang.org/tools/install/

Then use `mise` to install Zig and follow Neovim's Zig build flow:

```bash
mise use -g zig@0.15.2
git clone https://github.com/neovim/neovim.git
cd neovim
zig build
./zig-out/bin/nvim --version | head -n 1
zig build install --prefix ~/.local
```

If you install Neovim to `~/.local/bin`, ensure it comes before `/usr/bin` in `PATH`.

## Neovim navigation quick reference

Core code navigation (LSP):

- `grd`: go to definition
- `grD`: go to declaration
- `grr`: find references
- `gri`: go to implementation
- `grt`: go to type definition
- `grn`: rename symbol
- `gra`: code action
- `gO`: document symbols
- `gW`: workspace symbols
- `<leader>q`: diagnostics list
- `<leader>sd`: diagnostics picker

Window/project movement:

- `Ctrl-h/j/k/l`: move between windows
- `<leader>sf`: find files
- `<leader>sg`: live grep
- `<leader><leader>`: find buffers

Kotlin/Gradle helpers:

- `<leader>kb`: gradle build
- `<leader>kt`: gradle test
- `<leader>kr`: gradle bootRun
- `<leader>kk`: prompt for custom gradle task
- `<leader>k?` or `:KotlinKeys`: open in-editor key reference

Dart/Web helpers:

- `<leader>dr`: dart run
- `<leader>dt`: dart test
- `<leader>ds`: dart run webdev serve --auto=refresh
- `<leader>db`: dart run build_runner build --delete-conflicting-outputs
- `<leader>dw`: dart run build_runner watch --delete-conflicting-outputs
- `<leader>dd`: prompt for custom dart args
- `<leader>d?` or `:DartKeys`: open in-editor key reference

## Tmux daily workflow

`dot_tmux.conf` is configured for a modern Neovim-centric workflow:

- Vim-aware pane navigation with `Ctrl-h/j/k/l`
- Pane splits inherit current working directory
- Vi copy mode bindings with macOS clipboard integration
- Mouse support, larger scrollback, and readable status line
- Fast pane resize with prefix + `H/J/K/L`
- Auto-tiling: panes retile after split/close/resize; prefix + `t` to force tiled layout
- Session/window pickers: prefix + `s` (sessions), prefix + `w` (windows)

Plugins are configured in `dot_tmux.conf`. TPM is cloned automatically on first `chezmoi apply`. Run prefix + `I` inside tmux to install plugins. Includes `tmux-sensible`, `tmux-resurrect`, `tmux-continuum`, `tmux-fzf`.

### Bootstrap a dev session

Use `tmuxdev` (shell function in `dot_bash_profile.tmpl` / `dot_zshrc.tmpl`):

```bash
tmuxdev                    # web layout, session = dir name, path = PWD
tmuxdev my-session         # web layout, session my-session, path = PWD
tmuxdev my-session ~/proj  # web layout, session my-session, path ~/proj
tmuxdev dev                # dev layout (editor + AI CLI, tests, shell), session = dir name
tmuxdev dev work ~/proj    # dev layout, session work, path ~/proj
```

- **web** (default): editor (nvim, git st, ls), runtime, test, ops windows. Requires `tmuxp` (Brewfile / `linux/pip-packages.txt`).
- **dev**: editor (Neovim + AI CLI pane), tests, shell.

## Repo-scoped GitHub auth for chezmoi

The shell config includes a `gh` wrapper that automatically sets:

- `GH_CONFIG_DIR=$HOME/.config/gh-personal`

...but only when your current directory is inside your chezmoi source path (`chezmoi source-path`).

This lets you keep your default global `gh` account while always using your personal profile in the chezmoi repo.

### Automatic on `chezmoi apply`

`.chezmoiscripts/run_after_21-gh-personal-auth.sh.tmpl` bootstraps auth for the personal `gh` profile when needed.

It uses:

- `GH_CONFIG_DIR` from `CHEZMOI_GH_CONFIG_DIR` (default: `$HOME/.config/gh-personal`)
- `CHEZMOI_GH_TOKEN_OP_REF` / `.gh.tokenOpRef` to read the token via 1Password CLI (`op`)

### Manual bootstrap (optional)

Run:

```bash
ghpersonalauth
```

This logs in `gh` using the dedicated config dir and validates auth status.
