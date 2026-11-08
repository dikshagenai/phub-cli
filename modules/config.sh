#!/usr/bin/env bash

# phub-cli configuration module
# Manages download directory settings, autodownload modes, and persistent preferences

DEFAULT_DOWNLOAD_DIR="$HOME/Videos/phub-cli"
CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/phub-cli"
CONFIG_FILE="$CONFIG_DIR/config"

_ensure_config_dir() {
    mkdir -p "$CONFIG_DIR" 2>/dev/null
}

# --- AUTODOWNLOAD MODE ---

get_autodownload_mode() {
    if [ -n "$PHUBCLI_AUTODOWNLOAD" ]; then
        case "$PHUBCLI_AUTODOWNLOAD" in
            1|on|ON|multi|MULTI) echo "on"; return ;;
            page|pages|page_mode|PAGE_MODE) echo "page_mode"; return ;;
            0|off|OFF|*) echo "off"; return ;;
        esac
    fi

    if [ -f "$CONFIG_FILE" ]; then
        local mode
        mode=$(grep -E "^AUTODOWNLOAD_MODE=" "$CONFIG_FILE" 2>/dev/null | cut -d'=' -f2 | tr -d ' "\r\n')
        case "$mode" in
            on|multi) echo "on"; return ;;
            page_mode) echo "page_mode"; return ;;
            *) echo "off"; return ;;
        esac
    fi

    echo "off"
}

set_autodownload_mode() {
    local mode="$1"
    _ensure_config_dir
    if [ -f "$CONFIG_FILE" ] && grep -q "^AUTODOWNLOAD_MODE=" "$CONFIG_FILE" 2>/dev/null; then
        sed -i "s/^AUTODOWNLOAD_MODE=.*/AUTODOWNLOAD_MODE=$mode/" "$CONFIG_FILE"
    else
        echo "AUTODOWNLOAD_MODE=$mode" >> "$CONFIG_FILE"
    fi
}

# --- DOWNLOAD DIRECTORY ---

get_configured_download_dir() {
    if [ -n "$PHUBCLI_DOWNLOAD_DIR" ]; then
        echo "$PHUBCLI_DOWNLOAD_DIR"
        return
    fi

    if [ -f "$CONFIG_FILE" ]; then
        local configured
        configured=$(grep -E "^DOWNLOAD_DIR=" "$CONFIG_FILE" 2>/dev/null | cut -d'=' -f2- | tr -d '\r\n')
        if [ -n "$configured" ]; then
            echo "$configured"
            return
        fi
    fi

    echo "$DEFAULT_DOWNLOAD_DIR"
}

expand_path() {
    local p="$1"
    if [[ "$p" == "~"* ]]; then
        echo "${HOME}${p:1}"
    else
        echo "$p"
    fi
}

is_remote_target() {
    local p="$1"
    [[ "$p" =~ ^(ftp|ftps|sftp):// ]]
}

is_ftp_writable() {
    local url="$1"
    [[ "$url" != */ ]] && url="${url}/"
    local tfile
    tfile=$(mktemp)
    echo "probe" > "$tfile"
    local probename=".phub_probe_$$"
    curl -s -f --connect-timeout 4 -m 8 --ftp-create-dirs -T "$tfile" "${url}${probename}" >/dev/null 2>&1
    local res=$?
    rm -f "$tfile"
    if [ "$res" -eq 0 ]; then
        local remote_clean
        remote_clean=$(echo "$url" | sed -E "s|^[a-zA-Z]+://[^/]+||")
        remote_clean="${remote_clean%/}/${probename}"
        curl -s -Q "DELE ${remote_clean}" "$url" >/dev/null 2>&1 || true
        return 0
    fi
    return 1
}

is_dir_writable() {
    local p="$1"
    [ -z "$p" ] && return 1
    [ "$p" = "default" ] || [ "$p" = "reset" ] && p="$DEFAULT_DOWNLOAD_DIR"

    if is_remote_target "$p"; then
        is_ftp_writable "$p"
        return $?
    fi

    local exp
    exp=$(expand_path "$p")

    # Try creating directory if it does not exist
    mkdir -p "$exp" 2>/dev/null

    if [ -d "$exp" ]; then
        local test_file="$exp/.phub_test_$$"
        if touch "$test_file" 2>/dev/null; then
            rm -f "$test_file" 2>/dev/null
            return 0
        fi
    fi
    return 1
}

get_download_dir() {
    local configured
    configured=$(get_configured_download_dir)
    local target
    target=$(expand_path "$configured")

    # 1. Check if configured directory or remote target is writable
    if is_dir_writable "$target"; then
        echo "$target"
        return 0
    fi

    # 2. Fallback to default download directory
    if [ -c /dev/tty ]; then
        echo -e "  \033[38;5;197m⚠️  Notice: Cannot write/connect to '${target}'. Falling back to default: '${DEFAULT_DOWNLOAD_DIR}'\033[0m" > /dev/tty
    else
        echo -e "  ⚠️  Notice: Cannot write/connect to '${target}'. Falling back to default: '${DEFAULT_DOWNLOAD_DIR}'" >&2
    fi

    mkdir -p "$DEFAULT_DOWNLOAD_DIR" 2>/dev/null
    echo "$DEFAULT_DOWNLOAD_DIR"
    return 1
}

set_download_dir() {
    local dir="$1"
    _ensure_config_dir

    if [ -z "$dir" ] || [ "$dir" = "$DEFAULT_DOWNLOAD_DIR" ] || [ "$dir" = "default" ] || [ "$dir" = "reset" ]; then
        reset_download_dir
        return
    fi

    if [ -f "$CONFIG_FILE" ] && grep -q "^DOWNLOAD_DIR=" "$CONFIG_FILE" 2>/dev/null; then
        sed -i "s|^DOWNLOAD_DIR=.*|DOWNLOAD_DIR=$dir|" "$CONFIG_FILE"
    else
        echo "DOWNLOAD_DIR=$dir" >> "$CONFIG_FILE"
    fi
}

reset_download_dir() {
    if [ -f "$CONFIG_FILE" ] && grep -q "^DOWNLOAD_DIR=" "$CONFIG_FILE" 2>/dev/null; then
        sed -i "/^DOWNLOAD_DIR=/d" "$CONFIG_FILE"
    fi
}

format_dir_label() {
    local max_len="${1:-18}"
    local configured
    configured=$(get_configured_download_dir)

    local display="$configured"
    if [[ "$display" == "$HOME"* ]]; then
        display="~${display#$HOME}"
    fi

    if [ "${#display}" -le "$max_len" ]; then
        echo "$display"
    else
        if is_remote_target "$display"; then
            local host_part
            host_part=$(echo "$display" | sed -E 's|^[a-zA-Z]+://([^/]+).*|\1|')
            local short_ftp="ftp://${host_part}"
            if [ "${#short_ftp}" -le "$max_len" ]; then
                echo "$short_ftp"
            else
                echo "${short_ftp:0:$((max_len - 3))}..."
            fi
        else
            local base
            base=$(basename "$display")
            local shortened=".../${base}"
            if [ "${#shortened}" -le "$max_len" ]; then
                echo "$shortened"
            else
                echo "${display:0:$((max_len - 3))}..."
            fi
        fi
    fi
}
