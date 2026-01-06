(cat ~/.cache/wal/sequences &)

# Add local bin to PATH (for claude, npm global, etc.)
export PATH="$HOME/.local/bin:$PATH"

eval "$(starship init zsh)"

# fetch system information
$HOME/.config/fastfetch/fastfetch.sh

source /usr/share/zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh                   # Autosuggestions for commands
source /usr/share/zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh           # Syntax Highlighting and colors
source /usr/share/zsh/plugins/zsh-history-substring-search/zsh-history-substring-search.zsh # Substring history search using up and down arrow keys
source /usr/share/zsh/plugins/zsh-sudo/sudo.plugin.zsh
source /usr/share/zsh/plugins/zsh-auto-notify/auto-notify.plugin.zsh
source /usr/share/zsh/plugins/fzf-tab-git/fzf-tab.plugin.zsh

#Zsh Auto-Suggestions
ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE="fg=#696969,bold"
HISTSIZE=1000             # Maximum events for internal history
SAVEHIST=1000             # Maximum events in history file
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

# # Informative Prompt
# echo "Ctrl+F => fastfetch / clear"

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
TEST_CONNECTION="$HOME/.config/hypr/scripts/test-connection.sh"
alias conn=$TEST_CONNECTION

# Aliases for neofetch
alias n=$NEOFETCH

# Aliases for logout
alias logout='hyprctl dispatch exit'

# Set up fzf key bindings and fuzzy completion
source <(fzf --zsh)

# Configuration Update (usando scripts locales del fork)
alias update='~/.config/hypr/maintenance/UPDATE.sh'
alias update-all='~/.config/hypr/maintenance/UPDATE.sh --all'
alias update-quick='~/.config/hypr/maintenance/UPDATE.sh --quick'

alias defaults="$HOME/.config/hypr/maintenance/DEFAULTS.sh"

# Waifu Chat Bot and Assistant
alias waifu='source $HOME/linux-chat-bot/main.sh "$(pwd)"'

# Custom Zsh config
[[ -f "$HOME/custom.zshrc" ]] && source "$HOME/custom.zshrc"

###REACT NATIVE SETUP (android studio) comment if u don't use react native
export ANDROID_HOME=$HOME/Android/Sdk
export PATH=$PATH:$ANDROID_HOME/emulator
export PATH=$PATH:$ANDROID_HOME/platform-tools
############################################################