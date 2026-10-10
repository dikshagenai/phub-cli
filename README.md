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
- **Instant Playback**: Stream videos directly with `mpv` without opening a browser
- **Direct Downloads**: Download videos in multiple resolutions (1080p, 720p, 480p, 360p)
- **Autodownload Modes**: Global toggle supporting 3 modes:
  - `off`: Default interactive mode.
  - `on`: Multi-select parallel download mode. Select multiple videos at once with `[Tab]` (or `[Ctrl-A]`), browse across pages, and hit Enter / Next to download all selected videos concurrently.
  - `page_mode`: Multi-page batch downloader for categories and searches with parallel 5-worker queue and fragment speed acceleration.
- **Browser Opener**: Quickly open any video in your default web browser
- **Resilient**: Graceful handling of network drops, fast failure recovery, and retry options
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

```bash
phub-cli
```

### Optional Environment Variables

```bash
# Enable blinking title on the home screen
PHUBCLI_BLINK=1 phub-cli

# Disable custom fzf color theme
PHUBCLI_FZF_THEME=0 phub-cli

# Set autodownload mode (off | on | page_mode)
PHUBCLI_AUTODOWNLOAD=page_mode phub-cli
```

---

## Acknowledgements

All original credit and sincere thanks go to the creators and contributors of [curtosis-org/phub-cli](https://github.com/curtosis-org/phub-cli). This repository proudly carries forward the project torch.

**Inspired by ani-cli. Built for terminals.**

---

## Disclaimer

This project does not host, store, or distribute any media. It only provides a terminal interface to publicly accessible content. Use responsibly and in accordance with your local laws.
