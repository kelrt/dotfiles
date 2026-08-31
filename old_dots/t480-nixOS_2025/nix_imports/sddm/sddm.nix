{pkgs, lib, config, ...}: 
let sddm-astronaut = pkgs.sddm-astronaut.override {
    # embeddedTheme = "hyprland_kath";
    # embeddedTheme = "post-apocalyptic_hacker";
    # embeddedTheme = "black-hole";
    # embeddedTheme = "cyberpunk";
    embeddedTheme = "jake_the_dog";
    # embeddedTheme = "japanese_aesthetic";
    # embeddedTheme = "pixel_sakura";
    # embeddedTheme = "purple_leaves";
  };
in {
  environment.systemPackages = [
    sddm-astronaut
  ];

  services = {

    displayManager = {
      sddm = {
        wayland.enable = true;
        enable = true;
        #package = pkgs.kdePackages.sddm; #plasma 6 defines this interally i guess

        theme = "sddm-astronaut-theme";

        extraPackages = [sddm-astronaut];

      };
      autoLogin = {
        enable = false;
        user = "relz";
      };
    };
  };
  # # Enable fingerprint authentication
  # security.pam.services.sddm.fprintAuth = true;

  # # Enable the fingerprint daemon
  # services.fprintd.enable = true;
}