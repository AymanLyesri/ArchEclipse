#!/usr/bin/env python3
"""Wallpaper downloader."""

from __future__ import annotations

import os
import re
import shutil
import sys
from pathlib import Path
from typing import Iterable

if __package__ in (None, ""):
    sys.path.append(str(Path(__file__).resolve().parent.parent))
    from components.utils import run_cmd, run_shell
else:
    from .utils import run_cmd, run_shell

BOLD = "\033[1m"
CYAN = "\033[0;36m"
GREEN = "\033[0;32m"
YELLOW = "\033[1;33m"
MAGENTA = "\033[0;35m"
RED = "\033[0;31m"
BLUE = "\033[0;34m"
NC = "\033[0m"


CATEGORIES = {
    "images_sfw": "urls_images_sfw",
    "images_nsfw": "urls_images_nsfw",
    "animated_sfw": "urls_animated_sfw",
    "animated_nsfw": "urls_animated_nsfw",
}

HOST_DEFAULT_EXT = {
    "motionbgs.com": "mp4",
}

urls_images_sfw = [
    "https://w.wallhaven.cc/full/qr/wallhaven-qrjq8l.png",
    "https://w.wallhaven.cc/full/zp/wallhaven-zpzv7j.jpg",
    "https://w.wallhaven.cc/full/po/wallhaven-polpoe.jpg",
    "https://w.wallhaven.cc/full/w5/wallhaven-w51kxr.jpg",
    "https://w.wallhaven.cc/full/5y/wallhaven-5y5dp3.jpg",
    "https://w.wallhaven.cc/full/5y/wallhaven-5yz968.jpg",
    "https://w.wallhaven.cc/full/d8/wallhaven-d8395l.jpg",
    "https://w.wallhaven.cc/full/yq/wallhaven-yq56jg.jpg",
    "https://cdn.donmai.us/original/6d/24/__cartethyia_and_fleurdelys_wuthering_waves_drawn_by_ryuutsuki_basetsu__6d24624379108e09c0746cf7b61ca09f.jpg",
    "https://cdn.donmai.us/original/ce/79/__gigi_murin_hololive_and_1_more_drawn_by_mazo_kunn__ce79dc4353279954ee6d54f0c3fb4650.jpg",
    "https://cdn.donmai.us/original/dd/26/__columbina_genshin_impact_drawn_by_tyhaya__dd26cadaa29efbdf29951905c1228e38.jpg",
    "https://cdn.donmai.us/original/f5/bd/__original_drawn_by_flantia__f5bd6abd01c8e2e36a84c8599fbef06a.jpg",
    "https://cdn.donmai.us/original/4f/76/__moonlit_reflection_and_sun_crows_descend_nikki_and_1_more_drawn_by_zangfoxzang__4f76dceceab3c4a26927d091e5f74ae0.jpg",
    "https://cdn.donmai.us/original/81/1f/__revenant_and_page_elden_ring_and_1_more_drawn_by_kwiaty_k__811f419d96b04c39cf9ce26d45cb2118.jpg",
    "https://cdn.donmai.us/original/59/e2/__original_drawn_by_vikiye__59e227bae545a3074f8fb4128065a4d4.jpg",
    "https://cdn.donmai.us/original/bd/70/__original_drawn_by_bodhi_wushushenghua__bd703bafcb56eb084528952720ae5611.jpg",
    "https://cdn.donmai.us/original/5f/94/__world_is_fleeting_as_foam_nikki_and_1_more_drawn_by_xxyt_xx__5f9486e7eac9a0da590f13a6cf45dab6.jpg",
    "https://cdn.donmai.us/original/2a/39/__guts_griffith_and_casca_neon_genesis_evangelion_and_2_more_drawn_by_spencer_sais__2a39d1e593cc0925ab32f4cca63854e7.png",
]

urls_images_nsfw = [
    "https://cdn.donmai.us/original/bc/66/__dehya_genshin_impact_drawn_by_xude__bc66c4b2ab9ac2c0e4c62cb0e59e0cd0.jpg",
    "https://cdn.donmai.us/original/df/37/__eula_genshin_impact_drawn_by_swkl_d__df37376cf347fd5ba6fc397ec7a0e00b.jpg",
    "https://cdn.donmai.us/original/28/51/__eula_genshin_impact_drawn_by_the_what_sa__2851e14012f4bf512ac33fe8df2f2df1.jpg",
    "https://cdn.donmai.us/original/3e/d7/__herta_honkai_and_1_more_drawn_by_apple_caramel__3ed780454ec4e598c89e2b9920bc5c1c.jpg",
    "https://cdn.donmai.us/original/7c/56/__iori_and_iori_blue_archive_drawn_by_dizzen__7c56e7e702806ceaac863b9b0d210b17.png",
    "https://cdn.donmai.us/original/99/dd/__kamisato_ayaka_and_shenhe_genshin_impact_drawn_by_swkl_d__99dd0704eabf5d700f3e3d05f45a9300.jpg",
    "https://cdn.donmai.us/original/82/e1/__kazusa_blue_archive_drawn_by_uaxa2334__82e1237f9fc8f67adce6dc48061d54ad.jpg",
    "https://cdn.donmai.us/original/f6/c9/__kisaki_blue_archive_drawn_by_aoi_sakura_seak5545__f6c90df1f7da64b7591db4b59edd0657.jpg",
    "https://cdn.donmai.us/original/6c/83/__kisaki_blue_archive_drawn_by_chen_bingyou__6c83c49df1027e034b7ef3f0f73235a7.jpg",
    "https://cdn.donmai.us/original/d7/2e/__kita_ikuyo_bocchi_the_rock_drawn_by_bafangyu__d72eb163096c2eb4a544d362ed6603d8.jpg",
    "https://cdn.donmai.us/original/1f/3a/__lumine_genshin_impact_drawn_by_heitian_keji__1f3aebacc1ef15d910b1c0b3619d9b22.jpg",
    "https://cdn.donmai.us/original/28/16/__ningguang_and_ningguang_genshin_impact_drawn_by_w_q_y__28169aa1d42203051a2cf3b9e58dbbf0.jpg",
    "https://cdn.donmai.us/original/3c/c5/__original_drawn_by_datan_uu__3cc582513dcff139a485b2c793736c44.jpg",
    "https://cdn.donmai.us/original/e5/fc/__original_drawn_by_ping9137__e5fc9c7c37bb19008006759aea886e39.jpg",
    "https://cdn.donmai.us/original/2c/6f/__mizugaiya_original_drawn_by_proxyl__2c6f048f4e1786ccb7941d5367b9fcaf.png",
    "https://cdn.donmai.us/original/39/8d/__original_drawn_by_ribao__398db021670fbf4ca9b6843fef5171e9.png",
    "https://cdn.donmai.us/original/7b/33/__original_drawn_by_swkl_d__7b333431520df7632406ad70186671eb.jpg",
    "https://cdn.donmai.us/original/1b/1f/__original_drawn_by_tu_er_tm__1b1fabdc9969afff10e57a00bd8be84e.jpg",
    "https://cdn.donmai.us/original/41/ae/__original_drawn_by_tuweibu__41ae2e99e1d5e2443d7582b83e05ef48.jpg",
    "https://cdn.donmai.us/original/0d/02/__rebecca_lucy_and_dorio_cyberpunk_and_1_more_drawn_by_feguimel__0d026f4ad56695ddb81e31f54337ea7a.jpg",
    "https://cdn.donmai.us/original/72/ae/__robin_honkai_and_1_more_drawn_by_swkl_d__72aeec3f718f00424689c5124f13563f.jpg",
    "https://cdn.donmai.us/original/19/ca/__shyrei_faolan_vedal987_pepe_the_frog_filian_layna_lazar_and_1_more_indie_virtual_youtuber_and_2_more_drawn_by_haedgie__19ca44fa28b99f7fcc265fa76a7840b5.jpg",
    "https://cdn.donmai.us/original/c5/df/__dusk_shu_nian_ling_nian_and_3_more_arknights_drawn_by_yamauchi_conan_comy__c5df4f9e6f6c3ad7044481e4016a8ff2.jpg",
    "https://cdn.donmai.us/original/6e/d8/__entelechia_arknights_drawn_by_fanfanfanlove__6ed8cba86b4c9f371a270a771b26291e.png",
    "https://cdn.donmai.us/original/c9/79/__hoshimi_miyabi_zenless_zone_zero_drawn_by_icecake__c9795356fb51ebac9fb543afd7380959.jpg",
    "https://cdn.donmai.us/original/5a/be/__napoli_and_napoli_azur_lane_drawn_by_shiran1024__5abe045d8800883566ec060b2f319395.jpg",
    "https://cdn.donmai.us/original/e2/83/__original_drawn_by_creamyghost__e28396e7cd44869472f742d25fb37d86.jpg",
    "https://cdn.donmai.us/original/c1/7b/__jinhsi_wuthering_waves_drawn_by_ceey__c17b00a9c413d75556e1ff8fdc82109e.jpg",
    "https://cdn.donmai.us/original/d7/36/__amiya_kal_tsit_theresa_and_amiya_arknights_and_1_more_drawn_by_lonki__d73672de44e20e5877592116ccccb73c.jpg",
    "https://cdn.donmai.us/original/62/4b/__rover_male_rover_and_cartethyia_wuthering_waves_drawn_by_jin_sumire__624b4bdf0074b1551ad3c8e9534892f4.jpg",
    "https://cdn.donmai.us/original/6b/b0/__lovely_labrynth_of_the_silver_castle_yu_gi_oh_drawn_by_ribao__6bb069c9a7f4b8a39e0b54a7901b2a81.jpg",
    "https://cdn.donmai.us/original/8b/16/__iuno_wuthering_waves_drawn_by_kryp132__8b16f466b4f3a18d119dd792121388e4.jpg",
    "https://cdn.donmai.us/original/7b/57/__warship_girls_r_drawn_by_tuweibu__7b5700be93c2158e2e3c35e7846d4a43.jpg",
    "https://cdn.donmai.us/original/59/55/__iuno_wuthering_waves_drawn_by_mian_tu_qiu__5955302450c9fe542416571af954c2a8.png",
    "https://cdn.donmai.us/original/e6/59/__ciel_kamitsubaki_studio_drawn_by_shirone_coxo_ii__e659fcfcb737cccce99c1f7ebdc34f2e.jpg",
    "https://cdn.donmai.us/original/5f/0f/__nimi_nightmare_and_naplings_indie_virtual_youtuber_drawn_by_greatodoggo__5f0fc1b6faec77b2f79efba5da92c737.png",
    "https://cdn.donmai.us/original/e5/39/__original_drawn_by_johnblack__e5391290da53bff7203cb4f21cbc4387.jpg",
    "https://cdn.donmai.us/original/0c/b9/__oshino_shinobu_monogatari_drawn_by_mika_pikazo__0cb93c971cdc7962d2aa8e313d76e649.jpg",
    "https://cdn.donmai.us/original/b3/f3/__yamamura_sadako_the_ring_drawn_by_esmile__b3f35e1cc8af78f3df37b3f28ec459ab.jpg",
    "https://cdn.donmai.us/original/d4/0b/__original_drawn_by_themaestronoob__d40b6c46fa83cbb615ed53e26c323f3a.jpg",
    "https://cdn.donmai.us/original/9c/7b/__drawn_by_esmile__9c7baa96bf9e9c166f2b3246e67b1cbd.jpg",
    "https://cdn.donmai.us/original/fb/e4/__kes_indie_virtual_youtuber_drawn_by_esmile__fbe4bf40812d3b36f9f8065cb186e6d6.jpg",
    "https://cdn.donmai.us/original/6a/c4/__heyimbee_indie_virtual_youtuber_drawn_by_peesh_san__6ac459163a7cc5a7434640911c9a44fc.png",
    "https://cdn.donmai.us/original/10/d3/__original_drawn_by_wangdaye__10d369ce4cc5794e673fd1fb4f076608.jpg",
    "https://cdn.donmai.us/original/be/1e/__kurokawa_akane_oshi_no_ko_drawn_by_esmile__be1e97721936d1b0c3e1c0a6aa749e94.jpg",
    "https://cdn.donmai.us/original/0e/06/__original_drawn_by_obsidian117__0e060859dfc8adf7e41fc47b03ec078b.jpg",
    "https://cdn.donmai.us/original/1e/e5/__gawr_gura_hololive_and_1_more_drawn_by_champchidi__1ee57bae47cedc57a80de43b271b9f42.jpg",
    "https://cdn.donmai.us/original/79/e6/__original_drawn_by_bodhi_wushushenghua__79e67145283e7e11872ffbbb53036592.jpg",
    "https://cdn.donmai.us/original/99/60/__nagant_revolver_girls_frontline_drawn_by_shenqi_xiaohuang__99608b5d084e879c9d9d0bb33aec55f3.jpg",
    "https://cdn.donmai.us/original/4f/b8/__spas_12_tmp_sabrina_and_harpsy_girls_frontline_and_1_more_drawn_by_spencer_sais__4fb8aa4c1d9c037fc8d055424e6363e7.png",
    "https://cdn.donmai.us/original/95/a8/__koseki_bijou_hololive_and_1_more_drawn_by_albreo__95a8b13bf7db1177b516f526698b740a.png",
    "https://cdn.donmai.us/original/d4/a3/__sonetto_reverse_1999_drawn_by_alvin2017uk__d4a3e0b75823127775ffe655fdfb4de4.jpg",
    "https://cdn.donmai.us/original/09/04/__mirko_and_shihouin_yoruichi_boku_no_hero_academia_and_2_more_drawn_by_themaestronoob__0904bb8f56b8e75629b23ac31e2f6246.jpg",
    "https://cdn.donmai.us/original/fb/ab/__nerissa_ravencroft_and_elizabeth_rose_bloodflame_hololive_and_1_more_drawn_by_daaku_koizumi_arata__fbab2a6ec8d5fdbbe438ee399bb6cd34.jpg",
    "https://cdn.donmai.us/original/b0/a1/__psylocke_luna_snow_and_jeff_the_land_shark_marvel_and_2_more_drawn_by_sciamano240__b0a1ae6b6a61ab051cbee96752e2ff92.png",
]

urls_animated_sfw = [
    "https://cdn.donmai.us/original/3e/1b/3e1b4d5d9c6cfb1dc6c623e15027852f.mp4",
    "https://motionbgs.com/dl/hd/8944",
    "https://motionbgs.com/dl/hd/9360",
    "https://motionbgs.com/dl/hd/9226",
    "https://motionbgs.com/dl/hd/9091",
    "https://motionbgs.com/dl/hd/8014",
    "https://motionbgs.com/dl/hd/8603",
    "https://motionbgs.com/dl/hd/7661",
    "https://motionbgs.com/dl/hd/7417",
]

urls_animated_nsfw = [
    "https://cdn.donmai.us/original/e9/5a/__meruccubus_original_drawn_by_merunyaa__e95a03b52164fbeac6ade8f075520b99.gif",
    "https://cdn.donmai.us/original/bc/c5/bcc54570d44b85514de5913bc650519c.mp4",
    "https://cdn.donmai.us/original/d9/a7/d9a7c2d2f4b3b1c602d29f713d9555a2.mp4",
    "https://cdn.donmai.us/original/66/90/__stella_original_drawn_by_flou_flou_art__6690ab6d2a4e25e034b23a1829241223.gif",
    "https://cdn.donmai.us/original/93/ed/93ed26b84107365858a27f7a6e3c0ac1.mp4",
    "https://cdn.donmai.us/original/cd/4d/cd4d33655b41919813b1cf9db1bebca2.mp4",
    "https://cdn.donmai.us/original/f1/8f/f18f81e79e8793eb1b0eae8162aebfc5.mp4",
    "https://cdn.donmai.us/sample/fb/f0/sample-fbf078a12eac875e2f6192754019a35f.webm",
    "https://cdn.donmai.us/sample/1d/a0/sample-1da07743622c41e353d1e610c487e711.webm",
    "https://cdn.donmai.us/original/87/94/879487139dcab2234a7e1cc95bfe3669.mp4",
    "https://cdn.donmai.us/original/d7/2f/d72f558193a787e698945493d76255fb.mp4",
    "https://cdn.donmai.us/sample/e7/2b/sample-e72b9cc52491048bc676f86653ea313e.webm",
    "https://cdn.donmai.us/original/44/6f/446f5828a683141696dccaedb777803a.mp4",
]


def _get_basename_from_url(url: str) -> str:
    without_query = url.split("?", maxsplit=1)[0]
    return os.path.basename(without_query)


def _get_host_from_url(url: str) -> str:
    match = re.match(r"^[a-zA-Z]+://([^/]+)", url)
    if not match:
        return ""
    return match.group(1).lower()


def _get_extension_hint_for_url(url: str, category: str) -> str:
    host = _get_host_from_url(url)
    if host in HOST_DEFAULT_EXT:
        return HOST_DEFAULT_EXT[host]
    if category.startswith("animated_"):
        return "mp4"
    return ""


def _resolve_download_filename(url: str, category: str) -> str:
    filename = _get_basename_from_url(url)
    if "." in filename:
        return filename
    hint_ext = _get_extension_hint_for_url(url, category)
    return f"{filename}.{hint_ext}" if hint_ext else filename


def _is_video_file(path: Path) -> bool:
    return (
        run_cmd(
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
                str(path),
            ],
            check=False,
        ).returncode
        == 0
    )


def _normalize_existing_animated_files(folder: Path, category: str) -> None:
    if not category.startswith("animated_"):
        return

    for file in folder.iterdir():
        if not file.is_file():
            continue
        if "." in file.name:
            continue
        if _is_video_file(file):
            renamed = file.with_suffix(".mp4")
            if not renamed.exists():
                file.rename(renamed)
                print(f"Renamed extension-less video: {file.name} -> {renamed.name}")


def _get_category_size(urls: Iterable[str]) -> int:
    if not urls:
        return 0

    result = run_cmd(
        ["curl", "--parallel", "--parallel-immediate", "-sI", *urls],
        capture_output=True,
        check=False,
    )
    sizes = re.findall(
        r"Content-Length:\s*(\d+)", result.stdout or "", flags=re.IGNORECASE
    )
    total = sum(int(value) for value in sizes)
    return int(total / 1024 / 1024)


def display_wallpaper_table() -> None:
    print(f"{BOLD}{CYAN}{'=' * 60}{NC}")
    print(f"{BOLD}{MAGENTA}WALLPAPER INSTALLATION MENU{NC}")
    print(f"{BOLD}{CYAN}{'=' * 60}{NC}")
    print("")

    print(f"{YELLOW}Calculating wallpaper sizes...{NC}")
    print("")

    total_count = 0
    total_size = 0

    print(
        f"{BOLD}{CYAN}{'CATEGORY':<14}{NC} {BOLD}{CYAN}{'COUNT':>7}{NC} {BOLD}{CYAN}{'SIZE (MB)':>12}{NC}"
    )

    for category, var_name in CATEGORIES.items():
        urls = globals()[var_name]
        count = len(urls)
        size = _get_category_size(urls)

        total_count += count
        total_size += size

        print(f"{category:<14} {count:>7} {size:>12} MB")

    print(f"{'TOTAL':<14} {total_count:>7} {total_size:>12} MB")
    print("")


def _convert_gif_to_mp4(input_path: Path) -> None:
    output_path = input_path.with_suffix(".mp4")

    if output_path.exists() and _is_video_file(output_path):
        input_path.unlink(missing_ok=True)
        return

    if not input_path.exists():
        print(f"Missing source GIF: {input_path.name}")
        return

    print(f"Converting GIF to MP4: {input_path.name}")

    run_cmd(
        [
            "ffmpeg",
            "-y",
            "-loglevel",
            "error",
            "-i",
            str(input_path),
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
            str(output_path),
        ],
        check=False,
    )

    if output_path.exists() and _is_video_file(output_path):
        input_path.unlink(missing_ok=True)
    else:
        output_path.unlink(missing_ok=True)
        print(f"Conversion failed: {input_path.name}")


def _download_category(category: str, urls: list[str]) -> None:
    if not urls:
        print(f"No wallpapers in {category}. Skipping...")
        return

    folder = Path.home() / ".config/wallpapers/defaults" / category
    folder.mkdir(parents=True, exist_ok=True)

    _normalize_existing_animated_files(folder, category)

    expected_files: list[str] = []
    downloaded = 0
    skipped = 0
    removed = 0

    for url in urls:
        filename = _resolve_download_filename(url, category)
        filepath = folder / filename

        if filename.lower().endswith(".gif"):
            converted_filename = f"{Path(filename).stem}.mp4"
            converted_filepath = folder / converted_filename
            expected_files.extend([filename, converted_filename])

            if converted_filepath.exists() and _is_video_file(converted_filepath):
                filepath.unlink(missing_ok=True)
                skipped += 1
                continue
        else:
            expected_files.append(filename)

        if filepath.exists():
            skipped += 1
            if filepath.suffix.lower() == ".gif":
                _convert_gif_to_mp4(filepath)
            continue

        print(f"Downloading: {filename}")
        result = run_cmd(["curl", "-L", "-o", str(filepath), url], check=False)
        if result.returncode == 0:
            downloaded += 1
            if filepath.suffix.lower() == ".gif":
                _convert_gif_to_mp4(filepath)
        else:
            print(f"Failed: {filename}")

    print("Cleaning up old files...")
    for file in folder.iterdir():
        if not file.is_file():
            continue
        if file.name not in expected_files:
            print(f"Removing: {file.name}")
            file.unlink()
            removed += 1

    print(f"Category: {category}")
    print(f"Downloaded: {downloaded}")
    print(f"Skipped: {skipped}")
    print(f"Removed: {removed}")
    print("")


def download_wallpapers(selected: Iterable[str]) -> None:
    print("Downloading wallpapers...")
    for category in selected:
        var_name = CATEGORIES[category]
        _download_category(category, globals()[var_name])
    print("Download complete.")


def show_choice_menu() -> None:
    print(f"{BOLD}{YELLOW}Select category:{NC}")
    print("")

    options = list(CATEGORIES.keys())
    for idx, category in enumerate(options, start=1):
        print(f"[{idx}] {category}")

    all_option = len(options) + 1
    cancel_option = len(options) + 2

    print(f"[{all_option}] ALL")
    print(f"[{cancel_option}] Cancel")
    print("")

    choice = input("Enter your choice: ").strip()

    if choice.isdigit():
        value = int(choice)
        if 1 <= value <= len(options):
            download_wallpapers([options[value - 1]])
            return
        if value == all_option:
            download_wallpapers(options)
            return

    print("Cancelled.")


def main() -> None:
    run_shell("echo ' ArchEclipse ' | lolcat", check=False)
    run_shell("figlet 'WALLPAPERS' -f slant | lolcat", check=False)
    display_wallpaper_table()
    show_choice_menu()


if __name__ == "__main__":
    main()
