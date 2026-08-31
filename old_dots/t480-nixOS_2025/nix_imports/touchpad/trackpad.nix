{ config, lib, pkgs, ... }:

let
  quirksFile = ./tap-and-drag.quirks;
in
{
  # Install the quirks file into the libinput override path
  environment.etc."libinput/local-overrides.quirks/tap-and-drag.quirks".source = quirksFile;

  # Systemd service to trigger udev and make quirks apply immediately
  systemd.services.trigger-udev = {
    description = "Trigger udev rules after switch";
    wantedBy = [ "multi-user.target" ];
    before = [ "display-manager.service" ];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${pkgs.systemd}/bin/udevadm trigger";
    };
  };
}
