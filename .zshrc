# Thin loader — real config lives in ~/.config/zsh/*.zsh (tracked in git).
# Machine-specific overrides go in ~/.config/zsh/custom/local.zsh (git-ignored).
for f in "$HOME/.config/zsh/"*.zsh(N); do
    source "$f"
done
unset f

# New custom location
[[ -f "$HOME/.config/zsh/custom/local.zsh" ]] && source "$HOME/.config/zsh/custom/local.zsh"
# Backwards compat with old location
[[ -f "$HOME/custom.zshrc" ]] && source "$HOME/custom.zshrc"
