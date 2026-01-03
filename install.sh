#!/usr/bin/env bash

set -euo pipefail

#########################
# Colorful UI helpers   #
#########################
if [[ -t 1 ]]; then
  RED="\033[1;31m"
  GREEN="\033[1;32m"
  YELLOW="\033[1;33m"
  BLUE="\033[1;34m"
  MAGENTA="\033[1;35m"
  CYAN="\033[1;36m"
  BOLD="\033[1m"
  RESET="\033[0m"
else
  RED=""; GREEN=""; YELLOW=""; BLUE=""; MAGENTA=""; CYAN=""; BOLD=""; RESET=""
fi

info()    { printf "%b[INFO]%b %s\n"   "$BLUE"   "$RESET" "$*"; }
success() { printf "%b[OK]%b   %s\n"   "$GREEN"  "$RESET" "$*"; }
warn()    { printf "%b[WARN]%b %s\n"  "$YELLOW" "$RESET" "$*"; }
error()   { printf "%b[ERR]%b  %s\n"   "$RED"    "$RESET" "$*" >&2; }
ask()     { printf "%b[?]%b    %s"      "$MAGENTA" "$RESET" "$*"; }

check_dependencies() {
  # Standard repo packages
  local required=(
    git unzip fc-cache curl
    kitty nemo wofi waybar hyprpaper
    grim slurp wl-copy wpctl playerctl
    notify-send pavucontrol nm-connection-editor
    ttf-font-awesome ttf-jetbrains-mono-nerd dunst 
  )
  
  # Packages that might be AUR or named differently
  local aur_packages=(
    "wlogout (AUR)"
  )

  local alt_groups=(
    "bluetooth_manager:blueman-manager|blueberry"
    "swayosd:swayosd-server"
  )
  local missing=()

  # Check standard commands
  for cmd in "${required[@]}"; do
    # Skip checking font packages directly via command - check fc-list later or assume package manager handles it
    if [[ "$cmd" == "ttf-"* ]]; then
        continue 
    fi
    
    if ! command -v "$cmd" >/dev/null 2>&1; then
      missing+=("$cmd")
    fi
  done

  # Check wlogout specifically
  if ! command -v wlogout >/dev/null 2>&1; then
      missing+=("wlogout (Available in AUR)")
  fi

  # Check alt groups
  for group in "${alt_groups[@]}"; do
    local label="$group"
    local tools_str="$group"
    if [[ "$group" == *:* ]]; then
      label="${group%%:*}"
      tools_str="${group#*:}"
    fi

    IFS='|' read -r -a tools <<<"$tools_str"
    local satisfied="no"
    for tool in "${tools[@]}"; do
      if command -v "$tool" >/dev/null 2>&1; then
        satisfied="yes"
        break
      fi
    done

    if [[ "$satisfied" == "no" ]]; then
      local pretty="${tools_str//|/ or }"
      if [[ "$label" != "$tools_str" ]]; then
        missing+=("$label ($pretty)")
      else
        missing+=("$pretty")
      fi
    fi
  done

  if ((${#missing[@]} > 0)); then
    error "Missing required dependencies:"
    for dep in "${missing[@]}"; do
      error "  - $dep"
    done
    warn "Note: 'wlogout' is an AUR package on Arch Linux (yay -S wlogout)."
    warn "Fonts required: ttf-font-awesome, ttf-jetbrains-mono-nerd"
    error "Install the missing packages with your package manager (pacman/yay) and rerun the installer."
    exit 1
  fi
}

#########################
# Pre-flight checks     #
#########################

info "Checking required tools..."
check_dependencies

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
INSTALL_STATE_FILE="${INSTALL_STATE_FILE:-$HOME/.config/snowland/.installed}"

trap 'error "Script failed at line $LINENO"' ERR

#########################
# Backup & copy configs #
#########################

backup_and_install_configs() {
  info "Backing up existing configs and installing new ones..."

  local backup_dir="$HOME/snowland_backups"
  local backup_root="$backup_dir/config_$(date +%Y%m%d_%H%M%S)"
  mkdir -p "$backup_root"

  local items=("hypr" "kitty" "waybar" "wofi" "dunst" "fastfetch")

  for item in "${items[@]}"; do
    local src="$SCRIPT_DIR/$item"
    local dst="$HOME/.config/$item"
    if [[ -e "$dst" ]]; then
      info "Backing up existing $dst to $backup_root/$item"
      mkdir -p "$(dirname "$backup_root/$item")"
      cp -a "$dst" "$backup_root/" 2>/dev/null || cp -a "$dst" "$backup_root/$item"
    fi

    if [[ -d "$src" ]]; then
      info "Installing $item configuration to $dst"
      mkdir -p "$(dirname "$dst")"
      rm -rf "$dst"
      cp -a "$src" "$dst"
    else
      warn "Source directory $src not found, skipping."
    fi
  done

  success "Configuration files installed. Backup stored at: $backup_root"
}

#########################
# Fonts installation    #
#########################

choose_font_target_dir() {
  local dir="$HOME/.local/share/fonts"
  info "Font installation scope: using user directory: $dir" >&2
  printf '%s\n' "$dir"
}

install_fonts() {
  info "Installing fonts (SF Mono + Lucida)..."

  local target_dir
  target_dir="$(choose_font_target_dir)"
  info "Using font directory: $target_dir"

  local need_sudo="no"
  if [[ "$target_dir" != "$HOME"/* ]]; then
    need_sudo="yes"
  fi

  local tmpdir
  tmpdir="$(mktemp -d -t snowland-fonts-XXXXXX)"
  trap "rm -rf '$tmpdir'" EXIT

  mkdir -p "$target_dir"

  # SF Mono font (OTF)
  info "Cloning SF Mono font repository..."
  git -C "$tmpdir" clone --depth 1 https://github.com/supercomputra/SF-Mono-Font.git sf-mono

  info "Installing SF Mono .otf files..."
  if [[ "$need_sudo" == "yes" ]]; then
    sudo mkdir -p "$target_dir"
    sudo find "$tmpdir/sf-mono" -maxdepth 1 -type f -name '*.otf' -exec cp {} "$target_dir" \;
  else
    find "$tmpdir/sf-mono" -maxdepth 1 -type f -name '*.otf' -exec cp {} "$target_dir" \;
  fi

  # Lucida fonts (TTF)
  info "Cloning Lucida fonts repository..."
  git -C "$tmpdir" clone --depth 1 https://github.com/witt-bit/lucida-fonts.git lucida-fonts

  info "Installing Lucida .ttf files..."
  if [[ "$need_sudo" == "yes" ]]; then
    sudo mkdir -p "$target_dir"
    sudo find "$tmpdir/lucida-fonts" -maxdepth 1 -type f -name '*.ttf' -exec cp {} "$target_dir" \;
  else
    find "$tmpdir/lucida-fonts" -maxdepth 1 -type f -name '*.ttf' -exec cp {} "$target_dir" \;
  fi

  info "Refreshing font cache..."
  if [[ "$need_sudo" == "yes" ]]; then
    sudo fc-cache -f "$target_dir"
  else
    fc-cache -f "$target_dir"
  fi

  rm -rf "$tmpdir"
  trap - EXIT
  success "Fonts installed in $target_dir"
}

#########################
# Theme & icon install  #
#########################

choose_theme_target_dir() {
  local type="$1" # gtk or icon
  local user_dir
  if [[ "$type" == "gtk" ]]; then
    user_dir="$HOME/.themes"
  else
    user_dir="$HOME/.icons"
  fi

  info "${type^^} installation scope: using user directory: $user_dir" >&2
  printf '%s\n' "$user_dir"
}

install_gtk_theme() {
  info "Installing OS-X Leopard GTK theme..."
  local target_dir
  target_dir="$(choose_theme_target_dir gtk)"
  info "Using GTK theme directory: $target_dir"

  local need_sudo="no"
  if [[ "$target_dir" != "$HOME"/* ]]; then
    need_sudo="yes"
  fi

  local tmpdir
  tmpdir="$(mktemp -d -t snowland-gtk-XXXXXX)"
  trap "rm -rf '$tmpdir'" EXIT

  local zipfile="$tmpdir/osx-leopard-theme.zip"
  info "Downloading GTK theme archive..."
  curl -L -o "$zipfile" "https://github.com/B00merang-Project/OS-X-Leopard/archive/refs/tags/1.2.zip"

  info "Extracting GTK theme..."
  unzip -q "$zipfile" -d "$tmpdir"
  local src_dir="$tmpdir/OS-X-Leopard-1.2"

  if [[ ! -d "$src_dir" ]]; then
    error "Expected theme directory $src_dir not found after extraction."
    exit 1
  fi

  if [[ "$need_sudo" == "yes" ]]; then
    sudo mkdir -p "$target_dir"
    sudo rm -rf "$target_dir/OS-X-Leopard-1.2"
    sudo cp -r "$src_dir" "$target_dir/"
  else
    mkdir -p "$target_dir"
    rm -rf "$target_dir/OS-X-Leopard-1.2"
    cp -r "$src_dir" "$target_dir/"
  fi

  rm -rf "$tmpdir"
  trap - EXIT
  success "GTK theme installed in $target_dir/OS-X-Leopard-1.2"
}

install_icon_theme() {
  info "Installing Mac-OS-X Lion icon theme..."
  local target_dir
  target_dir="$(choose_theme_target_dir icon)"
  info "Using icon theme directory: $target_dir"

  local need_sudo="no"
  if [[ "$target_dir" != "$HOME"/* ]]; then
    need_sudo="yes"
  fi

  local tmpdir
  tmpdir="$(mktemp -d -t snowland-icons-XXXXXX)"
  trap "rm -rf '$tmpdir'" EXIT

  local zipfile="$tmpdir/mac-osx-lion-icons.zip"
  info "Downloading icon theme archive..."
  curl -L -o "$zipfile" "https://github.com/B00merang-Artwork/Mac-OS-X-Lion/archive/master.zip"

  info "Extracting icon theme..."
  unzip -q "$zipfile" -d "$tmpdir"
  local src_dir="$tmpdir/Mac-OS-X-Lion-master"

  if [[ ! -d "$src_dir" ]]; then
    error "Expected icon directory $src_dir not found after extraction."
    exit 1
  fi

  if [[ "$need_sudo" == "yes" ]]; then
    sudo mkdir -p "$target_dir"
    sudo rm -rf "$target_dir/Mac-OS-X-Lion"
    sudo cp -r "$src_dir" "$target_dir/Mac-OS-X-Lion"
  else
    mkdir -p "$target_dir"
    rm -rf "$target_dir/Mac-OS-X-Lion"
    cp -r "$src_dir" "$target_dir/Mac-OS-X-Lion"
  fi

  rm -rf "$tmpdir"
  trap - EXIT
  success "Icon theme installed in $target_dir/Mac-OS-X-Lion"
}

#########################
# Wallpaper install     #
#########################

wallpaper_target_from_hypr() {
  local conf
  if [[ -f "$HOME/.config/hypr/hyprpaper.conf" ]]; then
    conf="$HOME/.config/hypr/hyprpaper.conf"
  elif [[ -f "$SCRIPT_DIR/hypr/hyprpaper.conf" ]]; then
    conf="$SCRIPT_DIR/hypr/hyprpaper.conf"
  else
    echo "$HOME/Pictures/wp.jpg"
    return
  fi

  local line path
  while IFS= read -r line; do
    [[ "$line" =~ ^[[:space:]]*# ]] && continue

    if [[ "$line" =~ =[[:space:]]*([^,]+)$ ]]; then
      path="${BASH_REMATCH[1]}"
    elif [[ "$line" =~ ,[[:space:]]*(.+)$ ]]; then
      path="${BASH_REMATCH[1]}"
    else
      continue
    fi

    # trim whitespace
    path="${path#${path%%[![:space:]]*}}"
    path="${path%${path##*[![:space:]]}}"

    if [[ -n "$path" ]]; then
      if [[ "$path" == "~/"* ]]; then
        path="$HOME/${path:2}"
      fi
      echo "$path"
      return
    fi
  done <"$conf"

  echo "$HOME/Pictures/wp.jpg"
}

install_wallpaper() {
  info "Installing Snow Leopard Aurora wallpaper..."

  local target_path
  target_path="$(wallpaper_target_from_hypr)"
  info "Target wallpaper path: $target_path"

  local target_dir
  target_dir="$(dirname "$target_path")"
  mkdir -p "$target_dir"

  if [[ -f "$target_path" ]]; then
    local backup="${target_path%.*}_backup_$(date +%Y%m%d_%H%M%S).${target_path##*.}"
    info "Backing up existing wallpaper to $backup"
    cp -a "$target_path" "$backup"
  fi

  local tmpdir
  tmpdir="$(mktemp -d -t snowland-wallpaper-XXXXXX)"
  trap "rm -rf '$tmpdir'" EXIT

  local zipfile="$tmpdir/aurora.zip"
  info "Downloading wallpaper archive..."
  curl -L -o "$zipfile" "https://blog.greggant.com/media/2021-09-25-nature/aurora.zip"

  info "Extracting wallpaper..."
  unzip -q "$zipfile" -d "$tmpdir"

  local src
  src="$tmpdir/Aurora.jpg"
  if [[ ! -f "$src" ]]; then
    src="$(find "$tmpdir" -type f -iname 'Aurora.jpg' | head -n1 || true)"
  fi

  if [[ -z "$src" || ! -f "$src" ]]; then
    error "Aurora.jpg not found in downloaded archive."
    rm -rf "$tmpdir"
    trap - EXIT
    return 1
  fi

  cp "$src" "$target_path"

  rm -rf "$tmpdir"
  trap - EXIT
  success "Wallpaper installed at $target_path"
}

#########################
# Main                  #
#########################

main() {
  echo
  printf "%bSnowland setup script%b\n" "$BOLD$CYAN" "$RESET"
  echo "---------------------------------------------"
  echo
  printf "%b DISCLAIMER%b\n" "$BOLD$YELLOW" "$RESET"
  echo "Use this installer at your own risk. This script will:"
  echo "  - Move and replace configuration files in ~/.config/"
  echo "  - Download and install themes and fonts"
  echo "  - Modify your system configuration"
  echo
  echo "All existing configurations will be backed up to:"
  printf "  %b~/snowland_backups/%b\n" "$BOLD" "$RESET"
  echo "before any changes are made. You can restore them if needed."
  echo
  echo "---------------------------------------------"
  echo

  echo "This script will:"
  echo "  - Backup your existing hypr, kitty, waybar, wofi, dunst configs from ~/.config"
  echo "  - Copy the versions from this folder into ~/.config"
  echo "  - Optionally install SF Mono + Lucida fonts (user-wide)"
  echo "  - Optionally install the OS-X Leopard GTK theme (user-wide)"
  echo "  - Optionally install the Mac-OS-X Lion icon theme (user-wide)"
  echo
  echo "Nothing is removed permanently: old configs are copied to a timestamped backup folder."
  echo

  local first_run="no"
  if [[ ! -f "$INSTALL_STATE_FILE" ]]; then
    first_run="yes"
    info "No previous Snowland installation detected. Running full setup."
  else
    info "Previous Snowland installation detected. You can choose what to reinstall."
  fi

  local ans

  if [[ "$first_run" == "yes" ]]; then
    # First-ever run: perform full config install, then ask about extras (default = yes)
    backup_and_install_configs

    echo
    echo "Fonts step:"
    echo "  - SF Mono (from https://github.com/supercomputra/SF-Mono-Font)"
    echo "  - Lucida TTFs (from https://github.com/witt-bit/lucida-fonts)"
    ask "Install these fonts now? [Y/n]: "
    read -r ans || true
    if [[ -z "${ans:-}" || "$ans" =~ ^[Yy]$ ]]; then
      install_fonts
    else
      warn "Skipping font installation."
    fi

    echo
    echo "GTK theme step:"
    echo "  - Theme: OS-X Leopard (from B00merang-Project, tag 1.2)"
    ask "Install this GTK theme now? [Y/n]: "
    read -r ans || true
    if [[ -z "${ans:-}" || "$ans" =~ ^[Yy]$ ]]; then
      install_gtk_theme
    else
      warn "Skipping GTK theme installation."
    fi

    echo
    echo "Icon theme step:"
    echo "  - Theme: Mac-OS-X Lion icons (from B00merang-Artwork master branch)"
    ask "Install this icon theme now? [Y/n]: "
    read -r ans || true
    if [[ -z "${ans:-}" || "$ans" =~ ^[Yy]$ ]]; then
      install_icon_theme
    else
      warn "Skipping icon theme installation."
    fi

    echo
    echo "Wallpaper step:"
    echo "  - Snow Leopard Aurora wallpaper (Aurora.jpg)"
    ask "Download and install this wallpaper now? [Y/n]: "
    read -r ans || true
    if [[ -z "${ans:-}" || "$ans" =~ ^[Yy]$ ]]; then
      install_wallpaper
    else
      warn "Skipping wallpaper installation."
    fi
  else
    # Subsequent runs: ask what to reinstall
    echo
    echo "Configuration step:"
    echo "  - hypr, kitty, waybar, wofi, dunst, and fastfetch configs in ~/.config"
    ask "Reinstall these configs? [y/N]: "
    read -r ans || true
    if [[ "$ans" =~ ^[Yy]$ ]]; then
      backup_and_install_configs
    else
      warn "Skipping config reinstall."
    fi

    echo
    echo "Fonts step:"
    echo "  - SF Mono (from https://github.com/supercomputra/SF-Mono-Font)"
    echo "  - Lucida TTFs (from https://github.com/witt-bit/lucida-fonts)"
    ask "Reinstall these fonts? [y/N]: "
    read -r ans || true
    if [[ "$ans" =~ ^[Yy]$ ]]; then
      install_fonts
    else
      warn "Skipping font installation."
    fi

    echo
    echo "GTK theme step:"
    echo "  - Theme: OS-X Leopard (from B00merang-Project, tag 1.2)"
    ask "Reinstall this GTK theme? [y/N]: "
    read -r ans || true
    if [[ "$ans" =~ ^[Yy]$ ]]; then
      install_gtk_theme
    else
      warn "Skipping GTK theme installation."
    fi

    echo
    echo "Icon theme step:"
    echo "  - Theme: Mac-OS-X Lion icons (from B00merang-Artwork master branch)"
    ask "Reinstall this icon theme? [y/N]: "
    read -r ans || true
    if [[ "$ans" =~ ^[Yy]$ ]]; then
      install_icon_theme
    else
      warn "Skipping icon theme installation."
    fi

    echo
    echo "Wallpaper step:"
    echo "  - Snow Leopard Aurora wallpaper (Aurora.jpg)"
    ask "(Re)install this wallpaper? [y/N]: "
    read -r ans || true
    if [[ "$ans" =~ ^[Yy]$ ]]; then
      install_wallpaper
    else
      warn "Skipping wallpaper installation."
    fi
  fi

  # Update installation state marker
  mkdir -p "$(dirname "$INSTALL_STATE_FILE")"
  if [[ "$first_run" == "yes" ]]; then
    {
      echo "first_install_at=$(date '+%Y-%m-%d %H:%M:%S')"
      echo "last_run_at=$(date '+%Y-%m-%d %H:%M:%S')"
    } >"$INSTALL_STATE_FILE"
  else
    echo "last_run_at=$(date '+%Y-%m-%d %H:%M:%S')" >>"$INSTALL_STATE_FILE"
  fi

  echo
  success "You're good to go, log out and Snowland should be installed!"
  info "Remember to open lxappearance (or another theme selector) to apply the Snowland GTK and icon themes."
  info "Also, adjust your hyprland and hyprpaper config to your display. Use hyprctl monitors to get the correct names and values"
}

main "$@"