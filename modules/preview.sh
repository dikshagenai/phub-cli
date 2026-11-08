#!/usr/bin/env bash

# Terminal colors
RED='\033[0;31m'
BOLD_RED='\033[1;31m'
PINK='\033[38;5;206m'
HOT_PINK='\033[38;5;200m'
PURPLE='\033[0;35m'
MAGENTA='\033[0;95m'
ROSE='\033[38;5;197m'
GOLD='\033[38;5;220m'
GREEN='\033[0;32m'
BOLD='\033[1m'
NC='\033[0m'

raw="$1"
[ -z "$raw" ] && exit 0

IFS='|' read -r viewkey title thumb_url duration rating _ <<< "$raw"

cols="${FZF_PREVIEW_COLUMNS:-50}"
lines="${FZF_PREVIEW_LINES:-20}"

# Navigation options
case "$viewkey" in
    NEXT)
        echo ""
        printf '%b\n' "  ${HOT_PINK}${BOLD}▶ NEXT PAGE${NC}"
        echo ""
        printf '%b\n' "  ${PINK}Load the next page of video results.${NC}"
        printf '%b\n' "  ${GOLD}Shortcut:${NC} Press ${HOT_PINK}[Enter]${NC} or ${HOT_PINK}[Ctrl-N]${NC}"
        exit 0
        ;;
    PREV)
        echo ""
        printf '%b\n' "  ${HOT_PINK}${BOLD}◀ PREVIOUS PAGE${NC}"
        echo ""
        printf '%b\n' "  ${PINK}Return to the previous page of video results.${NC}"
        printf '%b\n' "  ${GOLD}Shortcut:${NC} Press ${HOT_PINK}[Enter]${NC} or ${HOT_PINK}[Ctrl-P]${NC}"
        exit 0
        ;;
    DOWNLOAD)
        echo ""
        printf '%b\n' "  ${GOLD}${BOLD}🚀 DOWNLOAD SELECTED VIDEOS${NC}"
        echo ""
        printf '%b\n' "  ${PINK}Proceed to parallel download all selected videos.${NC}"
        printf '%b\n' "  ${HOT_PINK}Tip:${NC} Use ${HOT_PINK}[Tab]${NC} to select/deselect videos,"
        printf '%b\n' "       then press ${HOT_PINK}[Enter]${NC} to start batch download."
        exit 0
        ;;
esac

CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/phub-cli/thumbnails"
mkdir -p "$CACHE_DIR" 2>/dev/null
thumb_file="$CACHE_DIR/${viewkey}.jpg"

# Download thumbnail if not already cached
if [ ! -s "$thumb_file" ] && [ -n "$thumb_url" ]; then
    curl -s -f -L -m 2.5 \
        -H "User-Agent: Mozilla/5.0 (X11; Linux x86_64; rv:128.0) Gecko/20100101 Firefox/128.0" \
        -H "Referer: https://www.pornhub.com/" \
        -o "$thumb_file" "$thumb_url" 2>/dev/null
fi

rendered=0
img_lines=$((lines - 4))
[ "$img_lines" -lt 5 ] && img_lines=5

if [ -s "$thumb_file" ]; then
    # Kitty Terminal Graphics
    if [ -n "$KITTY_PID" ] || [ -n "$KITTY_WINDOW_ID" ] || [ "$TERM" = "xterm-kitty" ]; then
        if command -v kitten >/dev/null 2>&1; then
            kitten icat --clear --transfer-mode=memory --stdin=no --scale-up --place="${cols}x${img_lines}@0x0" "$thumb_file" 2>/dev/null
            for ((i=0; i<img_lines; i++)); do
                printf "\n"
            done
            rendered=1
        fi
    fi

    # Fallback: Chafa (supports Sixel, Kitty, and Unicode half-blocks)
    if [ "$rendered" -eq 0 ] && command -v chafa >/dev/null 2>&1; then
        chafa --size="${cols}x${img_lines}" "$thumb_file" 2>/dev/null
        rendered=1
    fi

    # Fallback: img2txt
    if [ "$rendered" -eq 0 ] && command -v img2txt >/dev/null 2>&1; then
        img2txt -W "$cols" -H "$img_lines" "$thumb_file" 2>/dev/null
        rendered=1
    fi
fi

# Text metadata display
if [ "$rendered" -eq 1 ]; then
    echo ""
    printf '%b\n' "${HOT_PINK}${BOLD}🎬 ${title}${NC}"
    info_line=""
    [ -n "$duration" ] && info_line="${GOLD}⏱️  ${duration}${NC}  "
    [ -n "$rating" ] && info_line="${info_line}${ROSE}★ ${rating}${NC}  "
    [ -n "$viewkey" ] && info_line="${info_line}${MAGENTA}🔑 ${viewkey}${NC}"
    [ -n "$info_line" ] && printf '%b\n' "$info_line"
    printf '%b\n' "${PINK}🔗 https://www.pornhub.com/view_video.php?viewkey=${viewkey}${NC}"
else
    echo ""
    printf '%b\n' "  ${BOLD_RED}┌────────────────────────────────────────────────────────┐${NC}"
    printf '%b\n' "  ${BOLD_RED}│${NC}                 ${GOLD}${BOLD}📺 Video Information${NC}                  ${BOLD_RED}│${NC}"
    printf '%b\n' "  ${BOLD_RED}└────────────────────────────────────────────────────────┘${NC}"
    echo ""
    printf '%b\n' "  ${HOT_PINK}${BOLD}🎬 Title:${NC}    ${title}"
    [ -n "$duration" ] && printf '%b\n' "  ${GOLD}⏱️  Duration:${NC} ${duration}"
    [ -n "$rating" ] && printf '%b\n' "  ${ROSE}★  Rating:${NC}   ${rating}"
    printf '%b\n' "  ${MAGENTA}🔑 Viewkey:${NC}  ${viewkey}"
    printf '%b\n' "  ${PINK}🔗 Link:${NC}     https://www.pornhub.com/view_video.php?viewkey=${viewkey}"
fi
