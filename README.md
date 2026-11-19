# dotfiles

Personal toolchain + config as one home-manager flake, set up via
`install.sh`. Public; no secrets.

## Install

```sh
git clone git@github.com:jeremywmoore/dotfiles.git ~/dotfiles
cd ~/dotfiles && ./install.sh
```

`install.sh`:

1. Sets the default login shell to `zsh` if it isn't already.
2. Installs Determinate Nix if `nix` isn't on PATH.
3. Starts `nix-daemon` if it's not running (containers without systemd).
4. Removes the `nix profile` entry that older installs made from this flake.
5. Runs `home-manager switch`, which installs the tools, links `home/`
   into `$HOME`, and starts the Rex server.

Idempotent — re-run safely after edits.

The config reads `$USER`, `$HOME`, the current system, and
`$DOTFILES_DIR` (the checkout) at evaluation time, so one config serves
every host. That needs `--impure`; `install.sh` and `just apply` pass it.

## Day-to-day

```sh
just            # show available recipes
just apply      # apply home.nix / flake.nix edits
just upgrade    # bump pins (flake.lock) and apply
just packages   # list every tool with its resolved version
just rollback   # activate the previous home-manager generation
just edit       # open home.nix in $EDITOR
```

Edit `home/<...>` files in place — home-manager links them to the
checkout, not the store, so `$HOME` edits are repo edits and need no
switch. A new file under `home/` needs `just apply` (and `git add`, since
flakes only see tracked files). Commit when ready. The starship prompt
shows a yellow `●` when there are uncommitted changes here.

## Layout

```
.
├── README.md
├── install.sh
├── justfile
├── flake.nix          # inputs + homeConfigurations.default
├── flake.lock
├── home.nix           # packages, home/ links, services
└── home/              # mirror of $HOME, linked in by home.nix
    ├── .zshrc
    └── .config/
        ├── jj/config.toml
        ├── starship.toml
        └── zellij/config.kdl
```

## What's installed

- **`claude-code`** — in nixpkgs, marked unfree, allowed via
  `allowUnfreePredicate` scoped to that one package.
- **`jj-domino`**, **`interactive-nix-search`** — pulled from their
  upstream flakes, not nixpkgs.
- **`rex`** — prebuilt flake from the vendor's `preview` channel (no
  `stable` channel yet). Keeps its own nixpkgs pin rather than following
  ours. Installed by its home-manager module; see below.
- nixpkgs: `jujutsu` (jj), `just`, `tmux`, `zellij`, `starship`, `delta`,
  `jq`.

## Rex server

On Linux, `services.rex` runs the Rex server as the `rex` systemd user
service. Hosts without a systemd user manager (most containers) get the
unit but don't start it. The module's SSH guard means home-manager owns
`~/.ssh/config`, so add hosts in `programs.ssh` rather than editing the
file.

The server stops at logout unless lingering is on:

```sh
loginctl enable-linger
```

`just apply` never restarts a running server, because a restart ends every
session. After an upgrade, run `systemctl --user restart rex`. Logs:
`journalctl --user -u rex`.

## Why this exists

Migrated off chezmoi + mise after running into layered cache-staleness
between mise's PATH manipulation, direnv-instant (per-directory env
cache), and VS Code Remote (frozen captured shell env). Nix's
content-addressed store paths and `flake.lock`-driven invalidation behave
correctly across all three. Full context:
<https://gist.github.com/jeremywmoore/6c5a3349d1fa79ab474343c9f0feeab9>
