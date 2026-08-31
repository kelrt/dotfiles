#!/bin/bash

GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${BLUE}===============================${NC}"
echo -e "${BLUE}     DOTFILES BACKUP SCRIPT    ${NC}"
echo -e "${BLUE}===============================${NC}"

# 1. Prepare target directories
echo -e "\n${YELLOW}[*] Preparing directories...${NC}"
REPO=~/Downloads/backups/dotfiles
mkdir -p $REPO/{sway,waybar,nvim,fcitx5,matugen,Thunar,librewolf}
mkdir -p $REPO/terminal/foot

# 2. Sync full folders (rsync --delete removes old ghost files)
echo -e "${YELLOW}[*] Mirroring configurations...${NC}"
rsync -a --delete ~/.config/sway/ $REPO/sway/
rsync -a --delete ~/.config/waybar/ $REPO/waybar/
rsync -a --delete ~/.config/nvim/ $REPO/nvim/
rsync -a --delete ~/.config/fcitx5/ $REPO/fcitx5/
rsync -a --delete ~/.config/matugen/ $REPO/matugen/
rsync -a --delete ~/.config/foot/ $REPO/terminal/foot/

# 3. Copy standalone files
cp ~/.zshrc ~/.zshenv $REPO/terminal/ 2>/dev/null
cp ~/.config/Thunar/uca.xml $REPO/Thunar/ 2>/dev/null
cp ~/.config/librewolf/librewolf/*.default-default/chrome/userChrome.css $REPO/librewolf/ 2>/dev/null

echo -e "${GREEN}[✔] Files synced successfully!${NC}"

# 4. Commit and push to Git
echo -e "\n${YELLOW}[*] Pushing to GitHub...${NC}"
cd $REPO
git add .
git commit -m "Auto-backup: $(date +'%Y-%m-%d %H:%M')"
git push

echo -e "\n${GREEN}[✔] Backup Complete!${NC}"
echo -e "${BLUE}===============================${NC}"
