{ config, pkgs, ... }:

{
  system.activationScripts.cleanupGenerations.text = ''
    NIX_ENV=/run/current-system/sw/bin/nix-env
    NIX_COLLECT_GARBAGE=/run/current-system/sw/bin/nix-collect-garbage
    WC=/run/current-system/sw/bin/wc
    GREP=/run/current-system/sw/bin/grep
    ECHO=/run/current-system/sw/bin/echo

    $ECHO "🗑️ Deleting generations older than 14 days."

    # Delete old system generations older than 14 days and count how many were deleted
    deleted_count=$($NIX_ENV -p /nix/var/nix/profiles/system --delete-generations +14d --quiet | $WC -l)

    # Run garbage collection and capture output (don't fail script if it fails)
    gc_output=$($NIX_COLLECT_GARBAGE 2>&1 || true)
  '';
}
