{
  lib,
  writeShellApplication,
  coreutils,
  git,
  gnused,
}:
writeShellApplication {
  name = "nix-gen";
  runtimeInputs = [
    coreutils
    git
    gnused
  ];
  text = builtins.readFile ./nix-gen.sh;
  meta = {
    description = "Label NixOS generations with human-readable names visible in systemd-boot";
    homepage = "https://github.com/htelsiz/nix-gen";
    license = lib.licenses.mit;
    platforms = lib.platforms.linux;
    mainProgram = "nix-gen";
  };
}
