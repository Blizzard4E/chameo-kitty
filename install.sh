#!/bin/bash

# Script to install chameo-kitty systemd service and timer files

# Define colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Print header
echo -e "${GREEN}=== Chameo-Kitty Wallpaper Installer ===${NC}"
echo "This script will install the chameo-kitty service and timer for automatic wallpaper rotation."

# Check if required files exist
if [ ! -f "chameo-kitty.service" ] || [ ! -f "chameo-kitty.timer" ] || [ ! -f "main.sh" ]; then
    echo -e "${RED}Error: Required files not found in current directory.${NC}"
    echo "Please make sure the following files exist in the current directory:"
    echo " - chameo-kitty.service"
    echo " - chameo-kitty.timer"
    echo " - main.sh"
    exit 1
fi

# Make main.sh executable
chmod +x main.sh
echo -e "${GREEN}✓${NC} Made main.sh executable"

# Create necessary directories
mkdir -p ~/.local/bin
mkdir -p ~/.config/systemd/user

# Copy main script to bin directory
cp main.sh ~/.local/bin/chameo-kitty
echo -e "${GREEN}✓${NC} Copied main.sh to ~/.local/bin/chameo-kitty"

# Copy service and timer files
cp chameo-kitty.service ~/.config/systemd/user/
cp chameo-kitty.timer ~/.config/systemd/user/
echo -e "${GREEN}✓${NC} Copied systemd files to user directory"

# Reload systemd daemon
systemctl --user daemon-reload
echo -e "${GREEN}✓${NC} Reloaded systemd daemon"

# Enable and start the timer
systemctl --user enable chameo-kitty.timer
systemctl --user start chameo-kitty.timer
echo -e "${GREEN}✓${NC} Enabled and started chameo-kitty timer"

# Show status
echo -e "\n${YELLOW}Service Status:${NC}"
systemctl --user status chameo-kitty.timer

echo -e "\n${GREEN}Installation complete!${NC}"
echo "The wallpaper rotator is now installed and will run according to the timer settings."
echo -e "\nUseful commands:"
echo " - systemctl --user status chameo-kitty.timer   # Check timer status"
echo " - systemctl --user status chameo-kitty.service # Check service status"
echo " - systemctl --user start chameo-kitty.service  # Run the service now"
echo " - journalctl --user -u chameo-kitty.service    # View service logs"