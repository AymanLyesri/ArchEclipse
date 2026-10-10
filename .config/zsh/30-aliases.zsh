# Aliases for ls
alias ls='lsd'

# Aliases for cat
alias cat='bat'

# Aliases for fastfetch
alias f=fastfetch_refresh

# Aliases for neofetch
alias n=$NEOFETCH

# Aliases for logout
alias logout='hyprctl dispatch exit'

# Test Connection
alias quickspeed="python3 <(curl -fsSL https://raw.githubusercontent.com/AymanLyesri/quickspeed/refs/heads/master/quickspeed.py)"

alias plugins="$HOME/.config/hypr/maintenance/components/plugins.py"

alias defaults="$HOME/.config/hypr/maintenance/components/defaults.py"

alias keyboard="$HOME/.config/hypr/maintenance/components/keyboard.py"

# Waifu Chat Bot and Assistant
alias waifu='source $HOME/linux-chat-bot/main.sh "$(pwd)"'

# Wallpapers
alias wallpapers="$HOME/.config/hypr/maintenance/components/wallpapers.py"
