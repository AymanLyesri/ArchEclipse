-- phinger ships Xcursor only (no hyprcursor theme), so keep Hyprland on the
-- XCursor path: `hyprctl setcursor phinger-cursors-*` then loads the installed
-- theme from /usr/share/icons instead of a ~/.icons copy.
hl.config({
    cursor = {
        enable_hyprcursor = false,
    },
})
