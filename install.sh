#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"

# 1. Symlink home/* into $HOME — works even without nix; never blocks the rest.
find home -type f | while read -r src; do
  dest="$HOME/${src#home/}"
  mkdir -p "$(dirname "$dest")"
  ln -srfv "$PWD/$src" "$dest"
done

# 2. Set default shell to zsh if it isn't already.
zsh_path="$(command -v zsh 2>/dev/null || true)"
if [ -z "$zsh_path" ]; then
  echo "warning: zsh not found in PATH; default shell unchanged" >&2
elif [ "$(getent passwd "$USER" | cut -d: -f7)" != "$zsh_path" ]; then
  if ! grep -qxF "$zsh_path" /etc/shells 2>/dev/null; then
    echo "$zsh_path missing from /etc/shells; adding (sudo)…"
    echo "$zsh_path" | sudo tee -a /etc/shells >/dev/null
  fi
  # `chsh` (without sudo) authenticates the user via PAM and prompts for a
  # password — which is awkward on devboxes / Codespaces where the user has
  # passwordless sudo but no actual password. Run chsh as root targeting
  # the user explicitly to skip the PAM auth.
  if sudo chsh -s "$zsh_path" "$USER"; then
    echo "Default shell set to $zsh_path. Open a new login session to use it."
  else
    echo "warning: chsh failed; default shell unchanged" >&2
  fi
fi

# 3. Bootstrap nix if not present (Determinate Systems installer; --no-confirm
# for non-interactive boots like Codespaces dotfiles install).
if ! command -v nix >/dev/null 2>&1; then
  echo "nix not found — installing Determinate Nix…"
  curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix \
    | sh -s -- install --determinate --no-confirm
  # Source the daemon profile so nix is on PATH for the rest of this run.
  for f in /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh /etc/profile.d/nix.sh; do
    if [ -f "$f" ]; then
      # shellcheck source=/dev/null
      . "$f"
      break
    fi
  done
fi

# 4. Start nix-daemon if it isn't running. Containers without systemd
# (Codespaces, plain Docker) don't auto-start it, so `nix profile add`
# fails with "cannot connect to socket".
if command -v nix >/dev/null 2>&1 && ! nix store ping >/dev/null 2>&1; then
  if command -v nix-daemon >/dev/null 2>&1; then
    echo "Starting nix-daemon (no systemd — common in containers)…"
    sudo nix-daemon --daemon >/dev/null 2>&1 &
    for _ in 1 2 3 4 5; do
      [ -S /nix/var/nix/daemon-socket/socket ] && break
      sleep 1
    done
  fi
fi

# 5. (Re)install nix profile from the flake. Best-effort — print recovery
# guidance instead of aborting if the daemon still isn't reachable.
if command -v nix >/dev/null 2>&1; then
  nix profile remove dotfiles 2>/dev/null || true
  nix profile remove flake 2>/dev/null || true
  if ! nix profile add "$PWD/flake"; then
    echo "warning: 'nix profile add' failed." >&2
    echo "  If it's a daemon issue: sudo nix-daemon --daemon & ; nix profile add $PWD/flake" >&2
  fi
else
  echo "warning: nix not on PATH after install; open a fresh shell and re-run ./install.sh" >&2
fi
