#!/bin/bash

# Goodies Menu
# Dependencies: wofi, grim, slurp, wlogout, wl-clipboard, pavucontrol, blueman

# Check for critical dependencies
if ! command -v wl-copy &> /dev/null; then
  notify-send "Error" "wl-clipboard is missing. Install it with: sudo pacman -S wl-clipboard"
  exit 1
fi

# Look up the menu style so the bar opens with the same theming as wofi
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
STYLE_CANDIDATES=(
  "$HOME/.config/wofi/style.css"
  "$HOME/.config/waybar/wofi_style.css"
  "$SCRIPT_DIR/../wofi_style.css"
  "$SCRIPT_DIR/../../wofi/style.css"
)
WOFI_STYLE=""
for candidate in "${STYLE_CANDIDATES[@]}"; do
  if [[ -f "$candidate" ]]; then
    WOFI_STYLE="$candidate"
    break
  fi
done
STYLE_ARGS=()
if [[ -n "$WOFI_STYLE" ]]; then
  STYLE_ARGS=(--style "$WOFI_STYLE")
fi

# Ensure Screenshots directory exists
mkdir -p $HOME/Pictures/Screenshots

# Define the menu options with Pango markup to force the correct font
# We use a span to force JetBrainsMono Nerd Font (or FontAwesome) on the icons
entries="<span font_family='JetBrainsMono Nerd Font'></span>   Screenshot Region\n<span font_family='JetBrainsMono Nerd Font'></span>   Screenshot Full\n<span font_family='JetBrainsMono Nerd Font'></span>   Run Command\n<span font_family='JetBrainsMono Nerd Font'></span>   Audio Settings\n<span font_family='JetBrainsMono Nerd Font'></span>   Bluetooth\n<span font_family='JetBrainsMono Nerd Font'></span>   Power Menu"

# Launch wofi
# --allow-markup: Vital for the font spans to work
# --dmenu: Run in dmenu mode
selected=$(echo -e "$entries" | wofi --dmenu --allow-markup --cache-file /dev/null --prompt "Menu" --width 250 --height 320 --location top --x 5 --y 30 "${STYLE_ARGS[@]}")

# Match against the text content, ignoring the icon and markup
# We use * wildcards to ignore the messy markup parts at the start
case $selected in
  *"  Screenshot Region")
    sleep 0.2
    file="$HOME/Pictures/Screenshots/Screenshot_$(date +%Y-%m-%d_%H-%M-%S).png"
    grim -g "$(slurp)" - | tee "$file" | wl-copy && notify-send "Screenshot" "Region saved to $file and clipboard"
    ;;
  *"  Screenshot Full")
    sleep 0.2
    file="$HOME/Pictures/Screenshots/Screenshot_$(date +%Y-%m-%d_%H-%M-%S).png"
    grim - | tee "$file" | wl-copy && notify-send "Screenshot" "Fullscreen saved to $file and clipboard"
    ;;
  *"  Run Command")
    wofi --show drun
    ;;
  *"  Audio Settings")
    pavucontrol
    ;;
  *"  Bluetooth")
    if command -v blueman-manager &> /dev/null; then
        blueman-manager
    elif command -v blueberry &> /dev/null; then
        blueberry
    else
        notify-send "Error" "No bluetooth manager found. Install 'blueman'."
    fi
    ;;
  *"  Power Menu")
    wlogout
    ;;
esac