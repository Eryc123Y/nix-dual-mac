{ lib, ... }:
{
  imports = [ ./machine.nix ];
  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
  networking.hostName = lib.mkDefault "nixos";
}
