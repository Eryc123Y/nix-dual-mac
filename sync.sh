#!/usr/bin/env bash
set -euo pipefail
ROOT=$(cd "$(dirname "$0")" && pwd)
cd "$ROOT"

die() { printf '%s\n' "$*" >&2; exit 1; }
clean_tree() {
  [ -z "$(git status --porcelain --untracked-files=all)" ] ||
    die "Local changes found. Review and commit them before continuing."
}
pull_config() {
  clean_tree
  branch=$(git symbolic-ref --quiet --short HEAD) || die "Check out a branch first."
  remote=$(git config --get "branch.$branch.remote") || die "Set an upstream remote first."
  ref=$(git config --get "branch.$branch.merge") || die "Set an upstream branch first."
  [ "$remote" != . ] || die "Use a remote repository as the upstream."
  git fetch --no-tags "$remote" "$ref"
  # Stop for both divergence and unpublished local commits. Never reset or stash.
  git merge-base --is-ancestor HEAD FETCH_HEAD ||
    die "Local commits are not on the remote. Push them or resolve divergence first."
  git merge --ff-only FETCH_HEAD
}
select_host() {
  host=${1:-}
  case "$host" in
    macbook|macmini)
      kind=darwin
      target="darwinConfigurations.$host.config.system.build.toplevel"
      user_attr="darwinConfigurations.$host.config.system.primaryUser"
      system_attr="darwinConfigurations.$host.config.nixpkgs.hostPlatform.system"
      ;;
    nixos)
      kind=nixos
      target="nixosConfigurations.nixos.config.system.build.toplevel"
      user_attr="lib.usernames.nixos"
      system_attr="nixosConfigurations.nixos.config.nixpkgs.hostPlatform.system"
      ;;
    linux-x86_64|linux-aarch64)
      kind=home
      target="homeConfigurations.$host.activationPackage"
      user_attr="homeConfigurations.$host.config.home.username"
      system_attr="homeConfigurations.$host.pkgs.stdenv.hostPlatform.system"
      ;;
    *) die "Choose macbook, macmini, nixos, linux-x86_64, or linux-aarch64." ;;
  esac
}
check_machine() {
  [ "$(id -u)" != 0 ] || die "Run this script as your normal user; it requests sudo when needed."
  case "$(uname -s)" in Darwin) os=darwin ;; Linux) os=linux ;; *) die "Unsupported operating system." ;; esac
  case "$(uname -m)" in arm64|aarch64) arch=aarch64 ;; x86_64) arch=x86_64 ;; *) die "Unsupported CPU architecture." ;; esac
  expected_system=$(nix eval --raw "$ROOT#$system_attr")
  [ "$expected_system" = "$arch-$os" ] || die "Target $host needs $expected_system; this machine is $arch-$os."
  username=$(nix eval --raw "$ROOT#$user_attr")
  [ "$username" = "$(id -un)" ] || die "Edit users.nix: $host must use the current account."
  if [ "$kind" = home ]; then
    expected_home=$(nix eval --raw "$ROOT#homeConfigurations.$host.config.home.homeDirectory")
    [ "$expected_home" = "$HOME" ] || die "Configure home.homeDirectory for this account before continuing."
  fi
  if [ "$kind" = nixos ]; then
    command -v nixos-rebuild >/dev/null || die "The nixos target requires an existing NixOS installation."
  fi
}
apply_config() {
  clean_tree
  check_machine
  "$ROOT/scripts/check.sh"
  case "$kind" in
    darwin)
      rebuild=$(nix build --no-link --print-out-paths "$ROOT#darwin-rebuild")
      sudo "$rebuild/bin/darwin-rebuild" switch --flake "$ROOT#$host"
      ;;
    nixos)
      # This fails safely until real machine settings replace the placeholder.
      nix build --no-link "$ROOT#$target"
      sudo nixos-rebuild switch --flake "$ROOT#$host"
      ;;
    home)
      generation=$(nix build --no-link --print-out-paths "$ROOT#$target")
      "$generation/activate"
      ;;
  esac
}

case "${1:-help}" in
  pull) [ "$#" = 1 ] || die "Usage: ./sync.sh pull"; pull_config ;;
  check) [ "$#" = 1 ] || die "Usage: ./sync.sh check"; "$ROOT/scripts/check.sh" ;;
  build)
    [ "$#" = 2 ] || die "Usage: ./sync.sh build HOST"
    select_host "$2"
    check_machine
    "$ROOT/scripts/check.sh"
    nix build --no-link "$ROOT#$target"
    ;;
  apply)
    [ "$#" = 2 ] || die "Usage: ./sync.sh apply HOST"
    select_host "$2"; apply_config
    ;;
  sync)
    [ "$#" = 2 ] || die "Usage: ./sync.sh sync HOST"
    select_host "$2"; pull_config; apply_config
    ;;
  help|--help|-h)
    printf '%s\n' 'Usage: ./sync.sh {pull|check|build HOST|apply HOST|sync HOST}' \
      'HOST: macbook, macmini, nixos, linux-x86_64, linux-aarch64.' \
      'sync = pull then apply. Linux Home Manager activation runs without sudo.' \
      'Commit and push reviewed changes yourself. No automatic commits or force pushes.'
    ;;
  *) die "Unknown command. Run ./sync.sh --help." ;;
esac
