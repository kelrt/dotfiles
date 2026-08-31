{ config, pkgs, lib, ... }:

{
  services.greetd = {
    enable = true;

    settings = {
      default_session = {
        command = "${pkgs.greetd.tuigreet}/bin/tuigreet --time --cmd Hyprland";
        user = "greeter";
      };
    };
  };

  users.users.greeter = {
    isSystemUser = true;
    createHome = true;
    home = "/var/lib/greetd";
    shell = pkgs.bash;
  };

  users.groups.greeter = {};

  # Disable other display managers to avoid conflict
  services.displayManager.sddm.enable = lib.mkForce false;
}
