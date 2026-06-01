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
    match = { class = "^(nwg-look|qt5ct|mpv|zoom|Rofi|feh)$" },
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
    match = { class = "^((.*)lutris(.*))$" },
    workspace = "7 silent",
})

hl.window_rule({
    match = { class = "^(steam_app_\\d+)$" },
    workspace = "10 silent",
})

hl.window_rule({
    match = { class = "^(.+\\.exe)$" },
    workspace = "10 silent",
})

hl.window_rule({
    match = { class = "^(Minecraft.*)$" },
    workspace = "10 silent",
})

hl.window_rule({
    match = { class = "^(steam_app_\\d+)$" },
    opacity = "1 override 1 override",
})

hl.window_rule({
    match = { class = "^(.+\\.exe)$" },
    opacity = "1 override 1 override",
})

hl.window_rule({
    match = { class = "^(Emulator)$" },
    opacity = "1 override 1 override",
})

hl.window_rule({
    match = { title = "Picture-in-Picture" },
    float = true,
})

hl.window_rule({
    match = { title = "Picture-in-Picture" },
    move = "100%-w-14 100%-w-7",
})

hl.window_rule({
    match = { title = "Picture-in-Picture" },
    pin = true,
})

hl.window_rule({
    match = { class = "preview-image" },
    float = true,
})

hl.window_rule({
    match = { class = "preview-image" },
    move = "cursor -50% -50%",
})

hl.window_rule({
    match = { title = "booru-image" },
    float = true,
})

hl.window_rule({
    match = { title = "booru-image" },
    move = "cursor -50% -50%",
})

hl.window_rule({
    match = { class = "^(grass)" },
    workspace = "9 silent",
})
