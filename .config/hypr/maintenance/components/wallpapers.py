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
    "https://cdn.donmai.us/original/15/5f/__original_drawn_by_ichika_ichika87__155f5d20f012fe915a3213edd53b22ab.jpg",
    "https://cdn.donmai.us/original/fd/e0/__ninomae_ina_nis_hololive_and_1_more_drawn_by_aqby69__fde0698714dc6c06e87952a1ef329602.jpg",
    "https://cdn.donmai.us/original/60/c8/__narantuya_arknights_drawn_by_helen_zzhao__60c81c2ace0b77d39c2537d4182d430f.jpg",
    "https://cdn.donmai.us/original/08/d0/__luci_hexia_drawn_by_damcheong__08d0e1c429ef1d88c0cd274cb75cbf86.jpg",
    "https://cdn.donmai.us/original/40/57/__yoru_mitaka_asa_pochita_war_devil_and_bucky_chainsaw_man_drawn_by_eaechas__40574201912be4a9dec5589b3374350c.jpg",
    "https://cdn.donmai.us/original/f4/10/__yinlin_wuthering_waves_drawn_by_void_0__f4101f0f07a1b7cc65e545e90180881e.jpg",
    "https://cdn.donmai.us/original/15/d9/__lumine_genshin_impact_drawn_by_void_0__15d9d2028600be71e78ed10fdda8a37c.jpg",
    "https://cdn.donmai.us/original/86/cc/__columbina_genshin_impact_drawn_by_void_0__86cc14bd3da8a9578bff20e148c1e74a.jpg",
    "https://cdn.donmai.us/original/2e/35/__cartethyia_wuthering_waves_drawn_by_void_0__2e35f55f3eb0407853fe119418e4a57e.jpg",
    "https://cdn.donmai.us/original/a7/1a/__artoria_pendragon_and_saber_alter_fate_drawn_by_void_0__a71a1a801a7fb08dd7697018e484c58a.jpg",
    "https://cdn.donmai.us/original/64/f5/__shorekeeper_wuthering_waves_drawn_by_void_0__64f5d0531e563ffa6397a023d1e59415.jpg",
    "https://cdn.donmai.us/original/8b/6a/__chiori_genshin_impact_drawn_by_void_0__8b6aee8b720517f41c675fb49a0f02c1.jpg",
    "https://cdn.donmai.us/original/e6/59/__ciel_kamitsubaki_studio_drawn_by_shirone_coxo_ii__e659fcfcb737cccce99c1f7ebdc34f2e.jpg",
    "https://cdn.donmai.us/original/26/00/__lachesis_misty_original_drawn_by_swd3e2__2600cb6244c96cb8b021586e4fb11125.jpg",
    "https://cdn.donmai.us/original/8b/43/__original_drawn_by_void_0__8b433da3ef498514c37f51c75617566c.jpg",
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
    "https://cdn.donmai.us/original/41/ae/__original_drawn_by_tuweibu__41ae2e99e1d5e2443d7582b83e05ef48.jpg",
    "https://cdn.donmai.us/original/0d/02/__rebecca_lucy_and_dorio_cyberpunk_and_1_more_drawn_by_feguimel__0d026f4ad56695ddb81e31f54337ea7a.jpg",
    "https://cdn.donmai.us/original/72/ae/__robin_honkai_and_1_more_drawn_by_swkl_d__72aeec3f718f00424689c5124f13563f.jpg",
    "https://cdn.donmai.us/original/19/ca/__shyrei_faolan_vedal987_pepe_the_frog_filian_layna_lazar_and_1_more_indie_virtual_youtuber_and_2_more_drawn_by_haedgie__19ca44fa28b99f7fcc265fa76a7840b5.jpg",
    "https://cdn.donmai.us/original/c5/df/__dusk_shu_nian_ling_nian_and_3_more_arknights_drawn_by_yamauchi_conan_comy__c5df4f9e6f6c3ad7044481e4016a8ff2.jpg",
    "https://cdn.donmai.us/original/6e/d8/__entelechia_arknights_drawn_by_fanfanfanlove__6ed8cba86b4c9f371a270a771b26291e.png",
    "https://cdn.donmai.us/original/c9/79/__hoshimi_miyabi_zenless_zone_zero_drawn_by_icecake__c9795356fb51ebac9fb543afd7380959.jpg",
    "https://cdn.donmai.us/original/e2/83/__original_drawn_by_creamyghost__e28396e7cd44869472f742d25fb37d86.jpg",
    "https://cdn.donmai.us/original/c1/7b/__jinhsi_wuthering_waves_drawn_by_ceey__c17b00a9c413d75556e1ff8fdc82109e.jpg",
    "https://cdn.donmai.us/original/d7/36/__amiya_kal_tsit_theresa_and_amiya_arknights_and_1_more_drawn_by_lonki__d73672de44e20e5877592116ccccb73c.jpg",
    "https://cdn.donmai.us/original/62/4b/__rover_male_rover_and_cartethyia_wuthering_waves_drawn_by_jin_sumire__624b4bdf0074b1551ad3c8e9534892f4.jpg",
    "https://cdn.donmai.us/original/6b/b0/__lovely_labrynth_of_the_silver_castle_yu_gi_oh_drawn_by_ribao__6bb069c9a7f4b8a39e0b54a7901b2a81.jpg",
    "https://cdn.donmai.us/original/8b/16/__iuno_wuthering_waves_drawn_by_kryp132__8b16f466b4f3a18d119dd792121388e4.jpg",
    "https://cdn.donmai.us/original/7b/57/__warship_girls_r_drawn_by_tuweibu__7b5700be93c2158e2e3c35e7846d4a43.jpg",
    "https://cdn.donmai.us/original/59/55/__iuno_wuthering_waves_drawn_by_mian_tu_qiu__5955302450c9fe542416571af954c2a8.png",
    "https://cdn.donmai.us/original/5f/0f/__nimi_nightmare_and_naplings_indie_virtual_youtuber_drawn_by_greatodoggo__5f0fc1b6faec77b2f79efba5da92c737.png",
    "https://cdn.donmai.us/original/e5/39/__original_drawn_by_johnblack__e5391290da53bff7203cb4f21cbc4387.jpg",
    "https://cdn.donmai.us/original/0c/b9/__oshino_shinobu_monogatari_drawn_by_mika_pikazo__0cb93c971cdc7962d2aa8e313d76e649.jpg",
    "https://cdn.donmai.us/original/b3/f3/__yamamura_sadako_the_ring_drawn_by_esmile__b3f35e1cc8af78f3df37b3f28ec459ab.jpg",
    "https://cdn.donmai.us/original/d4/0b/__original_drawn_by_themaestronoob__d40b6c46fa83cbb615ed53e26c323f3a.jpg",
    "https://cdn.donmai.us/original/fb/e4/__kes_indie_virtual_youtuber_drawn_by_esmile__fbe4bf40812d3b36f9f8065cb186e6d6.jpg",
    "https://cdn.donmai.us/original/6a/c4/__heyimbee_indie_virtual_youtuber_drawn_by_peesh_san__6ac459163a7cc5a7434640911c9a44fc.png",
    "https://cdn.donmai.us/original/10/d3/__original_drawn_by_wangdaye__10d369ce4cc5794e673fd1fb4f076608.jpg",
    "https://cdn.donmai.us/original/0e/06/__original_drawn_by_obsidian117__0e060859dfc8adf7e41fc47b03ec078b.jpg",
    "https://cdn.donmai.us/original/1e/e5/__gawr_gura_hololive_and_1_more_drawn_by_champchidi__1ee57bae47cedc57a80de43b271b9f42.jpg",
    "https://cdn.donmai.us/original/79/e6/__original_drawn_by_bodhi_wushushenghua__79e67145283e7e11872ffbbb53036592.jpg",
    "https://cdn.donmai.us/original/99/60/__nagant_revolver_girls_frontline_drawn_by_shenqi_xiaohuang__99608b5d084e879c9d9d0bb33aec55f3.jpg",
    "https://cdn.donmai.us/original/4f/b8/__spas_12_tmp_sabrina_and_harpsy_girls_frontline_and_1_more_drawn_by_spencer_sais__4fb8aa4c1d9c037fc8d055424e6363e7.png",
    "https://cdn.donmai.us/original/d4/a3/__sonetto_reverse_1999_drawn_by_alvin2017uk__d4a3e0b75823127775ffe655fdfb4de4.jpg",
    "https://cdn.donmai.us/original/09/04/__mirko_and_shihouin_yoruichi_boku_no_hero_academia_and_2_more_drawn_by_themaestronoob__0904bb8f56b8e75629b23ac31e2f6246.jpg",
    "https://cdn.donmai.us/original/fb/ab/__nerissa_ravencroft_and_elizabeth_rose_bloodflame_hololive_and_1_more_drawn_by_daaku_koizumi_arata__fbab2a6ec8d5fdbbe438ee399bb6cd34.jpg",
    "https://cdn.donmai.us/original/a6/1f/__ninomae_ina_nis_hololive_and_1_more_drawn_by_floomf__a61ffe48ee3181d772274f9dc743a2e0.png",
    "https://cdn.donmai.us/original/17/82/__ninomae_ina_nis_and_takodachi_hololive_and_1_more_drawn_by_floomf__17827b7078f7d16405490fdcf8d97771.png",
    "https://cdn.donmai.us/original/d7/3a/__seed_zenless_zone_zero_drawn_by_elsynien__d73a77c5ac9c4873afa2b6afabbc0f16.jpg",
    "https://cdn.donmai.us/original/87/39/__original_drawn_by_luceat17__87399f74b4211bad73cc53c794cfb64b.jpg",
    "https://cdn.donmai.us/original/fb/52/__usada_pekora_don_chan_pekomama_and_pekomon_hololive_drawn_by_mumu_lin__fb52b9770f3213d26ba3e4be40e568f5.png",
    "https://cdn.donmai.us/original/a4/6b/__janus_azur_lane__a46b8942465098b4746c5991efdfdfe8.png",
    "https://cdn.donmai.us/original/58/57/__makima_chainsaw_man_drawn_by_izei1337__58577761e142e76c0da9263556e52283.jpg",
    "https://cdn.donmai.us/original/3c/77/__prinz_moritz_azur_lane__3c7795af9ae9b14715a33c33eb584651.png",
    "https://cdn.donmai.us/original/7f/82/__kuchiki_rukia_bleach_and_1_more_drawn_by_esmile__7f8202975e7ff266c5d3853adb48a31c.jpg",
    "https://cdn.donmai.us/original/41/34/__hakuhou_azur_lane_drawn_by_yunsang__41349e7a65cb2c05b04c22df5580a316.png",
    "https://cdn.donmai.us/original/c1/4c/__power_chainsaw_man_drawn_by_esmile__c14cf324d6644a3cc16910f84e005eae.jpg",
    "https://cdn.donmai.us/original/56/20/__gwen_irelia_galio_and_mythmaker_gwen_league_of_legends_drawn_by_shen_fan__5620a8c6ea0f208f5b89d65a6c39b418.jpg",
    "https://cdn.donmai.us/original/33/e0/__yoru_chainsaw_man_drawn_by_esmile__33e0af29457cad2eaa7716717e166b04.jpg",
    "https://cdn.donmai.us/original/8b/c8/__jill_warrick_final_fantasy_and_1_more_drawn_by_nyantcha__8bc8992eeb13ce24c66676b4c3b77829.jpg",
    "https://cdn.donmai.us/original/1d/10/__vienna_indie_virtual_youtuber_drawn_by_greatodoggo__1d10013ede8872c9ba8e362f0166a45a.png",
    "https://cdn.donmai.us/original/fd/b6/__kafka_honkai_and_1_more_drawn_by_nanjo_maya__fdb6c88123f159aa7e6b299b4262ea18.jpg",
    "https://cdn.donmai.us/original/0e/61/__rebecca_and_lucy_cyberpunk_and_2_more_drawn_by_bigroll__0e61533e2ad8c6571abf7d1ea0817ca5.jpg",
    "https://cdn.donmai.us/original/2b/31/__original_drawn_by_zzo0__2b317d7a4f1566f08a96943ae83a7f4d.png",
    "https://cdn.donmai.us/original/46/b9/__luluca_and_ocean_breeze_luluca_epic_seven_drawn_by_95_jiuwujiang__46b9c7f9a799919719de925d0595c85a.jpg",
    "https://cdn.donmai.us/original/69/75/__qingyi_zenless_zone_zero_drawn_by_far_side__6975d85262bad6bb74d6f08aff5cfd4d.jpg",
    "https://cdn.donmai.us/original/29/ee/__odette_genshin_impact_drawn_by_far_side__29eed0cc6d330e44c90adbba60e893ee.jpg",
    "https://cdn.donmai.us/original/f2/82/__belle_wise_ellen_joe_and_eous_zenless_zone_zero_drawn_by_sushispin__f2822332886f538e871b532bed4cf2ce.jpg",
    "https://cdn.donmai.us/original/3f/c7/__recluse_elden_ring_and_1_more_drawn_by_kirani__3fc7d3992a0c7d3014a61ab05f8c3a16.jpg",
    "https://cdn.donmai.us/original/29/f9/__ishtar_fate_and_1_more_drawn_by_yd_orange_maru__29f94173e825e9a19fed51028f583843.jpg",
    "https://cdn.donmai.us/original/03/b7/__seia_blue_archive_drawn_by_iranon_new_iranon__03b7e2380ee8725ea5fa09d7d0173437.jpg",
    "https://cdn.donmai.us/original/ef/73/__rio_blue_archive_drawn_by_yerim__ef73864bb89ed15ebb7d3b3313e04f64.png"
    "https://cdn.donmai.us/original/36/0b/__clorinde_genshin_impact_drawn_by_omone_hokoma_agm__360bdaf1943f22c0348e68c744bc614a.jpg",
    "https://cdn.donmai.us/original/aa/d7/__evelyn_chevalier_zenless_zone_zero_drawn_by_dysoor__aad7269805e42ff5bda7674ff96c1f7a.jpg",
    "https://cdn.donmai.us/original/6d/9c/__original_drawn_by_ogre_illustogre__6d9c00d4137c55102387465e7325592f.png",
    "https://cdn.donmai.us/original/76/d2/__yelan_genshin_impact_drawn_by_queasy_s__76d2df7080f4a3e2d96bb2b8e27d6c1e.png",
    "https://cdn.donmai.us/original/39/e7/__vei_vshojo_drawn_by_dyarikku__39e7f60261458bd057e60b60edd7784b.jpg",
    "https://cdn.donmai.us/original/62/1d/__ishtar_fate_and_1_more_drawn_by_bao_pixiv_99415611__621d71a2e6d36ad8424e638bca8f9238.jpg",
    "https://cdn.donmai.us/original/83/6a/__nayuta_goddess_of_victory_nikke_drawn_by_bao_pixiv_99415611__836a218f385eab00edaea7cc69d95afe.jpg",
    "https://cdn.donmai.us/original/74/1f/__2b_and_pod_nier_and_1_more_drawn_by_kajin_kajinman__741fcb653a14aeb3db906080091d55fb.jpg",
    "https://cdn.donmai.us/original/85/4b/__brest_azur_lane_drawn_by_yolanda__854bb1c71e05317287583199ec536201.jpg",
    "https://cdn.donmai.us/original/95/e4/__dusk_arknights_drawn_by_omone_hokoma_agm__95e438265a597f57c5e7878aea35017d.jpg",
    "https://cdn.donmai.us/original/3c/ed/__xilonen_genshin_impact_drawn_by_void_0__3ced6e28ec3bc14b4c69911032593b1c.jpg",
    "https://cdn.donmai.us/original/18/65/__tanacita_tansy_hermis_chion_and_eleanor_stella_limnos_drawn_by_naguanan__186580294296d21d60fceba4ba59358c.jpg",
    "https://cdn.donmai.us/original/5a/be/__napoli_azur_lane_drawn_by_shiran1024__5abe045d8800883566ec060b2f319395.jpg",
    "https://cdn.donmai.us/original/e8/a4/__hsin_wuthering_waves_drawn_by_hemeruss__e8a489b002cc38bdb28d386e09333569.jpg",
    "https://cdn.donmai.us/original/b1/06/__original_drawn_by_h_an_516635864__b1066c6158a9a66346ff63a67e5c971f.png",
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
    "https://cdn.donmai.us/original/5c/5f/5c5fdeda81aeaa0a1c50ba8dda24a232.webm",
    "https://cdn.donmai.us/original/ab/66/ab66f357dd3a68566342c5570be2f859.mp4",
    "https://cdn.donmai.us/original/52/2d/522dda62d17aea4ee84b10c00df247e5.mp4",
    "https://cdn.donmai.us/original/34/30/3430021ab0ef2233ecd7efd817de0b4e.mp4",
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
    "https://cdn.donmai.us/original/d7/f2/d7f2dc6cb4be818b67c35e2366f4cd69.mp4",
    "https://cdn.donmai.us/original/33/28/3328518dc5859617c18c4bd8f564e374.mp4",
    "https://cdn.donmai.us/original/08/00/0800c53d039287c4b67c07a205eb0417.mp4",
    "https://cdn.donmai.us/original/a8/f1/__ellin_meiji_and_lethe_rin_original_and_1_more_drawn_by_aduare__a8f132c769e2dffa511ffde6f58ec709.gif",
    "https://cdn.donmai.us/original/25/a5/25a55b5aba44c6b52cca92b714bb01d9.mp4",
    "https://cdn.donmai.us/sample/66/3b/sample-663b1ee63119e6ac073f22e8dbfa66e0.webm",
    "https://cdn.donmai.us/sample/0e/8f/sample-0e8ff9e5080896a1dd7a5abb2aba98a8.webm",
    "https://cdn.donmai.us/original/ab/66/ab66f357dd3a68566342c5570be2f859.mp4",
    "https://cdn.donmai.us/original/f0/16/f016fd83fc2944f4df99b98785b8a83a.mp4",
    "https://cdn.donmai.us/original/8d/b3/8db30161af571ddbdab42a2673649f7d.mp4",
    "https://cdn.donmai.us/original/bb/59/bb5986d16a4995e502522012fa7b4299.mp4",
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


def display_wallpaper_table() -> None:
    print(f"{BOLD}{CYAN}{'=' * 60}{NC}")
    print(f"{BOLD}{MAGENTA}WALLPAPER INSTALLATION MENU{NC}")
    print(f"{BOLD}{CYAN}{'=' * 60}{NC}")
    print("")

    total_count = 0

    print(f"{BOLD}{CYAN}{'CATEGORY':<14}{NC} {BOLD}{CYAN}{'COUNT':>7}{NC}")

    for category, var_name in CATEGORIES.items():
        urls = globals()[var_name]
        count = len(urls)

        total_count += count

        print(f"{category:<14} {count:>7}")

    print(f"{'TOTAL':<14} {total_count:>7}")
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


def _managed_folder(category: str) -> Path | None:
    """Resolve the folder for a category, or None if it must not be managed.

    Fail-closed guards: only the four known category directories under
    ~/.config/wallpapers/defaults are ever managed. Anything else —
    a wallhaven/ dir, a custom collection, a typo'd category, a path
    escaping the defaults tree — is refused outright.
    """
    if category not in CATEGORIES:
        print(f"Refusing to manage unknown category directory: {category}")
        return None

    base = Path.home() / ".config/wallpapers/defaults"
    folder = base / category
    try:
        folder.resolve().relative_to(base.resolve())
    except ValueError:
        print(f"Refusing to manage directory outside wallpapers/defaults: {folder}")
        return None
    return folder


def _download_category(category: str, urls: list[str]) -> None:
    if not urls:
        print(f"No wallpapers in {category}. Skipping...")
        return

    folder = _managed_folder(category)
    if folder is None:
        return
    folder.mkdir(parents=True, exist_ok=True)

    _normalize_existing_animated_files(folder, category)

    expected_files: list[str] = []
    downloaded = 0
    skipped = 0

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

    print("Quarantining unmanaged files (kept, not deleted)...")
    quarantine_dir = Path.home() / ".cache/archeclipse-wallpaper-quarantine" / category
    quarantined = 0
    for file in folder.iterdir():
        # Directories (wallhaven/, custom collections, anything else) and
        # symlinks are NEVER managed — only this category's own top-level
        # regular files are. User dirs are left completely alone.
        if file.is_symlink():
            print(f"Ignoring symlink: {file.name} (not managed)")
            continue
        if not file.is_file():
            print(f"Ignoring directory: {file.name}/ (not managed)")
            continue
        if file.name not in expected_files:
            # Never delete: the user may have added their own wallpapers
            # here. Move them aside so they survive re-runs.
            quarantine_dir.mkdir(parents=True, exist_ok=True)
            target = quarantine_dir / file.name
            if target.exists():
                print(f"Already quarantined: {file.name} (leaving in place)")
                continue
            print(f"Quarantining: {file.name} -> {target}")
            file.rename(target)
            quarantined += 1

    print(f"Category: {category}")
    print(f"Downloaded: {downloaded}")
    print(f"Skipped: {skipped}")
    print(f"Quarantined: {quarantined}")
    if quarantined:
        print(f"Your files were moved to {quarantine_dir} (not deleted).")
    print("")


def download_wallpapers(selected: Iterable[str]) -> None:
    print("Downloading wallpapers...")
    for category in selected:
        if category not in CATEGORIES:
            print(f"Skipping unknown category: {category}")
            continue
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
