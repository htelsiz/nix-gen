{
  description = "Label NixOS generations with human-readable names visible in systemd-boot";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs =
    { self, nixpkgs }:
    let
      forAllSystems = nixpkgs.lib.genAttrs [
        "x86_64-linux"
        "aarch64-linux"
      ];
    in
    {
      packages = forAllSystems (system: {
        default = nixpkgs.legacyPackages.${system}.callPackage ./package.nix { };
      });

      nixosModules.default = import ./module.nix;

      overlays.default = _final: prev: {
        nix-gen = prev.callPackage ./package.nix { };
      };
    };
}
