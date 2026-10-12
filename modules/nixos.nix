{ pkgs, username, ... }:
{
  nix.settings.experimental-features = [ "nix-command" "flakes" ];
  programs.zsh.enable = true;
  users.users.${username} = {
    isNormalUser = true;
    home = "/home/${username}";
    shell = pkgs.zsh;
  };
  # Preserve boot, disks, networking, login access, and system.stateVersion
  # from the existing machine configuration. No credentials belong here.
}
