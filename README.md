# dotfiles

Personal toolchain + config, set up via symlinks from `home/` into `$HOME`
and a nix profile installed from `flake/`.

## Install

```sh
git clone git@github.com:jeremywmoore/dotfiles.git ~/dotfiles
cd ~/dotfiles && ./install.sh
```

`install.sh`:

1. Installs Determinate Nix if `nix` isn't on PATH (interactive — re-run
   afterward).
2. Symlinks every file under `home/` into the matching path in `$HOME`
   (relative symlinks, so the repo can be relocated).
3. (Re)installs the nix profile entry from `flake/`.
4. Sets the default login shell to `zsh` if it isn't already.

## Layout

```
.
├── install.sh
├── flake/             # nix profile source — see flake/README.md
└── home/              # mirror of $HOME, symlinked in by install.sh
    ├── .zshrc
    └── .config/
        ├── jj/config.toml
        ├── starship.toml
        └── zellij/config.kdl
```

## Day-to-day

- **Tools** (jj, claude, tmux, zellij, starship, just, jj-domino) → managed
  via the flake. From `flake/` run `just` to see recipes (`just upgrade`,
  `just packages`, etc.). See [`flake/README.md`](./flake/README.md).
- **Config files** → edit them in place. Because they're symlinks, edits in
  `$HOME` *are* edits in this repo. Commit when ready. The starship prompt
  shows a yellow `●` when there are uncommitted changes here.
