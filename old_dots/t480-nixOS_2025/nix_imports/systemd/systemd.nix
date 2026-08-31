{ config, pkgs, ... }:

{
  # Swap and resume configuration (still needed for hibernation to work at all)
  swapDevices = [
    {
      device = "/dev/disk/by-uuid/2e378d8c-48ab-4c5d-93f6-ae7578b433b9";
    }
  ];

  boot.resumeDevice = "/dev/disk/by-uuid/2e378d8c-48ab-4c5d-93f6-ae7578b433b9";
  boot.kernelParams = [
    "resume=/dev/disk/by-uuid/2e378d8c-48ab-4c5d-93f6-ae7578b433b9"
  ];

  # Logind handles suspend key and ignores automatic idle actions
  services.logind.extraConfig = ''
    HandleSuspendKey=suspend
    HandleHibernateKey=hibernate
    IdleAction=ignore
  '';

  # REMOVE this block — HibernateDelaySec no longer used
  # systemd.sleep.extraConfig = ''
  #   HibernateDelaySec=600
  #   HibernateMode=platform shutdown
  # '';
}
