#!/usr/bin/env bash

set -o noclobber -o noglob -o nounset -o pipefail
IFS=$'\n'

## If the option `use_preview_script` is set to `true`,
## then this script will be called and its output will be displayed in ranger.
## ANSI color codes are supported.
## STDIN is disabled, so interactive scripts won't work properly

## This script is considered a configuration file and must be updated manually.
## It will be left untouched if you upgrade ranger.

## Because of some automated testing we do on the script #'s for comments need
## to be doubled up. Code that is commented out, because it's an alternative for
## example, gets only one #.

## Meanings of exit codes:
## code | meaning    | action of ranger
## -----+------------+-------------------------------------------
## 0    | success    | Display stdout as preview
## 1    | no preview | Display no preview at all
## 2    | plain text | Display the plain content of the file
## 3    | fix width  | Don't reload when width changes
## 4    | fix height | Don't reload when height changes
## 5    | fix both   | Don't ever reload
## 6    | image      | Display the image `$IMAGE_CACHE_PATH` points to as an image preview
## 7    | image      | Display the file directly as an image

## Script arguments
FILE_PATH="${1}"         # Full path of the highlighted file
PV_WIDTH="${2}"          # Width of the preview pane (number of fitting characters)
## shellcheck disable=SC2034 # PV_HEIGHT is provided for convenience and unused
PV_HEIGHT="${3}"         # Height of the preview pane (number of fitting characters)
IMAGE_CACHE_PATH="${4}"  # Full path that should be used to cache image preview
PV_IMAGE_ENABLED="${5}"  # 'True' if image previews are enabled, 'False' otherwise.

FILE_EXTENSION="${FILE_PATH##*.}"
FILE_EXTENSION_LOWER="$(printf "%s" "${FILE_EXTENSION}" | tr '[:upper:]' '[:lower:]')"

## Settings
## Text previews prefer bat (tokyonight_night via ~/.config/bat/config).
HIGHLIGHT_SIZE_MAX=262143  # 256KiB
HIGHLIGHT_TABWIDTH=${HIGHLIGHT_TABWIDTH:-8}
HIGHLIGHT_STYLE=${HIGHLIGHT_STYLE:-pablo}
HIGHLIGHT_OPTIONS="--replace-tabs=${HIGHLIGHT_TABWIDTH} --style=${HIGHLIGHT_STYLE} ${HIGHLIGHT_OPTIONS:-}"
PYGMENTIZE_STYLE=${PYGMENTIZE_STYLE:-autumn}
OPENSCAD_IMGSIZE=${RNGR_OPENSCAD_IMGSIZE:-1000,1000}
OPENSCAD_COLORSCHEME=${RNGR_OPENSCAD_COLORSCHEME:-Tomorrow Night}
if command -v bat >/dev/null 2>&1; then
    BAT_BIN=bat
elif command -v batcat >/dev/null 2>&1; then
    BAT_BIN=batcat
else
    BAT_BIN=
fi

is_wsl() {
    [ -n "${WSL_DISTRO_NAME:-}" ] || grep -qi microsoft /proc/version 2>/dev/null
}

## Exit 7 asks ranger to render an inline image (w3m/kitty/etc.). On WSL that
## often blocks when preview_images is toggled on (zi) without a working backend.
can_display_images() {
    [[ "${PV_IMAGE_ENABLED}" == 'True' ]] || return 1
    if is_wsl; then
        return 1
    fi
    return 0
}

## Mirror nvim-treesitter chezmoi_template_language() in dot_config/nvim/init.lua.
chezmoi_logical_basename() {
    local name="${1##*/}"
    name="${name%.tmpl}"
    local prefix
    for prefix in private_ encrypted_ executable_ readonly_ literal_ dot_; do
        case "$name" in
            "${prefix}"*)
                if [ "$prefix" = dot_ ]; then
                    name=".${name#dot_}"
                else
                    name="${name#"$prefix"}"
                fi
                ;;
        esac
    done
    printf '%s' "$name"
}

## Neovim treesitter parser id, or empty to let bat guess from the path.
language_for_file() {
    local logical ext
    logical="$(chezmoi_logical_basename "${FILE_PATH}")"
    ext="${logical##*.}"
    if [ "$logical" = "$ext" ]; then
        ext=
    else
        ext="${ext,,}"
    fi

    case "$ext" in
        gotmpl|thrift|scm) printf '%s' "$ext"; return ;;
        c|h) printf 'c'; return ;;
        css) printf 'css'; return ;;
        dart) printf 'dart'; return ;;
        diff|patch) printf 'diff'; return ;;
        go) printf 'go'; return ;;
        groovy|gvy|gradle) printf 'groovy'; return ;;
        htm|html|xhtml) printf 'html'; return ;;
        java) printf 'java'; return ;;
        js|mjs|cjs|jsx) printf 'javascript'; return ;;
        json) printf 'json'; return ;;
        kt|kts) printf 'kotlin'; return ;;
        lua) printf 'lua'; return ;;
        md|markdown|mdown) printf 'markdown'; return ;;
        ps1|psm1|psd1) printf 'powershell'; return ;;
        toml|tml) printf 'toml'; return ;;
        ts|mts|cts) printf 'typescript'; return ;;
        tsx) printf 'tsx'; return ;;
        vim) printf 'vim'; return ;;
        yaml|yml) printf 'yaml'; return ;;
        bash|sh|zsh) printf 'bash'; return ;;
    esac

    case "$logical" in
        .bash_profile|.bashrc|.profile|.zprofile|.zshenv|.zshrc)
            printf 'bash'
            return
            ;;
    esac

    case "$(basename "${FILE_PATH}")" in
        *.tmpl) printf 'bash'; return ;;
    esac

    printf ''
}

bat_language_for_parser() {
    case "$1" in
        bash) printf 'bash' ;;
        c) printf 'c' ;;
        css) printf 'CSS' ;;
        dart) printf 'Dart' ;;
        diff) printf 'Diff' ;;
        go|gotmpl) printf 'Go' ;;
        groovy) printf 'Groovy' ;;
        html) printf 'HTML' ;;
        java) printf 'Java' ;;
        javascript) printf 'JavaScript (Babel)' ;;
        json) printf 'JSON' ;;
        kotlin) printf 'Kotlin' ;;
        lua|luadoc) printf 'Lua' ;;
        markdown|markdown_inline) printf 'Markdown' ;;
        powershell) printf 'PowerShell' ;;
        scm|query) printf '' ;;
        toml) printf 'TOML' ;;
        tsx) printf 'TypeScriptReact' ;;
        typescript) printf 'TypeScript' ;;
        vim) printf 'VimL' ;;
        vimdoc) printf 'VimHelp' ;;
        yaml) printf 'YAML' ;;
        *) printf '' ;;
    esac
}

preview_syntax_highlight() {
    if [[ "$( stat --printf='%s' -- "${FILE_PATH}" )" -gt "${HIGHLIGHT_SIZE_MAX}" ]]; then
        exit 2
    fi

    local parser bat_lang
    parser="$(language_for_file)"
    bat_lang="$(bat_language_for_parser "$parser")"

    if [ -n "${BAT_BIN}" ]; then
        if [ -n "$bat_lang" ]; then
            env COLORTERM=8bit "${BAT_BIN}" --language="$bat_lang" --color=always --style="plain" \
                -- "${FILE_PATH}" && exit 5
        fi
        env COLORTERM=8bit "${BAT_BIN}" --color=always --style="plain" \
            -- "${FILE_PATH}" && exit 5
    fi

    if [[ "$( tput colors )" -ge 256 ]]; then
        local pygmentize_format='terminal256'
        local highlight_format='xterm256'
    else
        local pygmentize_format='terminal'
        local highlight_format='ansi'
    fi

    if [ "$parser" = 'thrift' ] && command -v pygmentize >/dev/null 2>&1; then
        pygmentize -l thrift -f "${pygmentize_format}" -O "style=${PYGMENTIZE_STYLE}" \
            -- "${FILE_PATH}" && exit 5
    fi

    env HIGHLIGHT_OPTIONS="${HIGHLIGHT_OPTIONS}" highlight \
        --out-format="${highlight_format}" \
        --force -- "${FILE_PATH}" && exit 5

    if [ -n "$parser" ] && command -v pygmentize >/dev/null 2>&1; then
        pygmentize -l "$parser" -f "${pygmentize_format}" -O "style=${PYGMENTIZE_STYLE}" \
            -- "${FILE_PATH}" && exit 5
    fi
    pygmentize -f "${pygmentize_format}" -O "style=${PYGMENTIZE_STYLE}" \
        -- "${FILE_PATH}" && exit 5
    exit 2
}

handle_extension() {
    case "${FILE_EXTENSION_LOWER}" in
        ## Archive
        a|ace|alz|arc|arj|bz|bz2|cab|cpio|deb|gz|jar|lha|lz|lzh|lzma|lzo|\
        rpm|rz|t7z|tar|tbz|tbz2|tgz|tlz|txz|tZ|tzo|war|xpi|xz|Z|zip)
            atool --list -- "${FILE_PATH}" && exit 5
            bsdtar --list --file "${FILE_PATH}" && exit 5
            exit 1;;
        rar)
            ## Avoid password prompt by providing empty password
            unrar lt -p- -- "${FILE_PATH}" && exit 5
            exit 1;;
        7z)
            ## Avoid password prompt by providing empty password
            7z l -p -- "${FILE_PATH}" && exit 5
            exit 1;;

        ## PDF
        pdf)
            ## Preview as text conversion
            pdftotext -l 10 -nopgbrk -q -- "${FILE_PATH}" - | \
              fmt -w "${PV_WIDTH}" && exit 5
            mutool draw -F txt -i -- "${FILE_PATH}" 1-10 | \
              fmt -w "${PV_WIDTH}" && exit 5
            exiftool "${FILE_PATH}" && exit 5
            exit 1;;

        ## BitTorrent
        torrent)
            transmission-show -- "${FILE_PATH}" && exit 5
            exit 1;;

        ## OpenDocument
        odt|ods|odp|sxw)
            ## Preview as text conversion
            odt2txt "${FILE_PATH}" && exit 5
            ## Preview as markdown conversion
            pandoc -s -t markdown -- "${FILE_PATH}" && exit 5
            exit 1;;

        ## XLSX
        xlsx)
            ## Preview as csv conversion
            ## Uses: https://github.com/dilshod/xlsx2csv
            xlsx2csv -- "${FILE_PATH}" && exit 5
            exit 1;;

        ## HTML
        htm|html|xhtml)
            ## Preview as text conversion
            w3m -dump "${FILE_PATH}" && exit 5
            lynx -dump -- "${FILE_PATH}" && exit 5
            elinks -dump "${FILE_PATH}" && exit 5
            pandoc -s -t markdown -- "${FILE_PATH}" && exit 5
            ;;

        ## JSON
        json)
            jq --color-output . "${FILE_PATH}" && exit 5
            python -m json.tool -- "${FILE_PATH}" && exit 5
            ;;

        ## Source aligned with nvim-treesitter parsers (see language_for_file)
        lua|luac|dart|go|kt|kts|java|c|h|cpp|cc|cxx|hh|hpp|css|diff|patch|\
        groovy|gvy|gradle|sh|bash|zsh|ps1|psm1|psd1|toml|tml|ts|mts|cts|tsx|\
        js|mjs|cjs|jsx|vim|yaml|yml|md|markdown|mdown|gotmpl|thrift|scm|tmpl)
            preview_syntax_highlight;;

        ## Direct Stream Digital/Transfer (DSDIFF) and wavpack aren't detected
        ## by file(1).
        dff|dsf|wv|wvc)
            mediainfo "${FILE_PATH}" && exit 5
            exiftool "${FILE_PATH}" && exit 5
            ;; # Continue with next handler on failure
    esac
}

handle_image() {
    ## Size of the preview if there are multiple options or it has to be
    ## rendered from vector graphics. If the conversion program allows
    ## specifying only one dimension while keeping the aspect ratio, the width
    ## will be used.
    local DEFAULT_SIZE="1920x1080"

    local mimetype="${1}"
    case "${mimetype}" in
        ## SVG
        # image/svg+xml|image/svg)
        #     convert -- "${FILE_PATH}" "${IMAGE_CACHE_PATH}" && exit 6
        #     exit 1;;

        ## DjVu
        # image/vnd.djvu)
        #     ddjvu -format=tiff -quality=90 -page=1 -size="${DEFAULT_SIZE}" \
        #           - "${IMAGE_CACHE_PATH}" < "${FILE_PATH}" \
        #           && exit 6 || exit 1;;

        ## Image
        image/*)
            if command -v identify >/dev/null 2>&1; then
                local orientation
                orientation="$( identify -format '%[EXIF:Orientation]\n' -- "${FILE_PATH}" )"
                ## If orientation data is present and the image actually
                ## needs rotating ("1" means no rotation)...
                if [[ -n "$orientation" && "$orientation" != 1 ]] \
                        && command -v convert >/dev/null 2>&1; then
                    ## ...auto-rotate the image according to the EXIF data.
                    convert -- "${FILE_PATH}" -auto-orient "${IMAGE_CACHE_PATH}" && exit 6
                fi
            fi

            ## `w3mimgdisplay` will be called for all images (unless overriden
            ## as above), but might fail for unsupported types.
            if can_display_images; then
                exit 7
            fi
            exit 1;;

        ## Video
        # video/*)
        #     # Thumbnail
        #     ffmpegthumbnailer -i "${FILE_PATH}" -o "${IMAGE_CACHE_PATH}" -s 0 && exit 6
        #     exit 1;;

        ## PDF
        # application/pdf)
        #     pdftoppm -f 1 -l 1 \
        #              -scale-to-x "${DEFAULT_SIZE%x*}" \
        #              -scale-to-y -1 \
        #              -singlefile \
        #              -jpeg -tiffcompression jpeg \
        #              -- "${FILE_PATH}" "${IMAGE_CACHE_PATH%.*}" \
        #         && exit 6 || exit 1;;


        ## ePub, MOBI, FB2 (using Calibre)
        # application/epub+zip|application/x-mobipocket-ebook|\
        # application/x-fictionbook+xml)
        #     # ePub (using https://github.com/marianosimone/epub-thumbnailer)
        #     epub-thumbnailer "${FILE_PATH}" "${IMAGE_CACHE_PATH}" \
        #         "${DEFAULT_SIZE%x*}" && exit 6
        #     ebook-meta --get-cover="${IMAGE_CACHE_PATH}" -- "${FILE_PATH}" \
        #         >/dev/null && exit 6
        #     exit 1;;

        ## Font
        application/font*|application/*opentype)
            preview_png="/tmp/$(basename "${IMAGE_CACHE_PATH%.*}").png"
            if fontimage -o "${preview_png}" \
                         --pixelsize "120" \
                         --fontname \
                         --pixelsize "80" \
                         --text "  ABCDEFGHIJKLMNOPQRSTUVWXYZ  " \
                         --text "  abcdefghijklmnopqrstuvwxyz  " \
                         --text "  0123456789.:,;(*!?') ff fl fi ffi ffl  " \
                         --text "  The quick brown fox jumps over the lazy dog.  " \
                         "${FILE_PATH}";
            then
                convert -- "${preview_png}" "${IMAGE_CACHE_PATH}" \
                    && rm "${preview_png}" \
                    && exit 6
            else
                exit 1
            fi
            ;;

        ## Preview archives using the first image inside.
        ## (Very useful for comic book collections for example.)
        # application/zip|application/x-rar|application/x-7z-compressed|\
        #     application/x-xz|application/x-bzip2|application/x-gzip|application/x-tar)
        #     local fn=""; local fe=""
        #     local zip=""; local rar=""; local tar=""; local bsd=""
        #     case "${mimetype}" in
        #         application/zip) zip=1 ;;
        #         application/x-rar) rar=1 ;;
        #         application/x-7z-compressed) ;;
        #         *) tar=1 ;;
        #     esac
        #     { [ "$tar" ] && fn=$(tar --list --file "${FILE_PATH}"); } || \
        #     { fn=$(bsdtar --list --file "${FILE_PATH}") && bsd=1 && tar=""; } || \
        #     { [ "$rar" ] && fn=$(unrar lb -p- -- "${FILE_PATH}"); } || \
        #     { [ "$zip" ] && fn=$(zipinfo -1 -- "${FILE_PATH}"); } || return
        #
        #     fn=$(echo "$fn" | python -c "import sys; import mimetypes as m; \
        #             [ print(l, end='') for l in sys.stdin if \
        #               (m.guess_type(l[:-1])[0] or '').startswith('image/') ]" |\
        #         sort -V | head -n 1)
        #     [ "$fn" = "" ] && return
        #     [ "$bsd" ] && fn=$(printf '%b' "$fn")
        #
        #     [ "$tar" ] && tar --extract --to-stdout \
        #         --file "${FILE_PATH}" -- "$fn" > "${IMAGE_CACHE_PATH}" && exit 6
        #     fe=$(echo -n "$fn" | sed 's/[][*?\]/\\\0/g')
        #     [ "$bsd" ] && bsdtar --extract --to-stdout \
        #         --file "${FILE_PATH}" -- "$fe" > "${IMAGE_CACHE_PATH}" && exit 6
        #     [ "$bsd" ] || [ "$tar" ] && rm -- "${IMAGE_CACHE_PATH}"
        #     [ "$rar" ] && unrar p -p- -inul -- "${FILE_PATH}" "$fn" > \
        #         "${IMAGE_CACHE_PATH}" && exit 6
        #     [ "$zip" ] && unzip -pP "" -- "${FILE_PATH}" "$fe" > \
        #         "${IMAGE_CACHE_PATH}" && exit 6
        #     [ "$rar" ] || [ "$zip" ] && rm -- "${IMAGE_CACHE_PATH}"
        #     ;;
    esac

    # openscad_image() {
    #     TMPPNG="$(mktemp -t XXXXXX.png)"
    #     openscad --colorscheme="${OPENSCAD_COLORSCHEME}" \
    #         --imgsize="${OPENSCAD_IMGSIZE/x/,}" \
    #         -o "${TMPPNG}" "${1}"
    #     mv "${TMPPNG}" "${IMAGE_CACHE_PATH}"
    # }

    # case "${FILE_EXTENSION_LOWER}" in
    #     ## 3D models
    #     ## OpenSCAD only supports png image output, and ${IMAGE_CACHE_PATH}
    #     ## is hardcoded as jpeg. So we make a tempfile.png and just
    #     ## move/rename it to jpg. This works because image libraries are
    #     ## smart enough to handle it.
    #     csg|scad)
    #         openscad_image "${FILE_PATH}" && exit 6
    #         ;;
    #     3mf|amf|dxf|off|stl)
    #         openscad_image <(echo "import(\"${FILE_PATH}\");") && exit 6
    #         ;;
    # esac
}

handle_mime() {
    local mimetype="${1}"
    case "${mimetype}" in
        ## RTF and DOC
        text/rtf|*msword)
            ## Preview as text conversion
            ## note: catdoc does not always work for .doc files
            ## catdoc: http://www.wagner.pp.ru/~vitus/software/catdoc/
            catdoc -- "${FILE_PATH}" && exit 5
            exit 1;;

        ## DOCX, ePub, FB2 (using markdown)
        ## You might want to remove "|epub" and/or "|fb2" below if you have
        ## uncommented other methods to preview those formats
        *wordprocessingml.document|*/epub+zip|*/x-fictionbook+xml)
            ## Preview as markdown conversion
            pandoc -s -t markdown -- "${FILE_PATH}" && exit 5
            exit 1;;

        ## XLS
        *ms-excel)
            ## Preview as csv conversion
            ## xls2csv comes with catdoc:
            ##   http://www.wagner.pp.ru/~vitus/software/catdoc/
            xls2csv -- "${FILE_PATH}" && exit 5
            exit 1;;

        ## Text
        text/* | */xml | application/json | application/javascript | \
        application/typescript | application/x-sh | application/x-shellscript | \
        application/x-toml | text/x-lua | text/x-go | text/x-rust)
            preview_syntax_highlight;;

        ## DjVu
        image/vnd.djvu)
            ## Preview as text conversion (requires djvulibre)
            djvutxt "${FILE_PATH}" | fmt -w "${PV_WIDTH}" && exit 5
            exiftool "${FILE_PATH}" && exit 5
            exit 1;;

        ## Image
        image/*)
            if [[ "${PV_IMAGE_ENABLED}" != 'True' ]]; then
                exit 1
            fi
            ## Preview as text conversion
            # img2txt --gamma=0.6 --width="${PV_WIDTH}" -- "${FILE_PATH}" && exit 4
            if command -v exiftool >/dev/null 2>&1; then
                exiftool "${FILE_PATH}" && exit 5
            fi
            exit 1;;

        ## Video and audio
        video/* | audio/*)
            mediainfo "${FILE_PATH}" && exit 5
            exiftool "${FILE_PATH}" && exit 5
            exit 1;;
    esac
}

handle_fallback() {
    echo '----- File Type Classification -----' && file --dereference --brief -- "${FILE_PATH}" && exit 5
}


MIMETYPE="$( file --dereference --brief --mime-type -- "${FILE_PATH}" )"
if [[ "${PV_IMAGE_ENABLED}" == 'True' ]]; then
    handle_image "${MIMETYPE}"
fi
handle_extension
handle_mime "${MIMETYPE}"
handle_fallback

exit 1
