#!/usr/bin/env bash

# phub-cli data storage module
# Manages user favorites and watch history persistence

DATA_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/phub-cli"
FAVORITES_FILE="$DATA_DIR/favorites.txt"
HISTORY_FILE="$DATA_DIR/history.txt"
MAX_HISTORY_ENTRIES=100

_ensure_storage_dir() {
    mkdir -p "$DATA_DIR" 2>/dev/null
    touch "$FAVORITES_FILE" "$HISTORY_FILE" 2>/dev/null
}

# --- FAVORITES ---

is_favorite() {
    local viewkey="$1"
    [ -z "$viewkey" ] && return 1
    _ensure_storage_dir
    grep -q "^${viewkey}|" "$FAVORITES_FILE" 2>/dev/null
}

add_favorite() {
    local viewkey="$1"
    local title="$2"
    local thumb_url="${3:-}"
    local duration="${4:-}"
    local rating="${5:-}"
    local timestamp
    timestamp=$(date +%s)

    [ -z "$viewkey" ] && return 1
    _ensure_storage_dir

    # If already favorited, remove previous line to update it to top
    if is_favorite "$viewkey"; then
        remove_favorite "$viewkey" >/dev/null 2>&1
    fi

    # Clean pipes in title
    title=$(echo "$title" | tr '|' '-')

    echo "${viewkey}|${title}|${thumb_url}|${duration}|${rating}|${timestamp}" >> "$FAVORITES_FILE"
}

remove_favorite() {
    local viewkey="$1"
    [ -z "$viewkey" ] && return 1
    _ensure_storage_dir
    if [ -f "$FAVORITES_FILE" ]; then
        local tmp
        tmp=$(mktemp)
        grep -v "^${viewkey}|" "$FAVORITES_FILE" > "$tmp" 2>/dev/null || true
        mv "$tmp" "$FAVORITES_FILE"
    fi
}

toggle_favorite() {
    local viewkey="$1"
    local title="$2"
    local thumb_url="${3:-}"
    local duration="${4:-}"
    local rating="${5:-}"

    if is_favorite "$viewkey"; then
        remove_favorite "$viewkey"
        return 2 # removed
    else
        add_favorite "$viewkey" "$title" "$thumb_url" "$duration" "$rating"
        return 0 # added
    fi
}

get_favorites() {
    _ensure_storage_dir
    if [ -s "$FAVORITES_FILE" ]; then
        # Newest first, strip timestamp (output: viewkey|title|thumb_url|duration|rating)
        tac "$FAVORITES_FILE" 2>/dev/null | awk -F'|' '{print $1"|"$2"|"$3"|"$4"|"$5}'
    fi
}

clear_favorites() {
    _ensure_storage_dir
    > "$FAVORITES_FILE"
}

# --- WATCH HISTORY ---

add_history() {
    local viewkey="$1"
    local title="$2"
    local thumb_url="${3:-}"
    local duration="${4:-}"
    local rating="${5:-}"
    local timestamp
    timestamp=$(date +%s)

    [ -z "$viewkey" ] && return 1
    _ensure_storage_dir

    # Remove any existing line for this viewkey so latest watch moves to the top
    if [ -f "$HISTORY_FILE" ]; then
        local tmp
        tmp=$(mktemp)
        grep -v "^${viewkey}|" "$HISTORY_FILE" > "$tmp" 2>/dev/null || true
        mv "$tmp" "$HISTORY_FILE"
    fi

    # Clean pipes in title
    title=$(echo "$title" | tr '|' '-')

    echo "${viewkey}|${title}|${thumb_url}|${duration}|${rating}|${timestamp}" >> "$HISTORY_FILE"

    # Enforce history limit
    local count
    count=$(wc -l < "$HISTORY_FILE" 2>/dev/null | xargs)
    if [ -n "$count" ] && [ "$count" -gt "$MAX_HISTORY_ENTRIES" ]; then
        local excess=$(( count - MAX_HISTORY_ENTRIES ))
        local tmp
        tmp=$(mktemp)
        tail -n +"$((excess + 1))" "$HISTORY_FILE" > "$tmp" 2>/dev/null || true
        mv "$tmp" "$HISTORY_FILE"
    fi
}

get_history() {
    _ensure_storage_dir
    if [ -s "$HISTORY_FILE" ]; then
        # Newest first, strip timestamp (output: viewkey|title|thumb_url|duration|rating)
        tac "$HISTORY_FILE" 2>/dev/null | awk -F'|' '{print $1"|"$2"|"$3"|"$4"|"$5}'
    fi
}

clear_history() {
    _ensure_storage_dir
    > "$HISTORY_FILE"
}
