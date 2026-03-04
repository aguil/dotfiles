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
- Some packages may be machine- or distro-specific.
- Keep secrets and auth material out of this list.
