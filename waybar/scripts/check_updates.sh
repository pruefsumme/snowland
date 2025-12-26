#!/bin/bash

# Check for updates (pacman + aur)
# Dependencies: pacman-contrib

if ! command -v checkupdates &> /dev/null; then
    echo "{\"text\": \"Err\", \"tooltip\": \"pacman-contrib not installed\"}"
    exit 0
fi

# Calculate updates
official_updates=$(checkupdates | wc -l)
aur_updates=0

if command -v yay &> /dev/null; then
    aur_updates=$(yay -Qua | wc -l)
elif command -v paru &> /dev/null; then
    aur_updates=$(paru -Qua | wc -l)
fi

total_updates=$((official_updates + aur_updates))

# Output JSON for Waybar
if [ "$total_updates" -gt 0 ]; then
    tooltip="Official: $official_updates\nAUR: $aur_updates"
    echo "{\"text\": \"$total_updates\", \"tooltip\": \"$tooltip\", \"class\": \"updates\"}"
else
    echo "{\"text\": \"\", \"tooltip\": \"Up to date\", \"class\": \"none\"}"
fi
