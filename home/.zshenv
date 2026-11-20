# ssh runs commands in a non-interactive shell, which reads only this file.
# Rex needs the home-manager profile on PATH to find rex there.
[[ -d $HOME/.nix-profile/bin && :$PATH: != *:$HOME/.nix-profile/bin:* ]] && PATH="$HOME/.nix-profile/bin:$PATH"
# Some tools read only $BROWSER. On Linux, xdg-open is the opener shim from home.nix.
[[ $OSTYPE == linux* ]] && export BROWSER=xdg-open
