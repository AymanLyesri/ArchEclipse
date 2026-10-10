setopt INC_APPEND_HISTORY
setopt SHARE_HISTORY
setopt HIST_REDUCE_BLANKS
setopt HIST_VERIFY
setopt HIST_FIND_NO_DUPS
setopt HIST_IGNORE_ALL_DUPS
setopt HIST_SAVE_NO_DUPS

# History
HISTSIZE=2000             # Maximum events for internal history
SAVEHIST=2000             # Maximum events in history file
HISTDIR=~/.cache/zsh      # History directory
HISTFILE=$HISTDIR/history # History filepath
mkdir -p "$HISTDIR"       # Create history directory if it doesn't exist
touch "$HISTDIR/history"  # Create history file if it doesn't exist

# Zsh Tab Complete (-C skips the slow security stat-walk, ~28ms -> ~13ms)
autoload -U compinit
compinit -C

# Zsh Substring History Search
bindkey '^[[A' history-substring-search-up
bindkey '^[[B' history-substring-search-down
