{ config, pkgs, ... }:

{
  environment.shellAliases = {
    nrs = "sudo nixos-rebuild switch --flake ~/.dotfiles";
  };
}

