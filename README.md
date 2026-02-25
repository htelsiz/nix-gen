<div align="center">

# nix-gen

**Name your NixOS generations. See them in the boot menu.**

[![Nix Flake](https://img.shields.io/badge/nix-flake-blue?logo=nixos&logoColor=white)](https://nixos.wiki/wiki/Flakes)
[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)

</div>

---

## The Problem

NixOS generations are numbered: gen 42, gen 43, gen 44. These numbers mean nothing when you're staring at systemd-boot trying to remember which generation had the working NVIDIA driver, which one added Jellyfin, and which one broke audio.

**nix-gen fixes this.** Instead of:

```
NixOS Generation 42
NixOS Generation 43
NixOS Generation 44
```

You see:

```
NixOS — fix-nvidia-wayland
NixOS — add-jellyfin
NixOS — broke-audio-revert-me
```

One command. No impure flags. Works with `nh` and `nixos-rebuild`.

## Quick Start

### 1. Add to your flake

```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11";
    nix-gen = {
      url = "github:htelsiz/nix-gen";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { nixpkgs, nix-gen, self, ... }: {
    nixosConfigurations.myhost = nixpkgs.lib.nixosSystem {
      specialArgs = { inherit self; };  # required: module reads .nixos-label via self
      modules = [
        nix-gen.nixosModules.default
        { programs.nix-gen.enable = true; }
        ./configuration.nix
      ];
    };
  };
}
```

### 2. Rebuild with a label

```bash
nix-gen add-jellyfin
```

That's it. The label is baked into the generation and shows up in systemd-boot.

## Commands

```
nix-gen <label>            Rebuild + switch with label
nix-gen test <label>       Test rebuild (doesn't persist across reboot)
nix-gen boot <label>       Apply label on next boot only
nix-gen list               List all generations with their labels
nix-gen current            Show active generation and label
```

### Example: `nix-gen list`

```
  NixOS Generations
  ─────────────────────────────────────────────────────────────────
    41  2026-01-15 14:22:30  initial-install
    42  2026-01-18 09:15:42  add-nvidia-drivers
    43  2026-01-20 16:30:11  add-jellyfin
  → 44  2026-01-22 11:45:03  fix-audio-pipewire
```

The `→` marks your current generation.

## How It Works

```
                     ┌──────────────────────────────┐
  nix-gen <label>    │ 1. Write label to            │
  ─────────────────► │    .nixos-label               │
                     │ 2. git add + commit           │
                     │ 3. nh os switch (or           │
                     │    nixos-rebuild switch)       │
                     └──────────┬───────────────────┘
                                │
                     ┌──────────▼───────────────────┐
  NixOS module       │ builtins.readFile             │
  (pure eval)        │   .nixos-label                │
                     │         ↓                     │
                     │ system.nixos.label = <label>  │
                     └──────────┬───────────────────┘
                                │
                     ┌──────────▼───────────────────┐
  systemd-boot       │ Boot entry title:             │
                     │ "NixOS — <label>"             │
                     └──────────────────────────────┘
```

**Key design decisions:**

- **Pure evaluation** — the label file is committed to git, so flakes see it without `--impure`
- **Works with `nh`** — detects `nh` in PATH and uses it; falls back to `nixos-rebuild`
- **Unique labels enforced** — can't reuse a label across generations
- **Reads `$NH_FLAKE` / `$FLAKE`** — respects your existing flake path config (defaults to `/etc/nixos`)

## Standalone CLI

List and inspect generations without installing the NixOS module:

```bash
nix run github:htelsiz/nix-gen -- list
nix run github:htelsiz/nix-gen -- current
```

For labeled rebuilds, the NixOS module must be imported so `system.nixos.label` is set from `.nixos-label`.

## Constraints

- Labels can't look like file paths (`/foo` or `./bar` are rejected)
- Spaces are auto-replaced with hyphens
- Characters limited to `a-zA-Z0-9:_.-`
- Each label must be unique across all existing generations

## License

MIT — see [LICENSE](LICENSE).
