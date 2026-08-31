# Basic prompt
PROMPT='%F{green}%n@%m%f:%F{blue}%~%f$ '

# Enable colors
autoload -U colors && colors

# History settings
HISTFILE=~/.zsh_history
HISTSIZE=10000
SAVEHIST=10000
setopt appendhistory

# Source the plugins we installed via DNF
source /usr/share/zsh-autosuggestions/zsh-autosuggestions.zsh
source /usr/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh

# Add Cargo binaries to PATH
export PATH="$HOME/.cargo/bin:$PATH"

# Alias l -> ls -al
alias l='ls -al'
alias nv="nvim"
