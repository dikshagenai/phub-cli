#!/usr/bin/env bash

# phub-cli thumbnail cache maintenance
# Manages thumbnail cache pruning and size capping

CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/phub-cli/thumbnails"
CACHE_MAX_DAYS="${PHUBCLI_CACHE_MAX_DAYS:-14}"
CACHE_MAX_MB="${PHUBCLI_CACHE_MAX_MB:-200}"

prune_thumbnail_cache() {
    [ ! -d "$CACHE_DIR" ] && return 0

    # 1. Prune files older than CACHE_MAX_DAYS days
    if [ "$CACHE_MAX_DAYS" -gt 0 ] 2>/dev/null; then
        find "$CACHE_DIR" -type f -mtime +"$CACHE_MAX_DAYS" -delete 2>/dev/null
    fi

    # 2. Check total size in Megabytes
    local total_mb
    total_mb=$(du -sm "$CACHE_DIR" 2>/dev/null | awk '{print $1}')
    [ -z "$total_mb" ] && return 0

    # 3. If size exceeds CACHE_MAX_MB, delete oldest files until below 80% limit
    if [ "$total_mb" -gt "$CACHE_MAX_MB" ] 2>/dev/null; then
        local target_mb=$(( CACHE_MAX_MB * 8 / 10 ))
        # Find files sorted by modification time (oldest first)
        find "$CACHE_DIR" -type f -printf '%T@ %p\n' 2>/dev/null | sort -n | while read -r _ file; do
            rm -f "$file" 2>/dev/null
            total_mb=$(du -sm "$CACHE_DIR" 2>/dev/null | awk '{print $1}')
            [ -z "$total_mb" ] && break
            [ "$total_mb" -le "$target_mb" ] && break
        done
    fi
}

clear_thumbnail_cache() {
    if [ -d "$CACHE_DIR" ]; then
        rm -rf "${CACHE_DIR:?}"/* 2>/dev/null
    fi
}
