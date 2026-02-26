#!/usr/bin/env bash
set -euo pipefail

# ── Flake path detection ────────────────────────────────────────────────
# Priority: NIX_GEN_FLAKE > NH_FLAKE > FLAKE > git root > /etc/nixos

detect_flake() {
  for var in NIX_GEN_FLAKE NH_FLAKE FLAKE; do
    if [ -n "${!var:-}" ]; then echo "${!var}"; return; fi
  done
  local git_root
  git_root=$(git rev-parse --show-toplevel 2>/dev/null || true)
  if [ -n "$git_root" ] && [ -f "$git_root/flake.nix" ]; then
    echo "$git_root"
    return
  fi
  echo "/etc/nixos"
}

FLAKE=$(detect_flake)

# ── Helpers ──────────────────────────────────────────────────────────────

sanitize() {
  local val="$1"
  if [[ "$val" == /* || "$val" == ./* ]]; then
    echo "Error: '$val' looks like a path, not a label." >&2
    echo "Usage: nix-gen <label>  (e.g. nix-gen add-jellyfin)" >&2
    exit 1
  fi
  echo "$val" | tr ' ' '-' | tr -cd 'a-zA-Z0-9:_.-'
}

check_unique() {
  local label="$1"
  for link in /nix/var/nix/profiles/system-*-link; do
    [ -e "$link" ] || continue
    local existing
    existing=$(cat "$link/nixos-version" 2>/dev/null || true)
    if [ "$existing" = "$label" ]; then
      local gen
      gen=$(basename "$link" | sed 's/system-\([0-9]*\)-link/\1/')
      echo "Error: label '$label' already used by generation $gen." >&2
      echo "Each generation must have a unique label." >&2
      exit 1
    fi
  done
}

write_label() {
  local label="$1"
  if [ ! -d "$FLAKE" ]; then
    echo "Error: flake directory does not exist: $FLAKE" >&2
    echo "Set \$FLAKE or \$NH_FLAKE, or run from your config directory." >&2
    exit 1
  fi
  if [ -w "$FLAKE" ]; then
    echo "$label" > "$FLAKE/.nixos-label"
    git -C "$FLAKE" add -f .nixos-label
    git -C "$FLAKE" commit -m "label: $label" --quiet 2>/dev/null || true
  else
    echo "$label" | sudo tee "$FLAKE/.nixos-label" > /dev/null
    sudo git -C "$FLAKE" add -f .nixos-label
    sudo git -C "$FLAKE" commit -m "label: $label" --quiet 2>/dev/null || true
  fi
}

rebuild() {
  local action="$1" label="$2"
  shift 2

  check_unique "$label"
  write_label "$label"

  if command -v nh &>/dev/null; then
    nh os "$action" "$FLAKE" "$@"
  else
    sudo nixos-rebuild "$action" --flake "$FLAKE" "$@"
  fi
}

# ── Commands ─────────────────────────────────────────────────────────────

cmd_list() {
  local current
  current=$(readlink /nix/var/nix/profiles/system | sed 's/system-\([0-9]*\)-link/\1/')

  echo ""
  echo "  NixOS Generations"
  echo "  ─────────────────────────────────────────────────────────────────"

  for link in /nix/var/nix/profiles/system-*-link; do
    [ -e "$link" ] || continue
    local gen date label marker
    gen=$(basename "$link" | sed 's/system-\([0-9]*\)-link/\1/')
    date=$(stat -c '%y' "$link" | cut -d. -f1)
    label=$(cat "$link/nixos-version" 2>/dev/null || echo "?")

    marker="  "
    [ "$gen" = "$current" ] && marker="→ "

    printf "  %s%-4s  %-20s  %s\n" "$marker" "$gen" "$date" "$label"
  done | tail -30

  echo ""
}

cmd_current() {
  local gen label
  gen=$(readlink /nix/var/nix/profiles/system | sed 's/system-\([0-9]*\)-link/\1/')
  label=$(cat /run/current-system/nixos-version 2>/dev/null || echo "?")
  echo "Generation $gen: $label"
}

# ── Main ─────────────────────────────────────────────────────────────────

case "${1:-}" in
  list|ls)
    cmd_list
    ;;
  current)
    cmd_current
    ;;
  test)
    shift
    if [ $# -eq 0 ]; then
      echo "Usage: nix-gen test <label> [extra-args...]"
      exit 1
    fi
    label=$(sanitize "$1"); shift
    rebuild test "$label" "$@"
    ;;
  boot)
    shift
    if [ $# -eq 0 ]; then
      echo "Usage: nix-gen boot <label> [extra-args...]"
      exit 1
    fi
    label=$(sanitize "$1"); shift
    rebuild boot "$label" "$@"
    ;;
  help|-h|--help|"")
    echo "nix-gen — labeled NixOS rebuilds"
    echo ""
    echo "Every rebuild requires a label. Labels appear in systemd-boot."
    echo ""
    echo "Commands:"
    echo "  nix-gen <label>            Rebuild + switch (label required)"
    echo "  nix-gen test <label>       Test without persisting"
    echo "  nix-gen boot <label>       Apply on next boot only"
    echo "  nix-gen list               List generations with labels"
    echo "  nix-gen current            Show current generation"
    echo ""
    echo "Flake path: $FLAKE"
    echo "Override:   \$NIX_GEN_FLAKE, \$NH_FLAKE, or \$FLAKE"
    ;;
  *)
    if [ $# -gt 1 ]; then
      echo "Error: unexpected arguments after label: ${*:2}" >&2
      echo "Usage: nix-gen <label>" >&2
      exit 1
    fi
    label=$(sanitize "$1")
    rebuild switch "$label"
    ;;
esac
