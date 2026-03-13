function ksudo
    # This tells distrobox to enter the 'kali' box and run 'sudo' followed by whatever command you typed
    distrobox-enter -n kali -- sudo $argv
end
