# dotfiles

Personal toolchain (a nix flake) + config (symlinked from `home/`), set up
via `install.sh`. Public; no secrets.

## Install

```sh
git clone git@github.com:jeremywmoore/dotfiles.git ~/dotfiles
cd ~/dotfiles && ./install.sh
```

`install.sh`:

1. Symlinks every file under `home/` into the matching path in `$HOME`
   (relative symlinks, so the repo can be relocated).
2. Sets the default login shell to `zsh` if it isn't already.
3. Installs Determinate Nix if `nix` isn't on PATH.
4. Starts `nix-daemon` if it's not running (containers without systemd).
5. Installs the nix profile entry from this flake.
6. Applies the home-manager config (`home.nix`) on Linux hosts with a
   systemd user manager.

Idempotent — re-run safely after edits.

## Day-to-day

```sh
just            # show available recipes
just upgrade    # bump pins (flake.lock) and rebuild
just packages   # list every tool with its resolved version
just rollback   # revert to previous nix profile generation
just edit       # open flake.nix in $EDITOR
```

Edit `home/<...>` files in place — they're symlinked, so `$HOME` edits
are repo edits. Commit when ready. The starship prompt shows a yellow `●`
when there are uncommitted changes here.

## Layout

```
.
├── README.md
├── install.sh
├── justfile
├── flake.nix          # nix profile source
├── flake.lock
├── home.nix           # home-manager config (Rex server)
└── home/              # mirror of $HOME, symlinked in by install.sh
    ├── .zshrc
    └── .config/
        ├── jj/config.toml
        ├── starship.toml
        └── zellij/config.kdl
```

## What's in the flake

- **`claude-code`** — in nixpkgs, marked unfree, allowed via
  `allowUnfreePredicate` scoped to that one package.
- **`jj-domino`** — pulled from upstream flake
  (`github:zombiezen/jj-domino`), not nixpkgs.
- **`rex`** — prebuilt flake from the vendor's `preview` channel (no
  `stable` channel yet). Keeps its own nixpkgs pin rather than following
  ours. Installed through home-manager, not the buildEnv; see below.

## home-manager

`home.nix` holds only what needs a module: today, the Rex server as the
`rex` systemd user service. Tools stay in the buildEnv and plain dotfiles
stay in `home/`. home-manager owns `~/.ssh/config` (it carries the Rex
SSH guard), so add hosts in `programs.ssh` rather than editing the file.

The server stops at logout unless lingering is on:

```sh
loginctl enable-linger
```

`just apply` never restarts a running server, because a restart ends every
session. After an upgrade, run `systemctl --user restart rex`. Logs:
`journalctl --user -u rex`.
- nixpkgs: `jujutsu` (jj), `just`, `tmux`, `zellij`, `starship`, `delta`,
  `jq`.

## Why this exists

Migrated off chezmoi + mise after running into layered cache-staleness
between mise's PATH manipulation, direnv-instant (per-directory env
cache), and VS Code Remote (frozen captured shell env). Nix's
content-addressed store paths and `flake.lock`-driven invalidation behave
correctly across all three. Full context:
<https://gist.github.com/jeremywmoore/6c5a3349d1fa79ab474343c9f0feeab9>
