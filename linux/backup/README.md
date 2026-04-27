# Linux apt package workflow

This folder contains helper scripts for exporting and reinstalling apt packages.

## Export

Run from repo root:

```bash
bash ./linux/backup/export-apt-packages.sh
```

This writes the current manual package list to `linux/apt-packages.txt` using:

- `apt-mark showmanual | sort`

## Install

Run from repo root:

```bash
bash ./linux/backup/install-apt-packages.sh
```

The install script updates apt metadata and installs packages listed in
`linux/apt-packages.txt`.

## Notes

- Review the package list before committing.
- Optional Python tools (e.g. `tmuxp` for hand-written YAML tmux layouts) are in `linux/pip-packages.txt`. Install with: `pip install -r linux/pip-packages.txt`.
- Some packages may be machine- or distro-specific.
- Keep secrets and auth material out of this list.

## Optional: install gitleaks

`gitleaks` is often not available in default Ubuntu apt repositories.

Check availability:

```bash
apt-cache policy gitleaks
```

If no package candidate is available, install with Go:

```bash
go install github.com/gitleaks/gitleaks/v8@latest
```

Then run a repo scan from dotfiles root:

```bash
gitleaks detect --no-git --source .
```
