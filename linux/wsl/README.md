# WSL DNS: `single-request` for Go programs

`gh` and other Go programs fail name lookups intermittently under WSL's DNS
tunnelling, with errors like:

```text
dial tcp: lookup api.github.com on 10.255.255.254:53: no such host
error connecting to api.github.com
```

Other tools resolve the same host without trouble, so this is not an auth or
network outage.

## Cause

Measured on `wsl-personal` on 2026-09-27:

- `gh api graphql` failed on roughly every other call. `gh api /zen` failed less
  often, but did fail.
- `curl https://api.github.com/zen` succeeded 6 times out of 6.
- `dig @10.255.255.254 api.github.com A` and `AAAA` each returned `NOERROR` 3
  times out of 3 when queried one at a time.
- `GODEBUG=netdns=cgo` did not help, which suggests this `gh` build uses Go's
  own resolver regardless.

Go's resolver sends the A and AAAA queries in parallel over one socket. glibc,
which `curl` uses, copes with the WSL proxy; Go's parallel queries
intermittently come back as "no such host". The exact mechanism inside the proxy
was not pinned down.

## Fix

Go honours `options single-request` in `/etc/resolv.conf`, which makes it send
the two queries one after the other. WSL regenerates `/etc/resolv.conf` (a
symlink to `/mnt/wsl/resolv.conf`) on every start, so the option only sticks
once `/etc/wsl.conf` sets `generateResolvConf = false` under `[network]`.

```bash
bash linux/wsl/dns-single-request.sh           # apply; uses sudo
bash linux/wsl/dns-single-request.sh --check   # exit 0 if in place
bash linux/wsl/dns-single-request.sh --revert  # undo
```

The script:

- keeps every `nameserver`, `search` and `domain` line WSL generated, and adds
  `single-request` to the `options`;
- backs up the original `resolv.conf`, symlink and all, to
  `/etc/resolv.conf.pre-single-request` the first time it runs;
- is idempotent.

The change takes effect for new processes at once. No restart is needed; the
`wsl.conf` change only stops WSL from undoing it on the next start.

`--revert` restores the backup and sets `generateResolvConf = true`. Run
`wsl.exe --shutdown` from Windows afterwards so WSL regenerates the file.

**The trade-off:** with generation off, the file no longer follows changes to
Windows' DNS configuration. On this setup the only nameserver is WSL's own
proxy, `10.255.255.254`, which does not change, so nothing is lost. On a machine
whose `resolv.conf` lists upstream servers directly, re-run the script after
those change.

`chezmoi apply` prints a hint on WSL when the fix is not in place
(`.chezmoiscripts/run_after_26-wsl-dns-hint.sh.tmpl`). It never applies the fix
itself, because writing `/etc` needs sudo and an apply must not prompt.
