function ne() {
  export NGROK_ENV="${1:-local}"
}

alias gitclean='git branch -d $(git branch --merged=main | grep -v main) && git fetch --prune'
alias fixssh='export SSH_AUTH_SOCK=$(ls -t /tmp/ssh-**/* | head -1)'
alias pp='tr ":" "\n" <<< "$PATH"'

# Strip stale mise install paths injected by parent processes — most
# commonly VS Code Remote's resolved shell env, captured at server
# startup and replayed into every terminal. Kept active even though
# mise is currently disabled below: the VS Code Server is long-lived
# and still hands out PATHs from when mise was active.
PATH=$(printf '%s' "$PATH" | tr ':' '\n' | grep -vE '/\.local/share/mise/installs/' | paste -sd:)

# --- mise activation (disabled) ---
# Tools migrated to ~/dotfiles/flake.nix → `nix profile install ~/dotfiles`.
# Re-enable everything below to switch back. See gist
# https://gist.github.com/jeremywmoore/6c5a3349d1fa79ab474343c9f0feeab9 for context.
#
# unset __MISE_ORIG_PATH
# eval "$(~/.local/bin/mise activate zsh)"
#
# # direnv-instant caches the resolved env per directory and won't notice
# # mise config changes that don't trigger an install (e.g. `mise use`,
# # manual edits to ~/.config/mise/config.toml). Watch config mtime and
# # nuke the cache when it changes so the next shell rebuilds against the
# # updated tool set. The mise [hooks].postinstall hook handles install /
# # upgrade; this complements it.
# __mise_invalidate_direnv_instant() {
#   emulate -L zsh
#   local mtime
#   mtime=$(stat -c %Y ~/.config/mise/config.toml 2>/dev/null) || return
#   if [[ -n "${__MISE_CONFIG_MTIME:-}" && "$mtime" != "$__MISE_CONFIG_MTIME" ]]; then
#     rm -rf ~/.cache/direnv-instant
#   fi
#   export __MISE_CONFIG_MTIME="$mtime"
# }
# autoload -Uz add-zsh-hook
# add-zsh-hook precmd __mise_invalidate_direnv_instant

eval "$(starship init zsh)"

source <(jj util completion zsh)
export ND_SSO_NO_BROWSER=true

eval "$(zellij setup --generate-auto-start zsh)"
setopt INTERACTIVE_COMMENTS
