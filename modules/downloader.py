#!/usr/bin/env python3
"""
phub-cli parallel downloader module
Handles multi-threaded concurrent downloading of video lists using yt-dlp with speed optimizations.
"""

import sys
import os
import re
import time
import argparse
import signal
import subprocess
import threading
import atexit
import shutil
import urllib.request
import tarfile
from concurrent.futures import ThreadPoolExecutor

# Terminal colors
RED = '\033[0;31m'
BOLD_RED = '\033[1;31m'
PINK = '\033[38;5;206m'
HOT_PINK = '\033[38;5;200m'
PURPLE = '\033[0;35m'
BOLD_PURPLE = '\033[1;35m'
MAGENTA = '\033[0;95m'
DEEP_PINK = '\033[38;5;125m'
ROSE = '\033[38;5;197m'
GOLD = '\033[38;5;220m'
GREEN = '\033[0;32m'
BOLD_GREEN = '\033[1;32m'
BOLD = '\033[1m'
NC = '\033[0m'
CLEAR_LINE = '\033[2K'
CURSOR_UP = '\033[1A'

# Formats
QUALITY_FORMATS = {
    "best": "best[protocol=https]/best[protocol^=http]/bestvideo+bestaudio/best",
    "720p": "best[height<=720][protocol=https]/best[height<=720]/bestvideo[height<=720]+bestaudio/best",
    "480p": "best[height<=480][protocol=https]/best[height<=480]/bestvideo[height<=480]+bestaudio/best",
    "360p": "best[height<=360][protocol=https]/best[height<=360]/bestvideo[height<=360]+bestaudio/best",
}

# Global state for cleanup and UI
running_processes = set()
cookie_file = None
stop_requested = False
aria2c_executable = None


def get_aria2c_path():
    """Locate or auto-download static aria2c binary for multi-connection download acceleration."""
    global aria2c_executable
    if aria2c_executable:
        return aria2c_executable

    candidates = [
        shutil.which("aria2c"),
        os.path.expanduser("~/.local/bin/aria2c"),
        os.path.expanduser("~/.config/phub-cli/bin/aria2c"),
        "/usr/local/bin/aria2c",
        "/usr/bin/aria2c",
    ]
    for p in candidates:
        if p and os.path.isfile(p) and os.access(p, os.X_OK):
            aria2c_executable = p
            return aria2c_executable

    # Attempt to auto-install static binary if missing
    try:
        dest_dir = os.path.expanduser("~/.local/bin")
        target_bin = os.path.join(dest_dir, "aria2c")
        if not os.path.exists(target_bin):
            os.makedirs(dest_dir, exist_ok=True)
            url = "https://github.com/P3TERX/Aria2-Pro-Core/releases/download/1.35.0/aria2-1.35.0-static-linux-amd64.tar.gz"
            tar_path = os.path.join(dest_dir, "aria2_tmp.tar.gz")
            req = urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0"})
            with urllib.request.urlopen(req, timeout=8) as resp, open(tar_path, "wb") as out:
                shutil.copyfileobj(resp, out)
            with tarfile.open(tar_path, "r:gz") as tar:
                tar.extractall(path=dest_dir)
            if os.path.exists(tar_path):
                os.remove(tar_path)
            if os.path.exists(target_bin):
                os.chmod(target_bin, 0o755)
        if os.path.isfile(target_bin) and os.access(target_bin, os.X_OK):
            aria2c_executable = target_bin
            return aria2c_executable
    except Exception:
        pass

    return None


def cleanup():
    global cookie_file, running_processes
    for p in list(running_processes):
        try:
            p.terminate()
            p.kill()
        except Exception:
            pass
    if cookie_file and os.path.exists(cookie_file):
        try:
            os.remove(cookie_file)
        except Exception:
            pass


atexit.register(cleanup)


def handle_sigint(signum, frame):
    global stop_requested
    stop_requested = True
    print(f"\n{ROSE}⚠️  Cancellation requested. Stopping active downloads...{NC}", file=sys.stderr)
    cleanup()
    sys.exit(130)


signal.signal(signal.SIGINT, handle_sigint)
signal.signal(signal.SIGTERM, handle_sigint)


def extract_firefox_cookies():
    """Attempt to extract firefox cookies once to a shared temp file to avoid sqlite concurrency locks."""
    global cookie_file
    tmp_path = f"/tmp/phub_cookies_{os.getpid()}.txt"
    try:
        cmd = [
            "yt-dlp",
            "--cookies-from-browser=firefox",
            "--cookies", tmp_path,
            "--skip-download",
            "https://www.pornhub.com"
        ]
        res = subprocess.run(cmd, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=6)
        if res.returncode == 0 and os.path.exists(tmp_path) and os.path.getsize(tmp_path) > 100:
            cookie_file = tmp_path
            return cookie_file
    except Exception:
        pass
    if os.path.exists(tmp_path):
        try:
            os.remove(tmp_path)
        except Exception:
            pass
    return None


class ParallelDownloader:
    def __init__(self, videos, output_dir, quality="720p", concurrency=5, fragments=4, simulate=False):
        self.videos = videos  # list of (viewkey, title)
        self.total = len(videos)
        self.output_dir = os.path.expanduser(output_dir)
        self.quality = quality
        self.concurrency = min(concurrency, 5)
        self.fragments = fragments
        self.simulate = simulate
        self.format_str = QUALITY_FORMATS.get(quality, QUALITY_FORMATS["720p"])

        self.slots = [
            {"slot": i, "status": "idle", "title": "", "progress": "", "speed": "", "eta": ""}
            for i in range(self.concurrency)
        ]
        self.slot_lock = threading.Lock()
        self.available_slots = list(range(self.concurrency))

        self.completed_count = 0
        self.success_count = 0
        self.failed_count = 0
        self.completed_lock = threading.Lock()

        self.failed_items = []
        self.is_tty = sys.stdout.isatty()
        self.start_time = time.time()

    def acquire_slot(self):
        with self.slot_lock:
            if self.available_slots:
                return self.available_slots.pop(0)
        return None

    def release_slot(self, slot_idx):
        with self.slot_lock:
            self.slots[slot_idx]["status"] = "idle"
            self.slots[slot_idx]["title"] = ""
            self.slots[slot_idx]["progress"] = ""
            self.slots[slot_idx]["speed"] = ""
            self.slots[slot_idx]["eta"] = ""
            self.available_slots.append(slot_idx)

    def download_item(self, item_index, viewkey, title):
        if stop_requested:
            return

        slot_idx = None
        while slot_idx is None and not stop_requested:
            slot_idx = self.acquire_slot()
            if slot_idx is None:
                time.sleep(0.05)

        if stop_requested or slot_idx is None:
            return

        clean_title = re.sub(r'[\r\n\t]+', ' ', title).strip()
        display_title = (clean_title[:38] + "..") if len(clean_title) > 40 else clean_title

        with self.slot_lock:
            self.slots[slot_idx]["status"] = "downloading"
            self.slots[slot_idx]["title"] = display_title
            self.slots[slot_idx]["progress"] = "0%"
            self.slots[slot_idx]["speed"] = "starting"
            self.slots[slot_idx]["eta"] = ""

        page_url = f"https://www.pornhub.org/view_video.php?viewkey={viewkey}"
        output_template = os.path.join(self.output_dir, "%(title)s.%(ext)s")

        ytdl_cmd = [
            "yt-dlp",
            "--newline",
            "--progress",
            "--continue",
            "--no-playlist",
            "--retries", "5",
            "--fragment-retries", "5",
            "--file-access-retries", "3",
            "--concurrent-fragments", str(self.fragments),
            "--buffer-size", "1024K",
            "--no-mtime",
            "-f", self.format_str,
            "-o", output_template,
        ]

        if self.simulate:
            ytdl_cmd.append("-s")
        else:
            aria_bin = get_aria2c_path()
            if aria_bin:
                ytdl_cmd.extend([
                    "--downloader", aria_bin,
                    "--downloader-args", "aria2c:--summary-interval=1 -x 16 -s 16 -k 1M -j 16"
                ])

        if cookie_file:
            ytdl_cmd.extend(["--cookies", cookie_file])

        ytdl_cmd.append(page_url)

        proc = None
        success = False
        error_msg = ""

        try:
            proc = subprocess.Popen(
                ytdl_cmd,
                stdout=subprocess.PIPE,
                stderr=subprocess.STDOUT,
                text=True,
                bufsize=1
            )
            running_processes.add(proc)

            progress_regex_ytdl = re.compile(
                r'\[download\]\s+([\d\.]+%)(?:\s+of\s+([^\s]+))?(?:\s+at\s+([^\s]+))?(?:\s+ETA\s+([^\s]+))?'
            )
            progress_regex_aria = re.compile(
                r'\[#[a-f0-9]+\s+.*?\((\d+%?)\)\s+CN:\d+\s+DL:([^\s]+)\s+ETA:([^\s\]]+)\]'
            )

            for line in iter(proc.stdout.readline, ''):
                if stop_requested:
                    break
                line = line.strip()
                if not line:
                    continue

                m_ytdl = progress_regex_ytdl.search(line)
                m_aria = progress_regex_aria.search(line)
                if m_ytdl:
                    pct = m_ytdl.group(1) or ""
                    spd = m_ytdl.group(3) or ""
                    eta = m_ytdl.group(4) or ""
                    with self.slot_lock:
                        self.slots[slot_idx]["progress"] = pct
                        if spd:
                            self.slots[slot_idx]["speed"] = spd
                        if eta:
                            self.slots[slot_idx]["eta"] = eta
                elif m_aria:
                    pct, spd, eta = m_aria.groups()
                    with self.slot_lock:
                        self.slots[slot_idx]["progress"] = pct if "%" in pct else pct + "%"
                        self.slots[slot_idx]["speed"] = spd if "B" in spd else spd + "B/s"
                        self.slots[slot_idx]["eta"] = eta
                elif "ERROR:" in line or "error:" in line:
                    error_msg = line

            proc.wait()
            success = (proc.returncode == 0)

        except Exception as e:
            error_msg = str(e)
            success = False
        finally:
            if proc:
                running_processes.discard(proc)
            self.release_slot(slot_idx)

        with self.completed_lock:
            self.completed_count += 1
            if success:
                self.success_count += 1
                if not self.is_tty:
                    print(f"[{self.completed_count}/{self.total}] ✅ Succeeded: {clean_title}")
            else:
                self.failed_count += 1
                short_err = error_msg.replace("ERROR:", "").strip() if error_msg else "Unknown error"
                if len(short_err) > 60:
                    short_err = short_err[:57] + "..."
                self.failed_items.append((clean_title, short_err))
                if not self.is_tty:
                    print(f"[{self.completed_count}/{self.total}] ❌ Failed: {clean_title} ({short_err})")

    def render_ui(self):
        """Render multi-slot status dashboard in interactive terminal."""
        lines_to_clear = self.concurrency + 2
        first_frame = True

        while not stop_requested:
            with self.completed_lock:
                done = self.completed_count
                succ = self.success_count
                fail = self.failed_count

            if done >= self.total:
                break

            with self.slot_lock:
                current_slots = [dict(s) for s in self.slots]

            # Build status lines
            status_lines = []
            for s in current_slots:
                if s["status"] == "downloading":
                    prog = s["progress"] or "..."
                    spd = f"at {s['speed']}" if s["speed"] else ""
                    eta = f"ETA {s['eta']}" if s["eta"] else ""
                    stats = " ".join(filter(None, [prog, spd, eta]))
                    status_lines.append(
                        f"  {HOT_PINK}[Worker {s['slot']+1}]{NC} 🚀 {PINK}{s['title']:<40}{NC} {GOLD}[ {stats} ]{NC}"
                    )
                else:
                    status_lines.append(
                        f"  {HOT_PINK}[Worker {s['slot']+1}]{NC} 💤 {ROSE}Waiting / idle{NC}"
                    )

            # Overall progress bar
            pct = (done / self.total) * 100 if self.total > 0 else 0
            bar_width = 24
            filled = int(bar_width * done / self.total) if self.total > 0 else 0
            bar = "█" * filled + "░" * (bar_width - filled)

            summary_line = (
                f"  {BOLD}Progress:{NC} [{GOLD}{bar}{NC}] {BOLD}{done}/{self.total}{NC} ({pct:.1f}%) | "
                f"{GREEN}✅ {succ} done{NC} | {RED}❌ {fail} failed{NC}"
            )

            output = "\n".join(status_lines) + "\n\n" + summary_line

            if not first_frame:
                sys.stdout.write((CURSOR_UP + CLEAR_LINE) * lines_to_clear)
            first_frame = False

            sys.stdout.write(output + "\n")
            sys.stdout.flush()

            time.sleep(0.15)

        # Clear active dashboard lines when finished
        if not first_frame:
            sys.stdout.write((CURSOR_UP + CLEAR_LINE) * lines_to_clear)
            sys.stdout.flush()

    def run(self):
        os.makedirs(self.output_dir, exist_ok=True)

        print("")
        print(f"  {BOLD_RED}┌────────────────────────────────────────────────────────────┐{NC}")
        print(f"  {BOLD_RED}│{NC}   {HOT_PINK}{BOLD}phub-cli Parallel Downloader (Max {self.concurrency} Workers){NC}            {BOLD_RED}│{NC}")
        print(f"  {BOLD_RED}└────────────────────────────────────────────────────────────┘{NC}")
        print(f"  {HOT_PINK}📁 Destination:{NC} {GOLD}{self.output_dir}{NC}")
        print(f"  {PINK}📺 Quality:{NC}     {GOLD}{self.quality}{NC}")
        print(f"  {ROSE}⚡ Concurrency:{NC} {GOLD}{self.concurrency} parallel videos ({self.fragments} fragments/vid){NC}")
        aria_bin = get_aria2c_path()
        if aria_bin:
            print(f"  {GREEN}🚀 Accelerator:{NC} {GOLD}aria2c enabled (16 multi-connection streams/video){NC}")
        print(f"  {MAGENTA}📋 Total Queue:{NC} {BOLD}{self.total} videos{NC}")
        if cookie_file:
            print(f"  {GOLD}🍪 Cookie Jar:{NC}  {GREEN}Firefox cookies cached successfully{NC}")
        print("")

        # Start UI rendering thread if running interactively
        ui_thread = None
        if self.is_tty:
            ui_thread = threading.Thread(target=self.render_ui, daemon=True)
            ui_thread.start()

        # ThreadPoolExecutor for concurrent downloads
        with ThreadPoolExecutor(max_workers=self.concurrency) as executor:
            futures = []
            for idx, (viewkey, title) in enumerate(self.videos):
                f = executor.submit(self.download_item, idx, viewkey, title)
                futures.append(f)

            for f in futures:
                f.result()

        if ui_thread:
            ui_thread.join(timeout=1.0)

        elapsed = time.time() - self.start_time
        mins = int(elapsed // 60)
        secs = int(elapsed % 60)
        time_str = f"{mins}m {secs}s" if mins > 0 else f"{secs}s"

        print("")
        print(f"  {BOLD_RED}┌────────────────────────────────────────────────────────────┐{NC}")
        print(f"  {BOLD_RED}│{NC}                 {GOLD}{BOLD}Batch Download Summary{NC}                     {BOLD_RED}│{NC}")
        print(f"  {BOLD_RED}├────────────────────────────────────────────────────────────┤{NC}")
        print(f"  {BOLD_RED}│{NC}  Total Queued:     {self.total:<40} {BOLD_RED}│{NC}")
        print(f"  {BOLD_RED}│{NC}  {GREEN}✅ Succeeded:{NC}     {self.success_count:<40} {BOLD_RED}│{NC}")
        print(f"  {BOLD_RED}│{NC}  {RED}❌ Failed:{NC}        {self.failed_count:<40} {BOLD_RED}│{NC}")
        print(f"  {BOLD_RED}│{NC}  ⏱️ Elapsed Time:   {time_str:<40} {BOLD_RED}│{NC}")
        print(f"  {BOLD_RED}│{NC}  📁 Destination:   {self.output_dir[-38:]:<40} {BOLD_RED}│{NC}")
        print(f"  {BOLD_RED}└────────────────────────────────────────────────────────────┘{NC}")

        if self.failed_items:
            print("")
            print(f"  {RED}⚠️  Failed downloads:{NC}")
            for title, err in self.failed_items[:10]:
                print(f"    • {ROSE}{title}{NC}: {err}")
            if len(self.failed_items) > 10:
                print(f"    • ... and {len(self.failed_items) - 10} more.")


def main():
    parser = argparse.ArgumentParser(description="phub-cli parallel batch downloader")
    parser.add_argument("--list", "-l", required=True, help="File containing viewkey|title lines")
    parser.add_argument("--output-dir", "-o", default=os.path.expanduser("~/Videos/phub-cli"), help="Download folder")
    parser.add_argument("--quality", "-q", default="720p", choices=["best", "720p", "480p", "360p"], help="Target video resolution")
    parser.add_argument("--concurrency", "-c", type=int, default=5, help="Concurrent downloads (max 5)")
    parser.add_argument("--fragments", "-f", type=int, default=4, help="Concurrent fragments per video (default: 4)")
    parser.add_argument("--simulate", "-s", action="store_true", help="Simulate downloads without writing to disk")

    args = parser.parse_args()

    if not os.path.exists(args.list):
        sys.stderr.write(f"Error: Video list file '{args.list}' does not exist.\n")
        sys.exit(1)

    videos = []
    with open(args.list, "r", encoding="utf-8", errors="ignore") as fp:
        for line in fp:
            line = line.strip()
            if not line or "|" not in line:
                continue
            parts = line.split("|", 1)
            viewkey = parts[0].strip()
            title = parts[1].strip() if len(parts) > 1 else viewkey
            if viewkey:
                videos.append((viewkey, title))

    if not videos:
        print(f"{GOLD}No valid videos found in list file.{NC}")
        sys.exit(0)

    # Attempt to export firefox cookies once to avoid parallel SQLite locks
    extract_firefox_cookies()

    downloader = ParallelDownloader(
        videos=videos,
        output_dir=args.output_dir,
        quality=args.quality,
        concurrency=args.concurrency,
        fragments=args.fragments,
        simulate=args.simulate,
    )
    downloader.run()


if __name__ == "__main__":
    main()
