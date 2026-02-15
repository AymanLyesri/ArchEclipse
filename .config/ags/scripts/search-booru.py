#!/usr/bin/env python3

import json
import sys
from abc import ABC, abstractmethod
from typing import List, Optional, Dict, Any

import requests
from requests.auth import HTTPBasicAuth


# ============================================================
# Provider interface
# ============================================================


class BooruProvider(ABC):
    @abstractmethod
    def fetch_posts(
        self,
        tags: List[str],
        post_id: str = "random",
        page: int = 1,
        limit: int = 6,
    ) -> Optional[List[Dict[str, Any]]]:
        pass

    @abstractmethod
    def fetch_tags(self, tag: str, limit: int = 10) -> List[str]:
        pass


# ============================================================
# Danbooru provider
# ============================================================


class DanbooruProvider(BooruProvider):
    BASE = "https://danbooru.donmai.us"
    USER = "publicapi"
    KEY = "Pr5ddYN7P889AnM6nq2nhgw1"
    # EXCLUDE_TAGS = ["-animated"]
    EXCLUDE_TAGS = []

    def __init__(self, api_user: Optional[str] = None, api_key: Optional[str] = None):
        self.user = api_user or self.USER
        self.key = api_key or self.KEY

    def fetch_posts(self, tags, post_id="random", page=1, limit=6):
        if post_id == "random":
            url = (
                f"{self.BASE}/posts.json?"
                f"limit={limit}&page={page}&tags=+{'+'.join(tags) + '+' + '+'.join(self.EXCLUDE_TAGS)}"
            )
        else:
            url = f"{self.BASE}/posts/{post_id}.json"

        r = requests.get(url, auth=HTTPBasicAuth(self.user, self.key))
        if r.status_code != 200:
            return None

        posts = r.json()
        if not isinstance(posts, list):
            posts = [posts]

        result = []
        for post in posts:
            variants = post.get("media_asset", {}).get("variants", [])
            preview = variants[1]["url"] if len(variants) > 1 else None

            data = {
                "id": post.get("id"),
                "url": post.get("file_url"),
                "preview": preview,
                "width": post.get("image_width"),
                "height": post.get("image_height"),
                "extension": post.get("file_ext"),
                "tags": post.get("tag_string", "").split(),
            }

            if all(data.values()):
                result.append(data)

        return result

    def fetch_tags(self, tag, limit=10):
        url = f"{self.BASE}/tags.json"
        params = {
            "search[name_matches]": f"*{tag}*",
            "search[order]": "count",
            "limit": limit,
        }

        r = requests.get(url, params=params, auth=HTTPBasicAuth(self.user, self.key))
        if r.status_code != 200:
            return []

        return [t["name"] for t in r.json()]


# ============================================================
# Gelbooru provider
# ============================================================


class GelbooruProvider(BooruProvider):
    BASE = "https://gelbooru.com/index.php"
    USER = "1667355"
    KEY = "1ccd9dd7c457c2317e79bd33f47a1138ef9545b9ba7471197f477534efd1dd05"
    EXCLUDE_TAGS = ["-animated"]

    def __init__(self, api_user: Optional[str] = None, api_key: Optional[str] = None):
        self.user = api_user or self.USER
        self.key = api_key or self.KEY

    def fetch_posts(self, tags, post_id="random", page=1, limit=6):
        params = {
            "page": "dapi",
            "s": "post",
            "q": "index",
            "json": "1",
            "limit": limit,
            "user_id": self.user,
            "api_key": self.key,
        }

        if post_id != "random":
            params["id"] = post_id
        else:
            params["pid"] = max(0, page - 1)
            params["tags"] = " ".join(tags + self.EXCLUDE_TAGS)

        try:
            r = requests.get(self.BASE, params=params, timeout=15)
            r.raise_for_status()
        except Exception:
            return None

        posts = r.json().get("post", [])
        if isinstance(posts, dict):
            posts = [posts]

        result = []
        for post in posts:
            url = post.get("file_url")
            data = {
                "id": post.get("id"),
                "url": url,
                "preview": post.get("preview_url"),
                "width": post.get("width"),
                "height": post.get("height"),
                "extension": url.split(".")[-1] if url else None,
                "tags": str(post.get("tags", "")).split(),
            }

            if all(data.values()):
                result.append(data)

        return result or None

    def fetch_tags(self, tag, limit=10):
        params = {
            "page": "dapi",
            "s": "tag",
            "q": "index",
            "json": "1",
            "name_pattern": f"%{tag}%",
            "limit": 1000,
            "user_id": self.user,
            "api_key": self.key,
        }

        try:
            r = requests.get(self.BASE, params=params, timeout=15)
            r.raise_for_status()
        except Exception:
            return []

        tags = r.json().get("tag", []) or []
        tags.sort(key=lambda t: int(t.get("post_count", 0)), reverse=True)
        return [t["name"] for t in tags[:limit] if t.get("name")]


import requests
from typing import List, Optional, Dict, Any

# ============================================================
# Safebooru provider
# ============================================================


class SafebooruProvider(BooruProvider):
    """
    Safebooru (Danbooru-based) provider.
    Uses the same API schema as Danbooru, but without authentication.
    """

    BASE = "https://safebooru.donmai.us"
    EXCLUDE_TAGS = ["-animated"]

    def fetch_posts(
        self,
        tags: List[str],
        post_id: str = "random",
        page: int = 1,
        limit: int = 6,
    ) -> Optional[List[Dict[str, Any]]]:

        if post_id == "random":
            url = (
                f"{self.BASE}/posts.json?"
                f"limit={limit}&page={page}&tags=+{'+'.join(tags) + '+' + '+'.join(self.EXCLUDE_TAGS)}"
            )
        else:
            url = f"{self.BASE}/posts/{post_id}.json"

        try:
            r = requests.get(url, timeout=15)
            r.raise_for_status()
        except Exception:
            return None

        posts = r.json()
        if not isinstance(posts, list):
            posts = [posts]

        result = []
        for post in posts:
            variants = post.get("media_asset", {}).get("variants", [])
            preview = variants[1]["url"] if len(variants) > 1 else None

            data = {
                "id": post.get("id"),
                "url": post.get("file_url"),
                "preview": preview,
                "width": post.get("image_width"),
                "height": post.get("image_height"),
                "extension": post.get("file_ext"),
                "tags": post.get("tag_string", "").split(),
            }

            if all(data.values()):
                result.append(data)

        return result or None

    def fetch_tags(self, tag: str, limit: int = 10):
        url = f"{self.BASE}/tags.json"
        params = {
            "search[name_matches]": f"*{tag}*",
            "search[order]": "count",
            "limit": limit,
        }

        try:
            r = requests.get(url, params=params, timeout=15)
            r.raise_for_status()
        except Exception:
            return []

        return [t["name"] for t in r.json()]


# ============================================================
# Provider registry
# ============================================================


def get_provider(
    api: str, api_user: Optional[str] = None, api_key: Optional[str] = None
) -> Optional[BooruProvider]:
    """Get a provider instance with optional custom credentials."""
    providers = {
        "danbooru": lambda: DanbooruProvider(api_user, api_key),
        "gelbooru": lambda: GelbooruProvider(api_user, api_key),
        "safebooru": lambda: SafebooruProvider(),
    }
    factory = providers.get(api.lower())
    return factory() if factory else None


# ============================================================
# CLI
# ============================================================


def main():
    if len(sys.argv) < 2:
        print(
            "Usage: search-booru.py --api [danbooru|gelbooru|safebooru] "
            "--id [id] --tags [tag,tag] --tag [tag] --page [n] --limit [n] "
            "--api-user [user] --api-key [key]"
        )
        sys.exit(1)

    api = None
    post_id = "random"
    tags: List[str] = []
    page = 1
    limit = 6
    tag_query = None
    api_user = None
    api_key = None

    for i in range(1, len(sys.argv)):
        if sys.argv[i] == "--api":
            api = sys.argv[i + 1].lower()
        elif sys.argv[i] == "--id":
            post_id = sys.argv[i + 1]
        elif sys.argv[i] == "--tags":
            tags = sys.argv[i + 1].split(",")
        elif sys.argv[i] == "--tag":
            tag_query = sys.argv[i + 1]
        elif sys.argv[i] == "--page":
            page = int(sys.argv[i + 1])
        elif sys.argv[i] == "--limit":
            limit = int(sys.argv[i + 1])
        elif sys.argv[i] == "--api-user":
            api_user = sys.argv[i + 1]
        elif sys.argv[i] == "--api-key":
            api_key = sys.argv[i + 1]

    if not api:
        print("API source is required. Use --api [danbooru|gelbooru|safebooru].")
        sys.exit(1)

    provider = get_provider(api, api_user, api_key)
    if not provider:
        print("Invalid API source. Use 'danbooru', 'gelbooru', or 'safebooru'.")
        sys.exit(1)

    if tag_query:
        data = provider.fetch_tags(tag_query)
    else:
        data = provider.fetch_posts(tags, post_id, page, limit)

    print(json.dumps(data) if data else "Failed to fetch data from API.")


if __name__ == "__main__":
    main()
