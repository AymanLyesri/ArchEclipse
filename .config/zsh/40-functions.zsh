# Aliases for fastfetch
fastfetch_refresh() {
    clear
    $HOME/.config/fastfetch/fastfetch.sh
}
fastfetch_widget() {
    BUFFER="fastfetch_refresh"
    zle accept-line
}
zle -N fastfetch_widget
bindkey '^F' fastfetch_widget

TRAPUSR1() { # refresh fastfetch on signal
    fastfetch_refresh
}

# Aliase functions
function code() {
    /bin/code $1 && exit
}

# Configuration Update
archeclipse() {
    if [[ "$1" == "dev" ]]; then
        python3 <(curl -fsSL https://raw.githubusercontent.com/AymanLyesri/hyprland-conf/refs/heads/dev/.config/hypr/maintenance/update.py) dev
    else
        python3 <(curl -fsSL https://raw.githubusercontent.com/AymanLyesri/hyprland-conf/refs/heads/master/.config/hypr/maintenance/update.py)
    fi
}
