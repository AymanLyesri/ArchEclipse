import json
import os
import sys
import requests
from requests.auth import HTTPBasicAuth

exclude_tags = ["-animated"]

import requests
from requests.auth import HTTPBasicAuth


def fetch_danbooru(tags, post_id, page=1, limit=6):
    if post_id == "random":
        api_url = (
            f"https://danbooru.donmai.us/posts.json?limit={limit}&page={page}&tags="
            f"+{'+'.join(tags)}"
        )
    else:
        api_url = f"https://danbooru.donmai.us/posts/{post_id}.json?"

    user_name = "publicapi"
    api_key = "Pr5ddYN7P889AnM6nq2nhgw1"  # Replace with your own API key
    response = requests.get(api_url, auth=HTTPBasicAuth(user_name, api_key))

    if response.status_code == 200:
        posts = response.json()

        # check if posts is an array if not convert it to an array
        if not isinstance(posts, list):
            posts = [posts]

        result = []
        for post in posts:
            media_asset = post.get("media_asset", {})
            variants = media_asset.get("variants", [])

            # Ensure there is at least a second variant available
            preview_url = variants[1].get("url") if len(variants) > 1 else None

            post_data = {
                "id": post.get("id"),
                "url": post.get("file_url"),
                "preview": preview_url,
                "width": post.get("image_width"),
                "height": post.get("image_height"),
                "extension": post.get("file_ext"),
            }

            # Filter out posts that have any empty (None or missing) values
            if all(post_data.values()):
                result.append(post_data)

        return result

    return None


def fetch_danbooru_tags(tag: str, limit: int = 10):
    """Fetch the top 10 most popular matching tags from Danbooru."""
    user_id = "publicapi"  # Danbooru's public API user (rate-limited)
    api_key = "Pr5ddYN7P889AnM6nq2nhgw1"  # Replace with your own if needed
    url = "https://danbooru.donmai.us/tags.json"

    # Search for tags containing the input string (wildcard search)
    params = {
        "search[name_matches]": f"*{tag}*",
        "limit": 10,  # Fetch extra to ensure we get the most popular
        "search[order]": "count",  # Order by post count (highest first)
    }

    try:
        response = requests.get(
            url, params=params, auth=HTTPBasicAuth(user_id, api_key)
        )
        response.raise_for_status()

        tags = response.json()

        if not tags:
            return []

        # Extract tag names from the top 10 most popular
        top_tags = [tag["name"] for tag in tags[:limit]]

        return top_tags

    except requests.exceptions.RequestException as e:
        return {"error": str(e)}


# ---- paste/replace into your script ----
def fetch_gelbooru(tags, post_id, page=1, limit=6):
    """
    tags: list of tag strings (e.g. ["1girl","smile"])
    post_id: "random" or specific id
    page: 1-based page (function will convert to pid=page-1)
    limit: results per page
    """
    base = "https://gelbooru.com/index.php"
    user_id = "1667355"
    api_key = "1ccd9dd7c457c2317e79bd33f47a1138ef9545b9ba7471197f477534efd1dd05"

    # common params for post queries
    params = {
        "page": "dapi",
        "s": "post",
        "q": "index",
        "json": "1",
        "limit": int(limit),
    }

    # request a single post by id
    if post_id != "random":
        params["id"] = post_id
        # don't set pid/limit for id-based lookup
    else:
        # Gelbooru uses 'pid' = zero-based page index
        pid = max(0, int(page) - 1)
        params["pid"] = pid

        # build tags string: space-separated, include exclude tags (e.g. -animated)
        if tags:
            params["tags"] = " ".join(tags + exclude_tags)
        else:
            params["tags"] = " ".join(exclude_tags)

    # add auth as query params (Gelbooru expects user_id & api_key as GET params)
    if user_id:
        params["user_id"] = user_id
    if api_key:
        params["api_key"] = api_key

    try:
        resp = requests.get(base, params=params, timeout=15)
        resp.raise_for_status()
        data = resp.json()
    except Exception as e:
        # return None or error info — keep your original behavior (you can print e for debugging)
        # print("Gelbooru request error:", e)
        return None

    # Gelbooru returns a 'post' array for searches; for id-based it may return 'post' dict or array
    posts = data.get("post", [])
    if isinstance(posts, dict):
        posts = [posts]
    if posts is None:
        posts = []

    result = []
    for post in posts:
        # Gelbooru fields: id, file_url, preview_url, width, height
        post_data = {
            "id": post.get("id"),
            "url": post.get("file_url"),
            "preview": post.get("preview_url"),
            "width": post.get("width"),
            "height": post.get("height"),
        }
        # keep same filtering behavior as your Danbooru function (only complete posts)
        if all(post_data.values()):
            result.append(post_data)

    return result if result else None


def fetch_gelbooru_tags(tag: str, limit: int = 10):
    """
    Fetch matching tags from Gelbooru.
    Uses the tag index endpoint and returns up to `limit` tag names ordered by post_count.
    """
    base = "https://gelbooru.com/index.php"
    user_id = "1667355"
    api_key = "1ccd9dd7c457c2317e79bd33f47a1138ef9545b9ba7471197f477534efd1dd05"

    params = {
        "page": "dapi",
        "s": "tag",
        "q": "index",
        "json": "1",
        # many Gelbooru installs accept 'name_pattern' for wildcard searches; if not supported,
        # you can try 'name' instead.
        "name_pattern": f"%{tag}%",
        "limit": 1000,  # fetch a big chunk and sort locally
    }

    if user_id:
        params["user_id"] = user_id
    if api_key:
        params["api_key"] = api_key

    try:
        resp = requests.get(base, params=params, timeout=15)
        resp.raise_for_status()
        payload = resp.json()
    except Exception as e:
        return {"error": str(e)}

    tags_list = payload.get("tag", []) or []
    # ensure numeric post_count, sort desc
    try:
        sorted_tags = sorted(
            tags_list, key=lambda x: int(x.get("post_count", 0)), reverse=True
        )
        tag_names = [t.get("name") for t in sorted_tags if t.get("name")]
        return tag_names[:limit]
    except Exception:
        # fallback: just return up to limit of names if sorting fails
        return [t.get("name") for t in tags_list[:limit] if t.get("name")]


def main():
    # Check if the correct number of arguments is passed
    if len(sys.argv) < 2:
        print(
            "Usage: search-booru.py --api [danbooru/gelbooru] --id [id] --tags [tag,tag...] --page [page] --limit [limit]"
        )
        sys.exit(1)

    # Initialize variables
    api_source = ""
    post_id = "random"
    tags = []
    page = 1  # Default page
    limit = 6  # Default limit
    tag = ""

    # Parse arguments
    for i in range(1, len(sys.argv)):
        if sys.argv[i] == "--api":
            api_source = sys.argv[i + 1].lower()
        elif sys.argv[i] == "--id":
            post_id = sys.argv[i + 1]
        elif sys.argv[i] == "--page":
            page = int(sys.argv[i + 1])
        elif sys.argv[i] == "--limit":
            limit = int(sys.argv[i + 1])
        elif sys.argv[i] == "--tag":
            tag = sys.argv[i + 1]
        elif sys.argv[i] == "--tags":
            tags = sys.argv[i + 1].split(",")

    save_dir = os.path.expanduser("~/.config/ags/assets/waifu")
    os.makedirs(save_dir, exist_ok=True)

    if api_source == "danbooru":
        if tag:
            data = fetch_danbooru_tags(tag)
        else:
            data = fetch_danbooru(tags, post_id, page, limit)
    elif api_source == "gelbooru":
        if tag:
            data = fetch_gelbooru_tags(tag)
        else:
            data = fetch_gelbooru(tags, post_id, page, limit)
    else:
        print("Invalid API source. Use 'danbooru' or 'gelbooru'.")
        sys.exit(1)

    if data:
        print(json.dumps(data))
    else:
        print("Failed to fetch data from API.")


if __name__ == "__main__":
    main()
