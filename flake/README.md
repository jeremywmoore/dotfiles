# dotfiles

Personal toolchain managed as a nix flake, installed via `nix profile`.

## TL;DR

```sh
just            # show available recipes
just upgrade    # bump pins and rebuild
just rollback   # revert to previous generation
just edit       # edit flake.nix
```

First-time install is handled by the repo's root `install.sh` (which symlinks
`home/*` into `$HOME` and runs `nix profile install ~/dotfiles/flake`). To
install just this flake without the full dotfiles bootstrap:

```sh
nix profile install ~/dotfiles/flake
```

## Adding / removing a tool

Edit `flake.nix` (`just edit`) → `paths` list → `just apply`.

`apply` reuses current `flake.lock` pins; use `upgrade` when you want
fresh upstream versions.

## Notes on what's here

- **`claude-code`** — in nixpkgs but marked unfree, allowed via
  `allowUnfreePredicate` scoped to that one package.
- **`jj-domino`** — pulled from its upstream flake
  (`github:zombiezen/jj-domino`), not nixpkgs.
- **`jj-stack`** — intentionally absent; redundant with `jj-domino`.

## Why this exists

Migrated off mise after hitting layered cache-staleness between mise's PATH
manipulation, direnv-instant (per-directory env cache), and VS Code Remote
(frozen captured shell env). Nix's content-addressed store paths and
`flake.lock`-driven invalidation behave correctly across all three.

The `~/.zshrc` PATH scrub remains active to strip stale mise install paths
that VS Code Server keeps replaying until it's restarted. Full context:
https://gist.github.com/jeremywmoore/6c5a3349d1fa79ab474343c9f0feeab9
