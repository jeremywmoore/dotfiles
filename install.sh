#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"

# Bootstrap nix if not present (Determinate Systems installer; --determinate
# flag pulls Determinate Nix specifically). Interactive — prompts for sudo.
if ! command -v nix >/dev/null 2>&1; then
  echo "nix not found — installing Determinate Nix…"
  curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix \
    | sh -s -- install --determinate
  echo "Nix installed. Open a new shell and re-run ./install.sh to finish."
  exit 0
fi

# Symlink home/* into $HOME (relative symlinks survive repo relocation)
find home -type f | while read -r src; do
  dest="$HOME/${src#home/}"
  mkdir -p "$(dirname "$dest")"
  ln -srfv "$PWD/$src" "$dest"
done

# (Re)install nix profile from the flake
nix profile remove dotfiles 2>/dev/null || true
nix profile remove flake 2>/dev/null || true
nix profile install "$PWD/flake"

# Set default shell to zsh if it isn't already.
zsh_path="$(command -v zsh 2>/dev/null || true)"
if [ -z "$zsh_path" ]; then
  echo "warning: zsh not found in PATH; default shell unchanged" >&2
elif [ "$(getent passwd "$USER" | cut -d: -f7)" != "$zsh_path" ]; then
  if ! grep -qxF "$zsh_path" /etc/shells 2>/dev/null; then
    echo "$zsh_path missing from /etc/shells; adding (sudo)…"
    echo "$zsh_path" | sudo tee -a /etc/shells >/dev/null
  fi
  chsh -s "$zsh_path"
  echo "Default shell set to $zsh_path. Open a new login session for it to take effect."
fi
