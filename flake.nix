{
  description = "j.moore personal toolchain";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    jj-domino.url = "github:zombiezen/jj-domino";
    interactive-nix-search.url = "github:omarjatoi/interactive-nix-search";
    # No stable channel yet. Not `follows` nixpkgs: the build is prebuilt
    # against its own pin.
    rex.url = "https://pkgs.superlogical.com/rex/nix/preview.tar.gz";
  };

  outputs = { nixpkgs, home-manager, rex, ... }@inputs: {
    # One config serves every host (devbox, Codespaces). Each host has its own
    # user and system, so home.nix reads them from the environment. Evaluate
    # with --impure.
    homeConfigurations.default = home-manager.lib.homeManagerConfiguration {
      pkgs = import nixpkgs {
        system = builtins.currentSystem;
        # claude-code is marked unfree (proprietary). Allow only it.
        config.allowUnfreePredicate = pkg:
          builtins.elem (nixpkgs.lib.getName pkg) [ "claude-code" ];
      };
      extraSpecialArgs = { inherit inputs; };
      modules = [
        rex.homeModules.default
        ./home.nix
      ];
    };
  };
}
