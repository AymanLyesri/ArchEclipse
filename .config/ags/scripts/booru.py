#!/usr/bin/env python3

import json
import sys
from abc import ABC, abstractmethod
from typing import List, Optional, Dict, Any

import requests
from requests.auth import HTTPBasicAuth


class ErrorResponse:
    """Structured error response."""

    def __init__(self, code: str, message: str, details: Optional[str] = None):
        self.code = code
        self.message = message
        self.details = details

    def to_dict(self) -> Dict[str, Any]:
        return {
            "error": True,
            "code": self.code,
            "message": self.message,
            "details": self.details,
        }


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
    # EXCLUDE_TAGS = ["-animated"]
    EXCLUDE_TAGS = []

    def __init__(self, api_user: Optional[str] = None, api_key: Optional[str] = None):
        self.user = api_user
        self.key = api_key

    def fetch_posts(self, tags, post_id="random", page=1, limit=6):
        if post_id == "random":
            url = (
                f"{self.BASE}/posts.json?"
                f"limit={limit}&page={page}&tags=+{'+'.join(tags) + '+' + '+'.join(self.EXCLUDE_TAGS)}"
            )
        else:
            url = f"{self.BASE}/posts/{post_id}.json"

        r = None
        try:
            auth = (
                HTTPBasicAuth(self.user, self.key) if self.user and self.key else None
            )
            r = requests.get(url, auth=auth, timeout=15)
            r.raise_for_status()
        except requests.exceptions.Timeout:
            raise Exception(f"Request timeout after 15 seconds for {self.BASE}")
        except requests.exceptions.ConnectionError as e:
            raise Exception(
                f"Connection error: Unable to reach {self.BASE}. Check your internet connection."
            )
        except requests.exceptions.HTTPError as e:
            if r and r.status_code == 401:
                raise Exception(
                    f"Authentication failed (401): Invalid API credentials for Danbooru"
                )
            elif r and r.status_code == 404:
                raise Exception(
                    f"Post not found (404): Post ID {post_id} does not exist"
                )
            else:
                raise Exception(
                    f"HTTP error {r.status_code}: {r.reason}" if r else str(e)
                )
        except Exception as e:
            raise Exception(f"Unexpected error: {str(e)}")

        try:
            posts = r.json()
        except json.JSONDecodeError:
            raise Exception(f"Invalid JSON response from {self.BASE}")

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

        try:
            auth = (
                HTTPBasicAuth(self.user, self.key) if self.user and self.key else None
            )
            r = requests.get(url, params=params, auth=auth, timeout=15)
            r.raise_for_status()
        except requests.exceptions.Timeout:
            raise Exception(f"Request timeout after 15 seconds for {self.BASE}")
        except requests.exceptions.ConnectionError:
            raise Exception(
                f"Connection error: Unable to reach {self.BASE}. Check your internet connection."
            )
        except requests.exceptions.HTTPError as e:
            if e.response.status_code == 401:
                raise Exception(
                    f"Authentication failed (401): Invalid API credentials for Danbooru"
                )
            else:
                raise Exception(
                    f"HTTP error {e.response.status_code}: {e.response.reason}"
                )
        except Exception as e:
            raise Exception(f"Unexpected error: {str(e)}")

        try:
            return [t["name"] for t in r.json()]
        except (json.JSONDecodeError, KeyError, TypeError) as e:
            raise Exception(f"Failed to parse tag response: {str(e)}")


# ============================================================
# Gelbooru provider
# ============================================================


class GelbooruProvider(BooruProvider):
    BASE = "https://gelbooru.com/index.php"
    EXCLUDE_TAGS = ["-animated"]

    def __init__(self, api_user: Optional[str] = None, api_key: Optional[str] = None):
        self.user = api_user
        self.key = api_key

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
        except requests.exceptions.Timeout:
            raise Exception(f"Request timeout after 15 seconds for Gelbooru")
        except requests.exceptions.ConnectionError:
            raise Exception(
                f"Connection error: Unable to reach Gelbooru. Check your internet connection."
            )
        except requests.exceptions.HTTPError as e:
            if e.response.status_code == 401:
                raise Exception(
                    f"Authentication failed (401): Invalid API credentials for Gelbooru"
                )
            else:
                raise Exception(
                    f"HTTP error {e.response.status_code}: {e.response.reason}"
                )
        except Exception as e:
            raise Exception(f"Unexpected error: {str(e)}")

        try:
            posts = r.json().get("post", [])
        except (json.JSONDecodeError, AttributeError) as e:
            raise Exception(f"Invalid JSON response from Gelbooru: {str(e)}")

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
        except requests.exceptions.Timeout:
            raise Exception(f"Request timeout after 15 seconds for Gelbooru")
        except requests.exceptions.ConnectionError:
            raise Exception(
                f"Connection error: Unable to reach Gelbooru. Check your internet connection."
            )
        except requests.exceptions.HTTPError as e:
            raise Exception(f"HTTP error {e.response.status_code}: {e.response.reason}")
        except Exception as e:
            raise Exception(f"Unexpected error: {str(e)}")

        try:
            tags = r.json().get("tag", []) or []
            tags.sort(key=lambda t: int(t.get("post_count", 0)), reverse=True)
            return [t["name"] for t in tags[:limit] if t.get("name")]
        except (json.JSONDecodeError, KeyError, TypeError) as e:
            raise Exception(f"Failed to parse tag response: {str(e)}")


import requests
from typing import List, Optional, Dict, Any

# ============================================================
# Safebooru provider
# ============================================================


class SafebooruProvider(BooruProvider):
    """
    Safebooru (Danbooru-based) provider.
    Uses the same API schema as Danbooru, but without authentication.
    Optionally accepts API credentials (currently unused).
    """

    BASE = "https://safebooru.donmai.us"
    EXCLUDE_TAGS = ["-animated"]

    def __init__(self, api_user: Optional[str] = None, api_key: Optional[str] = None):
        # Safebooru doesn't require authentication, but accepts it for compatibility
        self.user = api_user
        self.key = api_key

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
        except requests.exceptions.Timeout:
            raise Exception(f"Request timeout after 15 seconds for Safebooru")
        except requests.exceptions.ConnectionError:
            raise Exception(
                f"Connection error: Unable to reach Safebooru. Check your internet connection."
            )
        except requests.exceptions.HTTPError as e:
            if e.response.status_code == 404:
                raise Exception(
                    f"Post not found (404): Post ID {post_id} does not exist"
                )
            else:
                raise Exception(
                    f"HTTP error {e.response.status_code}: {e.response.reason}"
                )
        except Exception as e:
            raise Exception(f"Unexpected error: {str(e)}")

        try:
            posts = r.json()
        except json.JSONDecodeError:
            raise Exception(f"Invalid JSON response from Safebooru")

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
        except requests.exceptions.Timeout:
            raise Exception(f"Request timeout after 15 seconds for Safebooru")
        except requests.exceptions.ConnectionError:
            raise Exception(
                f"Connection error: Unable to reach Safebooru. Check your internet connection."
            )
        except requests.exceptions.HTTPError as e:
            raise Exception(f"HTTP error {e.response.status_code}: {e.response.reason}")
        except Exception as e:
            raise Exception(f"Unexpected error: {str(e)}")

        try:
            return [t["name"] for t in r.json()]
        except (json.JSONDecodeError, KeyError, TypeError) as e:
            raise Exception(f"Failed to parse tag response: {str(e)}")


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
        "safebooru": lambda: SafebooruProvider(api_user, api_key),
    }
    factory = providers.get(api.lower())
    return factory() if factory else None


# ============================================================
# CLI
# ============================================================


def main():
    if len(sys.argv) < 2:
        error = ErrorResponse(
            "MISSING_ARGS",
            "Missing required arguments",
            "Usage: booru.py --api [danbooru|gelbooru|safebooru] "
            "--id [id] --tags [tag,tag] --tag [tag] --page [n] --limit [n] "
            "--api-user [user] --api-key [key]",
        )
        print(json.dumps(error.to_dict()))
        sys.exit(1)

    api = None
    post_id = "random"
    tags: List[str] = []
    page = 1
    limit = 6
    tag_query = None
    api_user = None
    api_key = None

    try:
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
    except (IndexError, ValueError) as e:
        error = ErrorResponse("INVALID_ARGS", "Invalid argument format", str(e))
        print(json.dumps(error.to_dict()))
        sys.exit(1)

    if not api:
        error = ErrorResponse(
            "MISSING_API",
            "API source is required",
            "Use --api [danbooru|gelbooru|safebooru]",
        )
        print(json.dumps(error.to_dict()))
        sys.exit(1)

    if api not in {"danbooru", "gelbooru", "safebooru"}:
        error = ErrorResponse(
            "INVALID_API",
            "Invalid API source",
            f"'{api}' is not supported. Use 'danbooru', 'gelbooru', or 'safebooru'",
        )
        print(json.dumps(error.to_dict()))
        sys.exit(1)

    if api in {"danbooru", "gelbooru"} and (not api_user or not api_key):
        error = ErrorResponse(
            "MISSING_CREDENTIALS",
            "API user and key are required for danbooru/gelbooru",
            "Provide both --api-user and --api-key arguments",
        )
        print(json.dumps(error.to_dict()))
        sys.exit(1)

    try:
        provider = get_provider(api, api_user, api_key)
        if not provider:
            error = ErrorResponse(
                "PROVIDER_ERROR",
                "Failed to initialize provider",
                f"Could not create provider for API: {api}",
            )
            print(json.dumps(error.to_dict()))
            sys.exit(1)

        if tag_query:
            data = provider.fetch_tags(tag_query)
        else:
            data = provider.fetch_posts(tags, post_id, page, limit)

        if data is None or (isinstance(data, list) and len(data) == 0):
            error = ErrorResponse(
                "NO_RESULTS",
                "No results found",
                "The API returned no data. Try different tags or check if the post exists.",
            )
            print(json.dumps(error.to_dict()))
            sys.exit(1)

        print(json.dumps(data))
    except Exception as e:
        error = ErrorResponse(
            "UNEXPECTED_ERROR", "An unexpected error occurred", str(e)
        )
        print(json.dumps(error.to_dict()))
        sys.exit(1)


if __name__ == "__main__":
    main()
