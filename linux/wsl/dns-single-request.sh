#!/usr/bin/env bash
# Make Go programs such as gh resolve names reliably under WSL DNS tunnelling.
#
# Go's own resolver sends A and AAAA queries in parallel over one socket, and
# WSL's DNS proxy intermittently answers that with NXDOMAIN, so `gh` fails with
# "lookup api.github.com on 10.255.255.254:53: no such host" on roughly every
# other call while curl (glibc) never does. Go honours `options single-request`
# in resolv.conf, which serialises the two queries. WSL regenerates
# /etc/resolv.conf on every boot, so the option only sticks once wsl.conf stops
# that. See README.md next to this script.
#
# Usage:
#   dns-single-request.sh [--apply]   write both files (default; uses sudo)
#   dns-single-request.sh --check     exit 0 if already in place, 1 if not
#   dns-single-request.sh --revert    restore the backed-up resolv.conf and
#                                     the prior generateResolvConf setting
#
# WSL_CONF and RESOLV_CONF override the file paths, for tests.
set -euo pipefail

WSL_CONF="${WSL_CONF:-/etc/wsl.conf}"
RESOLV_CONF="${RESOLV_CONF:-/etc/resolv.conf}"
BACKUP="${RESOLV_CONF}.pre-single-request"
# Holds the generateResolvConf value wsl.conf had before --apply; empty when
# the key was unset.
WSL_BACKUP="${WSL_CONF}.pre-single-request"

die() {
  printf 'dns-single-request: %s\n' "$*" >&2
  exit 2
}

is_wsl() {
  [ -n "${WSL_DISTRO_NAME:-}" ] || [ -e /proc/sys/fs/binfmt_misc/WSLInterop ]
}

# Run a command directly when the target directory is writable, else via sudo.
as_owner() {
  local target_dir="$1"
  shift
  if [ -w "$target_dir" ]; then
    "$@"
  else
    sudo "$@"
  fi
}

# Print wsl.conf with `generateResolvConf = <value>` set in [network], adding
# the section or the key as needed and leaving everything else untouched. An
# empty value removes the key instead.
render_wsl_conf() {
  local value="$1"
  local src="$WSL_CONF"
  [ -f "$src" ] || src=/dev/null
  awk -v value="$value" '
    function emit_key() { if (value != "") print "generateResolvConf = " value; done = 1 }
    /^[[:space:]]*\[/ {
      if (in_network && !done) emit_key()
      in_network = (tolower($0) ~ /^[[:space:]]*\[network\][[:space:]]*$/)
      if (in_network) seen = 1
      print
      next
    }
    in_network && tolower($0) ~ /^[[:space:]]*generateresolvconf[[:space:]]*=/ {
      if (!done) emit_key()
      next
    }
    { print }
    END {
      if (in_network && !done) emit_key()
      if (!seen && value != "") { if (NR > 0) print ""; print "[network]"; emit_key() }
    }
  ' "$src"
}

# Print the generateResolvConf value set in [network], or nothing when unset.
generation_value() {
  [ -f "$WSL_CONF" ] || return 0
  awk '
    /^[[:space:]]*\[/ { in_network = (tolower($0) ~ /^[[:space:]]*\[network\][[:space:]]*$/); next }
    in_network && tolower($0) ~ /^[[:space:]]*generateresolvconf[[:space:]]*=/ {
      sub(/^[^=]*=[[:space:]]*/, ""); sub(/[[:space:]]*$/, ""); print; exit
    }
  ' "$WSL_CONF"
}

generation_disabled() {
  [ -f "$WSL_CONF" ] || return 1
  awk '
    /^[[:space:]]*\[/ { in_network = (tolower($0) ~ /^[[:space:]]*\[network\][[:space:]]*$/); next }
    in_network && tolower($0) ~ /^[[:space:]]*generateresolvconf[[:space:]]*=[[:space:]]*false[[:space:]]*$/ { found = 1 }
    END { exit found ? 0 : 1 }
  ' "$WSL_CONF"
}

single_request_set() {
  [ -f "$RESOLV_CONF" ] && [ ! -L "$RESOLV_CONF" ] &&
    grep -Eq '^[[:space:]]*options([[:space:]].*)?[[:space:]]single-request([[:space:]]|$)' "$RESOLV_CONF"
}

# Print resolv.conf keeping every nameserver/search/domain line as it is now,
# with `single-request` added to any existing options.
render_resolv_conf() {
  [ -r "$RESOLV_CONF" ] || die "cannot read $RESOLV_CONF"
  awk '
    /^[[:space:]]*(#|;|$)/ { next }
    /^[[:space:]]*options[[:space:]]/ {
      for (i = 2; i <= NF; i++) if ($i != "single-request") opts = opts " " $i
      next
    }
    { print }
    END { print "options" opts " single-request" }
  ' "$RESOLV_CONF"
}

write_file() {
  local target="$1" content="$2" dir tmp
  dir="$(dirname "$target")"
  tmp="$(mktemp)"
  printf '%s\n' "$content" >"$tmp"
  as_owner "$dir" rm -f "$target"
  as_owner "$dir" install -m 0644 "$tmp" "$target"
  rm -f "$tmp"
}

apply() {
  local resolv wsl dir
  if single_request_set && generation_disabled; then
    printf 'dns-single-request: already in place\n'
    return 0
  fi
  dir="$(dirname "$RESOLV_CONF")"
  resolv="$(render_resolv_conf)"
  wsl="$(render_wsl_conf false)"
  # Keep what WSL made, symlink and all, so --revert can put it back exactly.
  if [ ! -e "$BACKUP" ] && [ ! -L "$BACKUP" ]; then
    as_owner "$dir" cp -P "$RESOLV_CONF" "$BACKUP"
  fi
  if [ ! -e "$WSL_BACKUP" ]; then
    write_file "$WSL_BACKUP" "$(generation_value)"
  fi
  write_file "$WSL_CONF" "$wsl"
  write_file "$RESOLV_CONF" "$resolv"
  printf 'dns-single-request: wrote %s and %s (backup: %s)\n' \
    "$WSL_CONF" "$RESOLV_CONF" "$BACKUP"
  printf 'dns-single-request: in effect now; it survives restarts because WSL no longer regenerates %s\n' \
    "$RESOLV_CONF"
}

revert() {
  local dir prior=true
  dir="$(dirname "$RESOLV_CONF")"
  [ -e "$BACKUP" ] || [ -L "$BACKUP" ] || die "no backup at $BACKUP; nothing to revert"
  # A backup from before WSL_BACKUP existed has no record; assume the default.
  if [ -f "$WSL_BACKUP" ]; then
    prior="$(head -n 1 "$WSL_BACKUP")"
  fi
  write_file "$WSL_CONF" "$(render_wsl_conf "$prior")"
  as_owner "$(dirname "$WSL_BACKUP")" rm -f "$WSL_BACKUP"
  as_owner "$dir" rm -f "$RESOLV_CONF"
  as_owner "$dir" mv "$BACKUP" "$RESOLV_CONF"
  if [ "$(printf '%s' "$prior" | tr '[:upper:]' '[:lower:]')" = false ]; then
    printf 'dns-single-request: restored %s and left resolv.conf generation disabled, as it was\n' \
      "$RESOLV_CONF"
  else
    printf 'dns-single-request: restored %s; run wsl.exe --shutdown from Windows so WSL regenerates it on the next start\n' \
      "$RESOLV_CONF"
  fi
}

main() {
  local mode="${1:---apply}"
  case "$mode" in
    --check)
      single_request_set && generation_disabled
      ;;
    --apply)
      is_wsl || die "not running under WSL; nothing to do"
      apply
      ;;
    --revert)
      is_wsl || die "not running under WSL; nothing to do"
      revert
      ;;
    -h | --help)
      sed -n '2,19p' "$0" | sed 's/^# \{0,1\}//'
      ;;
    *)
      die "unknown option: $mode (try --help)"
      ;;
  esac
}

main "$@"
