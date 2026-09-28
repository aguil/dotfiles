# WSL DNS: TCP lookups for Go programs

`gh` and other Go programs fail name lookups intermittently under WSL's DNS
tunnelling, with errors like:

```text
dial tcp: lookup api.github.com on 10.255.255.254:53: no such host
error connecting to api.github.com
```

Other tools resolve the same host without trouble, so this is not an auth or
network outage.

## Cause

When WSL's DNS proxy, `10.255.255.254`, answers a UDP query from its cache, the
reply is malformed: the proxy copies the query's EDNS OPT record into the answer
section, right after the question, and puts the real answer after it. The header
counts one answer and no additional records, so a parser reads the OPT record as
the only answer. The first, uncached answer for a name is well formed.

Go's resolver always sends EDNS, finds no A or AAAA record in such a reply, and
reports "no such host". glibc, which `curl` uses, sends no EDNS by default, so
there is no OPT record to copy and its lookups succeed.

Measured on `wsl-personal` on 2026-09-28:

- `gh api graphql` failed 5 times out of 12.
- A Go lookup of `api.github.com.` over UDP failed 20 times out of 20 once the
  name was cached; over TCP it succeeded 20 times out of 20.
- `dig @10.255.255.254 api.github.com A` on a cached name reports "Message
  parser reports malformed message packet" and shows `. CLASS1232 OPT` as the
  answer. With `+noedns` or `+tcp` the answer is clean.
- `options single-request`, the first attempt at a fix, made no difference: the
  failures have nothing to do with A and AAAA queries running in parallel.

## Fix

Go and glibc both honour `options use-vc` in `/etc/resolv.conf`, which makes
them send every query over TCP. WSL regenerates `/etc/resolv.conf` (a symlink to
`/mnt/wsl/resolv.conf`) on every start, so the option only sticks once
`/etc/wsl.conf` sets `generateResolvConf = false` under `[network]`.

```bash
bash linux/wsl/dns-tcp.sh           # apply; uses sudo
bash linux/wsl/dns-tcp.sh --check   # exit 0 if in place
bash linux/wsl/dns-tcp.sh --revert  # undo
```

The script:

- keeps every `nameserver`, `search` and `domain` line WSL generated, and adds
  `use-vc` to the `options`;
- backs up the original `resolv.conf`, symlink and all, to
  `/etc/resolv.conf.pre-dns-tcp`, and the prior `generateResolvConf` value to
  `/etc/wsl.conf.pre-dns-tcp`, the first time it runs;
- is idempotent.

The change takes effect for new processes at once. No restart is needed; the
`wsl.conf` change only stops WSL from undoing it on the next start.

`--revert` restores the backup and puts `generateResolvConf` back the way it was
before `--apply`: removed if it was unset, otherwise its old value. If that
re-enables generation, run `wsl.exe --shutdown` from Windows afterwards so WSL
regenerates the file.

**The trade-off:** with generation off, the file no longer follows changes to
Windows' DNS configuration. On this setup the only nameserver is WSL's own
proxy, `10.255.255.254`, which does not change, so nothing is lost. On a machine
whose `resolv.conf` lists upstream servers directly, re-run the script after
those change.

`chezmoi apply` prints a hint on WSL when the fix is not in place
(`.chezmoiscripts/run_after_26-wsl-dns-hint.sh.tmpl`). It never applies the fix
itself, because writing `/etc` needs sudo and an apply must not prompt.
