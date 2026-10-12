# Evaluation only. This is deliberately not exposed as a deployment host.
{ ... }:
{
  nixpkgs.hostPlatform = "x86_64-linux";
  system.stateVersion = "26.05";
  boot.loader.grub.devices = [ "nodev" ];
  fileSystems."/" = {
    device = "/dev/evaluation-fixture-only";
    fsType = "ext4";
  };
}
