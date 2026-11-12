(command cat ~/.cache/coloreclipse/sequences &)

eval "$(starship init zsh)"

# Deferred system info: prompt paints first, fastfetch prints right after.
# Skipped for nested shells / scripts / non-tty.
# Parent process is checked instead of $SHLVL: SHLVL counts every shell in the
# whole ancestry, so it was only 1 when foot itself was spawned by the
# compositor (SHLVL 0) — `foot` from a terminal (2) and from the app launcher
# (3; the bar starts through sh -c/flock -c layers) were silently skipped.
# foot execs the shell itself, so a fresh terminal shell always has a
# foot/footclient parent; nested shells have zsh/bash as their parent.
if [[ $(</proc/$PPID/comm) == foot* && -t 1 ]]; then
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