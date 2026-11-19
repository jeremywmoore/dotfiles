{ config, lib, pkgs, inputs, ... }:
let
  inherit (pkgs.stdenv.hostPlatform) system;

  # Links point at the checkout, not the store, so edits in $HOME are repo
  # edits and take effect without a switch.
  dotfiles = builtins.getEnv "DOTFILES_DIR";
  homeSrc = ./home;
  homeFiles = map
    (f: lib.removePrefix "${toString homeSrc}/" (toString f))
    (lib.filesystem.listFilesRecursive homeSrc);
in
{
  assertions = [{
    assertion = dotfiles != "";
    message = "Set DOTFILES_DIR to the checkout. install.sh and `just apply` set it.";
  }];

  home.username = builtins.getEnv "USER";
  home.homeDirectory = builtins.getEnv "HOME";
  home.stateVersion = "26.05";

  programs.home-manager.enable = true;

  home.packages = with pkgs; [
    claude-code
    delta            # syntax-highlighting pager for diffs
    jq
    jujutsu          # jj
    just
    tmux
    zellij
    starship
    inputs.jj-domino.packages.${system}.default
    inputs.interactive-nix-search.packages.${system}.default
  ];

  # force replaces the plain symlinks that older installs made.
  home.file = lib.genAttrs homeFiles (f: {
    source = config.lib.file.mkOutOfStoreSymlink "${dotfiles}/home/${f}";
    force = true;
  });

  programs.rex.enable = true;
  # The server is a systemd user service. On macOS the Rex app runs it.
  services.rex.enable = pkgs.stdenv.hostPlatform.isLinux;

  # The Rex SSH guard needs this. home-manager then owns ~/.ssh/config.
  programs.ssh = {
    enable = true;
    enableDefaultConfig = false;
  };
}
