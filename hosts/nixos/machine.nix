{ ... }:
{
  # Replace this entire file with your existing working NixOS configuration.
  # Copy its hardware-configuration.nix and any relative imports alongside it.
  # Preserve your real disks, bootloader, access settings, and stateVersion.
  # Review for private information before committing to your own repository.
  assertions = [ {
    assertion = false;
    message = "Nix Sync: replace hosts/nixos/machine.nix with your real NixOS machine configuration before building or applying.";
  } ];
}
