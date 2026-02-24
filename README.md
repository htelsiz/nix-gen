# nix-gen

Label NixOS generations with human-readable names visible in systemd-boot.

## The Problem

NixOS generations are numbered sequentially -- gen 42, gen 43, gen 44.
These numbers mean nothing when you are staring at a boot menu trying to
remember which generation had the working NVIDIA driver, which one added
Jellyfin, and which one broke audio.

nix-gen lets you name them. Instead of "NixOS Generation 42", your boot
entry reads "NixOS -- add-jellyfin". You pick the right one instantly.

## Quick Start

Add nix-gen to your flake inputs:

```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11";
    nix-gen.url = "github:htelsiz/nix-gen";
    nix-gen.inputs.nixpkgs.follows = "nixpkgs";
  };
}
```

Pass `self` through `specialArgs` so the module can read `.nixos-label`
at evaluation time:

```nix
nixosConfigurations.myhost = nixpkgs.lib.nixosSystem {
  specialArgs = { inherit self; };
  modules = [
    nix-gen.nixosModules.default
    ./configuration.nix
  ];
};
```

Enable the module:

```nix
{ programs.nix-gen.enable = true; }
```

Rebuild with a label:

```
nix-gen add-jellyfin
```

## Commands

| Command                  | Description                          |
|--------------------------|--------------------------------------|
| `nix-gen <label>`        | Rebuild and switch with given label  |
| `nix-gen test <label>`   | Test rebuild (does not persist)      |
| `nix-gen boot <label>`   | Apply label on next boot only        |
| `nix-gen list`           | List generations with labels         |
| `nix-gen current`        | Show the active generation and label |
| `nix-gen help`           | Print usage summary                  |

Labels must not look like file paths. Spaces are replaced with hyphens.
Each label must be unique across all existing generations.

## How It Works

nix-gen uses a `.nixos-label` file and pure evaluation to bake labels
into NixOS generations:

1. `nix-gen <label>` writes the label to `.nixos-label` in your flake root.
2. It stages the file with `git add` (flakes only see tracked or staged files).
3. It commits the label file so the tree is clean for `nh` or `nixos-rebuild`.
4. The NixOS module reads `.nixos-label` with `builtins.readFile` at eval time.
5. It sets `system.nixos.label`, which bakes the label into the generation.
6. systemd-boot picks up the label and displays it in the boot menu.

No impure evaluation. No `--impure` flag. The label is part of the flake
inputs just like any other tracked file.

## Standalone CLI

You can run nix-gen without installing the NixOS module. The CLI works on
its own for listing and inspecting generations:

```
nix run github:htelsiz/nix-gen -- list
nix run github:htelsiz/nix-gen -- current
```

To use it for labeled rebuilds, the NixOS module must be imported so that
`system.nixos.label` is set from `.nixos-label`.

## License

MIT -- see [LICENSE](LICENSE).
