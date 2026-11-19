# home-manager owns only what needs a module: services and generated
# config. Tools go in the flake's buildEnv, and plain dotfiles in home/.
{ ... }:
{
  home.username = "j.moore";
  home.homeDirectory = "/home/j.moore";
  home.stateVersion = "26.05";

  programs.home-manager.enable = true;

  services.rex.enable = true;

  # Needed for the Rex SSH guard. home-manager then owns ~/.ssh/config.
  programs.ssh = {
    enable = true;
    enableDefaultConfig = false;
  };
}
