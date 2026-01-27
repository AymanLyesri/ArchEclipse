#!/usr/bin/env python3
# -*- coding: utf-8 -*-

"""
CLI-friendly manga provider system
Optimized for:
- bash execution
- AGS exec()
- JSON output
"""

from __future__ import annotations

from datetime import datetime
import json
import sys
import argparse
import requests
from abc import ABC, abstractmethod
from dataclasses import dataclass, asdict
from typing import Dict, List, Optional, Any

# ==========================================================
# MODELS
# ==========================================================


@dataclass
class Manga:
    provider: str
    id: str
    title: str
    description: str
    tags: List[str]
    year: Optional[int]
    status: Optional[str]
    cover_url: Optional[str] = None
    cover_path: Optional[str] = None  # Add this field for local path
    cover_height: Optional[int] = None
    cover_width: Optional[int] = None

    def to_json(self):
        return asdict(self)


@dataclass
class Chapter:
    id: str
    title: str
    chapter: Optional[str] = None
    volume: Optional[str] = None
    pages: Optional[int] = None
    publish_date: Optional[str] = None

    def to_json(self):
        d = asdict(self)
        if self.publish_date and isinstance(self.publish_date, datetime):
            d["publish_date"] = self.publish_date.isoformat()
        return d


@dataclass
class Page:
    url: str
    path: Optional[str] = None  # Local path if downloaded
    height: Optional[int] = None
    width: Optional[int] = None

    def to_json(self):
        return asdict(self)


# ==========================================================
# PROVIDER INTERFACE
# ==========================================================


class MangaProvider(ABC):
    name: str

    @abstractmethod
    def search(self, query: str, limit: int, offset: int) -> List[Manga]: ...

    @abstractmethod
    def popular(self, limit: int, offset: int) -> List[Manga]: ...

    @abstractmethod
    def get_by_id(self, id: str) -> Manga: ...

    @abstractmethod
    def get_chapters(self, manga_id: str) -> List[Chapter]: ...

    @abstractmethod
    def get_pages(self, chapter_id: str) -> List[Page]: ...

    @abstractmethod
    def get_page(self, page_url: str) -> Page: ...


# ==========================================================
# REGISTRY
# ==========================================================


class ProviderRegistry:
    _providers: Dict[str, MangaProvider] = {}

    @classmethod
    def register(cls, provider: MangaProvider):
        cls._providers[provider.name] = provider

    @classmethod
    def get(cls, name: str) -> MangaProvider:
        return cls._providers[name]


# ==========================================================
# MANGADEX PROVIDER
# ==========================================================


import os
from pathlib import Path
from typing import Dict, Any, List, Optional
import requests


class MangaDexProvider(MangaProvider):
    name = "mangadex"
    BASE_URL = "https://api.mangadex.org"

    # Default cover directory
    COVERS_DIR = Path.home() / ".config" / "ags" / "assets" / "manga" / name / "covers"
    PAGES_DIR = Path.home() / ".config" / "ags" / "assets" / "manga" / name / "pages"

    def __init__(self, covers_dir: Optional[str] = None):
        self.session = requests.Session()
        self.session.headers.update({"User-Agent": "AGS-MangaCLI/1.0"})

        # Setup covers directory
        if covers_dir:
            self.covers_dir = Path(covers_dir)
        else:
            self.covers_dir = self.COVERS_DIR

        # Create directory if it doesn't exist
        self.covers_dir.mkdir(parents=True, exist_ok=True)

    def _get(self, endpoint: str, params: Dict[str, Any] | None = None):
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
                # Fetch cover art information
                data = self._get(f"/cover", {"manga[]": manga_id, "limit": 1})
                if data["data"]:
                    cover_filename = data["data"][0]["attributes"]["fileName"]
                else:
                    return None
            except Exception:
                return None

        # MangaDex cover URL format: https://uploads.mangadex.org/covers/{manga_id}/{cover_filename}
        return f"https://uploads.mangadex.org/covers/{manga_id}/{cover_filename}"

    def _download_cover_image(self, manga_id: str, cover_url: str) -> str | None:
        """Download cover image to local directory."""
        try:
            # Determine file extension from URL
            ext = os.path.splitext(cover_url)[1]
            if not ext:  # Default to .jpg if no extension found
                ext = ".jpg"

            # Create filename: {manga_id}{ext}
            filename = f"{manga_id}{ext}"
            filepath = self.covers_dir / filename

            # Download the image
            response = self.session.get(cover_url, timeout=15)
            response.raise_for_status()

            # Save to file
            with open(filepath, "wb") as f:
                f.write(response.content)

            return str(filepath)
        except Exception as e:
            print(f"Failed to download cover for {manga_id}: {e}")
            return None

    def _get_cover_filepath(self, manga_id: str) -> str | None:
        """Check if cover exists locally and return its path."""
        # Check for common image extensions
        extensions = [".jpg", ".jpeg", ".png", ".webp", ".gif"]

        for ext in extensions:
            filepath = self.covers_dir / f"{manga_id}{ext}"
            if filepath.exists():
                return str(filepath)

        return None

    def _parse(
        self,
        data: Dict[str, Any],
        include_cover: bool = True,
        download_cover: bool = True,
    ) -> Manga:
        attr = data["attributes"]

        title = attr.get("title", {}).get("en") or next(
            iter(attr.get("title", {}).values()), ""
        )

        description = attr.get("description", {}).get("en", "")

        tags = [t["attributes"]["name"].get("en", "") for t in attr.get("tags", [])]

        # Extract cover information
        cover_url = None
        if include_cover and "relationships" in data:
            # Look for cover art relationships
            for rel in data["relationships"]:
                if rel["type"] == "cover_art":
                    cover_filename = rel["attributes"]["fileName"]
                    cover_url = self._get_cover_url(data["id"], cover_filename)
                    break

        # If no cover found in relationships, try to fetch it separately
        if include_cover and not cover_url:
            cover_url = self._get_cover_url(data["id"])

        # Get local cover path (check if already downloaded)
        local_cover_path = self._get_cover_filepath(data["id"])

        # Download cover if it doesn't exist locally and we have a URL
        if not local_cover_path and cover_url and download_cover:
            local_cover_path = self._download_cover_image(data["id"], cover_url)

        # Get cover dimensions if downloaded
        cover_height = None
        cover_width = None
        if local_cover_path:
            from PIL import Image

            try:
                with Image.open(local_cover_path) as img:
                    cover_width, cover_height = img.size
            except Exception as e:
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
            cover_path=local_cover_path,  # Add local path to Manga object
            cover_height=cover_height,
            cover_width=cover_width,
        )

    def search(self, query: str, limit: int, offset: int, download_covers: bool = True):
        # Include cover art in search results
        data = self._get(
            "/manga",
            {
                "title": query,
                "limit": limit,
                "offset": offset,
                "includes[]": "cover_art",  # Include cover art relationships
            },
        )
        return [
            self._parse(m, include_cover=True, download_cover=download_covers)
            for m in data["data"]
        ]

    def popular(self, limit: int, offset: int, download_covers: bool = True):
        data = self._get(
            "/manga",
            {
                "limit": limit,
                "offset": offset,
                "order[followedCount]": "desc",
                "includes[]": "cover_art",  # Include cover art relationships
            },
        )
        return [
            self._parse(m, include_cover=True, download_cover=download_covers)
            for m in data["data"]
        ]

    def get_by_id(self, id: str, download_cover: bool = True):
        data = self._get(f"/manga/{id}", {"includes[]": "cover_art"})
        return self._parse(
            data["data"], include_cover=True, download_cover=download_cover
        )

    def get_chapters(self, manga_id: str) -> List[Chapter]:
        data = self._get(f"/manga/{manga_id}/feed", {"translatedLanguage[]": "en"})
        chapters = []
        for item in data["data"]:
            attr = item["attributes"]

            # Get the publish date as string (ISO format)
            publish_date = None
            if attr.get("publishAt"):
                # Just keep the string as-is from the API
                publish_date = attr["publishAt"]  # This is already in ISO format

            chapters.append(
                Chapter(
                    id=item["id"],
                    title=attr.get("title", ""),
                    chapter=attr.get("chapter"),
                    volume=attr.get("volume"),
                    pages=attr.get("pages"),
                    publish_date=publish_date,  # Store as string
                )
            )
        return chapters

    def get_pages(self, chapter_id: str) -> List[Page]:
        data = self._get(f"/at-home/server/{chapter_id}")
        base_url = data["baseUrl"]
        chapter_data = data["chapter"]

        # return list of Page objects
        pages = []
        for page_url in chapter_data["data"]:
            full_url = f"{base_url}/data/{chapter_data['hash']}/{page_url}"
            pages.append(Page(url=full_url))
        return pages

    # """Download page to local directory."""
    def download_page(self, page_url: str) -> Page | None:
        """Download page to local directory."""
        try:
            # Determine file extension from URL
            ext = os.path.splitext(page_url)[1]
            if not ext:  # Default to .jpg if no extension found
                ext = ".jpg"
            import hashlib

            url_hash = hashlib.md5(page_url.encode()).hexdigest()
            # Create filename: {url_hash}{ext}
            filename = f"{url_hash}{ext}"
            filepath = self.PAGES_DIR / filename
            # Download the image
            response = self.session.get(page_url, timeout=15)
            response.raise_for_status()
            # Save to file
            with open(filepath, "wb") as f:
                f.write(response.content)
            # Get image dimensions
            from PIL import Image

            with Image.open(filepath) as img:
                width, height = img.size
            return Page(
                url=page_url,
                path=str(filepath),
                width=width,
                height=height,
            )
        except Exception as e:
            print(f"Failed to download page: {e}")
            return None

    # get page and download it if not exists
    def get_page(self, page_url: str) -> Page:
        """Get page and download if not exists, returns local path."""

        # create the pages directory if not exists
        self.PAGES_DIR.mkdir(parents=True, exist_ok=True)

        # Check if already downloaded
        import hashlib

        url_hash = hashlib.md5(page_url.encode()).hexdigest()
        extensions = [".jpg", ".jpeg", ".png", ".webp", ".gif"]

        for ext in extensions:
            filepath = self.PAGES_DIR / f"{url_hash}{ext}"
            if filepath.exists():
                # Get image dimensions
                from PIL import Image

                with Image.open(filepath) as img:
                    width, height = img.size
                return Page(
                    url=page_url,
                    path=str(filepath),
                    width=width,
                    height=height,
                )
        # Download the page
        page = self.download_page(page_url)
        if page:
            return page
        else:
            raise Exception("Failed to download page")

    def ensure_cover_downloaded(self, manga_id: str) -> str | None:
        """Ensure a manga's cover is downloaded, returns the local path."""
        # Check if already downloaded
        local_path = self._get_cover_filepath(manga_id)
        if local_path:
            return local_path

        # Get manga info and download cover
        manga = self.get_by_id(manga_id, download_cover=True)
        return manga.cover_path

    def cleanup_covers(self, keep_recent: int = 100):
        """Clean up old cover files, keeping only the most recent ones."""
        try:
            # Get all cover files sorted by modification time
            cover_files = list(self.covers_dir.glob("*.*"))
            cover_files.sort(key=lambda x: x.stat().st_mtime, reverse=True)

            # Keep only the most recent ones
            for old_file in cover_files[keep_recent:]:
                old_file.unlink()

            return len(cover_files) - keep_recent
        except Exception as e:
            print(f"Error cleaning up covers: {e}")
            return 0


# ==========================================================
# EHENTAI PROVIDER
# ==========================================================

import re
import hashlib
from bs4 import BeautifulSoup


class EHentaiProvider(MangaProvider):
    """
    EH / ExHentai provider
    Uses:
    - gmetadata API for metadata
    - HTML scraping for page images
    """

    name = "ehentai"

    API_URL = "https://api.e-hentai.org/api.php"
    SITE_URL = "https://e-hentai.org"

    PAGES_DIR = Path.home() / ".config" / "ags" / "assets" / "manga" / name / "pages"
    COVERS_DIR = Path.home() / ".config" / "ags" / "assets" / "manga" / name / "covers"

    def __init__(self, cookies: Optional[dict] = None):
        self.session = requests.Session()
        self.session.headers.update({"User-Agent": "AGS-MangaCLI/1.0"})
        if cookies:
            self.session.cookies.update(cookies)

        self.PAGES_DIR.mkdir(parents=True, exist_ok=True)

    # ------------------------------------------------------
    # Helpers
    # ------------------------------------------------------

    def _gallery_id_token(self, url: str):
        """
        https://e-hentai.org/g/123456/abcdef/
        """
        m = re.search(r"/g/(\d+)/([a-zA-Z0-9]+)/", url)
        if not m:
            raise ValueError("Invalid gallery URL")
        return int(m.group(1)), m.group(2)

    def _post(self, payload: dict):
        r = self.session.post(self.API_URL, json=payload, timeout=15)
        r.raise_for_status()
        return r.json()

    # ------------------------------------------------------
    # Core API
    # ------------------------------------------------------

    def get_by_id(self, id: str) -> Manga:
        """
        id = gallery URL
        """
        gid, token = self._gallery_id_token(id)

        data = self._post(
            {
                "method": "gmetadata",
                "gidlist": [[gid, token]],
                "namespace": 1,
            }
        )

        meta = data["gmetadata"][0]

        return Manga(
            provider=self.name,
            id=id,
            title=meta["title"],
            description="",
            tags=meta.get("tags", []),
            year=int(meta["posted"][:4]) if meta.get("posted") else None,
            status=None,
            cover_url=meta.get("thumb"),
        )

    def search(self, query: str, limit: int = 20, offset: int = 0) -> List[Manga]:
        """
        Search galleries by keyword using EH HTML search.
        Safe mode:
        - single page fetch
        - offset mapped to page index
        """
        page = offset // max(limit, 1)

        params = {
            "f_search": query,
            "page": page,
        }

        html = self.session.get(
            self.SITE_URL,
            params=params,
            timeout=15,
        ).text

        soup = BeautifulSoup(html, "html.parser")

        results: List[Manga] = []
        rows = soup.select("table.itg tr")[1:]  # skip header

        for row in rows:
            link = row.select_one("td.gl3c a")
            thumb = row.select_one("td.gl2c img")
            title_cell = row.select_one("td.gl3c")

            if not link or not title_cell:
                continue

            url = link["href"]
            title = title_cell.text.strip()

            results.append(
                Manga(
                    provider=self.name,
                    id=str(url),  # gallery URL is the ID
                    title=title,
                    description="",
                    tags=[],
                    year=None,
                    status=None,
                    cover_url=str(thumb["src"]) if thumb else None,
                )
            )

            if len(results) >= limit:
                break

        return results

    def popular(self, limit: int = 10, offset: int = 0) -> List[Manga]:
        """
        Fetch current trending galleries from EH front page.
        Only first page is used (safe, low-risk).
        """
        html = self.session.get(self.SITE_URL, timeout=15).text
        soup = BeautifulSoup(html, "html.parser")

        galleries = []
        rows = soup.select("table.itg tr")[1:]  # skip header

        for row in rows:
            link = row.select_one("td.gl3c a")
            thumb = row.select_one("td.gl2c img")
            title_cell = row.select_one("td.gl3c")

            if not link or not title_cell:
                continue

            url = link["href"]
            title = title_cell.text.strip()

            galleries.append(
                Manga(
                    provider=self.name,
                    id=str(url),  # gallery URL is the ID
                    title=title,
                    description="",
                    tags=[],
                    year=None,
                    status=None,
                    cover_url=str(thumb["src"]) if thumb else None,
                )
            )

            if len(galleries) >= limit:
                break

        return galleries

    # ------------------------------------------------------
    # Chapters (fake)
    # ------------------------------------------------------

    def get_chapters(self, manga_id: str) -> List[Chapter]:
        """
        EH has no chapters → single virtual chapter
        """
        return [
            Chapter(
                id=manga_id,
                title="Gallery",
                chapter="1",
            )
        ]

    # ------------------------------------------------------
    # Pages
    # ------------------------------------------------------

    def get_pages(self, chapter_id: str) -> List[Page]:
        """
        chapter_id == gallery URL
        """
        html = self.session.get(chapter_id, timeout=15).text
        soup = BeautifulSoup(html, "html.parser")

        pages = []
        for a in soup.select("#gdt a"):
            pages.append(Page(url=str(a["href"])))

        return pages

    def get_page(self, page_url: str) -> Page:
        """
        Fetch image URL from page, download if missing
        """
        html = self.session.get(page_url, timeout=15).text
        soup = BeautifulSoup(html, "html.parser")

        img = soup.select_one("#img")
        if not img:
            raise Exception("Image not found")

        img_url = str(img["src"])

        h = hashlib.md5(img_url.encode()).hexdigest()
        ext = os.path.splitext(img_url)[1] or ".jpg"
        path = self.PAGES_DIR / f"{h}{ext}"

        if not path.exists():
            data = self.session.get(img_url, timeout=15).content
            path.write_bytes(data)

        return Page(
            url=img_url,
            path=str(path),
        )


# ==========================================================
# CLI
# ==========================================================


def parse_args():
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
    args = parse_args()

    ProviderRegistry.register(MangaDexProvider())
    ProviderRegistry.register(EHentaiProvider())
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

        # print instructions if no valid action provided
        print(
            json.dumps(
                {
                    "error": "No valid action provided. Use --search, --popular, --id, --chapters, or --pages."
                }
            ),
            file=sys.stderr,
        )
        sys.exit(1)

    except Exception as e:
        print(json.dumps({"error": str(e)}), file=sys.stderr)
        sys.exit(2)


if __name__ == "__main__":
    main()
