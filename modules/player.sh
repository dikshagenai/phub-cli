#!/usr/bin/env bash

#importing colors
DIR="$(cd -P "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$DIR/modules/ui.sh"

#spinner 
spinner() {
    local pid=$1
    local delay=0.1
    local spinstr='|/-\'

    while kill -0 "$pid" 2>/dev/null; do
        for i in $(seq 0 3); do
            printf "\r   ${HOT_PINK}%s${NC} Fetching stream... " "${spinstr:$i:1}" > /dev/tty
            sleep "$delay"
        done
    done
    printf "\r" > /dev/tty
}

play_video() {
    viewkey="$1"
    page_url="https://www.pornhub.org/view_video.php?viewkey=$viewkey"

    start_time=$(date +%s)

    #pre play
    clear

    messages=(
        "🔥 Preparing your video..."
        "💋 Unwrapping forbidden packets..."
        "💭 Please wait, lust takes time..."
        "😈 Negotiating with the content gods..."
        "📡 Tapping into the pleasure servers..."
        "🧠 Calibrating dopamine receptors..."
        "🍑 Warming up the pixels..."
        "🔓 Bypassing moral firewalls..."
        "💦 Hydrating the stream pipeline..."
        "📦 Extracting premium sensations..."
        "🕯 Lighting candles in the data center..."
        "🎥 Aligning sinful frames..."
    )
    pick1=${messages[RANDOM % ${#messages[@]}]}
    pick2=${messages[RANDOM % ${#messages[@]}]}
    pick3=${messages[RANDOM % ${#messages[@]}]}

    echo "" > /dev/tty
    echo -e "  ${HOT_PINK}$pick1${NC}" > /dev/tty
    sleep 0.3
    echo -e "  ${PINK}$pick2${NC}" > /dev/tty
    sleep 0.3
    echo -e "  ${ROSE}$pick3${NC}" > /dev/tty
    echo "" > /dev/tty

    #final
    echo "" > /dev/tty
    echo -e "  ${GOLD}▶ Launching player...${NC}" > /dev/tty
    sleep 0.6

    #play — let mpv use yt-dlp directly (avoids token expiration)
    local mpv_log
    mpv_log=$(mktemp)

    mpv \
        --msg-level=all=warn,ytdl=error \
        --profile=fast \
        --hwdec=auto \
        --cache=yes \
        --cache-secs=10 \
        --ytdl-format="bestvideo[height<=1080]+bestaudio/best" \
        --ytdl-raw-options="cookies-from-browser=firefox" \
        "$page_url" 2>"$mpv_log"
    local mpv_status=$?

    end_time=$(date +%s)
    duration=$((end_time - start_time))

    #failure
    if [ "$mpv_status" -ne 0 ] && [ "$duration" -lt 5 ]; then
        echo "" > /dev/tty
        echo -e "  ${RED}❌ Playback failed:${NC}" > /dev/tty
        local found_err=0
        if [ -s "$mpv_log" ]; then
            while IFS= read -r line; do
                if echo "$line" | grep -Eiq "error|failed|unavailable|denied|forbidden"; then
                    echo -e "  ${ROSE}$line${NC}" > /dev/tty
                    found_err=1
                fi
            done < "$mpv_log"
        fi
        if [ "$found_err" -eq 0 ]; then
            echo -e "  ${ROSE}Video stream is unavailable or connection was reset.${NC}" > /dev/tty
        fi
        echo "" > /dev/tty
        read -r -p "  Press Enter to continue..." _ </dev/tty
        rm -f "$mpv_log"
        return 1
    fi

    rm -f "$mpv_log"
    return 0
}

download_spinner() {
    local pid=$1
    local delay=0.1
    local spinstr='|/-\'

    while kill -0 "$pid" 2>/dev/null; do
        for i in $(seq 0 3); do
            printf "\r   ${GOLD}%s${NC} Downloading... " "${spinstr:$i:1}" > /dev/tty
            sleep "$delay"
        done
    done
    printf "\r" > /dev/tty
}

download_video() {
    viewkey="$1"
    quality="$2"
    page_url="https://www.pornhub.org/view_video.php?viewkey=$viewkey"
    download_dir="$HOME/Videos/phub-cli"

    # Create download directory if it doesn't exist
    mkdir -p "$download_dir"

    # Set format based on quality selection (prioritize direct https mp4 for reliability and resumability)
    case "$quality" in
        1)
            format="best[protocol=https]/best[protocol^=http]/bestvideo+bestaudio/best"
            quality_name="best"
            ;;
        2)
            format="best[height<=720][protocol=https]/best[height<=720]/bestvideo[height<=720]+bestaudio/best"
            quality_name="720p"
            ;;
        3)
            format="best[height<=480][protocol=https]/best[height<=480]/bestvideo[height<=480]+bestaudio/best"
            quality_name="480p"
            ;;
        4)
            format="best[height<=360][protocol=https]/best[height<=360]/bestvideo[height<=360]+bestaudio/best"
            quality_name="360p"
            ;;
        *)
            format="best[protocol=https]/best[protocol^=http]/bestvideo+bestaudio/best"
            quality_name="best"
            ;;
    esac

    while true; do
        clear

        messages=(
            "📥 Initiating download sequence..."
            "💾 Preparing storage containers..."
            "🔒 Securing the goods..."
            "📦 Packaging premium content..."
            "🚀 Launching download protocol..."
            "💿 Writing to disk with passion..."
        )
        pick1=${messages[RANDOM % ${#messages[@]}]}
        pick2=${messages[RANDOM % ${#messages[@]}]}

        echo "" > /dev/tty
        echo -e "  ${HOT_PINK}$pick1${NC}" > /dev/tty
        sleep 0.3
        echo -e "  ${PINK}$pick2${NC}" > /dev/tty
        echo "" > /dev/tty
        echo -e "  ${GOLD}📺 Quality: $quality_name${NC}" > /dev/tty
        echo -e "  ${DEEP_PINK}📁 Destination: $download_dir${NC}" > /dev/tty
        echo "" > /dev/tty

        local dl_log
        dl_log=$(mktemp)

        local aria2c_cmd=""
        if command -v aria2c >/dev/null 2>&1; then
            aria2c_cmd="aria2c"
        elif [ -x "$HOME/.local/bin/aria2c" ]; then
            aria2c_cmd="$HOME/.local/bin/aria2c"
        elif [ -x "$HOME/.config/phub-cli/bin/aria2c" ]; then
            aria2c_cmd="$HOME/.config/phub-cli/bin/aria2c"
        fi

        local ytdl_opts=(
            --no-playlist
            --progress
            --continue
            --concurrent-fragments 4
            --buffer-size 1024K
            --retries 10
            --fragment-retries 10
            --file-access-retries 5
            --no-mtime
        )

        if [ -n "$aria2c_cmd" ]; then
            ytdl_opts+=(
                --downloader "$aria2c_cmd"
                --downloader-args "aria2c:--summary-interval=1 -x 16 -s 16 -k 1M -j 16"
            )
        fi

        # Download with yt-dlp (attempt with firefox cookies first)
        yt-dlp \
            --cookies-from-browser=firefox \
            -f "$format" \
            -o "$download_dir/%(title)s.%(ext)s" \
            "${ytdl_opts[@]}" \
            "$page_url" 2>&1 | tee "$dl_log" > /dev/tty

        download_status=${PIPESTATUS[0]}

        # If failed due to locked or missing cookies, fallback and download without cookies
        if [ "$download_status" -ne 0 ] && grep -Eiq "cookie|database is locked|sqlite3\.OperationalError" "$dl_log"; then
            echo "" > /dev/tty
            echo -e "  ${YELLOW}⚠️  Browser cookies locked/unavailable. Retrying without cookies...${NC}" > /dev/tty
            > "$dl_log"
            yt-dlp \
                -f "$format" \
                -o "$download_dir/%(title)s.%(ext)s" \
                "${ytdl_opts[@]}" \
                "$page_url" 2>&1 | tee "$dl_log" > /dev/tty
            download_status=${PIPESTATUS[0]}
        fi

        if [ "$download_status" -eq 0 ]; then
            echo "" > /dev/tty
            echo -e "  ${GOLD}✅ Download complete!${NC}" > /dev/tty
            echo -e "  ${DEEP_PINK}📁 Saved to: $download_dir${NC}" > /dev/tty
            sleep 1
            rm -f "$dl_log"
            return 0
        else
            echo "" > /dev/tty
            echo -e "  ${RED}❌ Download failed.${NC}" > /dev/tty
            if [ -s "$dl_log" ]; then
                grep -Ei "error:|failed|unavailable|denied|forbidden" "$dl_log" | tail -n 3 | while IFS= read -r line; do
                    echo -e "  ${ROSE}$line${NC}" > /dev/tty
                done
            fi
            echo -e "  ${ROSE}😞 Video might be unavailable, restricted, or network connection dropped.${NC}" > /dev/tty
            echo "" > /dev/tty
            read -r -p "  Retry download? (y/n, default: n): " retry_dl </dev/tty
            rm -f "$dl_log"
            case "$retry_dl" in
                y|Y)
                    continue
                    ;;
                *)
                    return 1
                    ;;
            esac
        fi
    done
}

open_in_browser() {
    viewkey="$1"
    page_url="https://www.pornhub.com/view_video.php?viewkey=$viewkey"

    echo "" > /dev/tty
    echo -e "  ${HOT_PINK}🌐 Opening in browser...${NC}" > /dev/tty

    if command -v xdg-open >/dev/null 2>&1; then
        xdg-open "$page_url" 2>/dev/null &
    elif command -v open >/dev/null 2>&1; then
        open "$page_url" 2>/dev/null &
    else
        echo -e "  ${RED}❌ No browser opener found (xdg-open / open)${NC}" > /dev/tty
        read -r -p "  Press Enter to continue..." _ </dev/tty
        return 1
    fi

    sleep 1
}

batch_download_videos() {
    local list_file="$1"
    local quality="${2:-720p}"
    local concurrency="${3:-5}"
    local download_dir="$HOME/Videos/phub-cli"

    mkdir -p "$download_dir"

    python3 "$DIR/modules/downloader.py" \
        --list "$list_file" \
        --output-dir "$download_dir" \
        --quality "$quality" \
        --concurrency "$concurrency" \
        --fragments 4
}

confirm_and_run_batch_download() {
    local queue_file="$1"
    local default_quality="${2:-720p}"
    local unique_dl_tmp
    unique_dl_tmp=$(mktemp)
    awk -F'|' '!seen[$1]++' "$queue_file" > "$unique_dl_tmp"
    local total_selected
    total_selected=$(wc -l < "$unique_dl_tmp" | xargs)

    if [ -z "$total_selected" ] || [ "$total_selected" -eq 0 ]; then
        echo "" > /dev/tty
        echo -e "  ${GOLD}ℹ No videos selected. Use [Tab] to select videos first.${NC}" > /dev/tty
        rm -f "$unique_dl_tmp"
        sleep 1.2
        return 1
    fi

    clear
    echo "" > /dev/tty
    echo -e "  ${BOLD_RED}┌────────────────────────────────────────────────────────┐${NC}" > /dev/tty
    echo -e "  ${BOLD_RED}│${NC}              ${HOT_PINK}${BOLD}Parallel Download Queue${NC}                   ${BOLD_RED}│${NC}" > /dev/tty
    echo -e "  ${BOLD_RED}└────────────────────────────────────────────────────────┘${NC}" > /dev/tty
    echo "" > /dev/tty
    echo -e "  ${MAGENTA}📋 Selected videos:${NC} ${BOLD}$total_selected${NC}" > /dev/tty
    echo -e "  ${DEEP_PINK}📁 Destination:${NC} $HOME/Videos/phub-cli" > /dev/tty
    echo -e "  ${GOLD}⚡ Concurrency:${NC} 5 parallel downloads (with aria2 accelerator)" > /dev/tty
    echo "" > /dev/tty
    echo -e "  ${PINK}Queued videos:${NC}" > /dev/tty
    head -n 6 "$unique_dl_tmp" | while IFS='|' read -r vk title; do
        echo -e "    ${HOT_PINK}•${NC} ${title}" > /dev/tty
    done
    if [ "$total_selected" -gt 6 ]; then
        echo -e "    ${ROSE}... and $((total_selected - 6)) more${NC}" > /dev/tty
    fi
    echo "" > /dev/tty
    echo -e "  ${HOT_PINK}[1]${NC} ${PINK}Start parallel download (${default_quality} - Enter)${NC}" > /dev/tty
    echo -e "  ${HOT_PINK}[2]${NC} ${PINK}Choose resolution (Best / 720p / 480p / 360p)${NC}" > /dev/tty
    echo -e "  ${HOT_PINK}[3]${NC} ${PINK}Add more videos (keep queue and back to list)${NC}" > /dev/tty
    echo -e "  ${HOT_PINK}[c]${NC} ${PINK}Cancel and clear queue${NC}" > /dev/tty
    echo "" > /dev/tty
    read -r -p "$(printf '%b' "${HOT_PINK}Select option (default: 1) ❯ ${NC}")" dl_choice < /dev/tty

    case "$dl_choice" in
        2)
            local q_choice
            q_choice=$(quality_menu)
            local target_q="720p"
            case "$q_choice" in
                1) target_q="best" ;;
                2) target_q="720p" ;;
                3) target_q="480p" ;;
                4) target_q="360p" ;;
                b|B)
                    rm -f "$unique_dl_tmp"
                    return 2
                    ;;
            esac
            batch_download_videos "$unique_dl_tmp" "$target_q"
            rm -f "$unique_dl_tmp"
            > "$queue_file"
            echo "" > /dev/tty
            read -r -p "$(printf '%b' "  ${HOT_PINK}Press Enter to return to menu...${NC}")" _ < /dev/tty
            return 0
            ;;
        3)
            rm -f "$unique_dl_tmp"
            return 2
            ;;
        c|C|q|Q)
            rm -f "$unique_dl_tmp"
            > "$queue_file"
            return 3
            ;;
        1|""|*)
            batch_download_videos "$unique_dl_tmp" "$default_quality"
            rm -f "$unique_dl_tmp"
            > "$queue_file"
            echo "" > /dev/tty
            read -r -p "$(printf '%b' "  ${HOT_PINK}Press Enter to return to menu...${NC}")" _ < /dev/tty
            return 0
            ;;
    esac
}
