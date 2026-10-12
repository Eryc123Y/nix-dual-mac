{ pkgs, username, ... }:
{
  nixpkgs.hostPlatform = "aarch64-darwin";
  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  # Compatibility settings, not package versions. Keep on routine upgrades.
  system.stateVersion = 6;
  system.primaryUser = username;
  users.users.${username} = {
    home = "/Users/${username}";
    shell = pkgs.zsh;
  };
  programs.zsh.enable = true;

  # A small shared baseline; extend these in your own copy.
  system.defaults = {
    dock.autohide = true;
    finder.ShowPathbar = true;
    finder.AppleShowAllExtensions = true;
  };
}
