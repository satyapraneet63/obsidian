#!/bin/bash
set -Euo pipefail

# WOPR Gaming Mode Uninstaller
# Reverses changes made by WOPR_V3.sh installer

TARGET_DIR="$HOME/.local/share/steam-launcher"
SWITCH_BIN="$TARGET_DIR/enter-gamesmode"
RETURN_BIN="$TARGET_DIR/leave-gamesmode"
STATE_DIR="$HOME/.cache/gaming-session"
UDEV_RULES="/etc/udev/rules.d/99-gaming-performance.rules"
INTEL_ARC_GTK_FIX="$HOME/.config/environment.d/10-intel-arc-gtk.conf"

# Try to find the user's bindings config file
BINDINGS_CONFIG=""
for location in \
    "$HOME/.config/hypr/bindings.conf" \
    "$HOME/.config/hypr/keybinds.conf" \
    "$HOME/.config/hypr/hyprland.conf"; do
  if [ -f "$location" ]; then
    BINDINGS_CONFIG="$location"
    break
  fi
done

info() { echo "[*] $*"; }
warn() { echo "[!] $*"; }
err() { echo "[!] $*" >&2; }

# Check if gaming mode is installed
check_installation() {
  local found=false

  if [ -x "$SWITCH_BIN" ] || [ -x "$RETURN_BIN" ]; then
    found=true
  fi

  if [ -n "$BINDINGS_CONFIG" ] && grep -q "# Gaming Mode bindings" "$BINDINGS_CONFIG" 2>/dev/null; then
    found=true
  fi

  if [ "$found" = false ]; then
    warn "Gaming mode does not appear to be installed"
    echo ""
    read -p "Continue anyway? [y/N]: " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
      info "Uninstall cancelled"
      exit 0
    fi
  fi
}

remove_launchers() {
  info "Removing launcher binaries..."

  if [ -f "$SWITCH_BIN" ]; then
    rm -f "$SWITCH_BIN"
    info "  Removed: $SWITCH_BIN"
  fi

  if [ -f "$RETURN_BIN" ]; then
    rm -f "$RETURN_BIN"
    info "  Removed: $RETURN_BIN"
  fi

  # Remove backup files if they exist
  rm -f "$SWITCH_BIN.backup" "$RETURN_BIN.backup" 2>/dev/null

  # Remove target directory if empty
  if [ -d "$TARGET_DIR" ]; then
    if rmdir "$TARGET_DIR" 2>/dev/null; then
      info "  Removed empty directory: $TARGET_DIR"
    else
      info "  Directory not empty, keeping: $TARGET_DIR"
    fi
  fi
}

remove_keybindings() {
  if [ -z "$BINDINGS_CONFIG" ]; then
    warn "No Hyprland bindings config found, skipping keybinding removal"
    return 0
  fi

  local has_block=false
  local has_super_shift_bindings=false

  if grep -q "# Gaming Mode bindings" "$BINDINGS_CONFIG" 2>/dev/null; then
    has_block=true
  fi

  # Check for any SUPER SHIFT R or SUPER SHIFT G bindings (case-insensitive, flexible spacing)
  if grep -Eiq 'bind\s*=.*\bSUPER\b.*\bSHIFT\b.*,\s*[RG]\s*,' "$BINDINGS_CONFIG" 2>/dev/null || \
     grep -Eiq 'bind\s*=.*\bSHIFT\b.*\bSUPER\b.*,\s*[RG]\s*,' "$BINDINGS_CONFIG" 2>/dev/null; then
    has_super_shift_bindings=true
  fi

  if [ "$has_block" = false ] && [ "$has_super_shift_bindings" = false ]; then
    info "No gaming mode keybindings found in $BINDINGS_CONFIG"
    return 0
  fi

  info "Removing keybindings from: $BINDINGS_CONFIG"

  # Create backup before modifying
  cp "$BINDINGS_CONFIG" "$BINDINGS_CONFIG.uninstall-backup"

  # Remove the gaming mode bindings block if it exists
  if [ "$has_block" = true ]; then
    sed -i '/# Gaming Mode bindings - added by installation script/,/# End Gaming Mode bindings/d' "$BINDINGS_CONFIG"
    info "  Removed gaming mode bindings block"
  fi

  # Remove ALL occurrences of SUPER SHIFT R and SUPER SHIFT G bindings (including duplicates)
  # Handle both SUPER SHIFT and SHIFT SUPER orderings, case-insensitive
  # Pattern matches: bind = SUPER SHIFT, R, ... or bind=SUPER SHIFT,R,...
  local removed_r=0
  local removed_g=0

  # Count and remove SUPER+SHIFT+R bindings
  removed_r=$(grep -Eic 'bind\s*=.*\b(SUPER\b.*\bSHIFT|SHIFT\b.*\bSUPER)\b.*,\s*R\s*,' "$BINDINGS_CONFIG" 2>/dev/null || echo 0)
  if [ "$removed_r" -gt 0 ]; then
    sed -i -E '/bind\s*=.*\b(SUPER\b.*\bSHIFT|SHIFT\b.*\bSUPER)\b.*,\s*R\s*,/Id' "$BINDINGS_CONFIG"
    info "  Removed $removed_r SUPER+SHIFT+R binding(s)"
  fi

  # Count and remove SUPER+SHIFT+G bindings
  removed_g=$(grep -Eic 'bind\s*=.*\b(SUPER\b.*\bSHIFT|SHIFT\b.*\bSUPER)\b.*,\s*G\s*,' "$BINDINGS_CONFIG" 2>/dev/null || echo 0)
  if [ "$removed_g" -gt 0 ]; then
    sed -i -E '/bind\s*=.*\b(SUPER\b.*\bSHIFT|SHIFT\b.*\bSUPER)\b.*,\s*G\s*,/Id' "$BINDINGS_CONFIG"
    info "  Removed $removed_g SUPER+SHIFT+G binding(s)"
  fi

  # Clean up any trailing empty lines
  sed -i -e :a -e '/^\s*$/{ $d; N; ba; }' "$BINDINGS_CONFIG"

  info "  Keybindings removed (backup at $BINDINGS_CONFIG.uninstall-backup)"

  # Reload Hyprland config
  if command -v hyprctl >/dev/null 2>&1; then
    hyprctl reload >/dev/null 2>&1 && info "  Hyprland config reloaded" || warn "  Hyprland reload may have failed"
  fi
}

remove_state_files() {
  info "Removing state/cache files..."

  if [ -d "$STATE_DIR" ]; then
    rm -rf "$STATE_DIR"
    info "  Removed: $STATE_DIR"
  else
    info "  No state directory found"
  fi
}

remove_udev_rules() {
  if [ ! -f "$UDEV_RULES" ]; then
    info "No udev rules found at $UDEV_RULES"
    return 0
  fi

  echo ""
  echo "Found udev rules for performance control at:"
  echo "  $UDEV_RULES"
  echo ""
  read -p "Remove udev rules? [Y/n]: " -n 1 -r
  echo

  if [[ ! $REPLY =~ ^[Nn]$ ]]; then
    sudo rm -f "$UDEV_RULES"
    info "  Removed: $UDEV_RULES"

    # Reload udev rules
    sudo udevadm control --reload-rules 2>/dev/null || true
    info "  Udev rules reloaded"
  else
    info "  Keeping udev rules"
  fi
}

remove_intel_arc_fix() {
  if [ ! -f "$INTEL_ARC_GTK_FIX" ]; then
    return 0
  fi

  echo ""
  echo "Found Intel Arc GTK4 fix at:"
  echo "  $INTEL_ARC_GTK_FIX"
  echo ""
  warn "Removing this may cause visual glitches in GTK4 apps on Intel Arc GPUs"
  echo ""
  read -p "Remove Intel Arc GTK4 fix? [y/N]: " -n 1 -r
  echo

  if [[ $REPLY =~ ^[Yy]$ ]]; then
    rm -f "$INTEL_ARC_GTK_FIX"
    info "  Removed: $INTEL_ARC_GTK_FIX"

    # Remove directory if empty
    rmdir "$HOME/.config/environment.d" 2>/dev/null || true
  else
    info "  Keeping Intel Arc GTK4 fix"
  fi
}

remove_gamescope_capability() {
  if ! command -v gamescope >/dev/null 2>&1; then
    return 0
  fi

  local gamescope_path
  gamescope_path=$(command -v gamescope)

  if ! getcap "$gamescope_path" 2>/dev/null | grep -q 'cap_sys_nice'; then
    return 0
  fi

  echo ""
  echo "Gamescope has cap_sys_nice capability set."
  echo "This allows real-time priority for better gaming performance."
  echo ""
  read -p "Remove cap_sys_nice from gamescope? [y/N]: " -n 1 -r
  echo

  if [[ $REPLY =~ ^[Yy]$ ]]; then
    sudo setcap -r "$gamescope_path" 2>/dev/null && \
      info "  Removed capabilities from gamescope" || \
      warn "  Failed to remove capabilities from gamescope"
  else
    info "  Keeping gamescope capabilities"
  fi
}

show_manual_cleanup() {
  echo ""
  echo "=========================================="
  echo "  MANUAL CLEANUP (Optional)"
  echo "=========================================="
  echo ""
  echo "The uninstaller does NOT remove:"
  echo ""
  echo "1. Installed packages (steam, gamescope, mangohud, etc.)"
  echo "   To remove: sudo pacman -Rs steam gamescope mangohud gamemode gum"
  echo ""
  echo "2. User group memberships (video, input)"
  echo "   To remove: sudo gpasswd -d $USER video input"
  echo ""
  echo "3. Steam data directories:"
  echo "   ~/.steam"
  echo "   ~/.local/share/Steam"
  echo ""
  echo "4. Gaming mode config file (if exists):"
  echo "   ~/.gaming-mode.conf"
  echo "   /etc/gaming-mode.conf"
  echo ""
  echo "=========================================="
}

main() {
  echo ""
  echo "=========================================="
  echo "  WOPR Gaming Mode Uninstaller"
  echo "=========================================="
  echo ""

  check_installation

  echo ""
  echo "This will remove:"
  echo "  - Launcher binaries ($TARGET_DIR)"
  echo "  - Hyprland keybindings (Super+Shift+S/R)"
  echo "  - State/cache files ($STATE_DIR)"
  echo ""
  echo "Optional removal (will be prompted):"
  echo "  - Udev performance rules"
  echo "  - Intel Arc GTK4 fix"
  echo "  - Gamescope capabilities"
  echo ""

  read -p "Proceed with uninstall? [y/N]: " -n 1 -r
  echo

  if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    info "Uninstall cancelled"
    exit 0
  fi

  echo ""

  # Core removal
  remove_launchers
  remove_keybindings
  remove_state_files

  # Optional removal (with prompts)
  remove_udev_rules
  remove_intel_arc_fix
  remove_gamescope_capability

  # Show manual cleanup info
  show_manual_cleanup

  echo ""
  info "Uninstall complete!"
  echo ""
}

main "$@"
