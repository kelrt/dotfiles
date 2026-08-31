{ config, lib, pkgs, ... }:

{
  options = { };

  config = {
    # Ensure required KDE + XDG packages are available system-wide
    environment.systemPackages = with pkgs; [
      kdePackages.dolphin
      kdePackages.kio
      kdePackages.kde-cli-tools
      xdg-utils
      shared-mime-info
    ];

    # Set required environment variables
    environment.sessionVariables = {
      XDG_MENU_PREFIX = "nixos-";
      XDG_DATA_DIRS = lib.mkForce "/run/current-system/sw/share:/etc/profiles/per-user/$USER/share";
    };

    # Provide a minimal applications.menu so kbuildsycoca6 can build menu cache
    environment.etc."xdg/menus/applications.menu".text = ''
      <!DOCTYPE Menu PUBLIC "-//freedesktop//DTD Menu 1.0//EN"
                            "http://www.freedesktop.org/standards/menu-spec/1.0/menu.dtd">
      <Menu>
          <Name>Applications</Name>
          <DefaultAppDirs/>
          <DefaultDirectoryDirs/>
          <Include>
              <All/>
          </Include>
      </Menu>
    '';

    # Create a user systemd service to regenerate the KDE service cache at login
    systemd.user.services.kbuildsycoca6-refresh = {
      description = "Rebuild KDE system configuration cache";
      wantedBy = [ "default.target" ];
      serviceConfig = {
        ExecStart = "${pkgs.kdePackages.kde-cli-tools}/bin/kbuildsycoca6";
        Environment = "XDG_MENU_PREFIX=nixos-";
      };
    };
  };
}
