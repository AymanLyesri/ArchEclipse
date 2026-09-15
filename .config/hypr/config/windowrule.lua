hl.window_rule({
    match = { class = "^(org.kde.polkit-kde-authentication-agent-1)$" },
    float = true,
})

hl.window_rule({
    match = { class = "^(nm-connection-editor|blueman-manager)$" },
    float = true,
})

hl.window_rule({
    match = { class = "^(swayimg|Viewnior|pavucontrol|org.pulseaudio.pavucontrol)$" },
    float = true,
})

hl.window_rule({
    match = { class = "^(nwg-look|mpv|zoom|Rofi|feh)$" },
    float = true,
})

hl.window_rule({
    match = { class = "^(Rofi|pavucontrol|blueman-manager)$" },
    pin = true,
})

hl.window_rule({
    match = { class = "^(Spotify)$" },
    workspace = "4 silent",
})

hl.window_rule({
    match = { class = "^(steam)$" },
    workspace = "7 silent",
})

hl.window_rule({
    match = { class = "^(.*lutris.*)$" },
    workspace = "7 silent",
})

hl.window_rule({
    match = { class = "^(steam_app_\\d+|.+\\.exe|Minecraft.*)$" },
    workspace = "10 silent",
})

hl.window_rule({
    match = { class = "^(steam_app_\\d+|.+\\.exe|Emulator)$" },
    opacity = "1 override 1 override",
})

hl.window_rule({
    match = { title = "Picture-in-Picture" },
    float = true,
    move = "100%-w-14 100%-h-7",
    pin = true,
})

hl.window_rule({
    match = { class = "preview-image" },
    float = true,
    move = "cursor -50% -50%",
})

hl.window_rule({
    match = { title = "booru-image" },
    float = true,
    move = "cursor -50% -50%",
})

hl.window_rule({
    match = { class = "^(grass)" },
    workspace = "9 silent",
})
