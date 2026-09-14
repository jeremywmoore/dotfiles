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
6. Wires Serena into Claude Code (see [Serena](#serena)).

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
- **`serena`** — pulled from upstream flake (`github:oraios/serena`), not
  nixpkgs. Its input does not `follows` our nixpkgs: Serena builds its
  Python env with uv2nix and carries overrides tied to its own pin.
- nixpkgs: `jujutsu` (jj), `just`, `tmux`, `zellij`, `starship`, `delta`,
  `jq`.

## Serena

[Serena](https://oraios.github.io/serena) gives Claude Code symbol-level
code navigation and editing through a language server, in place of reading
and grepping whole files.

Upstream installs it with `uv tool install serena-agent`. This repo uses
the flake Serena ships instead, so it upgrades with `just upgrade` like
every other tool and needs no separate Python toolchain.

The input tracks Serena's default branch, so `serena --version` reports a
`.dev` version rather than a release. `flake.lock` still pins an exact
commit; `just upgrade` is what moves it. To follow releases instead, pin
the input to a tag: `serena.url = "github:oraios/serena/v1.7.0"`.

`install.sh` step 6 creates `~/.serena/serena_config.yml` and registers the
MCP server at user scope, so it applies to every project:

```sh
claude mcp add --scope user serena -- \
  serena start-mcp-server --context claude-code --project-from-cwd
```

`--project-from-cwd` activates whatever directory Claude Code starts in.

### Per-project data

Serena keeps per-project data (a generated `project.yml`, memories, and a
language-server cache) in a `.serena/` folder. By default that folder goes
*inside* the project, where jj auto-tracks it into the next change. Step 6
redirects it to a central location instead:

```yaml
# ~/.serena/serena_config.yml
project_serena_folder_location: "$HOME/.serena/projects$projectDir"
```

The path is keyed on `$projectDir`, not the `$projectFolderName` that
upstream's example uses. Two checkouts of one repo share a folder name, so
`$projectFolderName` maps `/opt/ngrok` and `~/ngrok` to the same directory
and merges their caches and memories. `$projectDir` is absolute, so the
paths stay distinct:

```
/opt/ngrok  ->  ~/.serena/projects/opt/ngrok
~/ngrok     ->  ~/.serena/projects/home/j.moore/ngrok
```

Serena prefers an existing in-project `.serena/` over the configured path.
Delete a project's `.serena/` folder to move it to the central location.

Upstream intends the in-project layout: the `.serena/.gitignore` Serena
writes excludes only `cache` and `project.local.yml`, so `project.yml` and
`memories/` are meant to be committed and shared. Central storage trades
that away to keep other people's repos clean.

Verify with `/mcp` in Claude Code. `.zshrc` sets `MCP_TIMEOUT=60000`
because a cold start has to boot a language server.

### Counteracting Claude Code's tool bias

Claude Code's built-in tool descriptions bias the model towards its own
tools, so it often ignores Serena. Two mitigations:

- `claude-serena` (a `.zshrc` function) starts Claude Code with Serena's
  system prompt override. It replaces the default system prompt, so it is
  a separate command rather than a `claude` wrapper.
- Reminder hooks re-anchor the model on Serena and stop it drifting in
  long sessions. `install.sh` merges four of them into
  `~/.claude/settings.json`: `remind` and `auto-approve` on `PreToolUse`,
  `activate` on `SessionStart`, and `cleanup` on `SessionEnd`. The merge
  is idempotent and leaves the rest of the file alone. Delete the entries
  to opt out; `install.sh` only adds a hook it cannot already find.

`settings.json` is merged rather than symlinked from `home/`, because
Claude Code rewrites that file itself and would replace a symlink with a
plain file.

## Why this exists

Migrated off chezmoi + mise after running into layered cache-staleness
between mise's PATH manipulation, direnv-instant (per-directory env
cache), and VS Code Remote (frozen captured shell env). Nix's
content-addressed store paths and `flake.lock`-driven invalidation behave
correctly across all three. Full context:
<https://gist.github.com/jeremywmoore/6c5a3349d1fa79ab474343c9f0feeab9>
