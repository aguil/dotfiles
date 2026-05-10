# Shell prompt font setup (oh-my-posh)

The Spaceship-style theme in `dot_config/oh-my-posh/spaceship-custom.omp.json`
uses **Nerd Font** icons (Private Use Area codepoints). Oh My Posh does **not**
ship fonts; the **terminal** (or IDE terminal) must use a font that includes
those glyphs, or icons render as blanks or replacement boxes.

See also: [Oh My Posh — Fonts](https://ohmyposh.dev/docs/installation/fonts).

## Windows + WSL

Fonts apply to **where the pixels are drawn**: the **Windows host** terminal
(Windows Terminal, Cursor’s terminal on Windows, etc.). Installing a font only
inside WSL does **not** make it available to Windows Terminal’s font picker.

1. Install a Nerd Font **from Windows** (PowerShell or Command Prompt), not only
   from a Linux shell:

   ```powershell
   oh-my-posh font install
   ```

   Choose **Meslo**, or install Meslo directly:

   ```powershell
   oh-my-posh font install Meslo
   ```

   If the CLI misbehaves on your Windows version, download **Meslo** from
   [Nerd Fonts](https://www.nerdfonts.com/font-downloads), extract the `.ttf`
   files, then right-click → **Install** or **Install for all users**.

2. **Windows Terminal** — set the face in **`settings.json`** (Ctrl+, → Open JSON).
   The UI font dropdown is often incomplete; the JSON value is authoritative.

   Under `profiles` → `defaults`, set for example:

   ```json
   "font": {
     "face": "MesloLGM Nerd Font",
     "size": 12
   }
   ```

   Merge with any existing `"font"` object (do not duplicate keys).

3. **Confirm the exact family name** Windows registered (names vary by package):

   ```powershell
   (New-Object System.Drawing.Text.InstalledFontCollection).Families |
     Where-Object Name -match 'Meslo|Nerd|NF' |
     Select-Object -ExpandProperty Name
   ```

   Use the printed string as `"face"` exactly.

4. **Fully quit** Windows Terminal (all windows), then reopen so the face reloads.

## Linux / macOS

Install any **Nerd Font** from [Nerd Fonts](https://www.nerdfonts.com/) (or your
package manager), then select that font in your terminal emulator’s profile.
On Linux, `fc-list` can confirm the family name.

## Cursor / VS Code

Set the integrated terminal font to the same Nerd Font family (for example
`terminal.integrated.fontFamily` in VS Code–compatible settings).

## Neovim

`dot_config/nvim/init.lua` sets `vim.g.have_nerd_font`. When your **terminal**
font is a Nerd Font and icons look correct in the shell prompt, you can set
that flag to `true` so plugin icon behavior matches your terminal.

## Quick check

In the shell (with the Nerd Font active in that terminal):

```bash
printf '%s\n' '\ue627\ue798\ue235\ue718\ue76f\ue738\ue634'
```

You should see distinct icons (Go, Dart, Python, Node, Bun, Java, Kotlin) used
in the custom Oh My Posh theme.
