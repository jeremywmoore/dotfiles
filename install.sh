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
elif [ "$(getent passwd "${USER:-$(id -un)}" | cut -d: -f7)" != "$zsh_path" ]; then
  if ! grep -qxF "$zsh_path" /etc/shells 2>/dev/null; then
    echo "$zsh_path missing from /etc/shells; adding (sudo)…"
    echo "$zsh_path" | sudo tee -a /etc/shells >/dev/null
  fi
  # `chsh` (without sudo) authenticates the user via PAM and prompts for a
  # password — which is awkward on devboxes / Codespaces where the user has
  # passwordless sudo but no actual password. Run chsh as root targeting
  # the user explicitly to skip the PAM auth.
  if sudo chsh -s "$zsh_path" "${USER:-$(id -un)}"; then
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
  # Resolve the full path: nix-daemon usually isn't on root's PATH (it
  # lives under /nix/var/nix/profiles/default/bin), and sudo searches its
  # own PATH unless given an absolute path.
  nix_daemon_path="$(command -v nix-daemon 2>/dev/null || true)"
  if [ -n "$nix_daemon_path" ]; then
    echo "Starting nix-daemon in background (no systemd — common in containers)…"
    nix_daemon_log=/tmp/nix-daemon.log
    sudo -b sh -c "$nix_daemon_path >$nix_daemon_log 2>&1"
    # Poll up to 10s for the socket to appear.
    for _ in 1 2 3 4 5 6 7 8 9 10; do
      [ -S /nix/var/nix/daemon-socket/socket ] && break
      sleep 1
    done
    if ! nix store ping >/dev/null 2>&1; then
      echo "  warning: nix-daemon didn't come up. Last 20 lines of $nix_daemon_log:" >&2
      tail -20 "$nix_daemon_log" >&2 || true
    fi
  fi
fi

# 5. (Re)install nix profile from the flake. Best-effort — print recovery
# guidance instead of aborting if the daemon still isn't reachable.
if command -v nix >/dev/null 2>&1; then
  nix profile remove dotfiles 2>/dev/null || true
  nix profile remove flake 2>/dev/null || true
  if ! nix profile add "$PWD"; then
    echo "warning: 'nix profile add' failed." >&2
    echo "  If it's a daemon issue: sudo nix-daemon & ; nix profile add $PWD" >&2
  fi
else
  echo "warning: nix not on PATH after install; open a fresh shell and re-run ./install.sh" >&2
fi

# 6. Wire Serena into Claude Code. This runs after step 5 because step 5 is
# what puts `serena`, `serena-hooks`, and `jq` on PATH.
if command -v serena >/dev/null 2>&1 && command -v claude >/dev/null 2>&1; then
  # 6a. Global Serena config. `serena init` rewrites the whole file, so only
  # create it when it is missing; re-running would discard hand edits.
  [ -f "$HOME/.serena/serena_config.yml" ] || serena init

  # 6b. Register at user scope so every project gets the server.
  # --project-from-cwd activates whatever directory Claude Code starts in.
  # `claude mcp add` fails on a duplicate name, hence the guard.
  if ! claude mcp get serena >/dev/null 2>&1; then
    claude mcp add --scope user serena -- \
      serena start-mcp-server --context claude-code --project-from-cwd
  fi

  # 6c. Keep per-project Serena data out of the projects themselves. By
  # default Serena writes a .serena/ directory into every repo it activates,
  # which jj auto-tracks into the next change. Key the central path on
  # $projectDir, not $projectFolderName: two checkouts of the same repo share
  # a folder name, and would then share one cache and one set of memories.
  serena_config="$HOME/.serena/serena_config.yml"
  serena_folder="$HOME"'/.serena/projects$projectDir'
  if [ -f "$serena_config" ]; then
    if grep -q '^project_serena_folder_location:' "$serena_config"; then
      sed -i "s|^project_serena_folder_location:.*|project_serena_folder_location: \"$serena_folder\"|" "$serena_config"
    else
      printf '\nproject_serena_folder_location: "%s"\n' "$serena_folder" >>"$serena_config"
    fi
  fi

  # 6d. Reminder hooks. Claude Code's built-in tool descriptions bias the
  # model towards its own tools, and it drifts in long sessions. These hooks
  # re-anchor it on Serena and auto-approve Serena calls in permissive
  # permission modes. They are merged with jq rather than symlinked from
  # home/: Claude Code writes settings.json itself (/model, plugin installs)
  # and an atomic rewrite would replace a symlink with a plain file.
  settings="$HOME/.claude/settings.json"
  mkdir -p "$(dirname "$settings")"
  [ -f "$settings" ] || echo '{}' >"$settings"
  if command -v jq >/dev/null 2>&1; then
    serena_hooks_tmp="$(mktemp)"
    if jq '
      def ensure($event; $matcher; $cmd):
        if any((.hooks[$event] // [])[]; any(.hooks[]?; .command == $cmd))
        then .
        else .hooks[$event] = ((.hooks[$event] // []) +
          [{matcher: $matcher, hooks: [{type: "command", command: $cmd}]}])
        end;
      ensure("PreToolUse"; ""; "serena-hooks remind --client=claude-code")
      | ensure("PreToolUse"; "mcp__serena__*"; "serena-hooks auto-approve --client=claude-code")
      | ensure("SessionStart"; ""; "serena-hooks activate --client=claude-code")
      | ensure("SessionEnd"; ""; "serena-hooks cleanup --client=claude-code")
    ' "$settings" >"$serena_hooks_tmp"; then
      # Copy through instead of `mv`, to keep the file's permissions and to
      # write through a symlink rather than replacing one.
      cat "$serena_hooks_tmp" >"$settings"
      echo "Serena hooks present in $settings"
    else
      echo "warning: could not merge Serena hooks into $settings" >&2
    fi
    rm -f "$serena_hooks_tmp"
  else
    echo "warning: jq not on PATH; skipped Serena hooks in $settings" >&2
  fi
else
  echo "warning: serena or claude not on PATH; skipped Serena setup" >&2
fi
