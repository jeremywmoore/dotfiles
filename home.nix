{ config, lib, pkgs, inputs, ... }:
let
  inherit (pkgs.stdenv.hostPlatform) system;

  # Links point at the checkout, not the store, so edits in $HOME are repo
  # edits and take effect without a switch.
  dotfiles = builtins.getEnv "DOTFILES_DIR";

  # Sends URLs to the opener daemon on the laptop through ~/.opener.sock,
  # which the opener-bridge service below serves. See
  # https://github.com/superbrothers/opener.
  xdg-open = pkgs.writeShellApplication {
    name = "xdg-open";
    runtimeInputs = [ pkgs.socat ];
    text = ''
      # opener-bridge owns the socket. Never remove it here: a failed send
      # can be a blip in the Rex forward, and deleting a live socket would
      # strand the bridge until it restarts.
      sock="$HOME/.opener.sock"
      if [ -S "$sock" ] && printf '%s\n' "$*" | socat - "UNIX-CONNECT:$sock" 2>/dev/null; then
        exit 0
      fi
      printf 'opener: could not reach the laptop (is opener-bridge running and the Rex forward up?). Open this by hand: %s\n' "$*" >&2
      exit 1
    '';
  };
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
    # zellij         # disabled; sessions are moving to rex
    starship
    inputs.jj-domino.packages.${system}.default
    inputs.interactive-nix-search.packages.${system}.default
  ] ++ lib.optionals pkgs.stdenv.hostPlatform.isLinux [
    xdg-open
  ];

  # force replaces the plain symlinks that older installs made.
  home.file = lib.genAttrs homeFiles (f: {
    source = config.lib.file.mkOutOfStoreSymlink "${dotfiles}/home/${f}";
    force = true;
  });

  programs.rex.enable = true;
  # The server is a systemd user service. On macOS the Rex app runs it.
  services.rex.enable = pkgs.stdenv.hostPlatform.isLinux;

  # Bridges ~/.opener.sock (what xdg-open writes to) to a TCP port that a
  # Rex reverse forward carries to the opener daemon on the laptop:
  #   rex -S <devbox> forward new -s opener -R 127.0.0.1:62222:127.0.0.1:62222
  # The laptop runs a second opener with `network: tcp` and
  # `address: 127.0.0.1:62222`. An `ssh -R` of the socket would fight Rex's
  # own SSH connection over it, so ssh config must not forward it.
  systemd.user.services.opener-bridge = lib.mkIf pkgs.stdenv.hostPlatform.isLinux {
    Unit.Description = "opener socket bridge to the Rex reverse forward";
    Service = {
      ExecStart = "${pkgs.socat}/bin/socat UNIX-LISTEN:%h/.opener.sock,fork,unlink-early,mode=600 TCP:127.0.0.1:62222";
      Restart = "always";
      RestartSec = 2;
      # socat exits 143 on SIGTERM; a normal stop is not a failure.
      SuccessExitStatus = 143;
    };
    Install.WantedBy = [ "default.target" ];
  };

  # The Rex SSH guard needs this. home-manager then owns ~/.ssh/config.
  programs.ssh = {
    enable = true;
    enableDefaultConfig = false;
  };
}
