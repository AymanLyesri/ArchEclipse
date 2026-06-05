#!/usr/bin/env python3
# -*- coding: utf-8 -*-

"""CLI-friendly manga provider system.

Optimized for:
- bash execution
- AGS exec()
- JSON output
"""

from __future__ import annotations

import argparse
from dataclasses import asdict, dataclass
import hashlib
import json
import os
from pathlib import Path
import sys
from abc import ABC, abstractmethod
from datetime import datetime
from typing import Any, Dict, List, Optional

from PIL import Image
import requests

# ==========================================================
# MODELS
# ==========================================================


@dataclass
class Manga:  # pylint: disable=too-many-instance-attributes
    """Data class representing a Manga object."""

    provider: str
    id: str
    title: str
    description: str
    tags: List[str]
    year: Optional[int]
    status: Optional[str]
    cover_url: Optional[str] = None
    cover_path: Optional[str] = None
    cover_height: Optional[int] = None
    cover_width: Optional[int] = None

    def to_json(self) -> Dict[str, Any]:
        """Convert the Manga object to a dictionary."""
        return asdict(self)


@dataclass
class Chapter:
    """Data class representing a Manga Chapter."""

    id: str
    title: str
    chapter: Optional[str] = None
    volume: Optional[str] = None
    pages: Optional[int] = None
    publish_date: Optional[str] = None

    def to_json(self) -> Dict[str, Any]:
        """Convert the Chapter object to a JSON-compatible dictionary."""
        d = asdict(self)
        if self.publish_date and isinstance(self.publish_date, datetime):
            d["publish_date"] = self.publish_date.isoformat()
        return d


@dataclass
class Page:
    """Data class representing a single Manga Page."""

    url: str
    path: Optional[str] = None
    height: Optional[int] = None
    width: Optional[int] = None

    def to_json(self) -> Dict[str, Any]:
        """Convert the Page object to a dictionary."""
        return asdict(self)


# ==========================================================
# PROVIDER INTERFACE
# ==========================================================


class MangaProvider(ABC):
    """Abstract base class for Manga sources."""

    name: str

    @abstractmethod
    def search(self, query: str, limit: int, offset: int) -> List[Manga]:
        """Search manga by a query string."""

    @abstractmethod
    def popular(self, limit: int, offset: int) -> List[Manga]:
        """Get popular manga list."""

    @abstractmethod
    def get_by_id(self, provider_id: str) -> Manga:
        """Fetch a specific manga by its specific provider ID."""

    @abstractmethod
    def get_chapters(self, manga_id: str) -> List[Chapter]:
        """Get all chapters for a given manga ID."""

    @abstractmethod
    def get_pages(self, chapter_id: str) -> List[Page]:
        """Get pages list for a given chapter ID."""

    @abstractmethod
    def get_page(self, page_url: str) -> Page:
        """Fetch/download a single page by its direct URL."""


# ==========================================================
# REGISTRY
# ==========================================================


class ProviderRegistry:
    """Registry to keep track of available Manga providers."""

    _providers: Dict[str, MangaProvider] = {}

    @classmethod
    def register(cls, provider: MangaProvider):
        """Register a new provider instance."""
        cls._providers[provider.name] = provider

    @classmethod
    def get(cls, name: str) -> MangaProvider:
        """Retrieve a registered provider by name."""
        return cls._providers[name]


# ==========================================================
# MANGADEX PROVIDER
# ==========================================================


class MangaDexProvider(MangaProvider):
    """MangaDex API provider implementation."""

    name = "mangadex"
    BASE_URL = "https://api.mangadex.org"

    COVERS_DIR = Path.home() / ".config" / "ags" / "cache" / "manga" / name / "covers"
    PAGES_DIR = Path.home() / ".config" / "ags" / "cache" / "manga" / name / "pages"

    def __init__(self, covers_dir: Optional[str] = None):
        """Initialize the MangaDex provider sessions and directories."""
        self.session = requests.Session()
        self.session.headers.update({"User-Agent": "AGS-MangaCLI/1.0"})

        self.covers_dir = Path(covers_dir) if covers_dir else self.COVERS_DIR
        self.covers_dir.mkdir(parents=True, exist_ok=True)

    def _get(self, endpoint: str, params: Dict[str, Any] | None = None) -> Any:
        """Internal GET helper request."""
        r = self.session.get(
            f"{self.BASE_URL}{endpoint}",
            params=params,
            timeout=15,
        )
        r.raise_for_status()
        return r.json()

    def _get_cover_url(
        self, manga_id: str, cover_filename: str | None = None
    ) -> str | None:
        """Get the URL for a manga cover image."""
        if not cover_filename:
            try:
                data = self._get("/cover", {"manga[]": manga_id, "limit": 1})
                if data["data"]:
                    cover_filename = data["data"][0]["attributes"]["fileName"]
                else:
                    return None
            except Exception:  # pylint: disable=broad-exception-caught
                return None

        return f"https://uploads.mangadex.org/covers/{manga_id}/{cover_filename}"

    def _download_cover_image(self, manga_id: str, cover_url: str) -> str | None:
        """Download cover image to local directory."""
        try:
            ext = os.path.splitext(cover_url)[1]
            if not ext:
                ext = ".jpg"

            filename = f"{manga_id}{ext}"
            filepath = self.covers_dir / filename

            response = self.session.get(cover_url, timeout=15)
            response.raise_for_status()

            with open(filepath, "wb") as f:
                f.write(response.content)

            return str(filepath)
        except Exception as e:  # pylint: disable=broad-exception-caught
            print(f"Failed to download cover for {manga_id}: {e}")
            return None

    def _get_cover_filepath(self, manga_id: str) -> str | None:
        """Check if cover exists locally and return its path."""
        extensions = [".jpg", ".jpeg", ".png", ".webp", ".gif"]

        for ext in extensions:
            filepath = self.covers_dir / f"{manga_id}{ext}"
            if filepath.exists():
                return str(filepath)

        return None

    def _extract_cover_art(self, data: Dict[str, Any], include_cover: bool) -> Optional[str]:
        """Extract cover art filename from relationships or API."""
        if not include_cover:
            return None
        if "relationships" in data:
            for rel in data["relationships"]:
                if rel["type"] == "cover_art":
                    cover_filename = rel["attributes"]["fileName"]
                    return self._get_cover_url(data["id"], cover_filename)
        return self._get_cover_url(data["id"])

    def _parse(
        self,
        data: Dict[str, Any],
        include_cover: bool = True,
        download_cover: bool = True,
    ) -> Manga:
        """Parse raw MangaDex API response into Manga object."""
        attr = data["attributes"]

        title = attr.get("title", {}).get("en") or next(
            iter(attr.get("title", {}).values()), ""
        )
        description = attr.get("description", {}).get("en", "")
        tags = [t["attributes"]["name"].get("en", "") for t in attr.get("tags", [])]

        cover_url = self._extract_cover_art(data, include_cover)
        local_cover_path = self._get_cover_filepath(data["id"])

        if not local_cover_path and cover_url and download_cover:
            local_cover_path = self._download_cover_image(data["id"], cover_url)

        cover_height = None
        cover_width = None
        if local_cover_path:
            try:
                with Image.open(local_cover_path) as img:
                    cover_width, cover_height = img.size
            except Exception as e:  # pylint: disable=broad-exception-caught
                print(f"Failed to get cover dimensions for {data['id']}: {e}")

        return Manga(
            provider=self.name,
            id=data["id"],
            title=title,
            description=description,
            tags=tags,
            year=attr.get("year"),
            status=attr.get("status"),
            cover_url=cover_url,
            cover_path=local_cover_path,
            cover_height=cover_height,
            cover_width=cover_width,
        )

    def search(
        self, query: str, limit: int, offset: int, download_covers: bool = True
    ) -> List[Manga]:
        """Search for manga titles."""
        data = self._get(
            "/manga",
            {
                "title": query,
                "limit": limit,
                "offset": offset,
                "includes[]": "cover_art",
            },
        )
        return [
            self._parse(m, include_cover=True, download_cover=download_covers)
            for m in data["data"]
        ]

    def popular(
        self, limit: int, offset: int, download_covers: bool = True
    ) -> List[Manga]:
        """Fetch popular manga based on standard rating."""
        data = self._get(
            "/manga",
            {
                "limit": limit,
                "offset": offset,
                "order[followedCount]": "desc",
                "includes[]": "cover_art",
            },
        )
        return [
            self._parse(m, include_cover=True, download_cover=download_covers)
            for m in data["data"]
        ]

    def get_by_id(self, provider_id: str, download_cover: bool = True) -> Manga:
        """Fetch single manga details by ID."""
        data = self._get(f"/manga/{provider_id}", {"includes[]": "cover_art"})
        return self._parse(
            data["data"], include_cover=True, download_cover=download_cover
        )

    def get_chapters(self, manga_id: str) -> List[Chapter]:
        """Retrieve chapter feed for a manga ID."""
        data = self._get(f"/manga/{manga_id}/feed", {"translatedLanguage[]": "en"})
        chapters = []
        for item in data["data"]:
            attr = item["attributes"]
            publish_date = attr.get("publishAt")

            chapters.append(
                Chapter(
                    id=item["id"],
                    title=attr.get("title", ""),
                    chapter=attr.get("chapter"),
                    volume=attr.get("volume"),
                    pages=attr.get("pages"),
                    publish_date=publish_date,
                )
            )
        return chapters

    def get_pages(self, chapter_id: str) -> List[Page]:
        """Get direct page server URLs for a chapter."""
        data = self._get(f"/at-home/server/{chapter_id}")
        base_url = data["baseUrl"]
        chapter_data = data["chapter"]

        pages = []
        for page_url in chapter_data["data"]:
            full_url = f"{base_url}/data/{chapter_data['hash']}/{page_url}"
            pages.append(Page(url=full_url))
        return pages

    def download_page(self, page_url: str) -> Page | None:
        """Download page to local directory."""
        try:
            ext = os.path.splitext(page_url)[1]
            if not ext:
                ext = ".jpg"

            url_hash = hashlib.md5(page_url.encode()).hexdigest()
            filename = f"{url_hash}{ext}"
            filepath = self.PAGES_DIR / filename

            response = self.session.get(page_url, timeout=15)
            response.raise_for_status()

            with open(filepath, "wb") as f:
                f.write(response.content)

            with Image.open(filepath) as img:
                width, height = img.size
            return Page(
                url=page_url,
                path=str(filepath),
                width=width,
                height=height,
            )
        except Exception as e:  # pylint: disable=broad-exception-caught
            print(f"Failed to download page: {e}")
            return None

    def get_page(self, page_url: str) -> Page:
        """Get page and download if not exists, returns local path."""
        self.PAGES_DIR.mkdir(parents=True, exist_ok=True)

        url_hash = hashlib.md5(page_url.encode()).hexdigest()
        extensions = [".jpg", ".jpeg", ".png", ".webp", ".gif"]

        for ext in extensions:
            filepath = self.PAGES_DIR / f"{url_hash}{ext}"
            if filepath.exists():
                with Image.open(filepath) as img:
                    width, height = img.size
                return Page(
                    url=page_url,
                    path=str(filepath),
                    width=width,
                    height=height,
                )

        page = self.download_page(page_url)
        if page:
            return page
        raise ValueError("Failed to download page")

    def ensure_cover_downloaded(self, manga_id: str) -> str | None:
        """Ensure a manga's cover is downloaded, returns the local path."""
        local_path = self._get_cover_filepath(manga_id)
        if local_path:
            return local_path

        manga = self.get_by_id(manga_id, download_cover=True)
        return manga.cover_path

    def cleanup_covers(self, keep_recent: int = 100) -> int:
        """Clean up old cover files, keeping only the most recent ones."""
        try:
            cover_files = list(self.covers_dir.glob("*.*"))
            cover_files.sort(key=lambda x: x.stat().st_mtime, reverse=True)

            for old_file in cover_files[keep_recent:]:
                old_file.unlink()

            return len(cover_files) - keep_recent
        except Exception as e:  # pylint: disable=broad-exception-caught
            print(f"Error cleaning up covers: {e}")
            return 0


# ==========================================================
# MANGALIB PROVIDER
# ==========================================================


class MangalibProvider(MangaProvider):
    """MangaLib API provider implementation."""

    name = "mangalib"
    BASE_URL = "https://api.cdnlibs.org/api"
    COVER_URL = "https://cover.imglib.info"
    PAGES_URL = "https://img3.mixlib.me"

    COVERS_DIR = Path.home() / ".config" / "ags" / "cache" / "manga" / name / "covers"
    PAGES_DIR = Path.home() / ".config" / "ags" / "cache" / "manga" / name / "pages"

    def __init__(self, covers_dir: Optional[str] = None):
        """Initialize the MangaLib session and local paths."""
        self.session = requests.Session()
        self.session.headers.update(
            {
                "User-Agent": (
                    "Mozilla/5.0 (X11; Linux x86_64) "
                    "AppleWebKit/537.36 (KHTML, like Gecko) "
                    "Chrome/120.0.0.0 Safari/537.36"
                ),
                "Accept": "application/json, text/plain, */*",
                "Origin": "https://mangalib.org",
                "Referer": "https://mangalib.org/",
                "Site-Id": "1",
            }
        )
        self.covers_dir = Path(covers_dir) if covers_dir else self.COVERS_DIR
        self.covers_dir.mkdir(parents=True, exist_ok=True)
        self.PAGES_DIR.mkdir(parents=True, exist_ok=True)

    def _get(self, endpoint: str, params: Any = None) -> Any:
        """Handle conditional plain query string appending vs standard dict params."""
        url = f"{self.BASE_URL}{endpoint}"
        if isinstance(params, str):
            url = f"{url}?{params}"
            params = None

        r = self.session.get(url, params=params, timeout=15)
        r.raise_for_status()
        return r.json()

    def _download_image(self, url: str, filepath: Path) -> str | None:
        """Download generic item asset from an absolute location."""
        try:
            if filepath.exists():
                return str(filepath)
            r = self.session.get(url, timeout=15)
            r.raise_for_status()
            with open(filepath, "wb") as f:
                f.write(r.content)
            return str(filepath)
        except Exception as e:  # pylint: disable=broad-exception-caught
            print(f"Failed to download image {url}: {e}", file=sys.stderr)
            return None

    def _extract_text_from_prosemirror(self, node: Any) -> str:
        """Recursively extracts plain text from the MangaLib description JSON structure."""
        if not node:
            return ""
        if isinstance(node, str):
            return node
        if isinstance(node, dict):
            if node.get("type") == "text" and "text" in node:
                return node["text"]
            text = ""
            if "content" in node and isinstance(node["content"], list):
                for child in node["content"]:
                    text += self._extract_text_from_prosemirror(child)
                if node.get("type") in ["paragraph", "heading"]:
                    text += "\n"
            return text
        if isinstance(node, list):
            return "".join(self._extract_text_from_prosemirror(child) for child in node)
        return ""

    def _extract_cover_url(self, data: Dict[str, Any], manga_id: str) -> Optional[str]:
        """Extract best fit image cover URL from metadata."""
        cover_data = data.get("cover")
        if cover_data:
            if isinstance(cover_data, dict):
                filename = (
                    cover_data.get("high")
                    or cover_data.get("default")
                    or cover_data.get("thumbnail")
                )
                if filename:
                    if filename.startswith("http"):
                        return filename
                    return f"{self.COVER_URL}/uploads/cover/{manga_id}/cover/{filename}"
            elif isinstance(cover_data, str):
                if cover_data.startswith("http"):
                    return cover_data
                return f"{self.COVER_URL}{cover_data}"

        if data.get("thumbnail"):
            thumb = data.get("thumbnail")
            return thumb if thumb.startswith("http") else f"{self.COVER_URL}{thumb}"
        return None

    def _extract_tags(self, data: Dict[str, Any]) -> List[str]:
        """Extract tags and genres from raw manga data."""
        tags = []
        for field in ["genres", "tags"]:
            raw_list = data.get(field, [])
            if isinstance(raw_list, list):
                for item in raw_list:
                    if isinstance(item, dict) and item.get("name"):
                        tags.append(item.get("name"))
                    elif isinstance(item, str):
                        tags.append(item)
        return list(set(tags))

    def _extract_description(self, data: Dict[str, Any]) -> str:
        """Extract and format the manga description safely."""
        raw_summary = data.get("summary") or data.get("description") or ""
        if isinstance(raw_summary, (dict, list)):
            description = self._extract_text_from_prosemirror(raw_summary).strip()
        else:
            description = str(raw_summary).strip()

        if not description and data.get("shorthand"):
            description = str(data.get("shorthand")).strip()

        return description

    def _extract_status(self, data: Dict[str, Any]) -> str:
        """Extract status label safely."""
        status_data = data.get("status")
        if isinstance(status_data, dict):
            return status_data.get("label", "В процессе")
        return str(status_data or "Продолжается")

    def _parse_manga(self, data: Dict[str, Any]) -> Manga:
        """Parse MangaLib item raw information mapping fields safely."""
        manga_id = str(data.get("slug") or data.get("id", ""))
        title = (
            data.get("rus_name")
            or data.get("name")
            or data.get("eng_name")
            or "Unknown"
        )

        description = self._extract_description(data)
        tags = self._extract_tags(data)
        cover_url = self._extract_cover_url(data, manga_id)

        local_cover = None
        cover_width = None
        cover_height = None

        if cover_url:
            ext = os.path.splitext(cover_url.split("?")[0])[1] or ".jpg"
            filepath = self.covers_dir / f"{manga_id}{ext}"
            local_cover = self._download_image(cover_url, filepath)
            if local_cover:
                try:
                    with Image.open(local_cover) as img:
                        cover_width, cover_height = img.size
                except Exception:  # pylint: disable=broad-exception-caught
                    pass

        status_label = self._extract_status(data)

        return Manga(
            provider=self.name,
            id=manga_id,
            title=title,
            description=description,
            tags=tags,
            year=data.get("year"),
            status=status_label,
            cover_url=cover_url,
            cover_path=local_cover,
            cover_width=cover_width,
            cover_height=cover_height,
        )

    def _sanitize_limit(self, limit: int) -> int:
        if limit < 10:
            return 10
        return ((limit + 9) // 10) * 10

    def get_by_id(self, provider_id: str) -> Manga:
        """Get localized details including full descriptions by key identifier."""
        raw_params = "fields[]=summary&fields[]=genres&fields[]=tags"
        res = self._get(f"/manga/{provider_id}", params=raw_params)
        return self._parse_manga(res.get("data", {}))

    def search(self, query: str, limit: int, offset: int) -> List[Manga]:
        """Query elements with extra fallback metadata parameters loaded sequentially."""
        safe_limit = self._sanitize_limit(limit)
        params = {
            "q": query,
            "site_id[0]": "1",
            "limit": safe_limit,
            "page": (offset // safe_limit) + 1,
        }
        res = self._get("/manga", params=params)
        base_items = [self._parse_manga(m) for m in res.get("data", [])][:limit]

        detailed_items = []
        for item in base_items:
            try:
                detailed_items.append(self.get_by_id(item.id))
            except Exception as e:  # pylint: disable=broad-exception-caught
                print(f"[DEBUG] get_by_id failed for {item.id}: {e}", file=sys.stderr)
                detailed_items.append(item)
        return detailed_items

    def popular(self, limit: int, offset: int) -> List[Manga]:
        """Fetch elements sorted by rating index scores."""
        safe_limit = self._sanitize_limit(limit)
        params = {
            "sort": "rate_avg",
            "site_id[0]": "1",
            "limit": safe_limit,
            "page": (offset // safe_limit) + 1,
        }
        res = self._get("/manga", params=params)
        base_items = [self._parse_manga(m) for m in res.get("data", [])][:limit]

        detailed_items = []
        for item in base_items:
            try:
                detailed_items.append(self.get_by_id(item.id))
            except Exception as e:  # pylint: disable=broad-exception-caught
                print(f"[DEBUG] get_by_id failed for {item.id}: {e}", file=sys.stderr)
                detailed_items.append(item)
        return detailed_items

    def get_chapters(self, manga_id: str) -> List[Chapter]:
        """Grab structured list containing chapter assets identifiers."""
        res = self._get(f"/manga/{manga_id}/chapters")
        chapters = []
        for item in res.get("data", []):
            volume = str(item.get("volume", ""))
            chapter_num = str(item.get("number", ""))
            title = item.get("name", "")
            chapters.append(
                Chapter(
                    id=f"{manga_id}/v{volume}/c{chapter_num}",
                    title=title,
                    chapter=chapter_num,
                    volume=volume,
                    publish_date=item.get("created_at"),
                )
            )
            chapters.sort(
                key=lambda c: (
                    float(c.volume or 0),
                    float(c.chapter or 0),
                )
            )
        return chapters

    def get_pages(self, chapter_id: str) -> List[Page]:
        """Splits composite identifiers mapping targets down to standard lists."""

        parts = chapter_id.split("/")

        manga_id = parts[0]
        volume = parts[1].removeprefix("v")
        chapter_num = parts[2].removeprefix("c")

        res = self._get(
            f"/manga/{manga_id}/chapter",
            {
                "number": chapter_num,
                "volume": volume,
            },
        )

        pages = []

        for p in res.get("data", {}).get("pages", []):
            url = p.get("url")
            if not url:
                continue

            if url.startswith("//"):
                url = f"{self.PAGES_URL}{url}"
            elif not url.startswith("http"):
                url = f"{self.PAGES_URL}/{url.lstrip('/')}"
            pages.append(Page(url=url))
        return pages

    def get_page(self, page_url: str) -> Page:
        """Fetch dimension sizes down locally keeping track of hash identifiers."""
        url_hash = hashlib.md5(page_url.encode()).hexdigest()
        ext = os.path.splitext(page_url.split("?")[0])[1] or ".jpg"
        filepath = self.PAGES_DIR / f"{url_hash}{ext}"

        local_path = self._download_image(page_url, filepath)

        width, height = None, None
        if local_path:
            try:
                with Image.open(local_path) as img:
                    width, height = img.size
            except Exception:  # pylint: disable=broad-exception-caught
                pass

        return Page(url=page_url, path=local_path, width=width, height=height)


# ==========================================================
# CLI
# ==========================================================


def parse_args() -> argparse.Namespace:
    """Parse standard user terminal configuration entries."""
    p = argparse.ArgumentParser(description="MangaDex CLI (AGS friendly)")
    p.add_argument("--provider", default="mangadex")
    p.add_argument("--search", help="Search manga by title")
    p.add_argument("--popular", action="store_true", help="Get popular manga")
    p.add_argument("--id", help="Get manga by ID")
    p.add_argument("--chapters", action="store_true", help="Get chapters for manga")
    p.add_argument("--manga-id", help="Manga ID for chapters")
    p.add_argument("--pages", action="store_true", help="Get pages for chapter")
    p.add_argument("--chapter-id", help="Chapter ID for pages")
    p.add_argument("--limit", type=int, default=20)
    p.add_argument("--offset", type=int, default=0)
    p.add_argument("--page", help="Get and download a single page by URL")
    return p.parse_args()


def main():
    """Main routing controller block executing subactions."""
    args = parse_args()

    ProviderRegistry.register(MangaDexProvider())
    ProviderRegistry.register(MangalibProvider())
    provider = ProviderRegistry.get(args.provider)

    try:
        if args.id:
            result = provider.get_by_id(args.id)
            print(json.dumps(result.to_json(), ensure_ascii=False))
            return

        if args.search:
            result = provider.search(args.search, args.limit, args.offset)
            print(json.dumps([m.to_json() for m in result], ensure_ascii=False))
            return

        if args.popular:
            result = provider.popular(args.limit, args.offset)
            print(json.dumps([m.to_json() for m in result], ensure_ascii=False))
            return

        if args.chapters:
            if not args.manga_id:
                print(
                    json.dumps({"error": "Manga ID required for chapters"}),
                    file=sys.stderr,
                )
                sys.exit(1)
            result = provider.get_chapters(args.manga_id)
            print(json.dumps([c.to_json() for c in result], ensure_ascii=False))
            return

        if args.pages:
            if not args.chapter_id:
                print(
                    json.dumps({"error": "Chapter ID required for pages"}),
                    file=sys.stderr,
                )
                sys.exit(1)
            result = provider.get_pages(args.chapter_id)
            print(
                json.dumps(
                    [p.to_json() if hasattr(p, "to_json") else p for p in result],
                    ensure_ascii=False,
                )
            )
            return

        if args.page:
            if not args.page.startswith("http"):
                print(
                    json.dumps({"error": "Valid page URL required"}),
                    file=sys.stderr,
                )
                sys.exit(1)
            result = provider.get_page(args.page)
            print(json.dumps(result.to_json(), ensure_ascii=False))
            return

        print(
            json.dumps(
                {
                    "error": (
                        "No valid action provided. "
                        "Use --search, --popular, --id, --chapters, or --pages."
                    )
                }
            ),
            file=sys.stderr,
        )
        sys.exit(1)

    except Exception as e:  # pylint: disable=broad-exception-caught
        print(json.dumps({"error": str(e)}), file=sys.stderr)
        sys.exit(2)


if __name__ == "__main__":
    main()
