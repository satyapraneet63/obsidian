#!/bin/bash
#
# WOPR Gaming Mode Uninstaller
# Removes all files and configurations created by wopr_deck_mode_laptop.sh
#
set -Euo pipefail

UNINSTALLER_VERSION="1.0"

info(){ echo "[*] $*"; }
warn(){ echo "[!] $*"; }
err(){ echo "[!] $*" >&2; }

# Track what was removed for summary
declare -a REMOVED_FILES=()
declare -a SKIPPED_FILES=()
declare -a FAILED_FILES=()
PACKAGES_REMOVED=false
GROUPS_REMOVED=false

remove_file() {
    local file="$1"
    local use_sudo="${2:-true}"

    if [[ "$use_sudo" == "true" ]]; then
        if sudo test -f "$file" 2>/dev/null || sudo test -L "$file" 2>/dev/null; then
            if sudo rm -f "$file" 2>/dev/null; then
                REMOVED_FILES+=("$file")
                info "Removed: $file"
                return 0
            else
                FAILED_FILES+=("$file")
                err "Failed to remove: $file"
                return 1
            fi
        else
            SKIPPED_FILES+=("$file")
            return 0
        fi
    else
        if [[ -f "$file" ]] || [[ -L "$file" ]]; then
            if rm -f "$file" 2>/dev/null; then
                REMOVED_FILES+=("$file")
                info "Removed: $file"
                return 0
            else
                FAILED_FILES+=("$file")
                err "Failed to remove: $file"
                return 1
            fi
        else
            SKIPPED_FILES+=("$file")
            return 0
        fi
    fi
}

remove_dir_if_empty() {
    local dir="$1"
    local use_sudo="${2:-true}"

    if [[ "$use_sudo" == "true" ]]; then
        if sudo test -d "$dir" 2>/dev/null; then
            # Check if directory is empty
            if [[ -z "$(sudo ls -A "$dir" 2>/dev/null)" ]]; then
                sudo rmdir "$dir" 2>/dev/null && info "Removed empty directory: $dir"
            fi
        fi
    else
        if [[ -d "$dir" ]]; then
            if [[ -z "$(ls -A "$dir" 2>/dev/null)" ]]; then
                rmdir "$dir" 2>/dev/null && info "Removed empty directory: $dir"
            fi
        fi
    fi
}

remove_hyprland_keybind() {
    local bindings_conf="$HOME/.config/hypr/bindings.conf"

    if [[ ! -f "$bindings_conf" ]]; then
        return 0
    fi

    if grep -q "switch-to-gaming" "$bindings_conf" 2>/dev/null; then
        info "Removing Gaming Mode keybind from bindings.conf..."
        # Remove the keybind line and the comment before it
        sed -i '/# Gaming Mode - Switch to Gamescope session/d' "$bindings_conf"
        sed -i '/switch-to-gaming/d' "$bindings_conf"
        # Clean up any resulting double blank lines
        sed -i '/^$/N;/^\n$/d' "$bindings_conf"
        info "Removed Gaming Mode keybind"
    fi
}

remove_hyprland_fcitx_env() {
    local hypr_conf="$HOME/.config/hypr/hyprland.conf"

    if [[ ! -f "$hypr_conf" ]]; then
        return 0
    fi

    if grep -q "FCITX_NO_WAYLAND_DIAGNOSE" "$hypr_conf" 2>/dev/null; then
        info "Removing FCITX env from hyprland.conf..."
        sed -i '/# Silence fcitx5 Wayland diagnose warning (gaming-mode installer)/d' "$hypr_conf"
        sed -i '/env = FCITX_NO_WAYLAND_DIAGNOSE,1/d' "$hypr_conf"
        info "Removed FCITX environment variable from Hyprland config"
    fi
}

remove_gamescope_capability() {
    if command -v gamescope >/dev/null 2>&1; then
        local gs_path
        gs_path=$(command -v gamescope)
        if getcap "$gs_path" 2>/dev/null | grep -q 'cap_sys_nice'; then
            info "Removing cap_sys_nice capability from gamescope..."
            sudo setcap -r "$gs_path" 2>/dev/null && info "Removed capability from gamescope" || warn "Failed to remove capability"
        fi
    fi
}

remove_user_from_groups() {
    echo ""
    echo "================================================================"
    echo "  USER GROUP CLEANUP"
    echo "================================================================"
    echo ""
    echo "  The installer may have added your user to these groups:"
    echo "    - video  (GPU hardware access)"
    echo "    - input  (controller/gamepad support)"
    echo "    - wheel  (NetworkManager control)"
    echo ""
    echo "  These groups may be needed for other purposes."
    echo "  Only remove them if you're sure they were added by the installer."
    echo ""
    read -p "Remove user from video, input, wheel groups? [y/N]: " -n 1 -r
    echo

    if [[ $REPLY =~ ^[Yy]$ ]]; then
        for group in video input wheel; do
            if groups 2>/dev/null | grep -qw "$group"; then
                info "Removing user from $group group..."
                sudo gpasswd -d "$USER" "$group" 2>/dev/null && info "Removed from $group" || warn "Failed to remove from $group"
            fi
        done
        GROUPS_REMOVED=true
        echo ""
        warn "You will need to log out and back in for group changes to take effect."
    else
        info "Keeping user group memberships"
    fi
}

remove_aur_packages() {
    echo ""
    echo "================================================================"
    echo "  AUR PACKAGE CLEANUP"
    echo "================================================================"
    echo ""
    echo "  The following AUR packages were installed for Gaming Mode:"
    echo "    - gamescope-session-git (or gamescope-session)"
    echo "    - gamescope-session-steam-git (or gamescope-session-steam)"
    echo ""
    read -p "Remove these AUR packages? [y/N]: " -n 1 -r
    echo

    if [[ $REPLY =~ ^[Yy]$ ]]; then
        local -a packages_to_remove=()

        for pkg in gamescope-session-git gamescope-session gamescope-session-steam-git gamescope-session-steam; do
            if pacman -Qi "$pkg" &>/dev/null; then
                packages_to_remove+=("$pkg")
            fi
        done

        if ((${#packages_to_remove[@]})); then
            info "Removing: ${packages_to_remove[*]}"
            sudo pacman -Rns --noconfirm "${packages_to_remove[@]}" 2>/dev/null && PACKAGES_REMOVED=true || warn "Some packages may not have been removed"
        else
            info "No gamescope-session packages found to remove"
        fi
    else
        info "Keeping AUR packages"
    fi
}

reset_sddm_session() {
    local sddm_conf="/etc/sddm.conf.d/zz-gaming-session.conf"

    # This file is removed as part of the system files cleanup
    # But we need to ensure SDDM defaults back to a working session
    if [[ -f /etc/sddm.conf.d/autologin.conf ]]; then
        info "SDDM autologin.conf exists - session will use that configuration"
    else
        info "Note: You may need to configure SDDM session settings manually if auto-login was dependent on gaming-session.conf"
    fi
}

remove_elephant_config() {
    local cfg="$HOME/.config/elephant/desktopapplications.toml"

    if [[ -f "$cfg" ]]; then
        if grep -q 'launch_prefix[[:space:]]*=[[:space:]]*"uwsm-app --"' "$cfg" 2>/dev/null; then
            info "Removing Elephant launcher uwsm-app configuration..."
            sed -i '/^launch_prefix[[:space:]]*=[[:space:]]*"uwsm-app --"/d' "$cfg"
            info "Removed Elephant launch_prefix configuration"
        fi
    fi
}

kill_gaming_processes() {
    info "Stopping any running gaming mode processes..."

    # Kill gaming-related processes
    pkill -f gaming-keybind-monitor 2>/dev/null || true
    pkill -f steam-library-mount 2>/dev/null || true
    pkill -f gamescope-session 2>/dev/null || true

    # Remove gaming session marker
    rm -f /tmp/.gaming-session-active 2>/dev/null || true
    rm -f /tmp/.gamescope-started-nm 2>/dev/null || true
}

show_summary() {
    echo ""
    echo "================================================================"
    echo "  UNINSTALL SUMMARY"
    echo "================================================================"
    echo ""

    if ((${#REMOVED_FILES[@]})); then
        echo "  FILES REMOVED: ${#REMOVED_FILES[@]}"
    fi

    if ((${#SKIPPED_FILES[@]})); then
        echo "  FILES SKIPPED (not found): ${#SKIPPED_FILES[@]}"
    fi

    if ((${#FAILED_FILES[@]})); then
        echo ""
        echo "  FAILED TO REMOVE:"
        for f in "${FAILED_FILES[@]}"; do
            echo "    - $f"
        done
    fi

    if [[ "$PACKAGES_REMOVED" == "true" ]]; then
        echo ""
        echo "  AUR packages removed"
    fi

    if [[ "$GROUPS_REMOVED" == "true" ]]; then
        echo ""
        echo "  User removed from video/input/wheel groups"
        echo "  (requires logout to take effect)"
    fi

    echo ""
    echo "================================================================"
    echo ""
}

uninstall() {
    echo ""
    echo "================================================================"
    echo "  WOPR GAMING MODE UNINSTALLER v${UNINSTALLER_VERSION}"
    echo "================================================================"
    echo ""
    echo "  This will remove all files and configurations created by the"
    echo "  WOPR Gaming Mode Installer (wopr_deck_mode_laptop.sh)."
    echo ""
    echo "  The following will be removed:"
    echo "    - System configuration files in /etc/"
    echo "    - Scripts in /usr/local/bin/"
    echo "    - GPU wrapper scripts"
    echo "    - Session desktop files"
    echo "    - Polkit rules"
    echo "    - Sudoers rules"
    echo "    - Udev rules"
    echo "    - User configuration files"
    echo "    - Hyprland keybind modifications"
    echo ""
    echo "  Optionally:"
    echo "    - AUR packages (gamescope-session-*)"
    echo "    - User group memberships (video, input, wheel)"
    echo ""
    read -p "Continue with uninstall? [y/N]: " -n 1 -r
    echo

    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        info "Uninstall cancelled"
        exit 0
    fi

    # Get sudo access
    sudo -v || { err "sudo authentication required"; exit 1; }

    # Stop any running gaming processes first
    kill_gaming_processes

    echo ""
    echo "Removing system files..."
    echo ""

    #=========================================================================
    # SYSTEM CONFIGURATION FILES (/etc/)
    #=========================================================================

    # Environment configuration
    remove_file "/etc/environment.d/90-nvidia-gamescope.conf"
    remove_file "/etc/environment.d/90-hybrid-gaming.conf"
    remove_file "/etc/environment.d/99-shader-cache.conf"
    remove_dir_if_empty "/etc/environment.d"

    # Udev rules
    remove_file "/etc/udev/rules.d/99-gaming-performance.rules"

    # Sudoers rules
    remove_file "/etc/sudoers.d/gaming-mode-sysctl"
    remove_file "/etc/sudoers.d/gaming-session-switch"

    # Security limits
    remove_file "/etc/security/limits.d/99-gaming-memlock.conf"

    # PipeWire configuration
    remove_file "/etc/pipewire/pipewire.conf.d/10-gaming-latency.conf"
    remove_dir_if_empty "/etc/pipewire/pipewire.conf.d"

    # NetworkManager configuration
    remove_file "/etc/NetworkManager/conf.d/10-iwd-backend.conf"
    remove_file "/etc/NetworkManager/conf.d/20-unmanaged-systemd.conf"
    remove_dir_if_empty "/etc/NetworkManager/conf.d"

    # Polkit rules
    remove_file "/etc/polkit-1/rules.d/50-gamescope-networkmanager.rules"
    remove_file "/etc/polkit-1/rules.d/50-udisks-gaming.rules"

    # SDDM configuration
    remove_file "/etc/sddm.conf.d/zz-gaming-session.conf"
    reset_sddm_session

    #=========================================================================
    # SCRIPTS (/usr/local/bin/)
    #=========================================================================

    echo ""
    echo "Removing scripts..."
    echo ""

    remove_file "/usr/local/bin/gamescope-session-nm-wrapper"
    remove_file "/usr/local/bin/gaming-session-switch"
    remove_file "/usr/local/bin/switch-to-gaming"
    remove_file "/usr/local/bin/switch-to-desktop"
    remove_file "/usr/local/bin/gaming-keybind-monitor"
    remove_file "/usr/local/bin/gamescope-nm-start"
    remove_file "/usr/local/bin/gamescope-nm-stop"
    remove_file "/usr/local/bin/steam-library-mount"

    #=========================================================================
    # GPU WRAPPER SCRIPTS
    #=========================================================================

    echo ""
    echo "Removing GPU wrapper scripts..."
    echo ""

    remove_file "/usr/local/lib/gamescope-gpu/gamescope"
    remove_dir_if_empty "/usr/local/lib/gamescope-gpu"

    remove_file "/usr/local/lib/gamescope-nvidia/gamescope"
    remove_dir_if_empty "/usr/local/lib/gamescope-nvidia"

    #=========================================================================
    # SESSION FILES
    #=========================================================================

    echo ""
    echo "Removing session files..."
    echo ""

    remove_file "/usr/lib/os-session-select"
    remove_file "/usr/share/wayland-sessions/gamescope-session-steam-nm.desktop"

    # Old/legacy files that may have been left behind
    remove_file "/usr/bin/gamescope-session"
    remove_file "/usr/share/wayland-sessions/gamescope-session.desktop"

    #=========================================================================
    # USER CONFIGURATION FILES
    #=========================================================================

    echo ""
    echo "Removing user configuration files..."
    echo ""

    remove_file "$HOME/.config/environment.d/gamescope-session-plus.conf" "false"
    remove_file "$HOME/.config/environment.d/90-fcitx-wayland.conf" "false"
    remove_dir_if_empty "$HOME/.config/environment.d" "false"

    #=========================================================================
    # HYPRLAND MODIFICATIONS
    #=========================================================================

    echo ""
    echo "Removing Hyprland modifications..."
    echo ""

    remove_hyprland_keybind
    remove_hyprland_fcitx_env

    #=========================================================================
    # ELEPHANT LAUNCHER CONFIG
    #=========================================================================

    remove_elephant_config

    #=========================================================================
    # GAMESCOPE CAPABILITY
    #=========================================================================

    echo ""
    echo "Removing gamescope capabilities..."
    echo ""

    remove_gamescope_capability

    #=========================================================================
    # RELOAD SERVICES
    #=========================================================================

    echo ""
    echo "Reloading system services..."
    echo ""

    # Reload udev rules
    sudo udevadm control --reload-rules 2>/dev/null || true

    # Restart polkit to pick up removed rules
    sudo systemctl restart polkit.service 2>/dev/null || true

    # Reload Hyprland if running
    if command -v hyprctl >/dev/null 2>&1 && hyprctl monitors >/dev/null 2>&1; then
        hyprctl reload >/dev/null 2>&1 && info "Hyprland config reloaded" || true
    fi

    #=========================================================================
    # OPTIONAL: AUR PACKAGES
    #=========================================================================

    remove_aur_packages

    #=========================================================================
    # OPTIONAL: USER GROUPS
    #=========================================================================

    remove_user_from_groups

    #=========================================================================
    # SUMMARY
    #=========================================================================

    show_summary

    echo "  WOPR Gaming Mode has been uninstalled."
    echo ""

    if [[ "$GROUPS_REMOVED" == "true" ]]; then
        echo "  Please log out and log back in for group changes to take effect."
        echo ""
    fi

    echo "  Note: The following packages installed as dependencies were NOT removed:"
    echo "    - steam, gamescope, mangohud, gamemode, etc."
    echo "  Remove these manually if desired: sudo pacman -Rns <package>"
    echo ""
}

verify_removal() {
    echo ""
    echo "================================================================"
    echo "  VERIFYING REMOVAL"
    echo "================================================================"
    echo ""

    local found_files=0

    # List of all files that should be removed
    local -a expected_removed=(
        "/etc/environment.d/90-nvidia-gamescope.conf"
        "/etc/environment.d/90-hybrid-gaming.conf"
        "/etc/environment.d/99-shader-cache.conf"
        "/etc/udev/rules.d/99-gaming-performance.rules"
        "/etc/sudoers.d/gaming-mode-sysctl"
        "/etc/sudoers.d/gaming-session-switch"
        "/etc/security/limits.d/99-gaming-memlock.conf"
        "/etc/pipewire/pipewire.conf.d/10-gaming-latency.conf"
        "/etc/NetworkManager/conf.d/10-iwd-backend.conf"
        "/etc/NetworkManager/conf.d/20-unmanaged-systemd.conf"
        "/etc/polkit-1/rules.d/50-gamescope-networkmanager.rules"
        "/etc/polkit-1/rules.d/50-udisks-gaming.rules"
        "/etc/sddm.conf.d/zz-gaming-session.conf"
        "/usr/local/bin/gamescope-session-nm-wrapper"
        "/usr/local/bin/gaming-session-switch"
        "/usr/local/bin/switch-to-gaming"
        "/usr/local/bin/switch-to-desktop"
        "/usr/local/bin/gaming-keybind-monitor"
        "/usr/local/bin/gamescope-nm-start"
        "/usr/local/bin/gamescope-nm-stop"
        "/usr/local/bin/steam-library-mount"
        "/usr/local/lib/gamescope-gpu/gamescope"
        "/usr/local/lib/gamescope-nvidia/gamescope"
        "/usr/lib/os-session-select"
        "/usr/share/wayland-sessions/gamescope-session-steam-nm.desktop"
        "$HOME/.config/environment.d/gamescope-session-plus.conf"
        "$HOME/.config/environment.d/90-fcitx-wayland.conf"
    )

    for file in "${expected_removed[@]}"; do
        if sudo test -f "$file" 2>/dev/null || sudo test -L "$file" 2>/dev/null; then
            echo "  STILL EXISTS: $file"
            ((found_files++))
        fi
    done

    # Check Hyprland keybind
    if [[ -f "$HOME/.config/hypr/bindings.conf" ]]; then
        if grep -q "switch-to-gaming" "$HOME/.config/hypr/bindings.conf" 2>/dev/null; then
            echo "  STILL EXISTS: Gaming Mode keybind in bindings.conf"
            ((found_files++))
        fi
    fi

    # Check gamescope capability
    if command -v gamescope >/dev/null 2>&1; then
        if getcap "$(command -v gamescope)" 2>/dev/null | grep -q 'cap_sys_nice'; then
            echo "  STILL EXISTS: cap_sys_nice on gamescope"
            ((found_files++))
        fi
    fi

    # Check AUR packages
    for pkg in gamescope-session-git gamescope-session gamescope-session-steam-git gamescope-session-steam; do
        if pacman -Qi "$pkg" &>/dev/null; then
            echo "  STILL INSTALLED: $pkg"
            ((found_files++))
        fi
    done

    echo ""
    if ((found_files == 0)); then
        echo "  All Gaming Mode components have been removed."
    else
        echo "  Found $found_files remaining items."
        echo "  Run the uninstaller again or remove them manually."
    fi
    echo ""
}

show_help() {
    echo "WOPR Gaming Mode Uninstaller v${UNINSTALLER_VERSION}"
    echo ""
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  --help, -h      Show this help message"
    echo "  --verify, -v    Verify removal (check for remaining files)"
    echo "  --force, -f     Skip confirmation prompts"
    echo "  --version       Show version number"
    echo ""
    echo "Without options, runs the interactive uninstall process."
    echo ""
}

# Parse command line arguments
FORCE_MODE=false

while [[ $# -gt 0 ]]; do
    case "$1" in
        --help|-h)
            show_help
            exit 0
            ;;
        --verify|-v)
            verify_removal
            exit 0
            ;;
        --force|-f)
            FORCE_MODE=true
            shift
            ;;
        --version)
            echo "WOPR Gaming Mode Uninstaller v${UNINSTALLER_VERSION}"
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            echo "Use --help for usage information."
            exit 1
            ;;
    esac
done

# Run uninstaller
uninstall
