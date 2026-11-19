{
  description = "j.moore personal toolchain";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    jj-domino.url = "github:zombiezen/jj-domino";
    interactive-nix-search.url = "github:omarjatoi/interactive-nix-search";
    # No stable channel yet. Not `follows` nixpkgs: the build is prebuilt
    # against its own pin.
    rex.url = "https://pkgs.superlogical.com/rex/nix/preview.tar.gz";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, flake-utils, jj-domino, interactive-nix-search, rex, home-manager }:
    (flake-utils.lib.eachDefaultSystem (system:
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
            jq
            jujutsu          # jj
            just
            tmux
            zellij
            starship
            jj-domino.packages.${system}.default
            interactive-nix-search.packages.${system}.default
          ];
        };
      }))
    // {
      # The Rex server runs as a systemd user service, so this is Linux only.
      homeConfigurations."j.moore" = home-manager.lib.homeManagerConfiguration {
        pkgs = nixpkgs.legacyPackages.x86_64-linux;
        modules = [
          rex.homeModules.default
          ./home.nix
        ];
      };
    };
}
