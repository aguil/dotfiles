# Clipboard image helpers for agent CLI paste (paste-image-agent, WSL wl-paste shim).
# Platform backends: WSL/Windows, macOS, Linux (wl-paste / xclip).

clipboard_image_resolve_powershell() {
  if command -v powershell.exe >/dev/null 2>&1; then
    command -v powershell.exe
    return 0
  fi

  local candidate
  for candidate in \
    /mnt/c/Windows/System32/WindowsPowerShell/v1.0/powershell.exe \
    /mnt/c/WINDOWS/System32/WindowsPowerShell/v1.0/powershell.exe; do
    if [ -x "$candidate" ]; then
      printf '%s\n' "$candidate"
      return 0
    fi
  done

  return 1
}

clipboard_image_wsl_bridge_available() {
  [ -n "${WSL_DISTRO_NAME:-}" ] && clipboard_image_resolve_powershell >/dev/null 2>&1
}

clipboard_image_fetch_windows_to_file() {
  local dest="$1"

  local powershell ps_script win_script base64_out status
  powershell="$(clipboard_image_resolve_powershell)" || return 1
  command -v wslpath >/dev/null 2>&1 || return 1
  command -v base64 >/dev/null 2>&1 || return 1

  ps_script="$(mktemp --suffix=.ps1)"
  cat >"$ps_script" <<'EOF'
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

function Get-ClipboardImage {
    $img = [System.Windows.Forms.Clipboard]::GetImage()
    if ($null -ne $img) { return $img }

    $obj = [System.Windows.Forms.Clipboard]::GetDataObject()
    if ($null -eq $obj) { return $null }

    $formats = @(
        'PNG',
        'image/png',
        [System.Windows.Forms.DataFormats]::Bitmap,
        [System.Windows.Forms.DataFormats]::Dib,
        'DeviceIndependentBitmap'
    )
    foreach ($fmt in $formats) {
        if (-not $obj.GetDataPresent($fmt)) { continue }
        $data = $obj.GetData($fmt)
        if ($null -eq $data) { continue }
        if ($data -is [System.Drawing.Image] -or $data -is [System.Drawing.Bitmap]) {
            return $data
        }
        if ($data -is [byte[]] -and $data.Length -gt 0) {
            $ms = New-Object System.IO.MemoryStream(,$data)
            try {
                return [System.Drawing.Image]::FromStream($ms)
            } catch {
                continue
            } finally {
                $ms.Dispose()
            }
        }
        if ($data -is [System.IO.MemoryStream]) {
            try {
                return [System.Drawing.Image]::FromStream($data)
            } catch {
                continue
            }
        }
    }

    return $null
}

$img = Get-ClipboardImage
if ($null -eq $img) { exit 1 }

$ms = New-Object System.IO.MemoryStream
try {
    $img.Save($ms, [System.Drawing.Imaging.ImageFormat]::Png)
    [Console]::Out.Write([Convert]::ToBase64String($ms.ToArray()))
} finally {
    $ms.Dispose()
    $img.Dispose()
}
EOF

  win_script="$(wslpath -w "$ps_script")"
  base64_out="$("$powershell" -NoProfile -STA -ExecutionPolicy Bypass -File "$win_script" 2>/dev/null || true)"
  status=$?
  rm -f "$ps_script"

  if [ "$status" -ne 0 ] || [ -z "$base64_out" ]; then
    return 1
  fi

  if ! printf '%s' "$base64_out" | base64 -d >"$dest" 2>/dev/null; then
    return 1
  fi

  [ -s "$dest" ]
}

clipboard_image_fetch_darwin_to_file() {
  local dest="$1"

  if command -v pngpaste >/dev/null 2>&1; then
    pngpaste "$dest" 2>/dev/null && [ -s "$dest" ]
    return
  fi

  command -v osascript >/dev/null 2>&1 || return 1
  osascript - "$dest" <<'APPLESCRIPT'
on run argv
    set dest to POSIX path of (item 1 of argv)
    try
        set pngData to (the clipboard as «class PNGf»)
    on error
        error "clipboard has no image"
    end try
    set fileRef to open for access dest with write permission
    try
        write pngData to fileRef
    finally
        close access fileRef
    end try
end run
APPLESCRIPT
}

clipboard_image_fetch_wayland_to_file() {
  local dest="$1"

  command -v wl-paste >/dev/null 2>&1 || return 1

  local types
  types="$(wl-paste --list-types 2>/dev/null || true)"

  if printf '%s\n' "$types" | grep -qx 'image/png'; then
    wl-paste --type image/png >"$dest"
    [ -s "$dest" ]
    return
  fi

  if printf '%s\n' "$types" | grep -qx 'image/jpeg'; then
    wl-paste --type image/jpeg >"$dest"
    [ -s "$dest" ]
    return
  fi

  if printf '%s\n' "$types" | grep -qx 'image/bmp'; then
    if command -v magick >/dev/null 2>&1; then
      wl-paste --type image/bmp | magick - "$dest"
      [ -s "$dest" ]
      return
    fi
    if command -v convert >/dev/null 2>&1; then
      wl-paste --type image/bmp | convert - "$dest"
      [ -s "$dest" ]
      return
    fi
  fi

  return 1
}

clipboard_image_fetch_xclip_to_file() {
  local dest="$1"

  command -v xclip >/dev/null 2>&1 || return 1
  xclip -selection clipboard -t image/png -o >"$dest" 2>/dev/null && [ -s "$dest" ]
}

clipboard_image_fetch_to_file() {
  local dest="$1"

  if clipboard_image_wsl_bridge_available; then
    clipboard_image_fetch_windows_to_file "$dest"
    return
  fi

  case "$(uname -s)" in
    Darwin)
      clipboard_image_fetch_darwin_to_file "$dest"
      ;;
    Linux)
      clipboard_image_fetch_wayland_to_file "$dest" ||
        clipboard_image_fetch_xclip_to_file "$dest"
      ;;
    *)
      return 1
      ;;
  esac
}

clipboard_image_emit_windows_as_mime() {
  local mime="${1:-image/png}"
  local tmp_png

  tmp_png="$(mktemp --suffix=.png)"
  if ! clipboard_image_fetch_windows_to_file "$tmp_png"; then
    rm -f "$tmp_png"
    return 1
  fi

  case "$mime" in
    image/png)
      cat "$tmp_png"
      ;;
    image/jpeg)
      if command -v magick >/dev/null 2>&1; then
        magick "$tmp_png" jpeg:-
      elif command -v convert >/dev/null 2>&1; then
        convert "$tmp_png" jpeg:-
      else
        rm -f "$tmp_png"
        return 1
      fi
      ;;
    image/gif)
      if command -v magick >/dev/null 2>&1; then
        magick "$tmp_png" gif:-
      elif command -v convert >/dev/null 2>&1; then
        convert "$tmp_png" gif:-
      else
        rm -f "$tmp_png"
        return 1
      fi
      ;;
    image/webp)
      if command -v magick >/dev/null 2>&1; then
        magick "$tmp_png" webp:-
      elif command -v convert >/dev/null 2>&1; then
        convert "$tmp_png" webp:-
      else
        rm -f "$tmp_png"
        return 1
      fi
      ;;
    *)
      rm -f "$tmp_png"
      return 1
      ;;
  esac

  rm -f "$tmp_png"
}

clipboard_image_has_image() {
  local tmp
  tmp="$(mktemp --suffix=.png)"
  if clipboard_image_fetch_to_file "$tmp"; then
    rm -f "$tmp"
    return 0
  fi
  rm -f "$tmp"
  return 1
}
