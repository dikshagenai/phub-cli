<p align="center">
  <img src="https://img.shields.io/badge/os-linux-brightgreen">
  <img src="https://img.shields.io/badge/os-mac-yellowgreen">
  <img src="https://img.shields.io/badge/interface-terminal-blue">
  <img src="https://img.shields.io/badge/player-mpv-red">
</p>

<h1 align="center">phub-cli</h1>

<h3 align="center">
A terminal-based video browser inspired by ani-cli.<br>
Browse, search, stream, and download directly from the terminal — no browser required.
</h3>

<p align="center">
  <b>Made with lust.</b>
</p>

> [!NOTE]
> **Maintained Fork**: This project is a continuation of the original [curtosis-org/phub-cli](https://github.com/curtosis-org/phub-cli). All credit and appreciation go to [curtosis-org](https://github.com/curtosis-org) and the original contributors for creating this tool. Ongoing maintenance continues here at [dikshagenai/phub-cli](https://github.com/dikshagenai/phub-cli).

---

## Features

- **Search & Browse**: Keyword search and category browsing with paginated results via `fzf`
- **Discovery Feeds**: Direct access to curated video feeds:
  - *Trending / Hot*
  - *Top Rated*
  - *Most Viewed*
  - *Most Recent*
  - *Longest*
- **Search Sorting & Duration Filters**: Sort by relevance, recent, views, rating, or duration, and filter by short (1-10m), medium (10-20m), or long (20m+)
- **Favorites & Watch History**:
  - Save favorite videos with one keypress (`[f]`) and browse them anytime
  - Automatically records watch history with quick replay and management
  - Persisted in standard XDG user directories (`~/.local/share/phub-cli/`)
- **Direct CLI Invocation (`ani-cli` style)**:
  - Launch search directly: `phub-cli "query"`
  - Direct video playback: `phub-cli -p <viewkey|URL>`
  - Direct feed access: `phub-cli -f trending`
  - Direct favorites & history: `phub-cli -F` / `phub-cli -H`
  - Direct download mode: `phub-cli -d "query"`
- **In-Terminal Thumbnail Previews**: High-resolution video thumbnail previews in the terminal via Kitty Graphics Protocol (`kitten icat`), with `chafa`/unicode fallback. Toggle preview anytime using `[Ctrl-/]`
- **Thumbnail Cache Maintenance**: Automatic background pruning and disk size capping (`~/.cache/phub-cli/thumbnails/`)
- **Parallel Batch Downloading & Retries**:
  - Multi-select videos across pages with `[Tab]` or `[Ctrl-A]` and download concurrently (up to 5 workers)
  - Automatic 3-stage self-retries on connection drops
  - Interactive post-batch retry prompts for failed downloads
- **Custom Download Location with Safe Auto-Fallback**:
  - Configure any custom folder interactively via menu `[7]` or CLI flag (`-o / --output-dir`)
  - Automatically validates folder permissions and safely falls back to default (`~/Videos/phub-cli`) if an invalid or unwritable directory is given
  - Tab-completion support when entering paths interactively
- **Instant Playback**: Stream videos directly with `mpv` without opening a browser
- **Direct Downloads**: Download videos in multiple resolutions (1080p, 720p, 480p, 360p) with `aria2` multi-connection acceleration
- **Browser Opener**: Quickly open any video in your default web browser
- **Keyboard-driven**: Fast, minimalist `ani-cli` style interaction

---

## Installation

This project is built and installed directly from source via GitHub:

```bash
git clone https://github.com/dikshagenai/phub-cli.git
cd phub-cli
chmod +x install.sh
sudo ./install.sh
```

After installation, launch it from anywhere in your terminal:

```bash
phub-cli
```

To uninstall:

```bash
sudo ./uninstall.sh
```

---

## Dependencies

Make sure you have the required system and Python dependencies installed:

### Required Tools
- `bash`
- `mpv`
- `fzf`
- `yt-dlp`
- `curl`
- `jq`
- `aria2` (recommended for 10x-15x multi-connection download acceleration)
- `python3` (with `beautifulsoup4`, `requests`, and `curl_cffi`)

### Quick Install Commands

- **Arch Linux**:
  ```bash
  sudo pacman -S mpv fzf yt-dlp curl jq aria2 python python-beautifulsoup4 python-requests
  pip install curl_cffi --break-system-packages
  ```

- **Debian / Ubuntu**:
  ```bash
  sudo apt install mpv fzf yt-dlp curl jq aria2 python3 python3-bs4 python3-requests
  pip install curl_cffi --break-system-packages
  ```

- **Fedora**:
  ```bash
  sudo dnf install mpv fzf yt-dlp curl jq aria2 python3 python3-beautifulsoup4 python3-requests
  pip install curl_cffi --break-system-packages
  ```

- **macOS (Homebrew)**:
  ```bash
  brew install mpv fzf yt-dlp curl jq aria2 python
  pip3 install beautifulsoup4 requests curl_cffi
  ```

---

## Usage & Options

### Interactive Menu
```bash
phub-cli
```

### Direct CLI Invocation (ani-cli style)
```bash
phub-cli [OPTIONS] [QUERY]

# Search directly
phub-cli "cosplay"

# Search sorted by most viewed with short duration filter
phub-cli -s views -l short "asmr"

# Open Discovery Feeds (trending, top, views, recent, longest)
phub-cli -f trending
phub-cli -f top_rated

# Direct playback by Pornhub viewkey or full URL
phub-cli -p ph639f727ab16db
phub-cli -p "https://www.pornhub.com/view_video.php?viewkey=ph639f727ab16db"

# Browse Favorites or Watch History
phub-cli -F          # Open Favorites
phub-cli -H          # Open Watch History

# Direct batch download mode
phub-cli -d "4k 60fps"

# Download to a custom destination directory (local or remote network)
phub-cli -o ~/Downloads "cosplay"
phub-cli -o "ftp://192.168.1.5:1234/device/videos" "cosplay"

# Permanently set default download folder (local or FTP)
phub-cli --set-download-dir ~/Downloads/Videos
phub-cli --set-download-dir "ftp://192.168.1.5:1234/device/videos"
```

### CLI Flags Reference
| Flag | Description |
| :--- | :--- |
| `-d, --download [QUERY]` | Search and batch download videos in parallel |
| `-o, --output-dir <DIR\|URL>` | Set download destination (local folder or remote `ftp://` / `sftp://`) |
| `--set-download-dir <DIR\|URL>` | Permanently configure default download destination |
| `-p, --play <KEY\|URL>` | Directly stream video in mpv |
| `-f, --feed <NAME>` | Browse discovery feed (`trending`, `top`, `views`, `recent`, `longest`) |
| `-F, --favorites` | View and manage your favorites collection |
| `-H, --history` | View watch history |
| `-s, --sort <ORDER>` | Search sort: `relevance`, `recent`, `views`, `rating`, `longest` |
| `-l, --duration <DUR>` | Search duration filter: `all`, `short` (1-10m), `medium` (10-20m), `long` (20m+) |
| `-v, --version` | Display version information |
| `-h, --help` | Display help banner |

### Optional Environment Variables

```bash
# Set custom download folder via environment variable
PHUBCLI_DOWNLOAD_DIR=~/Downloads phub-cli

# Enable blinking title on the home screen
PHUBCLI_BLINK=1 phub-cli

# Disable custom fzf color theme
PHUBCLI_FZF_THEME=0 phub-cli

# Set autodownload mode (off | on | page_mode)
PHUBCLI_AUTODOWNLOAD=on phub-cli

# Disable in-terminal thumbnail previews (use minimal title preview)
PHUBCLI_THUMBNAILS=0 phub-cli

# Customize thumbnail cache retention (days) and size cap (MB)
PHUBCLI_CACHE_MAX_DAYS=14 PHUBCLI_CACHE_MAX_MB=200 phub-cli
```

---

## Acknowledgements

All original credit and sincere thanks go to the creators and contributors of [curtosis-org/phub-cli](https://github.com/curtosis-org/phub-cli). This repository proudly carries forward the project torch.

**Inspired by ani-cli. Built for terminals.**

---

## Disclaimer

This project does not host, store, or distribute any media. It only provides a terminal interface to publicly accessible content. Use responsibly and in accordance with your local laws.
