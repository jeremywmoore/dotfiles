_dotfiles := justfile_directory()

# Show available recipes
default:
    @just --list

# Bump input pins (flake.lock) and apply
upgrade: bump apply

# Bump input pins only (no rebuild yet)
bump:
    nix flake update --flake {{ _dotfiles }}

# Apply current flake.nix selection without bumping pins
apply:
    DOTFILES_DIR={{ _dotfiles }} home-manager switch --impure --flake {{ _dotfiles }}#default

# Bump only one input (e.g. `just bump-input nixpkgs`)
bump-input input:
    nix flake update --flake {{ _dotfiles }} {{ input }}

# Show home-manager generations, newest first
list:
    home-manager generations

# Show every installed tool with its resolved name-version
packages:
    @for b in ~/.nix-profile/bin/*; do realpath "$b"; done \
        | sed 's|/bin/.*||' \
        | sort -u \
        | sed 's|^/nix/store/[a-z0-9]\{32\}-||'

# Show what changed between current and previous generation
diff:
    nix store diff-closures \
        "$(home-manager generations | sed -n 2p | awk '{print $7}')" \
        "$(home-manager generations | sed -n 1p | awk '{print $7}')"

# Roll back to the previous generation
rollback:
    "$(home-manager generations | sed -n 2p | awk '{print $7}')/activate"

# Verify the flake evaluates cleanly
check:
    DOTFILES_DIR={{ _dotfiles }} nix build --impure --no-link \
        '{{ _dotfiles }}#homeConfigurations.default.activationPackage'

# Open home.nix in $EDITOR
edit:
    ${EDITOR:-vi} {{ _dotfiles }}/home.nix

# Drop old generations and unreferenced store paths
gc:
    home-manager expire-generations now
    nix-collect-garbage
