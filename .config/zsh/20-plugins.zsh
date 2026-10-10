source /usr/share/zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh                   # Autosuggestions for commands
source /usr/share/zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh           # Syntax Highlighting and colors
source /usr/share/zsh/plugins/zsh-history-substring-search/zsh-history-substring-search.zsh # Substring history search using up and down arrow keys
source /usr/share/zsh/plugins/zsh-sudo/sudo.plugin.zsh
source /usr/share/zsh/plugins/zsh-auto-notify/auto-notify.plugin.zsh
source /usr/share/zsh/plugins/fzf-tab-git/fzf-tab.plugin.zsh

# Zsh Auto-Suggestions
[[ -f ~/.cache/cwal/colors.sh ]] && source ~/.cache/cwal/colors.sh
ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE="fg=${color8:-#696969},bold"

# Set up fzf key bindings and fuzzy completion
source <(fzf --zsh)
