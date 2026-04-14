function cleanup --wraps='sudo dnf clean all; and sudo dnf autoremove -y; and flatpak uninstall --unused -y; and sudo snapper cleanup timeline; and sudo snapper cleanup number' --description 'alias cleanup=sudo dnf clean all; and sudo dnf autoremove -y; and flatpak uninstall --unused -y; and sudo snapper cleanup timeline; and sudo snapper cleanup number'
    sudo dnf clean all; and sudo dnf autoremove -y; and flatpak uninstall --unused -y; and sudo snapper cleanup timeline; and sudo snapper cleanup number $argv
end
