{ config, pkgs, lib, ... }:

with lib;

let
  cfg = config.services.fcitx5;
in
{
  options.services.fcitx5 = {
    enable = mkEnableOption "Fcitx5 input method with Chewing for Traditional Chinese";
    hyprlandAutoStart = mkOption {
      type = types.bool;
      default = true;
      description = "Whether to auto-start Fcitx5 in Hyprland";
    };
  };

  config = mkIf cfg.enable {
    i18n.inputMethod = {
      enabled = "fcitx5";
      fcitx5.addons = with pkgs; [
        fcitx5-chinese-addons
        fcitx5-gtk
        libsForQt5.fcitx5-qt
        fcitx5-configtool
        fcitx5-chewing
      ];
    };

    environment.variables = {
      GTK_IM_MODULE = "fcitx";
      QT_IM_MODULE = "fcitx";
      XMODIFIERS = "@im=fcitx";
    };

    environment.systemPackages = with pkgs; [
      libchewing
    ];

    # For Hyprland users - create a desktop entry that Hyprland can autostart
    services.xserver.displayManager.sessionCommands = mkIf cfg.hyprlandAutoStart ''
      ${pkgs.fcitx5}/bin/fcitx5 --replace -d &
    '';
  };
}