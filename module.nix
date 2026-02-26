{
  config,
  lib,
  pkgs,
  self ? null,
  ...
}:
let
  cfg = config.programs.nix-gen;

  labelFile = self + "/.nixos-label";
  hasLabel = self != null && builtins.pathExists labelFile;
  fileLabel =
    if hasLabel then
      builtins.replaceStrings [ "\n" ] [ "" ] (builtins.readFile labelFile)
    else
      "";

  nix-gen = pkgs.callPackage ./package.nix { };
in
{
  options.programs.nix-gen = {
    enable = lib.mkEnableOption "nix-gen, labeled NixOS generation rebuilds";

    flake = lib.mkOption {
      type = lib.types.str;
      default = "/etc/nixos";
      description = "Path to the editable flake source directory.";
    };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [ nix-gen ];
    environment.sessionVariables.NIX_GEN_FLAKE = cfg.flake;
    system.nixos.label = lib.mkIf (fileLabel != "") fileLabel;
  };
}
