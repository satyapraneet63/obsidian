#!/bin/bash
#
# WOPR Gaming Mode Uninstaller
# Removes all files and configurations created by wopr_deck_mode_laptop.sh
#
set -euo pipefail

SCRIPT_VERSION="1.0"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

info()  { echo -e "${GREEN}[*]${NC} $*"; }
warn()  { echo -e "${YELLOW}[!]${NC} $*"; }
err()   { echo -e "${RED}[!]${NC} $*" >&2; }
header(){ echo -e "${BLUE}===${NC} $* ${BLUE}===${NC}"; }

# Track what was removed
declare -a removed_files=()
declare -a failed_files=()
declare -a skipped_files=()

remove_file() {
  local file="$1"
  local use_sudo="${2:-false}"

  if [[ "$use_sudo" == "true" ]]; then
    if sudo test -f "$file" 2>/dev/null || sudo test -L "$file" 2>/dev/null; then
      if sudo rm -f "$file" 2>/dev/null; then
        removed_files+=("$file")
        info "Removed: $file"
      else
        failed_files+=("$file")
        err "Failed to remove: $file"
      fi
    else
      skipped_files+=("$file")
    fi
  else
    if [[ -f "$file" ]] || [[ -L "$file" ]]; then
      if rm -f "$file" 2>/dev/null; then
        removed_files+=("$file")
        info "Removed: $file"
      else
        failed_files+=("$file")
        err "Failed to remove: $file"
      fi
    else
      skipped_files+=("$file")
    fi
  fi
}

remove_dir() {
  local dir="$1"
  local use_sudo="${2:-false}"

  if [[ "$use_sudo" == "true" ]]; then
    if sudo test -d "$dir" 2>/dev/null; then
      if sudo rm -rf "$dir" 2>/dev/null; then
        removed_files+=("$dir/")
        info "Removed directory: $dir"
      else
        failed_files+=("$dir/")
        err "Failed to remove directory: $dir"
      fi
    fi
  else
    if [[ -d "$dir" ]]; then
      if rm -rf "$dir" 2>/dev/null; then
        removed_files+=("$dir/")
        info "Removed directory: $dir"
      else
        failed_files+=("$dir/")
        err "Failed to remove directory: $dir"
      fi
    fi
  fi
}

remove_hyprland_keybind() {
  local hypr_conf="$HOME/.config/hypr/hyprland.conf"

  if [[ ! -f "$hypr_conf" ]]; then
    return 0
  fi

  # Check if the gaming mode keybind exists
  if grep -q "switch-to-gaming" "$hypr_conf" 2>/dev/null; then
    info "Removing Gaming Mode keybind from Hyprland config..."

    # Create backup
    cp "$hypr_conf" "${hypr_conf}.backup.$(date +%Y%m%d%H%M%S)"

    # Remove the keybind line(s)
    sed -i '/switch-to-gaming/d' "$hypr_conf"

    # Remove any comment lines we added
    sed -i '/# Gaming Mode - Switch to gamescope session/d' "$hypr_conf"

    info "Removed keybind from $hypr_conf (backup created)"
  fi
}

check_aur_packages() {
  local -a installed_packages=()

  if pacman -Qi gamescope-session-git &>/dev/null; then
    installed_packages+=("gamescope-session-git")
  fi

  if pacman -Qi gamescope-session-steam-git &>/dev/null; then
    installed_packages+=("gamescope-session-steam-git")
  fi

  if ((${#installed_packages[@]} > 0)); then
    echo ""
    warn "The following AUR packages were installed by Gaming Mode:"
    for pkg in "${installed_packages[@]}"; do
      echo "    - $pkg"
    done
    echo ""
    read -p "Remove these packages? [y/N]: " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
      for pkg in "${installed_packages[@]}"; do
        info "Removing $pkg..."
        sudo pacman -Rns --noconfirm "$pkg" 2>/dev/null || warn "Failed to remove $pkg"
      done
    else
      info "Keeping AUR packages"
    fi
  fi
}

show_summary() {
  echo ""
  header "UNINSTALL SUMMARY"
  echo ""

  if ((${#removed_files[@]} > 0)); then
    echo -e "${GREEN}Removed (${#removed_files[@]} items):${NC}"
    for f in "${removed_files[@]}"; do
      echo "  - $f"
    done
    echo ""
  fi

  if ((${#failed_files[@]} > 0)); then
    echo -e "${RED}Failed to remove (${#failed_files[@]} items):${NC}"
    for f in "${failed_files[@]}"; do
      echo "  - $f"
    done
    echo ""
  fi

  if ((${#removed_files[@]} > 0)); then
    echo -e "${GREEN}Gaming Mode has been uninstalled.${NC}"
    echo ""
    echo "Note: You may need to log out and back in for all changes to take effect."
  else
    echo "No Gaming Mode files were found to remove."
  fi
}

main() {
  echo ""
  echo "========================================"
  echo "  WOPR Gaming Mode Uninstaller v${SCRIPT_VERSION}"
  echo "========================================"
  echo ""
  echo "This will remove all Gaming Mode files and configurations."
  echo ""
  echo "The following will be removed:"
  echo "  - Session wrapper scripts (/usr/local/bin/*)"
  echo "  - GPU wrapper scripts (/usr/local/lib/gamescope-*)"
  echo "  - Session desktop file (/usr/share/wayland-sessions/)"
  echo "  - Environment configs (/etc/environment.d/)"
  echo "  - Polkit rules (/etc/polkit-1/rules.d/)"
  echo "  - Sudoers rules (/etc/sudoers.d/)"
  echo "  - User configs (~/.config/environment.d/)"
  echo "  - Hyprland keybind (Super+Shift+S)"
  echo ""

  read -p "Continue with uninstall? [y/N]: " -n 1 -r
  echo
  if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Uninstall cancelled."
    exit 0
  fi

  echo ""
  header "Removing system files (requires sudo)"

  # Scripts in /usr/local/bin/
  remove_file "/usr/local/bin/gamescope-session-nm-wrapper" true
  remove_file "/usr/local/bin/gaming-session-switch" true
  remove_file "/usr/local/bin/switch-to-gaming" true
  remove_file "/usr/local/bin/switch-to-desktop" true
  remove_file "/usr/local/bin/gaming-keybind-monitor" true
  remove_file "/usr/local/bin/gamescope-nm-start" true
  remove_file "/usr/local/bin/gamescope-nm-stop" true
  remove_file "/usr/local/bin/steam-library-mount" true

  # GPU wrapper directories
  remove_dir "/usr/local/lib/gamescope-gpu" true
  remove_dir "/usr/local/lib/gamescope-nvidia" true

  # Session desktop file
  remove_file "/usr/share/wayland-sessions/gamescope-session-steam-nm.desktop" true

  # Environment.d configs
  remove_file "/etc/environment.d/90-nvidia-gamescope.conf" true
  remove_file "/etc/environment.d/90-hybrid-gaming.conf" true
  remove_file "/etc/environment.d/99-shader-cache.conf" true

  # Polkit rules
  remove_file "/etc/polkit-1/rules.d/50-gamescope-networkmanager.rules" true
  remove_file "/etc/polkit-1/rules.d/50-udisks-gaming.rules" true

  # Sudoers files
  remove_file "/etc/sudoers.d/gaming-session-switch" true
  remove_file "/etc/sudoers.d/gaming-mode-sysctl" true

  # Udev rules
  remove_file "/etc/udev/rules.d/99-performance-gaming.rules" true

  echo ""
  header "Removing user files"

  # User environment configs
  remove_file "$HOME/.config/environment.d/gamescope-session-plus.conf"
  remove_file "$HOME/.config/environment.d/10-shader-cache.conf"

  # User gaming mode config
  remove_file "$HOME/.gaming-mode.conf"

  echo ""
  header "Removing Hyprland configuration"
  remove_hyprland_keybind

  echo ""
  header "Checking AUR packages"
  check_aur_packages

  # Reload systemd and polkit
  echo ""
  header "Reloading system services"
  sudo systemctl daemon-reload 2>/dev/null || true
  sudo systemctl restart polkit.service 2>/dev/null || true
  sudo udevadm control --reload-rules 2>/dev/null || true
  info "System services reloaded"

  show_summary
}

# Check if running as root (we need sudo for some operations, but not running as root)
if [[ $EUID -eq 0 ]]; then
  err "Please run this script as a normal user (not root)."
  err "The script will use sudo when needed."
  exit 1
fi

# Check for sudo access
if ! sudo -v 2>/dev/null; then
  err "This script requires sudo access to remove system files."
  exit 1
fi

main "$@"
