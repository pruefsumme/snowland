#!/bin/bash

# Goodies Menu
# Dependencies: wofi, grim, slurp, wlogout, wl-clipboard, pavucontrol, blueman

# Check for critical dependencies
if ! command -v wl-copy &> /dev/null; then
    notify-send "Error" "wl-clipboard is missing. Install it with: sudo pacman -S wl-clipboard"
    exit 1
fi

# Ensure Screenshots directory exists
mkdir -p $HOME/Pictures/Screenshots

# Define the menu options
entries="  Screenshot Region\n  Screenshot Full\n  Run Command\n  Audio Settings\n  Bluetooth\n  Power Menu"

# Launch wofi
# --x 5: Slight left offset to align with corner
# --y 30: Below the bar
selected=$(echo -e "$entries" | wofi --dmenu --cache-file /dev/null --prompt "Menu" --width 250 --height 320 --x 5 --y 30 --style "$HOME/.config/wofi/wofi_menu_style.css")

case $selected in
  "  Screenshot Region")
    sleep 0.2
    file="$HOME/Pictures/Screenshots/Screenshot_$(date +%Y-%m-%d_%H-%M-%S).png"
    grim -g "$(slurp)" - | tee "$file" | wl-copy && notify-send "Screenshot" "Region saved to $file and clipboard"
    ;;
  "  Screenshot Full")
    sleep 0.2
    file="$HOME/Pictures/Screenshots/Screenshot_$(date +%Y-%m-%d_%H-%M-%S).png"
    grim - | tee "$file" | wl-copy && notify-send "Screenshot" "Fullscreen saved to $file and clipboard"
    ;;
  "  Run Command")
    wofi --show drun
    ;;
  "  Audio Settings")
    pavucontrol
    ;;
  "  Bluetooth")
    if command -v blueman-manager &> /dev/null; then
        blueman-manager
    elif command -v blueberry &> /dev/null; then
        blueberry
    else
        notify-send "Error" "No bluetooth manager found. Install 'blueman'."
    fi
    ;;
  "  Power Menu")
    wlogout
    ;;
esac