{
  description = "j.moore personal toolchain";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    jj-domino.url = "github:zombiezen/jj-domino";
    interactive-nix-search.url = "github:omarjatoi/interactive-nix-search";
    # Serena builds its Python env with uv2nix against its own pinned
    # nixpkgs. Do not `follows` our nixpkgs: the build carries per-package
    # overrides tied to that pin and breaks when the pin moves under it.
    serena.url = "github:oraios/serena";
  };

  outputs = { self, nixpkgs, flake-utils, jj-domino, interactive-nix-search, serena }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs {
          inherit system;
          # claude-code is marked unfree (proprietary). Allow only it.
          config.allowUnfreePredicate = pkg:
            builtins.elem (nixpkgs.lib.getName pkg) [ "claude-code" ];
        };
      in {
        packages.default = pkgs.buildEnv {
          name = "personal-tools";
          paths = with pkgs; [
            claude-code
            delta            # syntax-highlighting pager for diffs
            jq               # install.sh merges Claude Code settings with it
            jujutsu          # jj
            just
            tmux
            zellij
            starship
            jj-domino.packages.${system}.default
            interactive-nix-search.packages.${system}.default
            # Provides both `serena` and `serena-hooks`; install.sh wires
            # them into Claude Code.
            serena.packages.${system}.default
          ];
        };
      });
}
