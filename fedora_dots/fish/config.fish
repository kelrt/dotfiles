if status is-interactive
    # Kali distrobox
    alias kali='distrobox enter --root kali --'
    alias ksudo='distrobox enter --root kali -- sudo'
    
    alias timer='~/.config/waybar/scripts/productivity-timer.sh'

    # Shorter common commands
    alias ll='ls -lah'
    alias ..='cd ..'
    alias ...='cd ../..'

    # Confirm before overwriting
    alias cp='cp -i'
    alias mv='mv -i'
    alias rm='rm -i'
    alias code='flatpak run com.visualstudio.code'
    alias l='ls -l'
end

set -gx GTK_IM_MODULE fcitx
set -gx QT_IM_MODULE fcitx
set -gx XMODIFIERS @im=fcitx
set -gx SDL_IM_MODULE fcitx
set -gx GLFW_IM_MODULE ibus


# --- Development Workflow ---

# Project Jump Shortcut
abbr -a c cd ~/Projects/code/

# Automated Environment Loading
if type -q direnv
    direnv hook fish | source
end

# Helper to create isolated No-CoW Python environments
function mkvirtual
    python -m venv .venv
    sudo chattr +C .venv 
    echo "layout python" > .envrc
    direnv allow
    echo "Isolated environment ready."
end

#keychain --eval --quiet id_ed25519 | source
set -g fish_greeting


set -x CHROME_EXECUTABLE ~/.local/bin/chrome-wayland.sh
abbr -a frun "flutter run -d chrome"

# --- SSH Agent Configuration ---
# Point to the stable systemd OpenSSH agent
set -gx SSH_AUTH_SOCK "$XDG_RUNTIME_DIR/ssh-agent.socket"
# Tell SSH to use the Seahorse GUI prompt if it needs a password
set -gx SSH_ASKPASS /usr/libexec/seahorse/ssh-askpass
