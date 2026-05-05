#!/usr/bin/env python3
"""
WALLPAPERS.py - Download and manage wallpapers for ArchEclipse
"""

import os
import subprocess
import sys
from pathlib import Path
from typing import Dict, List
import json
import tempfile
import shutil

# Add current directory to path for imports
sys.path.insert(0, os.path.dirname(__file__))
from ESSENTIALS import command_exists
from components.figlet import print_archeclipse_banner_text, print_figlet_lolcat

# Colors
BOLD = "\033[1m"
CYAN = "\033[0;36m"
GREEN = "\033[0;32m"
YELLOW = "\033[1;33m"
MAGENTA = "\033[0;35m"
RED = "\033[0;31m"
BLUE = "\033[0;34m"
NC = "\033[0m"

FZF_HEIGHT = "40%"

# Wallpaper URLs organized by category
URLS_IMAGES_SFW = [
    "https://w.wallhaven.cc/full/qr/wallhaven-qrjq8l.png",
    "https://w.wallhaven.cc/full/zp/wallhaven-zpzv7j.jpg",
    "https://w.wallhaven.cc/full/po/wallhaven-polpoe.jpg",
    "https://w.wallhaven.cc/full/w5/wallhaven-w51kxr.jpg",
    "https://w.wallhaven.cc/full/5y/wallhaven-5y5dp3.jpg",
    "https://w.wallhaven.cc/full/5y/wallhaven-5yz968.jpg",
    "https://w.wallhaven.cc/full/d8/wallhaven-d8395l.jpg",
    "https://w.wallhaven.cc/full/yq/wallhaven-yq56jg.jpg",
]

URLS_ANIMATED_SFW = [
    "https://cdn.donmai.us/original/3e/1b/3e1b4d5d9c6cfb1dc6c623e15027852f.mp4",
    "https://motionbgs.com/dl/hd/8944",
    "https://motionbgs.com/dl/hd/9360",
]

CATEGORIES = {
    "images_sfw": URLS_IMAGES_SFW,
    "animated_sfw": URLS_ANIMATED_SFW,
}

HOST_DEFAULT_EXT = {
    "motionbgs.com": "mp4",
}


def get_basename_from_url(url: str) -> str:
    """Get basename from URL"""
    url = url.split("?")[0]  # Remove query parameters
    return os.path.basename(url)


def get_host_from_url(url: str) -> str:
    """Get host from URL"""
    from urllib.parse import urlparse

    parsed = urlparse(url)
    return parsed.netloc.lower()


def get_extension_hint_for_url(url: str, category: str) -> str:
    """Get extension hint for URL"""
    host = get_host_from_url(url)

    if host in HOST_DEFAULT_EXT:
        return HOST_DEFAULT_EXT[host]

    if category.startswith("animated_"):
        return "mp4"

    return ""


def resolve_download_filename(url: str, category: str) -> str:
    """Resolve download filename"""
    filename = get_basename_from_url(url)

    if "." in os.path.basename(filename):
        return filename

    hint_ext = get_extension_hint_for_url(url, category)
    if hint_ext:
        return f"{filename}.{hint_ext}"

    return filename


def get_category_size(urls: List[str]) -> int:
    """Get total size of category in MB"""
    if not urls:
        return 0

    try:
        # Use curl to get content lengths
        cmd = ["curl", "--parallel", "--parallel-immediate", "-sI"] + urls
        result = subprocess.run(cmd, capture_output=True, text=True, timeout=30)

        import re

        sizes = re.findall(r"Content-Length:\s*(\d+)", result.stdout + result.stderr)
        total_bytes = sum(int(s) for s in sizes)
        return int(total_bytes / 1024 / 1024)
    except Exception:
        return 0


def convert_gif_to_mp4(input_file: str) -> None:
    """Convert GIF to MP4"""
    output_file = input_file.rsplit(".", 1)[0] + ".mp4"

    # Skip if converted file already exists
    if os.path.exists(output_file):
        try:
            subprocess.run(
                [
                    "ffprobe",
                    "-v",
                    "error",
                    "-select_streams",
                    "v:0",
                    "-show_entries",
                    "stream=codec_name",
                    "-of",
                    "csv=p=0",
                    output_file,
                ],
                capture_output=True,
                check=True,
            )
            if os.path.exists(input_file):
                os.remove(input_file)
            return
        except Exception:
            pass

    if not os.path.exists(input_file):
        print(f"{YELLOW}  ⚠ Missing source GIF:{NC} {os.path.basename(input_file)}")
        return

    print(f"{CYAN}  🔄 Converting GIF → MP4:{NC} {os.path.basename(input_file)}")

    subprocess.run(
        [
            "ffmpeg",
            "-y",
            "-loglevel",
            "error",
            "-i",
            input_file,
            "-map",
            "0:v:0",
            "-an",
            "-movflags",
            "faststart",
            "-pix_fmt",
            "yuv444p",
            "-c:v",
            "libx264",
            "-crf",
            "16",
            "-preset",
            "slow",
            "-tune",
            "animation",
            output_file,
        ],
        capture_output=True,
    )

    if os.path.exists(output_file):
        os.remove(input_file)
    else:
        print(f"{RED}  ✗ Conversion failed:{NC} {os.path.basename(input_file)}")


def download_category(category: str, urls: List[str]) -> None:
    """Download wallpapers for a category"""
    if not urls:
        print(f"{YELLOW}⚠ No wallpapers in {category}. Skipping...{NC}")
        return

    home = os.path.expanduser("~")
    folder = os.path.join(home, ".config/wallpapers/defaults", category)
    os.makedirs(folder, exist_ok=True)

    expected_files = []
    downloaded = 0
    skipped = 0

    for url in urls:
        filename = resolve_download_filename(url, category)
        filepath = os.path.join(folder, filename)

        if filename.lower().endswith(".gif"):
            converted_filename = filename.rsplit(".", 1)[0] + ".mp4"
            converted_filepath = os.path.join(folder, converted_filename)
            expected_files.append(filename)
            expected_files.append(converted_filename)

            # Check if already converted
            try:
                subprocess.run(
                    [
                        "ffprobe",
                        "-v",
                        "error",
                        "-select_streams",
                        "v:0",
                        "-show_entries",
                        "stream=codec_name",
                        "-of",
                        "csv=p=0",
                        converted_filepath,
                    ],
                    capture_output=True,
                    check=True,
                )
                if os.path.exists(filepath):
                    os.remove(filepath)
                skipped += 1
                continue
            except Exception:
                pass
        else:
            expected_files.append(filename)

        if os.path.exists(filepath):
            skipped += 1
            if filepath.lower().endswith(".gif"):
                convert_gif_to_mp4(filepath)
        else:
            print(f"{CYAN}  ⬇ Downloading: {NC}{filename}")
            try:
                subprocess.run(
                    ["curl", "-L", "-o", filepath, url], capture_output=True, timeout=60
                )
                if os.path.exists(filepath):
                    downloaded += 1
                    if filepath.lower().endswith(".gif"):
                        convert_gif_to_mp4(filepath)
            except Exception as e:
                print(f"{RED}  ✗ Failed: {NC}{filename}")

    # Clean up old files
    print(f"{YELLOW}🧹 Cleaning up old files...{NC}")
    removed = 0

    for file in os.listdir(folder):
        filepath = os.path.join(folder, file)
        if os.path.isfile(filepath) and file not in expected_files:
            print(f"{RED}  ✗ Removing: {NC}{file}")
            os.remove(filepath)
            removed += 1

    print(f"{BOLD}{MAGENTA}  Category: {category}{NC}")
    print(f"{GREEN}  ✓ Downloaded: {downloaded}{NC}")
    print(f"{YELLOW}  ⊙ Skipped: {skipped}{NC}")
    print(f"{RED}  ✗ Removed: {removed}{NC}")
    print("")


def display_wallpaper_table() -> None:
    """Display wallpaper installation menu"""
    print(
        f"{BOLD}{CYAN}╔════════════════════════════════════════════════════════════╗{NC}"
    )
    print(
        f"{BOLD}{CYAN}║{NC}        {BOLD}{MAGENTA}🖼️  WALLPAPER INSTALLATION MENU{NC}  {BOLD}{CYAN}║{NC}"
    )
    print(
        f"{BOLD}{CYAN}╚════════════════════════════════════════════════════════════╝{NC}"
    )
    print("")

    print(f"{YELLOW}⏳ Calculating wallpaper sizes...{NC}")

    total_count = 0
    total_size = 0

    print("")
    print(f"{BOLD}{CYAN}┌──────────────┬──────────────┬─────────────────┐{NC}")
    print(f"{BOLD}{CYAN}│CATEGORY      │     COUNT    │    SIZE (MB)    │{NC}")
    print(f"{BOLD}{CYAN}├──────────────┼──────────────┼─────────────────┤{NC}")

    for category, urls in CATEGORIES.items():
        count = len(urls)
        size = get_category_size(urls)

        total_count += count
        total_size += size

        print(
            f"{BOLD}{CYAN}│{NC} {category:<12} {BOLD}{CYAN}│{NC} {count:>12} {BOLD}{CYAN}│{NC} {size:>15} MB {BOLD}{CYAN}│{NC}"
        )

    print(f"{BOLD}{CYAN}├──────────────┼──────────────┼─────────────────┤{NC}")
    print(
        f"{BOLD}{CYAN}│{NC} {'TOTAL':<12} {BOLD}{CYAN}│{NC} {total_count:>12} {BOLD}{CYAN}│{NC} {total_size:>15} MB {BOLD}{CYAN}│{NC}"
    )
    print(f"{BOLD}{CYAN}└──────────────┴──────────────┴─────────────────┘{NC}")
    print("")


def show_choice_menu() -> None:
    """Show wallpaper selection menu"""
    print(f"{BOLD}{YELLOW}📋 Select category:{NC}")
    print("")

    categories_list = list(CATEGORIES.keys())

    for i, category in enumerate(categories_list, 1):
        print(f"{GREEN}  [{i}]{NC} {category}")

    print(f"{BLUE}  [{len(categories_list)+1}]{NC} ALL")
    print(f"{CYAN}  [{len(categories_list)+2}]{NC} Cancel")

    print("")
    print(f"{BOLD}{CYAN}Enter your choice: {NC}", end="", flush=True)

    try:
        choice = input().strip()
    except EOFError:
        choice = ""

    try:
        choice_num = int(choice)

        if 1 <= choice_num <= len(categories_list):
            download_category(
                categories_list[choice_num - 1],
                CATEGORIES[categories_list[choice_num - 1]],
            )
        elif choice_num == len(categories_list) + 1:
            for cat in categories_list:
                download_category(cat, CATEGORIES[cat])
        else:
            print(f"{YELLOW}⊘ Cancelled.{NC}")
    except (ValueError, IndexError):
        print(f"{YELLOW}⊘ Cancelled.{NC}")


def main():
    """Main function"""
    print_archeclipse_banner_text()
    print_figlet_lolcat("WALLPAPERS")

    display_wallpaper_table()
    show_choice_menu()


if __name__ == "__main__":
    main()
