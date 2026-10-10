(cat ~/.cache/cwal/sequences &)

eval "$(starship init zsh)"

# Deferred system info: prompt paints first, fastfetch prints right after.
# Skipped for nested shells / scripts / non-tty.
if [[ $SHLVL -eq 1 && -t 1 ]]; then
  _fastfetch_deferred() {
    $HOME/.config/fastfetch/fastfetch.sh
    zle && zle reset-prompt
  }
  if zmodload zsh/sched 2>/dev/null; then
    sched +0 _fastfetch_deferred
  else
    $HOME/.config/fastfetch/fastfetch.sh
  fi
fi