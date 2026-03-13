{ config, pkgs, ... }:

let
  user = "relz";
  group = "users";
in {
  # Install cmus and related packages
  environment.systemPackages = with pkgs; [
    cmus
    pipewire
    alsa-utils
  ];

  # Enable and configure PipeWire with PulseAudio emulation
  services.pipewire = {
    enable = true;
    pulse.enable = true;
    alsa.enable = true;
    jack.enable = true;
    alsa.support32Bit = true;
  };

  # ALSA sound setup
  services.pulseaudio.enable = false;
  services.pulseaudio.support32Bit = false;

  # Add user to audio and wheel groups for permissions
  users.users.${user}.extraGroups = [ "audio" "wheel" ];

  # Deploy default cmus config for user 'relz'
  system.activationScripts.cmusConfig = {
    text = ''
      mkdir -p /home/${user}/.config/cmus
      cat > /home/${user}/.config/cmus/config <<EOF
# cmus basic config
set look_syntax = true
set confirm_exit = false
set seek_step = 10
set replaygain = no
set volume_step = 5
EOF
      chown -R ${user}:${group} /home/${user}/.config/cmus
    '';
  };

  # Disable mpd if enabled elsewhere to avoid conflicts
  systemd.services.mpd.enable = false;
}

