#!/usr/bin/env python3

import sys
import re
import time
import requests
from bs4 import BeautifulSoup

if len(sys.argv) < 2 or not sys.argv[1].strip():
    sys.stderr.write("Error: Category ID is required.\n")
    sys.exit(1)

category_id = sys.argv[1].strip()
try:
    page = int(sys.argv[2]) if len(sys.argv) > 2 else 1
    if page < 1:
        page = 1
except ValueError:
    page = 1

headers = {
    "User-Agent": "Mozilla/5.0 (X11; Linux x86_64; rv:128.0) Gecko/20100101 Firefox/128.0",
    "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
    "Accept-Language": "en-US,en;q=0.5",
    "Connection": "keep-alive",
}

base_urls = [
    f"https://www.pornhub.org/video?c={category_id}&page={page}",
    f"https://www.pornhub.com/video?c={category_id}&page={page}",
]

html = None
last_error = "Unknown error"

for attempt in range(1, 4):
    for url in base_urls:
        try:
            with requests.Session() as session:
                resp = session.get(url, headers=headers, timeout=15)
                if resp.status_code == 200:
                    html = resp.text
                    break
                elif resp.status_code == 404:
                    # Pornhub returns HTTP 404 when category page is empty or does not exist
                    sys.exit(0)
                elif resp.status_code == 403:
                    last_error = "HTTP 403 Forbidden: Access is blocked or Cloudflare is active."
                    break
                elif resp.status_code == 429:
                    last_error = "HTTP 429: Rate limited by Pornhub. Please wait a moment."
                    break
                else:
                    last_error = f"HTTP {resp.status_code}: Unexpected response from Pornhub."
        except requests.exceptions.Timeout:
            last_error = "Connection timed out."
        except requests.exceptions.ConnectionError as e:
            last_error = f"Network connection error: {e}"
        except Exception as e:
            last_error = f"Request error: {e}"
    if html:
        break
    if attempt < 3:
        time.sleep(1)

if not html:
    sys.stderr.write(f"Error: {last_error}\n")
    sys.exit(1)

soup = BeautifulSoup(html, "html.parser")
seen = set()

for a in soup.find_all("a", href=re.compile(r"view_video\.php\?viewkey=")):
    href = a.get("href", "")
    title = a.get("title", "").strip()

    if not title:
        continue

    match = re.search(r"viewkey=([a-zA-Z0-9]+)", href)
    if not match:
        continue

    viewkey = match.group(1)

    if viewkey in seen:
        continue

    seen.add(viewkey)
    print(f"{viewkey}|{title}")
