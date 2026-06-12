(cat ~/.cache/cwal/sequences &)

eval "$(starship init zsh)"

# fetch system information
$HOME/.config/fastfetch/fastfetch.sh

source /usr/share/zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh                   # Autosuggestions for commands
source /usr/share/zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh           # Syntax Highlighting and colors
source /usr/share/zsh/plugins/zsh-history-substring-search/zsh-history-substring-search.zsh # Substring history search using up and down arrow keys
source /usr/share/zsh/plugins/zsh-sudo/sudo.plugin.zsh
source /usr/share/zsh/plugins/zsh-auto-notify/auto-notify.plugin.zsh
source /usr/share/zsh/plugins/fzf-tab-git/fzf-tab.plugin.zsh

setopt INC_APPEND_HISTORY
setopt SHARE_HISTORY
setopt HIST_REDUCE_BLANKS
setopt HIST_VERIFY
setopt INC_APPEND_HISTORY
setopt SHARE_HISTORY
setopt HIST_FIND_NO_DUPS
setopt HIST_IGNORE_ALL_DUPS
setopt HIST_SAVE_NO_DUPS

#Zsh Auto-Suggestions
ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE="fg=#696969,bold"
HISTSIZE=2000             # Maximum events for internal history
SAVEHIST=2000             # Maximum events in history file
HISTDIR=~/.cache/zsh      # History directory
HISTFILE=$HISTDIR/history # History filepath
mkdir -p "$HISTDIR"       # Create history directory if it doesn't exist
touch "$HISTDIR/history"  # Create history file if it doesn't exist

# Zsh Tab Complete
autoload -U compinit
compinit

#Zsh Substring History Search
bindkey '^[[A' history-substring-search-up
bindkey '^[[B' history-substring-search-down

############################################################

# Aliases for ls
alias ls='lsd'

# Aliases for cat
alias cat='bat'

# Aliases for fastfetch
fastfetch_refresh() {
    clear
    $HOME/.config/fastfetch/fastfetch.sh
    if zle; then
        echo
        zle redisplay
    fi
}
alias f=fastfetch_refresh
zle -N fastfetch_refresh
bindkey '^F' fastfetch_refresh

TRAPUSR1() { # refresh fastfetch on signal
    fastfetch_refresh
}

# Aliase functions
function code() {
    /bin/code $1 && exit
}
function v() {
    /bin/neovide --fork $1 && exit
}

# Test Connection
alias quickspeed="python3 <(curl -fsSL https://raw.githubusercontent.com/AymanLyesri/quickspeed/refs/heads/master/quickspeed.py)"

# Aliases for neofetch
alias n=$NEOFETCH

# Aliases for logout
alias logout='hyprctl dispatch exit'

# Set up fzf key bindings and fuzzy completion
source <(fzf --zsh)

# Configuration Update
archeclipse() {
    if [[ "$1" == "dev" ]]; then
        python3 <(curl -fsSL https://raw.githubusercontent.com/AymanLyesri/hyprland-conf/refs/heads/dev/.config/hypr/maintenance/update.py) dev
    else
        python3 <(curl -fsSL https://raw.githubusercontent.com/AymanLyesri/hyprland-conf/refs/heads/master/.config/hypr/maintenance/update.py)
    fi
}

alias plugins="$HOME/.config/hypr/maintenance/components/plugins.py"

alias defaults="$HOME/.config/hypr/maintenance/components/defaults.py"

alias keyboard="$HOME/.config/hypr/maintenance/components/keyboard.py"

# Waifu Chat Bot and Assistant
alias waifu='source $HOME/linux-chat-bot/main.sh "$(pwd)"'

# Wallpapers
alias wallpapers="$HOME/.config/hypr/maintenance/components/wallpapers.py"

# Custom Zsh config
[[ -f "$HOME/custom.zshrc" ]] && source "$HOME/custom.zshrc"

###REACT NATIVE SETUP (android studio) comment if u don't use react native
# export ANDROID_HOME=$HOME/Android/Sdk
# export PATH=$PATH:$ANDROID_HOME/emulator
# export PATH=$PATH:$ANDROID_HOME/platform-tools
############################################################
