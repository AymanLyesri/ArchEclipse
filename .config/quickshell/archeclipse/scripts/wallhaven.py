#!/usr/bin/env python3
"""Wallhaven.cc API provider (search + download).

Mirrors scripts/booru.py conventions: structured errors go to stderr as
{"error": true, "code": ..., "message": ...} with a non-zero exit, result
JSON goes to stdout with exit 0.

Search:
    wallhaven.py --search [--q Q] [--categories 111] [--purity 100]
        [--sorting date_added] [--order desc] [--top-range 1M]
        [--atleast 1920x1080] [--resolutions ...] [--ratios ...]
        [--page 1] [--api-key KEY]

    Prints {"data": [{id, preview, large, full, resolution, ratio,
    purity, category, file_type, page_url}], "meta": {page, per_page,
    total, last_page, seed}}.

Download (save + apply flow: the panel downloads the full-res file into
~/.config/wallpapers/wallhaven/ then reuses the local apply pipeline):
    wallhaven.py --download <id> --dest <path> [--full-url URL] [--api-key KEY]

    Prints {"path": dest, "id": id}. When --full-url is absent the file
    URL is resolved via the /w/<id> detail endpoint first.
"""

import json
import sys
from pathlib import Path

import requests

API_BASE = "https://wallhaven.cc/api/v1"
SORTINGS = {"date_added", "relevance", "random", "views", "favorites", "toplist"}
TIMEOUT = 25


class ErrorResponse:
    def __init__(self, code: str, message: str):
        self.code = code
        self.message = message

    def to_dict(self):
        return {"error": True, "code": self.code, "message": self.message}


def emit_error(error: "ErrorResponse") -> None:
    print(json.dumps(error.to_dict()), file=sys.stderr)


def fail(code: str, message: str, status: int = 1) -> "NoReturn":  # noqa: F821
    emit_error(ErrorResponse(code, message))
    sys.exit(status)


def valid_bits(v: str) -> bool:
    return isinstance(v, str) and len(v) == 3 and all(c in "01" for c in v)


def normalize_item(item: dict) -> dict:
    thumbs = item.get("thumbs") or {}
    return {
        "id": item.get("id", ""),
        "preview": thumbs.get("small", ""),
        "large": thumbs.get("large", ""),
        "full": item.get("path", ""),
        "resolution": item.get("resolution", ""),
        "ratio": str(item.get("ratio", "")),
        "purity": item.get("purity", ""),
        "category": item.get("category", ""),
        "file_type": item.get("file_type", ""),
        "page_url": item.get("url", ""),
    }


def do_search(args) -> None:
    if not valid_bits(args.categories):
        fail("INVALID_ARGS", "--categories must be 3 chars of 0/1 (general/anime/people).")
    if not valid_bits(args.purity):
        fail("INVALID_ARGS", "--purity must be 3 chars of 0/1 (sfw/sketchy/nsfw).")
    if args.sorting not in SORTINGS:
        fail("INVALID_ARGS", f"--sorting must be one of {sorted(SORTINGS)}.")
    if args.order not in ("desc", "asc"):
        fail("INVALID_ARGS", "--order must be desc or asc.")
    if args.page < 1:
        fail("INVALID_ARGS", "--page must be >= 1.")

    params = {
        "categories": args.categories,
        "purity": args.purity,
        "sorting": args.sorting,
        "order": args.order,
        "page": args.page,
    }
    if args.q:
        params["q"] = args.q
    if args.sorting == "toplist" and args.top_range:
        params["topRange"] = args.top_range
    if args.sorting == "random" and args.seed:
        params["seed"] = args.seed
    if args.atleast:
        params["atleast"] = args.atleast
    if args.resolutions:
        params["resolutions"] = args.resolutions
    if args.ratios:
        params["ratios"] = args.ratios
    if args.api_key:
        params["apikey"] = args.api_key

    try:
        resp = requests.get(f"{API_BASE}/search", params=params, timeout=TIMEOUT)
    except Exception as exc:
        fail("NETWORK_ERROR", f"Wallhaven search request failed: {exc}")

    if resp.status_code == 401:
        fail("AUTH_REQUIRED", "Wallhaven rejected the request (401). NSFW purity needs a valid API key.")
    if resp.status_code != 200:
        fail("API_ERROR", f"Wallhaven search failed with HTTP {resp.status_code}: {resp.text[:200]}")

    try:
        payload = resp.json()
    except Exception as exc:
        fail("API_ERROR", f"Wallhaven returned invalid JSON: {exc}")

    data = payload.get("data") or []
    meta = payload.get("meta") or {}
    print(json.dumps({
        "data": [normalize_item(it) for it in data if isinstance(it, dict)],
        "meta": {
            "page": meta.get("current_page", args.page),
            "per_page": meta.get("per_page", len(data)),
            "total": meta.get("total", len(data)),
            "last_page": meta.get("last_page", args.page),
            "seed": meta.get("seed", ""),
        },
    }))


def resolve_full(wall_id: str, api_key: str) -> dict:
    params = {}
    if api_key:
        params["apikey"] = api_key
    try:
        resp = requests.get(f"{API_BASE}/w/{wall_id}", params=params, timeout=TIMEOUT)
    except Exception as exc:
        fail("NETWORK_ERROR", f"Wallhaven detail request failed: {exc}")
    if resp.status_code == 401:
        fail("AUTH_REQUIRED", "Wallhaven rejected the request (401). This wallpaper needs a valid API key.")
    if resp.status_code == 404:
        fail("NOT_FOUND", f"Wallhaven wallpaper '{wall_id}' not found.")
    if resp.status_code != 200:
        fail("API_ERROR", f"Wallhaven detail failed with HTTP {resp.status_code}: {resp.text[:200]}")
    try:
        return resp.json().get("data") or {}
    except Exception as exc:
        fail("API_ERROR", f"Wallhaven returned invalid JSON: {exc}")
    return {}


def do_download(args) -> None:
    full_url = args.full_url
    if not full_url:
        full_url = resolve_full(args.download, args.api_key).get("path", "")
    if not full_url:
        fail("API_ERROR", f"Could not resolve a download URL for '{args.download}'.")
    try:
        resp = requests.get(full_url, timeout=60)
    except Exception as exc:
        fail("NETWORK_ERROR", f"Wallpaper download failed: {exc}")
    if resp.status_code != 200 or not resp.content:
        fail("API_ERROR", f"Wallpaper download failed with HTTP {resp.status_code}.")

    dest = Path(args.dest)
    try:
        dest.parent.mkdir(parents=True, exist_ok=True)
        dest.write_bytes(resp.content)
    except Exception as exc:
        fail("WRITE_FAILED", f"Could not write {dest}: {exc}")
    print(json.dumps({"path": str(dest), "id": args.download}))


def main() -> None:
    import argparse

    p = argparse.ArgumentParser(description="Wallhaven.cc provider: search + download.")
    p.add_argument("--search", action="store_true", help="Search wallpapers (default mode).")
    p.add_argument("--q", default="", help="Search query / tags.")
    p.add_argument("--categories", default="111", help="general/anime/people bit-string, e.g. 110.")
    p.add_argument("--purity", default="100", help="sfw/sketchy/nsfw bit-string, e.g. 100.")
    p.add_argument("--sorting", default="date_added")
    p.add_argument("--order", default="desc")
    p.add_argument("--top-range", default="1M", help="Only used with --sorting toplist.")
    p.add_argument("--atleast", default="", help="Minimum resolution, e.g. 1920x1080.")
    p.add_argument("--resolutions", default="", help="Exact resolutions, comma-separated.")
    p.add_argument("--ratios", default="", help="Aspect ratios, comma-separated (16x9).")
    p.add_argument("--seed", default="", help="Random-sort seed for stable paging.")
    p.add_argument("--page", type=int, default=1)
    p.add_argument("--api-key", default="")
    p.add_argument("--download", default="", help="Wallpaper id to download.")
    p.add_argument("--dest", default="", help="Destination file path for --download.")
    p.add_argument("--full-url", default="", help="Skip detail lookup; download this URL.")
    args = p.parse_args()

    if args.download:
        if not args.dest:
            fail("MISSING_ARGS", "--download needs --dest <path>.")
        do_download(args)
        return
    do_search(args)


if __name__ == "__main__":
    main()
