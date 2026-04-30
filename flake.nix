{
  description = "j.moore personal toolchain";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    jj-domino.url = "github:zombiezen/jj-domino";
    interactive-nix-search.url = "github:omarjatoi/interactive-nix-search";
  };

  outputs = { self, nixpkgs, flake-utils, jj-domino, interactive-nix-search }:
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
            jujutsu          # jj
            just
            tmux
            zellij
            starship
            jj-domino.packages.${system}.default
            interactive-nix-search.packages.${system}.default
          ];
        };
      });
}
