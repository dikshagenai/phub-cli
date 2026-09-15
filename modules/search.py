#!/usr/bin/env python3

import sys
import re
import time
import requests
from bs4 import BeautifulSoup

if len(sys.argv) < 2:
    sys.stderr.write("Error: Search query cannot be empty.\n")
    sys.exit(1)

# Last arg is page number if it's a digit
if len(sys.argv) > 2 and sys.argv[-1].isdigit():
    page = int(sys.argv[-1])
    query = " ".join(sys.argv[1:-1]).strip()
else:
    page = 1
    query = " ".join(sys.argv[1:]).strip()

if not query:
    sys.stderr.write("Error: Search query cannot be empty.\n")
    sys.exit(1)

keywords = [k.lower() for k in re.findall(r'\w+', query)]

headers = {
    "User-Agent": "Mozilla/5.0 (X11; Linux x86_64; rv:128.0) Gecko/20100101 Firefox/128.0",
    "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
    "Accept-Language": "en-US,en;q=0.5",
    "Connection": "keep-alive",
}

params = {"search": query, "page": page}

base_urls = [
    "https://www.pornhub.org/video/search",
    "https://www.pornhub.com/video/search",
]

html = None
last_error = "Unknown error"

for attempt in range(1, 4):
    for base_url in base_urls:
        try:
            with requests.Session() as session:
                resp = session.get(base_url, params=params, headers=headers, timeout=15)
                if resp.status_code == 200:
                    html = resp.text
                    break
                elif resp.status_code == 404:
                    # Pornhub returns HTTP 404 when no results are found
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

    title_l = title.lower()

    if keywords and not any(k in title_l for k in keywords):
        continue

    match = re.search(r"viewkey=([a-zA-Z0-9]+)", href)
    if not match:
        continue

    viewkey = match.group(1)

    if viewkey in seen:
        continue

    seen.add(viewkey)
    print(f"{viewkey}|{title}")
