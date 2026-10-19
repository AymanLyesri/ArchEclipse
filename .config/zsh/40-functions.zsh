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

_coloreclipse_refresh_colors() {
    local colors="$HOME/.cache/coloreclipse/colors.sh"
    local sequences="$HOME/.cache/coloreclipse/sequences"
    local colors_mtime sequences_mtime

    [[ -r "$colors" && -r "$sequences" ]] || return
    zmodload -F zsh/stat b:zstat 2>/dev/null || return
    colors_mtime=$(zstat -L +mtime -- "$colors" 2>/dev/null) || return
    sequences_mtime=$(zstat -L +mtime -- "$sequences" 2>/dev/null) || return
    [[ "$colors_mtime:$sequences_mtime" == "$_COLORECLIPSE_COLOR_MTIME" ]] && return

    source "$colors"
    command cat "$sequences"
    _COLORECLIPSE_COLOR_MTIME="$colors_mtime:$sequences_mtime"
}

precmd() {
    _coloreclipse_refresh_colors
}

_coloreclipse_watch_colors() {
    local sequences="$HOME/.cache/coloreclipse/sequences"
    local last_mtime="" mtime

    # exit when the parent shell dies, else disowned forks leak as orphans
    while kill -0 $PPID 2>/dev/null && [[ -r "$sequences" ]]; do
        zmodload -F zsh/stat b:zstat 2>/dev/null || return
        mtime=$(zstat -L +mtime -- "$sequences" 2>/dev/null) || return
        if [[ -n "$last_mtime" && "$mtime" != "$last_mtime" ]]; then
            command cat "$sequences"
        fi
        last_mtime="$mtime"
        sleep 0.2
    done
}

if [[ -o interactive && -t 1 && -z "${_COLORECLIPSE_WATCHER_STARTED-}" ]]; then
    typeset -g _COLORECLIPSE_WATCHER_STARTED=1
    _coloreclipse_watch_colors &!
fi

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
