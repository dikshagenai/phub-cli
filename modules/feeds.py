#!/usr/bin/env python3
"""
phub-cli discovery feeds scraper
Scrapes video feeds (trending/hot, top rated, most viewed, most recent).
Usage: python3 modules/feeds.py <feed_type> [page]
"""

import sys
import re
import time
import requests
from bs4 import BeautifulSoup

FEED_MAP = {
    "trending": "o=ht",
    "hot": "o=ht",
    "top_rated": "o=tr",
    "top": "o=tr",
    "most_viewed": "o=mv",
    "views": "o=mv",
    "most_recent": "o=mr",
    "recent": "o=mr",
    "longest": "o=lg",
}

if len(sys.argv) < 2 or not sys.argv[1].strip():
    sys.stderr.write("Error: Feed type is required (trending, top_rated, most_viewed, most_recent).\n")
    sys.exit(1)

feed_key = sys.argv[1].strip().lower()
feed_param = FEED_MAP.get(feed_key, "o=ht")

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
    f"https://www.pornhub.org/video?{feed_param}&page={page}",
    f"https://www.pornhub.com/video?{feed_param}&page={page}",
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
    title = a.get("title", "").strip() or a.get_text(strip=True)

    if not title or title.lower() in ("play all", "playlist"):
        continue

    title = title.replace("|", "-").replace("\n", " ").strip()

    match = re.search(r"viewkey=([a-zA-Z0-9]+)", href)
    if not match:
        continue

    viewkey = match.group(1)

    if viewkey in seen:
        continue

    seen.add(viewkey)

    parent = a.find_parent(["li", "div"], class_=re.compile(r"videoBox|pcVideoListItem|videoblock|phimage", re.I)) or a.find_parent(["li", "div"])

    img = parent.find("img") if parent else a.find("img")
    thumb_url = ""
    if img:
        for attr in ["data-thumb_url", "data-src", "data-mediumthumb", "data-image", "src"]:
            v = img.get(attr, "").strip()
            if v and not v.startswith("data:") and "blank.gif" not in v:
                thumb_url = ("https:" + v) if v.startswith("//") else v
                break

    duration = ""
    if parent:
        d_tag = parent.find(["var", "span"], class_=re.compile(r"duration", re.I))
        if d_tag:
            duration = d_tag.get_text(strip=True)

    rating = ""
    if parent:
        r_tag = parent.find(["span", "div"], class_=re.compile(r"value|rating", re.I))
        if r_tag:
            rating = r_tag.get_text(strip=True)

    print(f"{viewkey}|{title}|{thumb_url}|{duration}|{rating}")
