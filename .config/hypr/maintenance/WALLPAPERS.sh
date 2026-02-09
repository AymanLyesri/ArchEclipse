#!/bin/bash
source $HOME/.config/hypr/maintenance/ESSENTIALS.sh # source the essentials file INSIDE the repository

# List of URLs
urls=(
    "https://cdn.donmai.us/original/bc/66/__dehya_genshin_impact_drawn_by_xude__bc66c4b2ab9ac2c0e4c62cb0e59e0cd0.jpg"
    "https://cdn.donmai.us/original/df/37/__eula_genshin_impact_drawn_by_swkl_d__df37376cf347fd5ba6fc397ec7a0e00b.jpg"
    "https://cdn.donmai.us/original/28/51/__eula_genshin_impact_drawn_by_the_what_sa__2851e14012f4bf512ac33fe8df2f2df1.jpg"
    "https://cdn.donmai.us/original/3e/d7/__herta_honkai_and_1_more_drawn_by_apple_caramel__3ed780454ec4e598c89e2b9920bc5c1c.jpg"
    "https://cdn.donmai.us/original/7c/56/__iori_and_iori_blue_archive_drawn_by_dizzen__7c56e7e702806ceaac863b9b0d210b17.png"
    "https://cdn.donmai.us/original/99/dd/__kamisato_ayaka_and_shenhe_genshin_impact_drawn_by_swkl_d__99dd0704eabf5d700f3e3d05f45a9300.jpg"
    "https://cdn.donmai.us/original/82/e1/__kazusa_blue_archive_drawn_by_uaxa2334__82e1237f9fc8f67adce6dc48061d54ad.jpg"
    "https://cdn.donmai.us/original/f6/c9/__kisaki_blue_archive_drawn_by_aoi_sakura_seak5545__f6c90df1f7da64b7591db4b59edd0657.jpg"
    "https://cdn.donmai.us/original/6c/83/__kisaki_blue_archive_drawn_by_chen_bingyou__6c83c49df1027e034b7ef3f0f73235a7.jpg"
    "https://cdn.donmai.us/original/d7/2e/__kita_ikuyo_bocchi_the_rock_drawn_by_bafangyu__d72eb163096c2eb4a544d362ed6603d8.jpg"
    "https://cdn.donmai.us/original/1f/3a/__lumine_genshin_impact_drawn_by_heitian_keji__1f3aebacc1ef15d910b1c0b3619d9b22.jpg"
    "https://cdn.donmai.us/original/28/16/__ningguang_and_ningguang_genshin_impact_drawn_by_w_q_y__28169aa1d42203051a2cf3b9e58dbbf0.jpg"
    "https://cdn.donmai.us/original/3c/c5/__original_drawn_by_datan_uu__3cc582513dcff139a485b2c793736c44.jpg"
    "https://cdn.donmai.us/original/e5/fc/__original_drawn_by_ping9137__e5fc9c7c37bb19008006759aea886e39.jpg"
    "https://cdn.donmai.us/original/2c/6f/__mizugaiya_original_drawn_by_proxyl__2c6f048f4e1786ccb7941d5367b9fcaf.png"
    "https://cdn.donmai.us/original/39/8d/__original_drawn_by_ribao__398db021670fbf4ca9b6843fef5171e9.png"
    "https://cdn.donmai.us/original/7b/33/__original_drawn_by_swkl_d__7b333431520df7632406ad70186671eb.jpg"
    "https://cdn.donmai.us/original/1b/1f/__original_drawn_by_tu_er_tm__1b1fabdc9969afff10e57a00bd8be84e.jpg"
    "https://cdn.donmai.us/original/41/ae/__original_drawn_by_tuweibu__41ae2e99e1d5e2443d7582b83e05ef48.jpg"
    "https://cdn.donmai.us/original/59/e2/__original_drawn_by_vikiye__59e227bae545a3074f8fb4128065a4d4.jpg"
    "https://cdn.donmai.us/original/0d/02/__rebecca_lucy_and_dorio_cyberpunk_and_1_more_drawn_by_feguimel__0d026f4ad56695ddb81e31f54337ea7a.jpg"
    "https://cdn.donmai.us/original/72/ae/__robin_honkai_and_1_more_drawn_by_swkl_d__72aeec3f718f00424689c5124f13563f.jpg"
    "https://cdn.donmai.us/original/19/ca/__shyrei_faolan_vedal987_pepe_the_frog_filian_layna_lazar_and_1_more_indie_virtual_youtuber_and_2_more_drawn_by_haedgie__19ca44fa28b99f7fcc265fa76a7840b5.jpg"
    "https://cdn.donmai.us/original/c5/df/__dusk_shu_nian_ling_nian_and_3_more_arknights_drawn_by_yamauchi_conan_comy__c5df4f9e6f6c3ad7044481e4016a8ff2.jpg"
    "https://cdn.donmai.us/original/6e/d8/__entelechia_arknights_drawn_by_fanfanfanlove__6ed8cba86b4c9f371a270a771b26291e.png"
    "https://cdn.donmai.us/original/c9/79/__hoshimi_miyabi_zenless_zone_zero_drawn_by_icecake__c9795356fb51ebac9fb543afd7380959.jpg"
    "https://cdn.donmai.us/original/5a/be/__napoli_and_napoli_azur_lane_drawn_by_shiran1024__5abe045d8800883566ec060b2f319395.jpg"
    "https://cdn.donmai.us/original/e2/83/__original_drawn_by_creamyghost__e28396e7cd44869472f742d25fb37d86.jpg"
    "https://cdn.donmai.us/original/c1/7b/__jinhsi_wuthering_waves_drawn_by_ceey__c17b00a9c413d75556e1ff8fdc82109e.jpg"
    "https://cdn.donmai.us/original/d7/36/__amiya_kal_tsit_theresa_and_amiya_arknights_and_1_more_drawn_by_lonki__d73672de44e20e5877592116ccccb73c.jpg"
    "https://cdn.donmai.us/original/62/4b/__rover_male_rover_and_cartethyia_wuthering_waves_drawn_by_jin_sumire__624b4bdf0074b1551ad3c8e9534892f4.jpg"
    "https://cdn.donmai.us/original/6b/b0/__lovely_labrynth_of_the_silver_castle_yu_gi_oh_drawn_by_ribao__6bb069c9a7f4b8a39e0b54a7901b2a81.jpg"
    "https://cdn.donmai.us/original/8b/16/__iuno_wuthering_waves_drawn_by_kryp132__8b16f466b4f3a18d119dd792121388e4.jpg"
    "https://cdn.donmai.us/original/7b/57/__warship_girls_r_drawn_by_tuweibu__7b5700be93c2158e2e3c35e7846d4a43.jpg"
    "https://cdn.donmai.us/original/59/55/__iuno_wuthering_waves_drawn_by_mian_tu_qiu__5955302450c9fe542416571af954c2a8.png"
    "https://cdn.donmai.us/original/e6/59/__ciel_kamitsubaki_studio_drawn_by_shirone_coxo_ii__e659fcfcb737cccce99c1f7ebdc34f2e.jpg"
    "https://cdn.donmai.us/original/5f/0f/__nimi_nightmare_and_naplings_indie_virtual_youtuber_drawn_by_greatodoggo__5f0fc1b6faec77b2f79efba5da92c737.png"
    "https://cdn.donmai.us/original/e5/39/__original_drawn_by_johnblack__e5391290da53bff7203cb4f21cbc4387.jpg"
    "https://cdn.donmai.us/original/0c/b9/__oshino_shinobu_monogatari_drawn_by_mika_pikazo__0cb93c971cdc7962d2aa8e313d76e649.jpg"
    "https://cdn.donmai.us/original/b3/f3/__yamamura_sadako_the_ring_drawn_by_esmile__b3f35e1cc8af78f3df37b3f28ec459ab.jpg"
    "https://cdn.donmai.us/original/d4/0b/__original_drawn_by_themaestronoob__d40b6c46fa83cbb615ed53e26c323f3a.jpg"
    "https://cdn.donmai.us/original/9c/7b/__drawn_by_esmile__9c7baa96bf9e9c166f2b3246e67b1cbd.jpg"
    "https://cdn.donmai.us/original/fb/e4/__kes_indie_virtual_youtuber_drawn_by_esmile__fbe4bf40812d3b36f9f8065cb186e6d6.jpg"
    "https://cdn.donmai.us/original/6a/c4/__heyimbee_indie_virtual_youtuber_drawn_by_peesh_san__6ac459163a7cc5a7434640911c9a44fc.png"
    "https://cdn.donmai.us/original/10/d3/__original_drawn_by_wangdaye__10d369ce4cc5794e673fd1fb4f076608.jpg"
    "https://cdn.donmai.us/original/88/0c/__pearl_azur_lane__880cddda6a37d061f3e40075ee54e20f.png"
    
)

wallpapers_total_size() {
    curl --parallel --parallel-immediate -sI "${urls[@]}" |
    grep -ioP 'Content-Length:\s*\K\d+' |
    awk '{s+=$1} END {print int(s/1024/1024) " MB"}'
}

download_wallpapers() {
    echo "Downloading wallpapers..."
    
    # Folder to save the images
    folder="$HOME/.config/wallpapers/defaults"
    mkdir -p "$folder"
    
    # Track filenames from URLs
    expected_files=()
    
    for url in "${urls[@]}"; do
        filename=$(basename "$url")
        expected_files+=("$filename")
        filepath="$folder/$filename"
        
        if [[ -f "$filepath" ]]; then
            echo "$filename already exists. Skipping download."
        else
            echo "Downloading $filename..."
            curl -L -o "$filepath" "$url"
        fi
    done
    
    # Cleanup files not in the list
    echo "Cleaning up files not in the list..."
    for file in "$folder"/*; do
        basename_file=$(basename "$file")
        if [[ ! " ${expected_files[*]} " =~ " $basename_file " ]]; then
            echo "Removing $basename_file"
            rm "$file"
        fi
    done
    
    echo "Done."
}

echo "Calculating total size of wallpapers..."

size=$(wallpapers_total_size)

continue_prompt "Do you want to install default wallpapers? (total size: $size)" download_wallpapers
