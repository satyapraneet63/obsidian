#!/bin/bash
#
set -Euo pipefail

WOPR_VERSION="12.28"

CONFIG_FILE="/etc/gaming-mode.conf"
[[ -f "$HOME/.gaming-mode.conf" ]] && CONFIG_FILE="$HOME/.gaming-mode.conf"
# shellcheck source=/dev/null
source "$CONFIG_FILE" 2>/dev/null || true
: "${PERFORMANCE_MODE:=enabled}"

NEEDS_RELOGIN=0
NEEDS_REBOOT=0

info(){ echo "[*] $*"; }
warn(){ echo "[!] $*"; }
err(){ echo "[!] $*" >&2; }

die() {
  local msg="$1"; local code="${2:-1}"
  echo "FATAL: $msg" >&2
  logger -t gaming-mode "Installation failed: $msg"
  exit "$code"
}

check_aur_helper_functional() {
  local helper="$1"
  if $helper --version &>/dev/null; then
    return 0
  else
    return 1
  fi
}

rebuild_yay() {
  info "Attempting to rebuild yay..."
  local tmp_dir
  tmp_dir=$(mktemp -d)
  pushd "$tmp_dir" >/dev/null || return 1
  if git clone https://aur.archlinux.org/yay.git && cd yay && makepkg -si --noconfirm; then
    popd >/dev/null || true
    rm -rf "$tmp_dir"
    info "yay rebuilt successfully"
    return 0
  else
    popd >/dev/null || true
    rm -rf "$tmp_dir"
    err "Failed to rebuild yay"
    return 1
  fi
}

validate_environment() {
  command -v pacman  >/dev/null || die "pacman required"
  command -v hyprctl >/dev/null || die "hyprctl required"
  [ -d "$HOME/.config/hypr" ] || die "Hyprland config directory not found (~/.config/hypr)"
}

check_package() { pacman -Qi "$1" &>/dev/null; }

check_nvidia_kernel_params() {
  if ! lspci | grep -qi nvidia; then
    return 0
  fi

  if grep -qE "nvidia[-_]drm\.modeset=1" /proc/cmdline 2>/dev/null; then
    info "NVIDIA kernel parameter nvidia-drm.modeset=1 already configured"
    return 0
  fi

  echo ""
  echo "=== NVIDIA KERNEL PARAMETER CONFIGURATION ==="
  echo "NVIDIA GPU detected but nvidia-drm.modeset=1 is not set."
  echo "This parameter is required for proper Wayland/gamescope support."

  local bootloader=""
  local config_file=""

  if [ -f /boot/limine.conf ]; then
    bootloader="limine"; config_file="/boot/limine.conf"
  elif [ -f /boot/limine/limine.conf ]; then
    bootloader="limine"; config_file="/boot/limine/limine.conf"
  elif [ -d /boot/loader/entries ]; then
    bootloader="systemd-boot"
  elif [ -f /etc/default/grub ]; then
    bootloader="grub"
    info "Detected GRUB bootloader"
  fi

  case "$bootloader" in
    limine)
      echo "Limine config found at: $config_file"
      read -p "Add nvidia-drm.modeset=1 to Limine config? [Y/n]: " -n 1 -r
      echo
      if [[ ! $REPLY =~ ^[Nn]$ ]]; then
        configure_limine_nvidia "$config_file"
      else
        warn "Skipping - you'll need to add nvidia-drm.modeset=1 manually"
        show_manual_nvidia_instructions
      fi
      ;;
    systemd-boot)
      echo ""
      echo "  systemd-boot detected. You need to add nvidia-drm.modeset=1"
      echo "  to your boot entry in /boot/loader/entries/*.conf"
      echo ""
      show_manual_nvidia_instructions
      ;;
    grub)
      echo ""
      read -p "Add nvidia-drm.modeset=1 to GRUB config? [Y/n]: " -n 1 -r
      echo
      if [[ ! $REPLY =~ ^[Nn]$ ]]; then
        configure_grub_nvidia
      else
        warn "Skipping - you'll need to add nvidia-drm.modeset=1 manually"
        show_manual_nvidia_instructions
      fi
      ;;
    *)
      echo ""
      warn "Could not detect bootloader type"
      show_manual_nvidia_instructions
      ;;
  esac
}

configure_limine_nvidia() {
  local config_file="$1"

  info "Backing up Limine config..."
  sudo cp "$config_file" "${config_file}.backup.$(date +%Y%m%d%H%M%S)" || {
    err "Failed to backup Limine config"
    return 1
  }

  info "Adding nvidia-drm.modeset=1 to Limine cmdline..."

  if sudo sed -i '/^[[:space:]]*cmdline:/ s/$/ nvidia-drm.modeset=1/' "$config_file"; then
    # Verify the change was made
    if grep -q "nvidia-drm.modeset=1" "$config_file"; then
      info "Successfully added nvidia-drm.modeset=1 to Limine config"
      echo ""
      echo "  ✓ Limine config updated"
      echo "  ✓ Changes will take effect after reboot"
      echo ""
      NEEDS_REBOOT=1
    else
      err "Failed to add parameter - please add manually"
      show_manual_nvidia_instructions
    fi
  else
    err "Failed to modify Limine config"
    show_manual_nvidia_instructions
  fi
}

configure_grub_nvidia() {
  local grub_default="/etc/default/grub"

  info "Backing up GRUB config..."
  sudo cp "$grub_default" "${grub_default}.backup.$(date +%Y%m%d%H%M%S)" || {
    err "Failed to backup GRUB config"
    return 1
  }

  info "Adding nvidia-drm.modeset=1 to GRUB..."

  if ! grep -q "nvidia-drm.modeset=1" "$grub_default"; then
    sudo sed -i 's/\(GRUB_CMDLINE_LINUX_DEFAULT="[^"]*\)/\1 nvidia-drm.modeset=1/' "$grub_default"

    if grep -q "nvidia-drm.modeset=1" "$grub_default"; then
      info "Regenerating GRUB config..."
      sudo grub-mkconfig -o /boot/grub/grub.cfg || {
        err "Failed to regenerate GRUB config"
        return 1
      }
      info "Successfully configured GRUB for NVIDIA"
      NEEDS_REBOOT=1
    else
      err "Failed to add parameter to GRUB"
      show_manual_nvidia_instructions
    fi
  fi
}

show_manual_nvidia_instructions() {
  cat <<'MSG'
  Manual configuration required:
  Limine: Add nvidia-drm.modeset=1 to cmdline in /boot/limine.conf
  systemd-boot: Add to options in /boot/loader/entries/*.conf
  GRUB: Add to GRUB_CMDLINE_LINUX_DEFAULT, then run grub-mkconfig -o /boot/grub/grub.cfg
MSG
  warn "Gaming Mode may not work correctly without nvidia-drm.modeset=1"
}

# Check if system is a laptop (has battery)
is_laptop() {
  # Check for battery - most reliable laptop indicator
  if [[ -d /sys/class/power_supply ]]; then
    for supply in /sys/class/power_supply/*/type; do
      if [[ -f "$supply" ]] && grep -qi "battery" "$supply" 2>/dev/null; then
        return 0
      fi
    done
  fi
  # Check DMI chassis type (8=Portable, 9=Laptop, 10=Notebook, 14=Sub Notebook)
  if [[ -f /sys/class/dmi/id/chassis_type ]]; then
    local chassis
    chassis=$(cat /sys/class/dmi/id/chassis_type 2>/dev/null)
    case "$chassis" in
      8|9|10|14) return 0 ;;
    esac
  fi
  return 1
}

# Check which GPU has an active display connection
# Returns the driver name of the GPU with connected display
get_display_gpu_driver() {
  # Check each DRM card for connected displays
  for card_path in /sys/class/drm/card[0-9]*; do
    local card_name
    card_name=$(basename "$card_path")
    # Skip render nodes
    [[ "$card_name" == render* ]] && continue

    # Check connectors for this card (HDMI, DP, eDP, etc.)
    for connector in "$card_path"/"$card_name"-*/status; do
      if [[ -f "$connector" ]] && grep -q "^connected$" "$connector" 2>/dev/null; then
        # Found a connected display - get the driver for this card
        local driver_link="$card_path/device/driver"
        if [[ -L "$driver_link" ]]; then
          basename "$(readlink "$driver_link")"
          return 0
        fi
      fi
    done
  done
  return 1
}

# Check if a specific DRM card is an AMD iGPU (integrated) vs dGPU (discrete)
# Uses PCI class and device characteristics to distinguish
# Returns: 0 if iGPU, 1 if dGPU or unknown
is_amd_igpu_card() {
  local card_path="$1"
  local device_path="$card_path/device"

  # Get the PCI device info for more context
  local pci_slot=""
  if [[ -L "$device_path" ]]; then
    pci_slot=$(basename "$(readlink -f "$device_path")")
  fi

  # Get lspci info for this specific device
  local device_info=""
  if [[ -n "$pci_slot" ]]; then
    device_info=$(lspci -s "$pci_slot" 2>/dev/null)
  fi

  # Check for integrated GPU indicators in the device description
  # AMD iGPUs typically contain these strings
  if echo "$device_info" | grep -iqE 'renoir|cezanne|barcelo|rembrandt|phoenix|raphael|lucienne|picasso|raven|vega.*mobile|vega.*integrated|radeon.*graphics|yellow.*carp|green.*sardine|cyan.*skillfish|vangogh|van gogh|mendocino|hawk.*point|strix.*point|strix.*halo|krackan|sarlak'; then
    return 0  # iGPU
  fi

  # Check for discrete GPU indicators
  if echo "$device_info" | grep -iqE 'radeon rx|navi [0-9]|vega 56|vega 64|radeon vii|radeon pro|firepro|polaris|ellesmere|baffin|lexa|radeon [0-9]{3,4}[^0-9]'; then
    return 1  # dGPU
  fi

  # Fallback: Check if device is on PCI bus 00 (typically iGPU) vs higher bus (typically dGPU)
  # iGPUs are usually on bus 00, discrete GPUs on higher numbered buses
  if [[ "$pci_slot" =~ ^0000:00: ]]; then
    return 0  # Likely iGPU
  fi

  return 1  # Default to dGPU
}

# Get detailed info about which GPU has the display connected
# Returns: "nvidia", "intel", "amd-igpu", "amd-dgpu", or empty
get_display_gpu_type() {
  for card_path in /sys/class/drm/card[0-9]*; do
    local card_name
    card_name=$(basename "$card_path")
    [[ "$card_name" == render* ]] && continue

    # Check connectors for this card
    for connector in "$card_path"/"$card_name"-*/status; do
      if [[ -f "$connector" ]] && grep -q "^connected$" "$connector" 2>/dev/null; then
        local driver_link="$card_path/device/driver"
        if [[ -L "$driver_link" ]]; then
          local driver
          driver=$(basename "$(readlink "$driver_link")")

          case "$driver" in
            nvidia)
              echo "nvidia"
              return 0
              ;;
            i915|xe)
              echo "intel"
              return 0
              ;;
            amdgpu)
              # Need to determine if this is iGPU or dGPU
              if is_amd_igpu_card "$card_path"; then
                echo "amd-igpu"
              else
                echo "amd-dgpu"
              fi
              return 0
              ;;
          esac
        fi
      fi
    done
  done
  return 1
}

# Detect hybrid graphics setup (laptop with both Intel/AMD iGPU and NVIDIA dGPU)
# Returns: 0 if hybrid, 1 if not
# Sets: HYBRID_GPU=true/false, DISPLAY_GPU=intel/amd/nvidia, RENDER_GPU=nvidia/amd/intel
detect_hybrid_graphics() {
  local gpu_info
  gpu_info=$(lspci 2>/dev/null | grep -iE 'vga|3d|display' || echo "")

  local has_nvidia=false has_intel=false has_amd_igpu=false has_amd_dgpu=false

  # Check for NVIDIA
  if echo "$gpu_info" | grep -iq nvidia; then
    has_nvidia=true
  fi

  # Check for Intel integrated
  if echo "$gpu_info" | grep -iq intel; then
    has_intel=true
  fi

  # Check for AMD - need to distinguish iGPU from dGPU
  # Use comprehensive patterns for AMD iGPU codenames
  if echo "$gpu_info" | grep -iqE 'amd|radeon'; then
    # Check for integrated indicators - expanded pattern list
    if echo "$gpu_info" | grep -iqE 'renoir|cezanne|barcelo|rembrandt|phoenix|raphael|lucienne|picasso|raven|vega.*mobile|vega.*integrated|radeon.*graphics|yellow.*carp|green.*sardine|cyan.*skillfish|vangogh|van gogh|mendocino|hawk.*point|strix.*point|strix.*halo|krackan|sarlak'; then
      has_amd_igpu=true
    fi
    # Check for discrete indicators - expanded pattern list
    if echo "$gpu_info" | grep -iqE 'radeon rx|navi [0-9]|vega 56|vega 64|radeon vii|radeon pro|firepro|polaris|ellesmere|baffin|lexa|radeon [0-9]{3,4}[^0-9]'; then
      has_amd_dgpu=true
    fi
    # If we can't tell from patterns, use PCI bus heuristic
    if ! $has_amd_igpu && ! $has_amd_dgpu; then
      # Check each AMD GPU's PCI slot to determine if iGPU or dGPU
      local amd_on_bus00=false
      local amd_on_other_bus=false
      while IFS= read -r line; do
        local pci_addr
        pci_addr=$(echo "$line" | awk '{print $1}')
        if [[ "$pci_addr" =~ ^00: ]]; then
          amd_on_bus00=true
        else
          amd_on_other_bus=true
        fi
      done <<< "$(echo "$gpu_info" | grep -iE 'amd|radeon')"

      if $amd_on_bus00; then
        has_amd_igpu=true
      fi
      if $amd_on_other_bus; then
        has_amd_dgpu=true
      fi

      # Final fallback: If NVIDIA is also present, AMD is likely the iGPU
      if ! $has_amd_igpu && ! $has_amd_dgpu; then
        if $has_nvidia; then
          has_amd_igpu=true
        else
          # Single AMD, treat as dGPU (desktop)
          has_amd_dgpu=true
        fi
      fi
    fi
  fi

  # Determine if this is a hybrid setup
  HYBRID_GPU=false
  DISPLAY_GPU="unknown"
  RENDER_GPU="unknown"

  # Check if we have multiple GPUs (potential hybrid)
  local multi_gpu=false
  if { $has_intel && $has_nvidia; } || \
     { $has_amd_igpu && $has_nvidia; } || \
     { $has_amd_igpu && $has_amd_dgpu; }; then
    multi_gpu=true
  fi

  if $multi_gpu; then
    # Multiple GPUs detected - need to determine if this is hybrid (laptop) or desktop

    # Method 1: Check which GPU has the display connected (using improved detection)
    local display_gpu_type
    display_gpu_type=$(get_display_gpu_type)

    if [[ -n "$display_gpu_type" ]]; then
      info "Display connected to: $display_gpu_type"

      case "$display_gpu_type" in
        nvidia)
          # Display on NVIDIA = desktop mode (not hybrid)
          HYBRID_GPU=false
          DISPLAY_GPU="nvidia"
          RENDER_GPU="nvidia"
          info "Desktop mode: Monitor connected to NVIDIA GPU"
          return 1
          ;;
        intel)
          # Display on Intel iGPU - this IS hybrid mode
          HYBRID_GPU=true
          DISPLAY_GPU="intel"
          if $has_nvidia; then
            RENDER_GPU="nvidia"
            info "Hybrid graphics: Intel iGPU (display) + NVIDIA dGPU (render)"
          elif $has_amd_dgpu; then
            RENDER_GPU="amd"
            info "Hybrid graphics: Intel iGPU (display) + AMD dGPU (render)"
          fi
          return 0
          ;;
        amd-igpu)
          # Display on AMD iGPU - hybrid mode
          HYBRID_GPU=true
          DISPLAY_GPU="amd"
          if $has_nvidia; then
            RENDER_GPU="nvidia"
            info "Hybrid graphics: AMD iGPU (display) + NVIDIA dGPU (render)"
          elif $has_amd_dgpu; then
            RENDER_GPU="amd-dgpu"
            info "Hybrid graphics: AMD iGPU (display) + AMD dGPU (render)"
          fi
          return 0
          ;;
        amd-dgpu)
          # Display on AMD dGPU - desktop mode (not hybrid)
          HYBRID_GPU=false
          DISPLAY_GPU="amd"
          RENDER_GPU="amd"
          info "Desktop mode: Monitor connected to AMD dGPU"
          return 1
          ;;
      esac
    fi

    # Method 2: Fall back to laptop detection if display driver check inconclusive
    if is_laptop; then
      info "Laptop detected - assuming hybrid graphics mode"

      if $has_intel && $has_nvidia; then
        HYBRID_GPU=true
        DISPLAY_GPU="intel"
        RENDER_GPU="nvidia"
        info "Hybrid graphics: Intel iGPU + NVIDIA dGPU (laptop)"
        return 0
      elif $has_amd_igpu && $has_nvidia; then
        HYBRID_GPU=true
        DISPLAY_GPU="amd"
        RENDER_GPU="nvidia"
        info "Hybrid graphics: AMD iGPU + NVIDIA dGPU (laptop)"
        return 0
      elif $has_amd_igpu && $has_amd_dgpu; then
        HYBRID_GPU=true
        DISPLAY_GPU="amd-igpu"
        RENDER_GPU="amd-dgpu"
        info "Hybrid graphics: AMD iGPU + AMD dGPU (laptop)"
        return 0
      fi
    else
      # Desktop with multiple GPUs - use the discrete GPU
      info "Desktop detected with multiple GPUs - using discrete GPU"
      if $has_nvidia; then
        DISPLAY_GPU="nvidia"
        RENDER_GPU="nvidia"
        info "Desktop mode: NVIDIA GPU (iGPU ignored)"
      elif $has_amd_dgpu; then
        DISPLAY_GPU="amd"
        RENDER_GPU="amd"
        info "Desktop mode: AMD dGPU (iGPU ignored)"
      fi
      return 1
    fi
  fi

  # Single GPU or detection complete - not hybrid
  if $has_nvidia; then
    DISPLAY_GPU="nvidia"
    RENDER_GPU="nvidia"
  elif $has_amd_dgpu || $has_amd_igpu; then
    DISPLAY_GPU="amd"
    RENDER_GPU="amd"
  elif $has_intel; then
    DISPLAY_GPU="intel"
    RENDER_GPU="intel"
  fi

  info "Detected single/desktop GPU configuration: $DISPLAY_GPU"
  return 1
}

# Get the DRM card device for a specific GPU vendor
get_drm_card_for_gpu() {
  local vendor="$1"
  local pattern=""

  case "$vendor" in
    nvidia) pattern="nvidia" ;;
    intel) pattern="i915" ;;
    amd|amd-igpu|amd-dgpu) pattern="amdgpu" ;;
  esac

  # Find which card uses this driver
  for card in /sys/class/drm/card[0-9]*; do
    local card_name
    card_name=$(basename "$card")
    local driver_link="$card/device/driver"
    if [[ -L "$driver_link" ]]; then
      local driver
      driver=$(basename "$(readlink "$driver_link")")
      if [[ "$driver" == *"$pattern"* ]]; then
        echo "$card_name"
        return 0
      fi
    fi
  done
  return 1
}

install_nvidia_deckmode_env() {
  if ! lspci | grep -qi nvidia; then
    info "No NVIDIA detected; skipping NVIDIA Deck-mode env."
    return 0
  fi

  # Detect hybrid graphics before setting environment
  detect_hybrid_graphics

  local env_file="/etc/environment.d/90-nvidia-gamescope.conf"

  # For hybrid graphics, we need different configuration
  if [[ "$HYBRID_GPU" == "true" ]]; then
    info "Hybrid graphics detected - configuring for PRIME render offload"

    # Remove any existing NVIDIA-only config that would break hybrid
    if [[ -f "$env_file" ]]; then
      # Check if it's the old NVIDIA-only config
      if grep -q "GBM_BACKEND=nvidia-drm" "$env_file" 2>/dev/null; then
        info "Removing old NVIDIA-only config (incompatible with hybrid graphics)"
        sudo rm -f "$env_file"
      fi
    fi

    # For hybrid systems, create a config that enables PRIME offload
    local hybrid_env_file="/etc/environment.d/90-hybrid-gaming.conf"

    if [[ -f "$hybrid_env_file" ]]; then
      info "Hybrid gaming env already present: $hybrid_env_file"
      return 0
    fi

    info "Installing hybrid graphics gaming env..."
    sudo mkdir -p /etc/environment.d

    # Hybrid config: iGPU displays, NVIDIA renders games
    # NOTE: We do NOT set global PRIME offload vars here because they would
    # affect the Wayland compositor (gamescope) which must use iGPU for display.
    # Steam/games handle PRIME offload internally via launch options.
    sudo tee "$hybrid_env_file" >/dev/null <<'EOF'
# Hybrid Graphics Gaming Configuration
# iGPU handles display output (compositor/gamescope)
# NVIDIA dGPU handles game rendering via PRIME offload

# GBM_BACKEND is intentionally NOT set - lets compositor use iGPU
# __GLX_VENDOR_LIBRARY_NAME is intentionally NOT set globally - would break compositor
# __NV_PRIME_RENDER_OFFLOAD is intentionally NOT set globally - games set this themselves

# Steam and gamescope-session handle PRIME offload for games automatically.
# If needed, games can be launched with: prime-run %command%
# Or set launch options: __NV_PRIME_RENDER_OFFLOAD=1 __GLX_VENDOR_LIBRARY_NAME=nvidia %command%
EOF

    info "Installed $hybrid_env_file (PRIME render offload mode)"
    NEEDS_RELOGIN=1
    return 0
  fi

  # Non-hybrid NVIDIA system (desktop with NVIDIA as primary display)
  if [ -f "$env_file" ]; then
    info "NVIDIA gamescope env already present: $env_file"
    return 0
  fi

  info "Installing NVIDIA gamescope env (Deck-mode style)..."
  sudo mkdir -p /etc/environment.d

  sudo tee "$env_file" >/dev/null <<'EOF'
GBM_BACKEND=nvidia-drm
__GLX_VENDOR_LIBRARY_NAME=nvidia
__VK_LAYER_NV_optimus=NVIDIA_only
EOF

  info "Installed $env_file"
  NEEDS_RELOGIN=1
}

check_steam_dependencies() {
  info "Checking Steam dependencies for Arch Linux..."

  info "Force refreshing package database from all mirrors..."
  sudo pacman -Syy || die "Failed to refresh package database"

  echo ""
  echo "================================================================"
  echo "  SYSTEM UPDATE RECOMMENDED"
  echo "================================================================"
  echo ""
  echo "  It's recommended to upgrade your system before installing"
  echo "  gaming dependencies to avoid package version conflicts."
  echo ""
  read -p "Upgrade system now? [Y/n]: " -n 1 -r
  echo
  if [[ ! $REPLY =~ ^[Nn]$ ]]; then
    info "Upgrading system..."
    sudo pacman -Syu || die "Failed to upgrade system"
  fi
  echo ""

  local -a missing_deps=()
  local -a optional_deps=()
  local multilib_enabled=false

  if ! command -v lspci >/dev/null 2>&1; then
    info "Installing pciutils for GPU detection..."
    sudo pacman -S --needed --noconfirm pciutils || die "Failed to install pciutils"
  fi

  if grep -q "^\[multilib\]" /etc/pacman.conf 2>/dev/null; then
    multilib_enabled=true
    info "Multilib repository: enabled"
  else
    err "Multilib repository: NOT enabled (required for Steam)"
    missing_deps+=("multilib-repository")
  fi

  local -a core_deps=(
    "steam"
    "lib32-vulkan-icd-loader"
    "vulkan-icd-loader"
    "lib32-mesa"
    "mesa"
    "mesa-utils"
    "lib32-glibc"
    "lib32-gcc-libs"
    "lib32-libx11"
    "lib32-libxss"
    "lib32-alsa-plugins"
    "lib32-libpulse"
    "lib32-openal"
    "lib32-nss"
    "lib32-libcups"
    "lib32-sdl2-compat"
    "lib32-freetype2"
    "lib32-fontconfig"
    "lib32-libnm"  # Required for Steam NetworkManager integration in gamescope session
    "networkmanager"  # Required for network access in gamescope session (started on-demand)
    "gamemode"
    "lib32-gamemode"
    "ttf-liberation"
    "xdg-user-dirs"
    "kbd"  # Provides chvt for VT switching (prevents "Session paused" black screen)
  )

  local gpu_vendor
  gpu_vendor=$(lspci 2>/dev/null | grep -iE 'vga|3d|display' || echo "")

  local has_nvidia=false has_amd=false

  if echo "$gpu_vendor" | grep -iq nvidia; then
    has_nvidia=true
    info "Detected NVIDIA GPU"
  fi
  if echo "$gpu_vendor" | grep -iqE 'amd|radeon|advanced micro'; then
    has_amd=true
    info "Detected AMD GPU"
  fi
  if echo "$gpu_vendor" | grep -iq intel; then
    info "Detected Intel GPU; no Intel-specific drivers will be installed"
  fi

  local primary_gpu="unknown"
  if $has_nvidia; then
    primary_gpu="nvidia"
  elif $has_amd; then
    primary_gpu="amd"
  fi

  PRIMARY_GPU="$primary_gpu"
  info "Primary GPU selection: $PRIMARY_GPU"

  local -a gpu_deps=()

  if $has_nvidia; then
    gpu_deps+=(
      "nvidia-utils"
      "lib32-nvidia-utils"
      "nvidia-settings"
      "libva-nvidia-driver"
    )
    if ! check_package "nvidia" && ! check_package "nvidia-dkms" && ! check_package "nvidia-open-dkms"; then
      info "Note: You may need to install 'nvidia', 'nvidia-dkms', or 'nvidia-open-dkms' kernel module"
      optional_deps+=("nvidia-dkms")
    fi
  fi

  if $has_amd; then
    gpu_deps+=(
      "vulkan-radeon"
      "lib32-vulkan-radeon"
      # Note: libva-mesa-driver is now built into mesa package
      "libvdpau"
      "lib32-libvdpau"
    )
    ! check_package "xf86-video-amdgpu" && optional_deps+=("xf86-video-amdgpu")
  fi

  if ! $has_nvidia && ! $has_amd; then
    info "No NVIDIA/AMD GPU detected; installing AMD Vulkan drivers as fallback..."
    gpu_deps+=("vulkan-radeon" "lib32-vulkan-radeon")
  fi

  gpu_deps+=(
    "vulkan-tools"
    "vulkan-mesa-layers"
  )

  local -a recommended_deps=(
    "gamescope"
    "mangohud"
    "lib32-mangohud"
    "proton-ge-custom-bin"
    "protontricks"
    "udisks2"
  )

  info "Checking core Steam dependencies..."
  for dep in "${core_deps[@]}"; do
    if ! check_package "$dep"; then
      missing_deps+=("$dep")
    fi
  done

  info "Checking GPU-specific dependencies..."
  for dep in "${gpu_deps[@]}"; do
    if ! check_package "$dep"; then
      missing_deps+=("$dep")
    fi
  done

  info "Checking recommended dependencies..."
  for dep in "${recommended_deps[@]}"; do
    if ! check_package "$dep"; then
      optional_deps+=("$dep")
    fi
  done

  echo ""
  echo "================================================================"
  echo "  STEAM DEPENDENCY CHECK RESULTS"
  echo "================================================================"
  echo ""

  if [ "$multilib_enabled" = false ]; then
    echo "  CRITICAL: Multilib repository must be enabled!"
    echo ""
    echo "  To enable multilib, edit /etc/pacman.conf and uncomment:"
    echo "    [multilib]"
    echo "    Include = /etc/pacman.d/mirrorlist"
    echo ""
    read -p "Enable multilib repository now? [y/N]: " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
      enable_multilib_repo
    else
      die "Multilib repository is required for Steam"
    fi
  fi

  local -a clean_missing=()
  for item in "${missing_deps[@]}"; do
    [[ -n "$item" && "$item" != "multilib-repository" ]] && clean_missing+=("$item")
  done
  missing_deps=("${clean_missing[@]+"${clean_missing[@]}"}")

  if ((${#missing_deps[@]})); then
    echo "  MISSING REQUIRED PACKAGES (${#missing_deps[@]}):"
    for dep in "${missing_deps[@]}"; do
      echo "    - $dep"
    done
    echo ""

    read -p "Install missing required packages? [Y/n]: " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Nn]$ ]]; then
      info "Installing missing dependencies..."
      sudo pacman -S --needed "${missing_deps[@]}" || die "Failed to install Steam dependencies"
      info "Required dependencies installed successfully"
    else
      die "Missing required Steam dependencies"
    fi
  else
    info "All required Steam dependencies are installed!"
  fi

  echo ""
  if ((${#optional_deps[@]})); then
    echo "  RECOMMENDED PACKAGES (${#optional_deps[@]}):"
    for dep in "${optional_deps[@]}"; do
      echo "    - $dep"
    done
    echo ""

    read -p "Install recommended packages? [y/N]: " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
      info "Installing recommended packages..."
      local -a pacman_optional=()
      local -a aur_optional=()
      for dep in "${optional_deps[@]}"; do
        if pacman -Si "$dep" &>/dev/null; then
          pacman_optional+=("$dep")
        else
          aur_optional+=("$dep")
        fi
      done

      if ((${#pacman_optional[@]})); then
        sudo pacman -S --needed --noconfirm "${pacman_optional[@]}" || info "Some optional packages failed to install"
      fi

      if ((${#aur_optional[@]})); then
        echo ""
        info "The following packages are from AUR and need an AUR helper:"
        for dep in "${aur_optional[@]}"; do
          echo "    - $dep"
        done
        echo ""

        local aur_helper_available=""
        if command -v yay >/dev/null 2>&1; then
          if check_aur_helper_functional yay; then
            aur_helper_available="yay"
          else
            warn "yay is installed but broken (needs rebuild after system update)"
            read -p "Rebuild yay now? [Y/n]: " -n 1 -r
            echo
            REPLY=${REPLY:-Y}
            if [[ $REPLY =~ ^[Yy]$ ]] && rebuild_yay && check_aur_helper_functional yay; then
              aur_helper_available="yay"
            fi
          fi
        elif command -v paru >/dev/null 2>&1; then
          if check_aur_helper_functional paru; then
            aur_helper_available="paru"
          fi
        fi

        if [[ -n "$aur_helper_available" ]]; then
          read -p "Install AUR packages with $aur_helper_available? [y/N]: " -n 1 -r
          echo
          if [[ $REPLY =~ ^[Yy]$ ]]; then
            $aur_helper_available -S --needed --noconfirm "${aur_optional[@]}" || info "Some AUR packages failed to install"
          fi
        else
          info "No functional AUR helper found (yay/paru). Install manually if desired."
        fi
      fi
    fi
  else
    info "All recommended packages are already installed!"
  fi

  echo ""
  echo "================================================================"

  check_steam_config
}

enable_multilib_repo() {
  info "Enabling multilib repository..."

  sudo cp /etc/pacman.conf "/etc/pacman.conf.backup.$(date +%Y%m%d%H%M%S)" || die "Failed to backup pacman.conf"
  sudo sed -i '/^#\[multilib\]/,/^#Include/ s/^#//' /etc/pacman.conf || die "Failed to enable multilib"

  if grep -q "^\[multilib\]" /etc/pacman.conf 2>/dev/null; then
    info "Multilib repository enabled successfully"
    echo ""
    info "Updating system to enable multilib packages..."
    read -p "Proceed with system upgrade? [Y/n]: " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Nn]$ ]]; then
      sudo pacman -Syu || die "Failed to update and upgrade system"
    else
      die "System upgrade required after enabling multilib"
    fi
  else
    die "Failed to enable multilib repository"
  fi
}

check_steam_config() {
  info "Checking Steam configuration..."

  local missing_groups=()

  if ! groups | grep -qw 'video'; then
    missing_groups+=("video")
  fi

  if ! groups | grep -qw 'input'; then
    missing_groups+=("input")
  fi

  if ! groups | grep -qw 'wheel'; then
    missing_groups+=("wheel")
  fi

  if ((${#missing_groups[@]})); then
    echo ""
    echo "================================================================"
    echo "  USER GROUP PERMISSIONS"
    echo "================================================================"
    echo ""
    echo "  Your user needs to be added to the following groups:"
    echo ""
    for group in "${missing_groups[@]}"; do
      case "$group" in
        video) echo "    - video  - Required for GPU hardware access" ;;
        input) echo "    - input  - Required for controller/gamepad support" ;;
        wheel) echo "    - wheel  - Required for NetworkManager control in gaming mode" ;;
      esac
    done
    echo ""
    echo "  NOTE: After adding groups, you MUST log out and log back in"
    echo ""
    read -p "Add user to ${missing_groups[*]} group(s)? [Y/n]: " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Nn]$ ]]; then
      local groups_to_add
      groups_to_add=$(IFS=,; echo "${missing_groups[*]}")
      info "Adding user to groups: $groups_to_add"
      if sudo usermod -aG "$groups_to_add" "$USER"; then
        info "Successfully added user to group(s): $groups_to_add"
        NEEDS_RELOGIN=1
      else
        err "Failed to add user to groups"
      fi
    fi
  else
    info "User is in video, input, and wheel groups - permissions OK"
  fi

  if [ -d "$HOME/.steam" ]; then
    info "Steam directory found at ~/.steam"
  fi

  if [ -d "$HOME/.local/share/Steam" ]; then
    info "Steam data directory found at ~/.local/share/Steam"
  fi

  if check_package "wine"; then
    info "Wine is installed (helps with some Windows games)"
  fi

  if [ -f /proc/sys/vm/swappiness ]; then
    local swappiness
    swappiness=$(cat /proc/sys/vm/swappiness)
    if [ "$swappiness" -gt 10 ]; then
      info "Tip: Consider lowering vm.swappiness to 10 for better gaming performance"
    fi
  fi

  local max_files
  max_files=$(ulimit -n 2>/dev/null || echo "0")
  if [ "$max_files" -lt 524288 ]; then
    info "Tip: Increase open file limit for esync support"
  fi
}

setup_performance_permissions() {
  local udev_rules_file="/etc/udev/rules.d/99-gaming-performance.rules"
  local sudoers_file="/etc/sudoers.d/gaming-mode-sysctl"
  local needs_setup=false

  if [ ! -f "$udev_rules_file" ] || [ ! -f "$sudoers_file" ]; then
    needs_setup=true
  fi

  if [ "$needs_setup" = false ]; then
    info "Performance permissions already configured"
    return 0
  fi

  echo ""
  echo "================================================================"
  echo "  PERFORMANCE PERMISSIONS SETUP"
  echo "================================================================"
  echo ""
  echo "  To avoid sudo password prompts during gaming, we need to set"
  echo "  up permissions for CPU and GPU performance control."
  echo ""
  read -p "Set up passwordless performance controls? [Y/n]: " -n 1 -r
  echo

  if [[ $REPLY =~ ^[Nn]$ ]]; then
    info "Skipping permissions setup"
    return 0
  fi

  if [ ! -f "$udev_rules_file" ]; then
    info "Creating udev rules for CPU/GPU performance control..."

    if sudo tee "$udev_rules_file" > /dev/null <<'UDEV_RULES'
# Gaming Mode Performance Control Rules
KERNEL=="cpu[0-9]*", SUBSYSTEM=="cpu", ACTION=="add", RUN+="/bin/chmod 666 /sys/devices/system/cpu/%k/cpufreq/scaling_governor"
KERNEL=="card[0-9]", SUBSYSTEM=="drm", DRIVERS=="amdgpu", ACTION=="add", RUN+="/bin/chmod 666 /sys/class/drm/%k/device/power_dpm_force_performance_level"
KERNEL=="card[0-9]", SUBSYSTEM=="drm", DRIVERS=="i915", ACTION=="add", RUN+="/bin/chmod 666 /sys/class/drm/%k/gt_boost_freq_mhz"
KERNEL=="card[0-9]", SUBSYSTEM=="drm", DRIVERS=="i915", ACTION=="add", RUN+="/bin/chmod 666 /sys/class/drm/%k/gt_min_freq_mhz"
KERNEL=="card[0-9]", SUBSYSTEM=="drm", DRIVERS=="i915", ACTION=="add", RUN+="/bin/chmod 666 /sys/class/drm/%k/gt_max_freq_mhz"
UDEV_RULES
    then
      info "Udev rules created successfully"
      sudo udevadm control --reload-rules || true
      sudo udevadm trigger --subsystem-match=cpu --subsystem-match=drm || true
    fi
  fi

  if [[ -f "$sudoers_file" ]]; then
    info "Performance sudoers already exist at $sudoers_file"
  else
    info "Creating sudoers rule for Performance Mode sysctl tuning..."

    # Create sudoers file directly with sudo tee
    if sudo tee "$sudoers_file" > /dev/null << 'SUDOERS_PERF'
# Gaming Mode - Allow passwordless sysctl for performance tuning
%video ALL=(ALL) NOPASSWD: /usr/bin/sysctl -w kernel.sched_autogroup_enabled=*
%video ALL=(ALL) NOPASSWD: /usr/bin/sysctl -w kernel.sched_migration_cost_ns=*
%video ALL=(ALL) NOPASSWD: /usr/bin/sysctl -w kernel.sched_min_granularity_ns=*
%video ALL=(ALL) NOPASSWD: /usr/bin/sysctl -w kernel.sched_latency_ns=*
%video ALL=(ALL) NOPASSWD: /usr/bin/sysctl -w vm.swappiness=*
%video ALL=(ALL) NOPASSWD: /usr/bin/sysctl -w vm.dirty_ratio=*
%video ALL=(ALL) NOPASSWD: /usr/bin/sysctl -w vm.dirty_background_ratio=*
%video ALL=(ALL) NOPASSWD: /usr/bin/sysctl -w vm.dirty_writeback_centisecs=*
%video ALL=(ALL) NOPASSWD: /usr/bin/sysctl -w vm.dirty_expire_centisecs=*
%video ALL=(ALL) NOPASSWD: /usr/bin/sysctl -w fs.inotify.max_user_watches=*
%video ALL=(ALL) NOPASSWD: /usr/bin/sysctl -w fs.inotify.max_user_instances=*
%video ALL=(ALL) NOPASSWD: /usr/bin/sysctl -w fs.file-max=*
%video ALL=(ALL) NOPASSWD: /usr/bin/sysctl -w net.core.rmem_max=*
%video ALL=(ALL) NOPASSWD: /usr/bin/sysctl -w net.core.wmem_max=*
SUDOERS_PERF
    then
      sudo chmod 0440 "$sudoers_file"
      info "Performance sudoers created successfully"
    else
      err "Failed to create performance sudoers file"
    fi
  fi

  local memlock_file="/etc/security/limits.d/99-gaming-memlock.conf"
  if [ ! -f "$memlock_file" ]; then
    info "Creating memlock limits for gaming performance..."
    if sudo tee "$memlock_file" > /dev/null << 'MEMLOCKCONF'
# Gaming memlock limits - prevents memory from being swapped during gaming
# Required for esync/fsync and low-latency audio
* soft memlock 2147484
* hard memlock 2147484
MEMLOCKCONF
    then
      info "Memlock limits configured (2GB)"
    fi
  fi

  local pipewire_conf_dir="/etc/pipewire/pipewire.conf.d"
  local pipewire_conf="$pipewire_conf_dir/10-gaming-latency.conf"
  if [ ! -f "$pipewire_conf" ]; then
    info "Creating PipeWire low-latency audio configuration..."
    sudo mkdir -p "$pipewire_conf_dir"
    if sudo tee "$pipewire_conf" > /dev/null << 'PIPEWIRECONF'
# Low-latency PipeWire tuning
context.properties = {
    default.clock.min-quantum = 256
}
PIPEWIRECONF
    then
      info "PipeWire gaming latency configured"
    fi
  fi

  info "Performance permissions configured"
  return 0
}

setup_shader_cache() {
  local env_file="/etc/environment.d/99-shader-cache.conf"

  if [ -f "$env_file" ]; then
    info "Shader cache configuration already exists"
    return 0
  fi

  echo ""
  echo "================================================================"
  echo "  SHADER CACHE OPTIMIZATION"
  echo "================================================================"
  echo ""
  echo "  Configuring shader cache sizes for better gaming performance."
  echo "  This reduces stuttering in games by caching compiled shaders."
  echo ""
  read -p "Configure shader cache optimization? [Y/n]: " -n 1 -r
  echo

  if [[ $REPLY =~ ^[Nn]$ ]]; then
    info "Skipping shader cache configuration"
    return 0
  fi

  info "Creating shader cache configuration..."
  sudo mkdir -p /etc/environment.d || { warn "Failed to create /etc/environment.d"; return 0; }
  local tmp_shader
  tmp_shader=$(mktemp) || { warn "Failed to create temp file"; return 0; }

  cat > "$tmp_shader" << 'SHADERCACHE'
# Shader cache tuning
MESA_SHADER_CACHE_MAX_SIZE=12G
MESA_SHADER_CACHE_DISABLE_CLEANUP=1
RADV_PERFTEST=gpl
__GL_SHADER_DISK_CACHE=1
__GL_SHADER_DISK_CACHE_SIZE=12884901888
__GL_SHADER_DISK_CACHE_SKIP_CLEANUP=1
# VKD3D uses default cache path
DXVK_STATE_CACHE=1
# Silence fcitx5 Wayland diagnose notification
FCITX_NO_WAYLAND_DIAGNOSE=1
SHADERCACHE

  if sudo cp "$tmp_shader" "$env_file"; then
    rm -f "$tmp_shader"
    sudo chmod 644 "$env_file"
    info "Shader cache configured for all GPUs (AMD/NVIDIA + Proton)"
  else
    rm -f "$tmp_shader"
    warn "Failed to create shader cache configuration"
  fi
}

setup_fcitx_silence() {
  local env_dir="$HOME/.config/environment.d"
  local env_file="$env_dir/90-fcitx-wayland.conf"
  local hypr_conf="$HOME/.config/hypr/hyprland.conf"

  if [[ -f "$hypr_conf" ]]; then
    if ! grep -q "FCITX_NO_WAYLAND_DIAGNOSE" "$hypr_conf" 2>/dev/null; then
      {
        echo ""
        echo "# Silence fcitx5 Wayland diagnose warning (gaming-mode installer)"
        echo "env = FCITX_NO_WAYLAND_DIAGNOSE,1"
      } >> "$hypr_conf"
      info "Added FCITX_NO_WAYLAND_DIAGNOSE to Hyprland config"
      NEEDS_RELOGIN=1
    fi
  fi

  if [[ ! -f "$env_file" ]] || ! grep -q "FCITX_NO_WAYLAND_DIAGNOSE=1" "$env_file" 2>/dev/null; then
    mkdir -p "$env_dir" || return 0
    cat > "$env_file" <<'EOF'
# Silence fcitx5 Wayland diagnose popup about GTK_IM_MODULE
FCITX_NO_WAYLAND_DIAGNOSE=1
EOF
    info "Created fcitx Wayland silence config"
    NEEDS_RELOGIN=1
  fi
}

configure_elephant_launcher() {
  local cfg="$HOME/.config/elephant/desktopapplications.toml"
  if [[ ! -f "$cfg" ]]; then
    return 0
  fi
  if ! command -v uwsm-app >/dev/null 2>&1; then
    return 0
  fi

  if grep -q '^launch_prefix[[:space:]]*=[[:space:]]*"uwsm-app --"' "$cfg" 2>/dev/null; then
    return 0
  fi

  if grep -q '^launch_prefix[[:space:]]*=' "$cfg" 2>/dev/null; then
    sed -i 's|^launch_prefix[[:space:]]*=.*|launch_prefix = "uwsm-app --"|' "$cfg"
  else
    echo 'launch_prefix = "uwsm-app --"' >> "$cfg"
  fi
  info "Configured Elephant desktopapplications launch_prefix (uwsm-app)"
  restart_elephant_walker
}

restart_elephant_walker() {
  if ! systemctl --user show-environment >/dev/null 2>&1; then
    return 0
  fi
  if command -v omarchy-restart-walker >/dev/null 2>&1; then
    omarchy-restart-walker >/dev/null 2>&1 || true
    return 0
  fi
  systemctl --user restart elephant.service >/dev/null 2>&1 || true
  systemctl --user restart app-walker@autostart.service >/dev/null 2>&1 || true
}

setup_requirements() {
  local -a required_packages=("steam" "gamescope" "mangohud" "python" "python-evdev" "libcap" "gamemode" "curl" "pciutils" "ntfs-3g" "xcb-util-cursor")
  local -a packages_to_install=()
  for pkg in "${required_packages[@]}"; do
    check_package "$pkg" || packages_to_install+=("$pkg")
  done

  if ((${#packages_to_install[@]})); then
    info "The following packages are required: ${packages_to_install[*]}"
    read -p "Install missing packages? [Y/n]: " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Nn]$ ]]; then
      sudo pacman -S --needed "${packages_to_install[@]}" || die "package install failed"
    else
      die "Required packages missing - cannot continue"
    fi
  else
    info "All required packages present."
  fi

  setup_performance_permissions
  setup_fcitx_silence
  setup_shader_cache
  configure_elephant_launcher

  if [[ "${PERFORMANCE_MODE,,}" == "enabled" ]] && command -v gamescope >/dev/null 2>&1; then
    if ! getcap "$(command -v gamescope)" 2>/dev/null | grep -q 'cap_sys_nice'; then
      echo ""
      echo "================================================================"
      echo "  GAMESCOPE CAPABILITY REQUEST"
      echo "================================================================"
      echo ""
      echo "  Performance mode requires granting cap_sys_nice to gamescope."
      echo ""
      read -p "Grant cap_sys_nice to gamescope? [Y/n]: " -n 1 -r
      echo
      if [[ ! $REPLY =~ ^[Nn]$ ]]; then
        sudo setcap 'cap_sys_nice=eip' "$(command -v gamescope)" || warn "Failed to set capability"
        info "Capability granted to gamescope"
      fi
    fi
  fi
}

setup_session_switching() {
  echo ""
  echo "================================================================"
  echo "  SESSION SWITCHING SETUP (Hyprland <-> Gamescope)"
  echo "  Using ChimeraOS gamescope-session packages"
  echo "================================================================"
  echo ""
  echo "  This will:"
  echo "    - Install gamescope-session-git and gamescope-session-steam-git from AUR"
  echo "    - Configure Super+Shift+S to switch to Gaming Mode"
  echo "    - Configure Steam's 'Exit to Desktop' to return to Hyprland"
  echo ""
  read -p "Set up session switching? [Y/n]: " -n 1 -r
  echo
  if [[ $REPLY =~ ^[Nn]$ ]]; then
    info "Skipping session switching setup"
    return 0
  fi

  local current_user="${SUDO_USER:-$USER}"
  local user_home
  user_home=$(eval echo "~$current_user")

  local monitor_width=1920
  local monitor_height=1080
  local monitor_refresh=60
  local monitor_output=""

  if command -v hyprctl >/dev/null 2>&1; then
    local monitor_json
    monitor_json=$(hyprctl monitors -j 2>/dev/null)
    if [[ -n "$monitor_json" ]]; then
      # Parse JSON - try jq first, fall back to grep
      if command -v jq >/dev/null 2>&1; then
        monitor_width=$(echo "$monitor_json" | jq -r '.[0].width // 1920') || monitor_width=1920
        monitor_height=$(echo "$monitor_json" | jq -r '.[0].height // 1080') || monitor_height=1080
        monitor_refresh=$(echo "$monitor_json" | jq -r '.[0].refreshRate // 60 | floor') || monitor_refresh=60
        monitor_output=$(echo "$monitor_json" | jq -r '.[0].name // ""') || monitor_output=""
      else
        # Fallback: grep-based parsing (less reliable but works without jq)
        monitor_width=$(echo "$monitor_json" | grep -o '"width":[[:space:]]*[0-9]*' | head -1 | grep -o '[0-9]*$') || monitor_width=1920
        monitor_height=$(echo "$monitor_json" | grep -o '"height":[[:space:]]*[0-9]*' | head -1 | grep -o '[0-9]*$') || monitor_height=1080
        monitor_refresh=$(echo "$monitor_json" | grep -o '"refreshRate":[[:space:]]*[0-9]*' | head -1 | grep -o '[0-9]*$') || monitor_refresh=60
        monitor_output=$(echo "$monitor_json" | grep -o '"name":[[:space:]]*"[^"]*"' | head -1 | sed 's/.*"\([^"]*\)"$/\1/') || monitor_output=""
      fi
    fi
  fi

  info "Detected display: ${monitor_width}x${monitor_height}@${monitor_refresh}Hz${monitor_output:+ on $monitor_output}"

  info "Checking for old custom session files to clean up..."

  local -a old_files=(
    "/usr/bin/gamescope-session"
    "/usr/share/wayland-sessions/gamescope-session.desktop"
    "/usr/bin/jupiter-biosupdate"
    "/usr/bin/steamos-update"
    "/usr/bin/steamos-select-branch"
    "/usr/bin/steamos-session-select"
  )

  local cleaned=false
  for old_file in "${old_files[@]}"; do
    if [[ -f "$old_file" ]]; then
      info "Removing old file: $old_file"
      sudo rm -f "$old_file" && cleaned=true
    fi
  done

  if $cleaned; then
    info "Old custom session files removed"
  else
    info "No old files to clean up"
  fi

  info "Checking for ChimeraOS gamescope-session packages..."

  local -a aur_packages=()
  local -a packages_to_remove=()

  if ! check_package "gamescope-session-git" && ! check_package "gamescope-session"; then
    aur_packages+=("gamescope-session-git")
  fi

  local steam_scripts_missing=false
  local -a required_steam_scripts=(
    "/usr/bin/steamos-session-select"
    "/usr/bin/steamos-update"
    "/usr/bin/jupiter-biosupdate"
    "/usr/bin/steamos-select-branch"
  )

  for script in "${required_steam_scripts[@]}"; do
    if [[ ! -f "$script" ]]; then
      steam_scripts_missing=true
      break
    fi
  done

  if ! check_package "gamescope-session-steam-git"; then
    if check_package "gamescope-session-steam"; then
      # Non-git variant is installed but missing required scripts
      warn "gamescope-session-steam (non-git) is installed but missing Steam compatibility scripts"
      info "The -git version from ChimeraOS includes required scripts:"
      info "  - steamos-session-select, steamos-update, jupiter-biosupdate, steamos-select-branch"
      packages_to_remove+=("gamescope-session-steam")
    fi
    aur_packages+=("gamescope-session-steam-git")
  elif $steam_scripts_missing; then
    # Package is installed but files are missing (corrupted install)
    warn "gamescope-session-steam-git is installed but Steam compatibility scripts are missing!"
    info "Will reinstall package to restore missing files:"
    for script in "${required_steam_scripts[@]}"; do
      if [[ ! -f "$script" ]]; then
        info "  - Missing: $script"
      fi
    done
    packages_to_remove+=("gamescope-session-steam-git")
    aur_packages+=("gamescope-session-steam-git")
  fi

  if ((${#aur_packages[@]})); then
    echo ""
    echo "  The following AUR packages are required for ChimeraOS session:"
    for pkg in "${aur_packages[@]}"; do
      echo "    - $pkg"
    done
    if ((${#packages_to_remove[@]})); then
      echo ""
      echo "  The following packages need to be replaced:"
      for pkg in "${packages_to_remove[@]}"; do
        echo "    - $pkg (will be removed)"
      done
    fi
    echo ""

    local aur_helper=""
    if command -v yay >/dev/null 2>&1 && check_aur_helper_functional yay; then
      aur_helper="yay"
    elif command -v paru >/dev/null 2>&1 && check_aur_helper_functional paru; then
      aur_helper="paru"
    fi

    if [[ -n "$aur_helper" ]]; then
      read -p "Install ChimeraOS session packages with $aur_helper? [Y/n]: " -n 1 -r
      echo
      if [[ ! $REPLY =~ ^[Nn]$ ]]; then
        # Remove conflicting packages first (non-git variants)
        if ((${#packages_to_remove[@]})); then
          info "Removing conflicting packages: ${packages_to_remove[*]}"
          sudo pacman -Rns --noconfirm "${packages_to_remove[@]}" || {
            warn "Failed to remove old packages, trying to continue anyway..."
          }
        fi

        info "Installing ChimeraOS gamescope-session packages..."
        # Use non-interactive flags to avoid prompts
        # --answeredit None --answerclean None --answerdiff None skip the menus
        $aur_helper -S --needed --noconfirm --answeredit None --answerclean None --answerdiff None "${aur_packages[@]}" || {
          err "Failed to install gamescope-session packages"
          warn "You may need to install them manually: $aur_helper -S ${aur_packages[*]}"
        }
      fi
    else
      warn "No AUR helper found (yay/paru). Please install manually:"
      if ((${#packages_to_remove[@]})); then
        echo "    sudo pacman -Rns ${packages_to_remove[*]}"
      fi
      echo "    yay -S ${aur_packages[*]}"
      echo ""
      read -r -p "Press Enter to continue after installing, or Ctrl+C to abort..."
    fi
  else
    info "ChimeraOS gamescope-session packages already installed (correct -git versions)"
  fi

  info "Setting up NetworkManager integration..."
  if systemctl is-active --quiet iwd; then
    info "Detected iwd is active - configuring NetworkManager to use iwd backend..."
    sudo mkdir -p /etc/NetworkManager/conf.d
    sudo tee /etc/NetworkManager/conf.d/10-iwd-backend.conf > /dev/null << 'NM_IWD_CONF'
# NetworkManager + iwd coexistence
[device]
# Use iwd as the WiFi backend instead of wpa_supplicant
wifi.backend=iwd
wifi.scan-rand-mac-address=no

[main]
# Minimal plugin set - let iwd handle WiFi details
plugins=ifupdown,keyfile

[ifupdown]
# Don't manage interfaces configured in /etc/network/interfaces
managed=false

[connection]
# Don't autoconnect - let iwd/systemd-networkd handle connections
# NetworkManager is only here for Steam's D-Bus API
connection.autoconnect-slaves=0
NM_IWD_CONF
    info "Created NetworkManager iwd backend configuration"
  fi

  if systemctl is-active --quiet systemd-networkd; then
    info "Detected systemd-networkd - configuring NetworkManager to avoid conflicts..."
    sudo tee /etc/NetworkManager/conf.d/20-unmanaged-systemd.conf > /dev/null << 'NM_UNMANAGED'
# Unmanage systemd-networkd interfaces
[keyfile]
# Unmanage ethernet interfaces (systemd-networkd handles these)
unmanaged-devices=interface-name:en*;interface-name:eth*
NM_UNMANAGED
    info "Configured NetworkManager to not manage ethernet interfaces"
  fi

  local nm_start_script="/usr/local/bin/gamescope-nm-start"
  sudo tee "$nm_start_script" > /dev/null << 'NM_START'
#!/bin/bash
# Start NetworkManager for gamescope session

NM_MARKER="/tmp/.gamescope-started-nm"
LOG_TAG="gamescope-nm"

log() { logger -t "$LOG_TAG" "$*"; echo "$*"; }

if ! systemctl is-active --quiet NetworkManager.service; then
    log "Starting NetworkManager service..."
    systemctl start NetworkManager.service

    if [ $? -eq 0 ]; then
        # Mark that we started NM (so nm-stop knows to stop it)
        touch "$NM_MARKER"
        log "NetworkManager started successfully"
    else
        log "ERROR: Failed to start NetworkManager"
        exit 1
    fi

    # Wait for NetworkManager to be fully ready
    log "Waiting for NetworkManager to initialize..."
    for i in {1..20}; do
        if nmcli general status &>/dev/null; then
            log "NetworkManager ready after ${i} attempts"
            break
        fi
        sleep 0.5
    done

    # Verify network connectivity
    if nmcli general status 2>/dev/null | grep -q "connected"; then
        log "Network connected and ready"
    else
        log "WARNING: NetworkManager running but not connected - Steam may have limited network access"
    fi
else
    log "NetworkManager already running"
fi

# Final status for debugging
nmcli general status 2>/dev/null || log "WARNING: nmcli status check failed"
NM_START
  sudo chmod +x "$nm_start_script"

  local nm_stop_script="/usr/local/bin/gamescope-nm-stop"
  sudo tee "$nm_stop_script" > /dev/null << 'NM_STOP'
#!/bin/bash
# Stop NetworkManager after gamescope session ends

NM_MARKER="/tmp/.gamescope-started-nm"

if [ -f "$NM_MARKER" ]; then
    rm -f "$NM_MARKER"
    if systemctl is-active --quiet NetworkManager.service; then
        systemctl stop NetworkManager.service 2>/dev/null || true
    fi
fi
NM_STOP
  sudo chmod +x "$nm_stop_script"
  info "Created NetworkManager start/stop scripts"

  local steam_mount_script="/usr/local/bin/steam-library-mount"
  info "Creating Steam library drive mount script..."
  sudo tee "$steam_mount_script" > /dev/null << 'STEAM_MOUNT'
#!/bin/bash
# Steam Library Drive Auto-Mounter
# Only mounts drives that contain a Steam library (steamapps folder)
# Runs in gamescope session only

LOG_TAG="steam-library-mount"
MOUNT_BASE="/run/media/$USER"

log() { logger -t "$LOG_TAG" "$*"; }

check_steam_library() {
    local mount_point="$1"
    # Check for Steam library markers
    if [[ -d "$mount_point/steamapps" ]] || \
       [[ -d "$mount_point/SteamLibrary/steamapps" ]] || \
       [[ -d "$mount_point/SteamLibrary" ]] || \
       [[ -f "$mount_point/libraryfolder.vdf" ]] || \
       [[ -f "$mount_point/steamapps/libraryfolder.vdf" ]] || \
       [[ -f "$mount_point/SteamLibrary/libraryfolder.vdf" ]]; then
        return 0
    fi
    return 1
}

handle_device() {
    local device="$1"
    local part_name
    part_name=$(basename "$device")

    log "Checking device: $device"

    # Skip if already mounted
    if findmnt -n "$device" &>/dev/null; then
        # Already mounted - check if it has a Steam library
        local existing_mount
        existing_mount=$(findmnt -n -o TARGET "$device" 2>/dev/null)
        if [[ -n "$existing_mount" ]] && check_steam_library "$existing_mount"; then
            log "Steam library already mounted at $existing_mount"
        else
            log "Device $device mounted at $existing_mount (no Steam library)"
        fi
        return
    fi

    # Skip non-partition devices (whole disks)
    [[ "$device" =~ [0-9]$ ]] || { log "Skipping whole disk: $device"; return; }

    # Skip if not a recognized filesystem
    local fstype
    fstype=$(lsblk -n -o FSTYPE --nodeps "$device" 2>/dev/null)
    case "$fstype" in
        ext4|ext3|ext2|btrfs|xfs|ntfs|vfat|exfat|f2fs) ;;
        crypto_LUKS) log "Skipping encrypted: $device"; return ;;
        swap) log "Skipping swap: $device"; return ;;
        "") log "Skipping $device - no filesystem"; return ;;
        *) log "Skipping $device - unsupported filesystem: $fstype"; return ;;
    esac

    # Use udisksctl for mounting (works without root via polkit)
    if ! command -v udisksctl &>/dev/null; then
        log "udisksctl not found - cannot mount $device"
        return
    fi

    # Mount the device temporarily to check for Steam library
    log "Attempting to mount $device..."
    local mount_output
    mount_output=$(udisksctl mount -b "$device" --no-user-interaction 2>&1)
    local mount_rc=$?

    if [[ $mount_rc -ne 0 ]]; then
        log "Could not mount $device: $mount_output"
        return
    fi

    # Get the mount point from udisksctl output or findmnt
    local mount_point
    mount_point=$(findmnt -n -o TARGET "$device" 2>/dev/null)

    if [[ -z "$mount_point" ]]; then
        log "Could not determine mount point for $device"
        return
    fi

    # Check if this is a Steam library
    if check_steam_library "$mount_point"; then
        log "Steam library found on $device at $mount_point - keeping mounted"
    else
        log "No Steam library on $device - unmounting"
        udisksctl unmount -b "$device" --no-user-interaction 2>/dev/null
    fi
}

# Monitor for new block devices
log "Starting Steam library drive monitor..."

# Check existing unmounted partitions first
shopt -s nullglob
for dev in /dev/sd*[0-9]* /dev/nvme*p[0-9]*; do
    [[ -b "$dev" ]] && handle_device "$dev"
done
shopt -u nullglob

log "Initial device scan complete, watching for new devices..."

# Watch for new devices using udevadm monitor
# Parse the sysfs path to get the device name
udevadm monitor --kernel --subsystem-match=block 2>/dev/null | while read -r line; do
    # Match lines like: KERNEL[123.456] add      /devices/.../block/sda/sda1 (block)
    # Capture the LAST path component (partition/device name)
    if [[ "$line" =~ ^KERNEL.*[[:space:]]add[[:space:]]+.*/([^/[:space:]]+)[[:space:]]+\(block\)$ ]]; then
        dev_name="${BASH_REMATCH[1]}"
        dev_path="/dev/$dev_name"

        # Only handle partitions (contain numbers at the end)
        if [[ "$dev_name" =~ [0-9]$ ]] && [[ -b "$dev_path" ]]; then
            sleep 1  # Wait for device to settle
            handle_device "$dev_path"
        fi
    fi
done
STEAM_MOUNT
  sudo chmod +x "$steam_mount_script"
  info "Created $steam_mount_script"

  local polkit_rules="/etc/polkit-1/rules.d/50-gamescope-networkmanager.rules"

  # Use sudo test because polkit rules.d has restricted permissions (root:polkitd)
  if sudo test -f "$polkit_rules"; then
    info "Polkit rules already exist at $polkit_rules"
  else
    info "Creating Polkit rules for NetworkManager D-Bus access..."

    # Create polkit rules directly with sudo tee
    if sudo tee "$polkit_rules" > /dev/null << 'POLKIT_RULES'
// Allow wheel group users passwordless access to NetworkManager D-Bus actions
// Required for Steam's network UI in gamescope session
polkit.addRule(function(action, subject) {
    if ((action.id == "org.freedesktop.NetworkManager.enable-disable-network" ||
         action.id == "org.freedesktop.NetworkManager.enable-disable-wifi" ||
         action.id == "org.freedesktop.NetworkManager.network-control" ||
         action.id == "org.freedesktop.NetworkManager.wifi.scan" ||
         action.id == "org.freedesktop.NetworkManager.settings.modify.system" ||
         action.id == "org.freedesktop.NetworkManager.settings.modify.own" ||
         action.id == "org.freedesktop.NetworkManager.settings.modify.hostname") &&
        subject.isInGroup("wheel")) {
        return polkit.Result.YES;
    }
});
POLKIT_RULES
    then
      sudo chmod 644 "$polkit_rules"
      info "Polkit rules created successfully"
      sudo systemctl restart polkit.service 2>/dev/null || true
    else
      err "Failed to create polkit rules file"
    fi
  fi

  local udisks_polkit="/etc/polkit-1/rules.d/50-udisks-gaming.rules"

  # Use sudo test because polkit rules.d has restricted permissions (root:polkitd)
  if sudo test -f "$udisks_polkit"; then
    info "Udisks2 polkit rules already exist at $udisks_polkit"
  else
    info "Creating Polkit rules for external drive auto-mount..."
    sudo mkdir -p /etc/polkit-1/rules.d
    if sudo tee "$udisks_polkit" > /dev/null << 'UDISKS_POLKIT'
// Allow wheel group users passwordless access to mount/unmount drives
// Required for Steam to detect and use external game libraries
polkit.addRule(function(action, subject) {
    if ((action.id == "org.freedesktop.udisks2.filesystem-mount" ||
         action.id == "org.freedesktop.udisks2.filesystem-mount-system" ||
         action.id == "org.freedesktop.udisks2.filesystem-unmount-others" ||
         action.id == "org.freedesktop.udisks2.encrypted-unlock" ||
         action.id == "org.freedesktop.udisks2.power-off-drive") &&
        subject.isInGroup("wheel")) {
        return polkit.Result.YES;
    }
});
UDISKS_POLKIT
    then
      sudo chmod 644 "$udisks_polkit"
      info "Udisks2 polkit rules created successfully"
      sudo systemctl restart polkit.service 2>/dev/null || true
    else
      err "Failed to create udisks2 polkit rules"
    fi
  fi

  # gamescope-session-plus config
  info "Creating gamescope-session-plus configuration..."
  local env_dir="${user_home}/.config/environment.d"
  local gamescope_conf="${env_dir}/gamescope-session-plus.conf"

  mkdir -p "$env_dir"

  local output_connector=""
  [[ -n "$monitor_output" ]] && output_connector="OUTPUT_CONNECTOR=$monitor_output"

  # Detect GPU configuration
  detect_hybrid_graphics

  local is_nvidia=false
  local is_hybrid=false
  if [[ "$HYBRID_GPU" == "true" ]]; then
    is_hybrid=true
    info "Configuring gamescope for hybrid graphics (${DISPLAY_GPU} display + ${RENDER_GPU} render)"
  elif lspci | grep -qi nvidia; then
    is_nvidia=true
    # Clamp resolution for NVIDIA stability (only for dedicated NVIDIA)
    if [ "$monitor_width" -gt 2560 ]; then
      monitor_width=2560
    fi
    if [ "$monitor_height" -gt 1440 ]; then
      monitor_height=1440
    fi
  fi

  if $is_hybrid; then
    # Hybrid graphics config: iGPU displays, dGPU renders
    cat > "$gamescope_conf" << GAMESCOPE_CONF
# Gamescope Session Plus Configuration
# Generated by WOPR Gaming Mode Installer v${WOPR_VERSION}
# HYBRID GRAPHICS MODE: ${DISPLAY_GPU} (display) + ${RENDER_GPU} (render)

# Display configuration (auto-detected)
SCREEN_WIDTH=${monitor_width}
SCREEN_HEIGHT=${monitor_height}
CUSTOM_REFRESH_RATES=${monitor_refresh}
${output_connector}

# Hybrid graphics: iGPU handles display/compositor, NVIDIA handles game rendering
# Gamescope runs on iGPU (no GBM_BACKEND override)
# Games use NVIDIA via PRIME offload (handled by Steam/wrapper)

# VRR - depends on iGPU capabilities (Intel/AMD typically support VRR)
ADAPTIVE_SYNC=1

# HDR disabled for hybrid - NVIDIA can't output HDR through iGPU
# ENABLE_GAMESCOPE_HDR intentionally omitted

# Storage and drive management (CRITICAL for game installation)
STEAM_ALLOW_DRIVE_UNMOUNT=1

# Silence fcitx warning (safe for all sessions)
FCITX_NO_WAYLAND_DIAGNOSE=1
SDL_VIDEO_MINIMIZE_ON_FOCUS_LOSS=0

# NOTE: PRIME offload vars are NOT set here - they would affect gamescope compositor
# Games get PRIME offload via the session wrapper which sets them for game processes only
GAMESCOPE_CONF
  elif $is_nvidia; then
    # Dedicated NVIDIA config: Let gamescope-session-plus build the command normally
    # but OMIT ADAPTIVE_SYNC and ENABLE_GAMESCOPE_HDR to disable VRR/HDR
    # --force-composition is added via wrapper script (see below)
    cat > "$gamescope_conf" << GAMESCOPE_CONF
# Gamescope Session Plus Configuration
# Generated by WOPR Gaming Mode Installer v${WOPR_VERSION}
# Based on ChimeraOS gamescope-session-steam
# NVIDIA-specific: VRR and HDR disabled, --force-composition via wrapper

# Display configuration (auto-detected)
SCREEN_WIDTH=${monitor_width}
SCREEN_HEIGHT=${monitor_height}
CUSTOM_REFRESH_RATES=${monitor_refresh}
${output_connector}

# NVIDIA: ADAPTIVE_SYNC and ENABLE_GAMESCOPE_HDR intentionally omitted
# gamescope-session-plus checks -n (non-empty), so omitting disables them
# --force-composition is added by /usr/local/lib/gamescope-nvidia/gamescope wrapper

# Storage and drive management (CRITICAL for game installation)
STEAM_ALLOW_DRIVE_UNMOUNT=1

# Silence fcitx warning (safe for all sessions)
FCITX_NO_WAYLAND_DIAGNOSE=1
SDL_VIDEO_MINIMIZE_ON_FOCUS_LOSS=0
GAMESCOPE_CONF
  else
    # AMD/Intel-only config: Enable VRR and HDR
    cat > "$gamescope_conf" << GAMESCOPE_CONF
# Gamescope Session Plus Configuration
# Generated by WOPR Gaming Mode Installer v${WOPR_VERSION}
# Based on ChimeraOS gamescope-session-steam

# Display configuration (auto-detected)
SCREEN_WIDTH=${monitor_width}
SCREEN_HEIGHT=${monitor_height}
CUSTOM_REFRESH_RATES=${monitor_refresh}
${output_connector}

# Enable adaptive sync / VRR
ADAPTIVE_SYNC=1

# Enable HDR if supported
ENABLE_GAMESCOPE_HDR=1

# Storage and drive management (CRITICAL for game installation)
STEAM_ALLOW_DRIVE_UNMOUNT=1

# Silence fcitx warning (safe for all sessions)
FCITX_NO_WAYLAND_DIAGNOSE=1
SDL_VIDEO_MINIMIZE_ON_FOCUS_LOSS=0
GAMESCOPE_CONF
  fi

  info "Created $gamescope_conf"

  info "Creating GPU-specific gamescope wrapper..."
  local gpu_wrapper_dir="/usr/local/lib/gamescope-gpu"
  local gpu_wrapper="${gpu_wrapper_dir}/gamescope"

  sudo mkdir -p "$gpu_wrapper_dir"
  sudo tee "$gpu_wrapper" > /dev/null << 'GPU_WRAPPER'
#!/bin/bash
# GPU-aware gamescope wrapper
# Handles: dedicated NVIDIA, dedicated AMD, Intel, and hybrid graphics

EXTRA_ARGS=""

# Check if laptop
is_laptop() {
    for supply in /sys/class/power_supply/*/type; do
        [[ -f "$supply" ]] && grep -qi "battery" "$supply" 2>/dev/null && return 0
    done
    [[ -f /sys/class/dmi/id/chassis_type ]] && case "$(cat /sys/class/dmi/id/chassis_type 2>/dev/null)" in
        8|9|10|14) return 0 ;;
    esac
    return 1
}

# Check if a DRM card is an AMD iGPU (vs dGPU)
is_amd_igpu_card() {
    local card_path="$1"
    local device_path="$card_path/device"
    local pci_slot=""
    [[ -L "$device_path" ]] && pci_slot=$(basename "$(readlink -f "$device_path")")
    [[ -z "$pci_slot" ]] && return 1

    local device_info=$(lspci -s "$pci_slot" 2>/dev/null)

    # Check for AMD iGPU codenames
    if echo "$device_info" | grep -iqE 'renoir|cezanne|barcelo|rembrandt|phoenix|raphael|lucienne|picasso|raven|vega.*mobile|vega.*integrated|radeon.*graphics|yellow.*carp|green.*sardine|vangogh|van gogh|mendocino|hawk.*point|strix.*point|strix.*halo'; then
        return 0
    fi

    # Check for AMD dGPU indicators
    if echo "$device_info" | grep -iqE 'radeon rx|navi [0-9]|vega 56|vega 64|radeon vii|radeon pro|firepro|polaris|ellesmere|baffin|lexa'; then
        return 1
    fi

    # Fallback: PCI bus 00 = likely iGPU
    [[ "$pci_slot" =~ ^0000:00: ]] && return 0
    return 1
}

# Get display GPU type: nvidia, intel, amd-igpu, amd-dgpu
get_display_gpu_type() {
    for card_path in /sys/class/drm/card[0-9]*; do
        local card_name=$(basename "$card_path")
        [[ "$card_name" == render* ]] && continue
        for connector in "$card_path"/"$card_name"-*/status; do
            if [[ -f "$connector" ]] && grep -q "^connected$" "$connector" 2>/dev/null; then
                local driver_link="$card_path/device/driver"
                [[ -L "$driver_link" ]] || continue
                local driver=$(basename "$(readlink "$driver_link")")
                case "$driver" in
                    nvidia) echo "nvidia"; return 0 ;;
                    i915|xe) echo "intel"; return 0 ;;
                    amdgpu)
                        if is_amd_igpu_card "$card_path"; then
                            echo "amd-igpu"
                        else
                            echo "amd-dgpu"
                        fi
                        return 0
                        ;;
                esac
            fi
        done
    done
    return 1
}

# Detect GPU mode
detect_gpu_mode() {
    local gpu_info=$(lspci 2>/dev/null | grep -iE 'vga|3d|display' || echo "")
    local has_nvidia=false has_intel=false has_amd_igpu=false

    echo "$gpu_info" | grep -iq nvidia && has_nvidia=true
    echo "$gpu_info" | grep -iq intel && has_intel=true
    echo "$gpu_info" | grep -iqE 'renoir|cezanne|barcelo|rembrandt|phoenix|raphael|lucienne|picasso|raven|radeon.*graphics|vangogh|van gogh|mendocino|hawk.*point|strix.*point' && has_amd_igpu=true

    if $has_nvidia && { $has_intel || $has_amd_igpu; }; then
        # Multi-GPU: check display connection
        local display_type=$(get_display_gpu_type)
        case "$display_type" in
            nvidia) echo "nvidia" ;;  # Desktop: monitor on NVIDIA
            intel|amd-igpu) echo "hybrid" ;;  # Hybrid: monitor on iGPU
            amd-dgpu) echo "nvidia" ;;  # Unusual but treat as desktop
            *)
                # Fallback to laptop detection
                if is_laptop; then
                    echo "hybrid"
                else
                    echo "nvidia"
                fi
                ;;
        esac
    elif $has_nvidia; then
        echo "nvidia"
    else
        echo "other"
    fi
}

GPU_MODE=$(detect_gpu_mode)

case "$GPU_MODE" in
    hybrid)
        # Hybrid graphics: iGPU displays, NVIDIA renders games
        # Gamescope compositor runs on iGPU - no special flags needed
        # Games use NVIDIA via PRIME offload (handled by Steam/env vars)
        #
        # Note: --force-composition is NOT used here because:
        # 1. It's a workaround for NVIDIA display driver issues
        # 2. On hybrid, gamescope uses Intel/AMD iGPU which doesn't need it
        EXTRA_ARGS=""
        ;;
    nvidia)
        # Dedicated NVIDIA: Use --force-composition for stability
        if /usr/bin/gamescope --help 2>&1 | grep -q "force-composition"; then
            EXTRA_ARGS="--force-composition"
        fi
        ;;
    *)
        # AMD/Intel only - no special args needed
        ;;
esac

# Call the real gamescope with our extra args plus all original args
exec /usr/bin/gamescope $EXTRA_ARGS "$@"
GPU_WRAPPER

  sudo chmod +x "$gpu_wrapper"
  info "Created $gpu_wrapper"

  # Also create the old path for backward compatibility
  local nvidia_wrapper_dir="/usr/local/lib/gamescope-nvidia"
  sudo mkdir -p "$nvidia_wrapper_dir"
  sudo ln -sf "$gpu_wrapper" "$nvidia_wrapper_dir/gamescope" 2>/dev/null || \
    sudo cp "$gpu_wrapper" "$nvidia_wrapper_dir/gamescope"
  info "Created backward-compatible link at $nvidia_wrapper_dir/gamescope"

  info "Creating NetworkManager session wrapper..."
  local nm_wrapper="/usr/local/bin/gamescope-session-nm-wrapper"

  sudo tee "$nm_wrapper" > /dev/null << 'NM_WRAPPER'
#!/bin/bash
# Gamescope session wrapper (NM + GPU-specific handling + keybind monitor)
# Supports: Dedicated NVIDIA, AMD, Intel, and Hybrid graphics (Intel/AMD iGPU + NVIDIA dGPU)

log() { logger -t gamescope-wrapper "$*"; echo "$*"; }

# Check if system is a laptop
is_laptop() {
    # Check for battery
    for supply in /sys/class/power_supply/*/type; do
        [[ -f "$supply" ]] && grep -qi "battery" "$supply" 2>/dev/null && return 0
    done
    # Check chassis type
    if [[ -f /sys/class/dmi/id/chassis_type ]]; then
        case "$(cat /sys/class/dmi/id/chassis_type 2>/dev/null)" in
            8|9|10|14) return 0 ;;
        esac
    fi
    return 1
}

# Check if a DRM card is an AMD iGPU (vs dGPU)
is_amd_igpu_card() {
    local card_path="$1"
    local device_path="$card_path/device"
    local pci_slot=""
    [[ -L "$device_path" ]] && pci_slot=$(basename "$(readlink -f "$device_path")")
    [[ -z "$pci_slot" ]] && return 1

    local device_info=$(lspci -s "$pci_slot" 2>/dev/null)

    # Check for AMD iGPU codenames
    if echo "$device_info" | grep -iqE 'renoir|cezanne|barcelo|rembrandt|phoenix|raphael|lucienne|picasso|raven|vega.*mobile|vega.*integrated|radeon.*graphics|yellow.*carp|green.*sardine|vangogh|van gogh|mendocino|hawk.*point|strix.*point|strix.*halo'; then
        return 0
    fi

    # Check for AMD dGPU indicators
    if echo "$device_info" | grep -iqE 'radeon rx|navi [0-9]|vega 56|vega 64|radeon vii|radeon pro|firepro|polaris|ellesmere|baffin|lexa'; then
        return 1
    fi

    # Fallback: PCI bus 00 = likely iGPU
    [[ "$pci_slot" =~ ^0000:00: ]] && return 0
    return 1
}

# Get display GPU type: nvidia, intel, amd-igpu, amd-dgpu
get_display_gpu_type() {
    for card_path in /sys/class/drm/card[0-9]*; do
        local card_name=$(basename "$card_path")
        [[ "$card_name" == render* ]] && continue
        for connector in "$card_path"/"$card_name"-*/status; do
            if [[ -f "$connector" ]] && grep -q "^connected$" "$connector" 2>/dev/null; then
                local driver_link="$card_path/device/driver"
                [[ -L "$driver_link" ]] || continue
                local driver=$(basename "$(readlink "$driver_link")")
                case "$driver" in
                    nvidia) echo "nvidia"; return 0 ;;
                    i915|xe) echo "intel"; return 0 ;;
                    amdgpu)
                        if is_amd_igpu_card "$card_path"; then
                            echo "amd-igpu"
                        else
                            echo "amd-dgpu"
                        fi
                        return 0
                        ;;
                esac
            fi
        done
    done
    return 1
}

# Detect GPU mode (hybrid vs dedicated)
detect_gpu_mode() {
    local gpu_info=$(lspci 2>/dev/null | grep -iE 'vga|3d|display' || echo "")
    local has_nvidia=false has_intel=false has_amd_igpu=false

    echo "$gpu_info" | grep -iq nvidia && has_nvidia=true
    echo "$gpu_info" | grep -iq intel && has_intel=true
    echo "$gpu_info" | grep -iqE 'renoir|cezanne|barcelo|rembrandt|phoenix|raphael|lucienne|picasso|raven|radeon.*graphics|vangogh|van gogh|mendocino|hawk.*point|strix.*point' && has_amd_igpu=true

    # Check for multi-GPU setup
    if $has_nvidia && { $has_intel || $has_amd_igpu; }; then
        # Multiple GPUs - check which one has display connected
        local display_type=$(get_display_gpu_type)

        case "$display_type" in
            nvidia)
                # Monitor on NVIDIA = desktop mode, not hybrid
                echo "nvidia"
                return
                ;;
            intel|amd-igpu)
                # Monitor on iGPU = hybrid mode
                echo "hybrid"
                return
                ;;
            amd-dgpu)
                # Monitor on AMD dGPU = desktop mode
                echo "nvidia"  # Treat similar to dedicated NVIDIA
                return
                ;;
        esac

        # Fallback: use laptop detection
        if is_laptop; then
            echo "hybrid"
        else
            # Desktop with iGPU+dGPU, assume dGPU is primary
            echo "nvidia"
        fi
    elif $has_nvidia; then
        echo "nvidia"
    elif $has_amd_igpu || echo "$gpu_info" | grep -iqE 'amd|radeon'; then
        echo "amd"
    else
        echo "intel"
    fi
}

# Cleanup function
cleanup() {
    # Kill Steam library drive monitor
    pkill -f steam-library-mount 2>/dev/null || true
    # Kill keybind monitor
    pkill -f gaming-keybind-monitor 2>/dev/null || true
    sudo -n /usr/local/bin/gamescope-nm-stop 2>/dev/null || true
    rm -f /tmp/.gaming-session-active
}
trap cleanup EXIT INT TERM

# Detect GPU configuration
GPU_MODE=$(detect_gpu_mode)
log "Detected GPU mode: $GPU_MODE"

# GPU-specific gamescope wrappers and environment setup
# By prepending our wrapper directory to PATH, gamescope-session-plus
# will find our wrapper instead of /usr/bin/gamescope

case "$GPU_MODE" in
    hybrid)
        log "Hybrid graphics mode: iGPU display + NVIDIA render"
        # Use the GPU-aware wrapper for gamescope
        export PATH="/usr/local/lib/gamescope-gpu:$PATH"

        # CRITICAL: Do NOT set PRIME offload vars here!
        # These would affect gamescope compositor which MUST use iGPU for display.
        # Steam and gamescope-session-steam handle PRIME offload for games internally.
        #
        # If games don't use NVIDIA automatically, users can add to Steam launch options:
        #   __NV_PRIME_RENDER_OFFLOAD=1 __GLX_VENDOR_LIBRARY_NAME=nvidia __VK_LAYER_NV_optimus=NVIDIA_only %command%
        # Or use: prime-run %command%
        log "Hybrid: gamescope uses iGPU, Steam handles NVIDIA offload for games"
        ;;
    nvidia)
        log "Dedicated NVIDIA mode"
        # Use the GPU-aware wrapper
        export PATH="/usr/local/lib/gamescope-gpu:$PATH"

        # Full NVIDIA display + render (NVIDIA is the only/primary GPU)
        export GBM_BACKEND=nvidia-drm
        export __GLX_VENDOR_LIBRARY_NAME=nvidia
        export __VK_LAYER_NV_optimus=NVIDIA_only
        ;;
    amd|intel)
        log "AMD/Intel GPU mode"
        # No wrapper needed, no special env vars
        ;;
esac

# Start NetworkManager
sudo -n /usr/local/bin/gamescope-nm-start 2>/dev/null || {
    log "Warning: Could not start NetworkManager - Steam network features may not work"
}

# Start Steam library drive auto-mounter (only mounts drives with Steam libraries)
if [[ -x /usr/local/bin/steam-library-mount ]]; then
    /usr/local/bin/steam-library-mount &
    log "Steam library drive monitor started"
else
    log "Warning: steam-library-mount not found - external Steam libraries will not auto-mount"
fi

# Mark gaming session active
echo "gamescope" > /tmp/.gaming-session-active

# Pre-flight check for keybind monitor
keybind_ok=true

# Check python-evdev
if ! python3 -c "import evdev" 2>/dev/null; then
    log "WARNING: python-evdev not installed - Super+Shift+R keybind disabled"
    log "Fix: sudo pacman -S python-evdev"
    keybind_ok=false
fi

# Check input group membership
if ! groups | grep -qw input; then
    log "WARNING: User not in 'input' group - Super+Shift+R keybind disabled"
    log "Fix: sudo usermod -aG input $USER && log out/in"
    keybind_ok=false
fi

# Check if we can access any input devices
if $keybind_ok && ! ls /dev/input/event* >/dev/null 2>&1; then
    log "WARNING: No input devices accessible - Super+Shift+R keybind disabled"
    keybind_ok=false
fi

# Start keybind monitor if checks passed
if $keybind_ok; then
    /usr/local/bin/gaming-keybind-monitor &
    log "Keybind monitor started (Super+Shift+R to exit)"
else
    log "Keybind monitor NOT started - use Steam > Power > Exit to Desktop instead"
fi

# Set Steam-specific environment variables (ONLY for gaming mode, not desktop)
# These must NOT be in environment.d as they break Steam on normal desktop
export QT_IM_MODULE=steam
export GTK_IM_MODULE=Steam
export STEAM_DISABLE_AUDIO_DEVICE_SWITCHING=1
export STEAM_ENABLE_VOLUME_HANDLER=1

# Run gamescope-session-plus (NOT exec - we need to capture exit and do post-session cleanup)
/usr/share/gamescope-session-plus/gamescope-session-plus steam
rc=$?

exit $rc
NM_WRAPPER

  sudo chmod +x "$nm_wrapper"
  info "Created $nm_wrapper"

  info "Creating SDDM session entry..."
  local session_desktop="/usr/share/wayland-sessions/gamescope-session-steam-nm.desktop"

  sudo tee "$session_desktop" > /dev/null << 'SESSION_DESKTOP'
[Desktop Entry]
Name=Gaming Mode (ChimeraOS)
Comment=Steam Big Picture with ChimeraOS gamescope-session
Exec=/usr/local/bin/gamescope-session-nm-wrapper
Type=Application
DesktopNames=gamescope
SESSION_DESKTOP

  info "Created $session_desktop"

  info "Creating session-select script..."
  local os_session_select="/usr/lib/os-session-select"

  sudo tee "$os_session_select" > /dev/null << 'OS_SESSION_SELECT'
#!/bin/bash
# Steam "Exit to Desktop" handler

# Don't use set -e here - we want to continue even if some commands fail

# Clean up gaming session marker
rm -f /tmp/.gaming-session-active

# Update SDDM to boot into Hyprland on next login
# Uses helper script to avoid sudoers sed matching issues
sudo -n /usr/local/bin/gaming-session-switch desktop 2>/dev/null || {
  echo "Warning: Failed to update session config"
}

# Shutdown Steam gracefully (with timeout to prevent hanging)
# Steam should already be shutting down since user clicked "Exit to Desktop"
# but we call this to ensure clean shutdown and state saving
timeout 5 steam -shutdown 2>/dev/null || true

# Brief pause to allow Steam to finish cleanup
sleep 1

# Restart SDDM (this will end the gamescope session and start Hyprland)
# Use nohup and disown to ensure SDDM restart isn't killed with this script
# Use sudo -n to avoid hanging if sudoers matching fails (no TTY available)
nohup sudo -n systemctl restart sddm &>/dev/null &
disown

# Exit immediately - SDDM restart will handle the rest
exit 0
OS_SESSION_SELECT

  sudo chmod +x "$os_session_select"
  info "Created $os_session_select"

  info "Creating switch-to-gaming script..."
  local switch_script="/usr/local/bin/switch-to-gaming"

  sudo tee "$switch_script" > /dev/null << 'SWITCH_SCRIPT'
#!/bin/bash
# Switch to gaming mode

# Note: No set -e to ensure SDDM restart always runs even if earlier commands fail

# Update SDDM to boot into gamescope on next login
# Uses helper script to avoid sudoers sed matching issues
sudo -n /usr/local/bin/gaming-session-switch gaming 2>/dev/null || {
  notify-send -u critical -t 3000 "Gaming Mode" "Failed to update session config" 2>/dev/null || true
}

# Notify user
notify-send -u normal -t 2000 "Gaming Mode" "Switching to Gaming Mode..." 2>/dev/null || true

# Kill any leftover gamescope processes from previous sessions
# This prevents black screen on second launch
pkill -9 gamescope 2>/dev/null || true
pkill -9 -f gamescope-session 2>/dev/null || true

# Small delay for cleanup
sleep 1

# Switch to a different VT first to ensure clean display state
# This is critical to prevent black screen on subsequent launches
sudo -n chvt 2 2>/dev/null || true
sleep 0.3

# Restart SDDM (this will end Hyprland and start gamescope-session)
# This MUST run even if earlier commands failed
sudo -n systemctl restart sddm
SWITCH_SCRIPT

  sudo chmod +x "$switch_script"
  info "Created $switch_script"

  info "Creating switch-to-desktop script..."
  local switch_desktop_script="/usr/local/bin/switch-to-desktop"

  sudo tee "$switch_desktop_script" > /dev/null << 'SWITCH_DESKTOP'
#!/bin/bash
# Switch from gaming mode back to desktop (triggered by Super+Shift+R)

# Only run if we're in a gaming session
if [[ ! -f /tmp/.gaming-session-active ]]; then
  exit 0
fi

# Clean up gaming session marker
rm -f /tmp/.gaming-session-active

# Update SDDM to boot into Hyprland on next login
sudo -n /usr/local/bin/gaming-session-switch desktop 2>/dev/null || true

# Shutdown Steam gracefully (with timeout to prevent hanging)
timeout 5 steam -shutdown 2>/dev/null || true

# Brief pause for Steam cleanup
sleep 1

# Kill any remaining gamescope processes
pkill -9 gamescope 2>/dev/null || true
pkill -9 -f gamescope-session 2>/dev/null || true

sleep 0.5

# Switch VT to ensure clean display state
sudo -n chvt 2 2>/dev/null || true
sleep 0.3

# Restart SDDM (ends gamescope, starts Hyprland)
nohup sudo -n systemctl restart sddm &>/dev/null &
disown

exit 0
SWITCH_DESKTOP

  sudo chmod +x "$switch_desktop_script"
  info "Created $switch_desktop_script"

  info "Creating gaming mode keybind monitor..."
  local keybind_monitor="/usr/local/bin/gaming-keybind-monitor"

  sudo tee "$keybind_monitor" > /dev/null << 'KEYBIND_MONITOR'
#!/usr/bin/env python3
"""
Gaming Mode Keybind Monitor
Monitors for Super+Shift+R to exit gaming mode back to desktop.
Uses evdev to capture keyboard input regardless of compositor.
"""

import sys
import subprocess
import time
import syslog

# Log to both stderr and syslog for visibility
def log(msg, error=False):
    print(msg, file=sys.stderr if error else sys.stdout)
    syslog.syslog(syslog.LOG_ERR if error else syslog.LOG_INFO, msg)

syslog.openlog("gaming-keybind-monitor", syslog.LOG_PID)

try:
    import evdev
    from evdev import ecodes
except ImportError:
    log("FATAL: python-evdev not installed. Super+Shift+R keybind will not work!", error=True)
    log("Fix: sudo pacman -S python-evdev", error=True)
    sys.exit(1)

def find_keyboards():
    """Find all keyboard devices."""
    keyboards = []
    devices_checked = 0
    permission_errors = 0

    for path in evdev.list_devices():
        devices_checked += 1
        try:
            device = evdev.InputDevice(path)
            caps = device.capabilities()
            # Check if device has key events and common keyboard keys
            if ecodes.EV_KEY in caps:
                keys = caps[ecodes.EV_KEY]
                # Must have at least some letter keys to be a keyboard
                if ecodes.KEY_A in keys and ecodes.KEY_R in keys:
                    keyboards.append(device)
        except PermissionError:
            permission_errors += 1
        except Exception:
            continue

    if permission_errors > 0 and not keyboards:
        log(f"FATAL: Permission denied on {permission_errors}/{devices_checked} input devices.", error=True)
        log("Fix: Ensure user is in 'input' group and re-login.", error=True)
        log("Check with: groups | grep input", error=True)

    return keyboards

def monitor_keyboards(keyboards):
    """Monitor keyboards for Super+Shift+R combo."""
    # Track modifier state across all keyboards
    meta_pressed = False
    shift_pressed = False

    # Create selector for multiple devices
    from selectors import DefaultSelector, EVENT_READ
    selector = DefaultSelector()

    # Note: We do NOT grab the keyboard - we just listen passively
    # This allows all keys to still reach gamescope/Steam
    for kbd in keyboards:
        selector.register(kbd, EVENT_READ)

    log(f"Monitoring {len(keyboards)} keyboard(s) for Super+Shift+R...")

    try:
        while True:
            for key, mask in selector.select():
                device = key.fileobj
                try:
                    for event in device.read():
                        if event.type != ecodes.EV_KEY:
                            continue

                        # Track Meta (Super) key
                        if event.code in (ecodes.KEY_LEFTMETA, ecodes.KEY_RIGHTMETA):
                            meta_pressed = event.value > 0

                        # Track Shift key
                        elif event.code in (ecodes.KEY_LEFTSHIFT, ecodes.KEY_RIGHTSHIFT):
                            shift_pressed = event.value > 0

                        # Check for R key press (value=1 is key down)
                        elif event.code == ecodes.KEY_R and event.value == 1:
                            if meta_pressed and shift_pressed:
                                log("Super+Shift+R detected! Switching to desktop...")
                                subprocess.run(['/usr/local/bin/switch-to-desktop'])
                                return  # Exit after triggering
                except Exception as e:
                    log(f"Read error: {e}", error=True)
                    continue
    except KeyboardInterrupt:
        pass
    finally:
        selector.close()

def main():
    # Wait a moment for session to stabilize
    time.sleep(2)

    keyboards = find_keyboards()
    if not keyboards:
        log("FATAL: No accessible keyboards found! Super+Shift+R keybind will not work.", error=True)
        sys.exit(1)

    monitor_keyboards(keyboards)

if __name__ == '__main__':
    main()
KEYBIND_MONITOR

  sudo chmod +x "$keybind_monitor"
  info "Created $keybind_monitor"

  info "Creating SDDM session switching config..."
  local sddm_gaming_conf="/etc/sddm.conf.d/zz-gaming-session.conf"

  local autologin_user="$current_user"
  if [[ -f /etc/sddm.conf.d/autologin.conf ]]; then
    # Use sed instead of grep -oP for portability
    autologin_user=$(sed -n 's/^User=//p' /etc/sddm.conf.d/autologin.conf 2>/dev/null | head -1)
    [[ -z "$autologin_user" ]] && autologin_user="$current_user"
  fi

  sudo tee "$sddm_gaming_conf" > /dev/null << SDDM_GAMING
# Gaming Mode Session Switching Config
# Managed by WOPR Gaming Mode Installer
# This file controls which session SDDM auto-logs into
# Named with 'zz-' prefix to ensure it's read last and overrides other configs

[Autologin]
User=${autologin_user}
Session=hyprland-uwsm
Relogin=true
SDDM_GAMING

  info "Created $sddm_gaming_conf"

  info "Creating session switching helper script..."
  local session_helper="/usr/local/bin/gaming-session-switch"

  sudo tee "$session_helper" > /dev/null << 'SESSION_HELPER'
#!/bin/bash
# Session switch helper

CONF="/etc/sddm.conf.d/zz-gaming-session.conf"

if [[ ! -f "$CONF" ]]; then
  echo "Error: Config file not found: $CONF" >&2
  exit 1
fi

case "$1" in
  gaming)
    sed -i 's/^Session=.*/Session=gamescope-session-steam-nm/' "$CONF"
    echo "Session set to: gaming mode"
    ;;
  desktop)
    sed -i 's/^Session=.*/Session=hyprland-uwsm/' "$CONF"
    echo "Session set to: desktop mode"
    ;;
  *)
    echo "Usage: $0 {gaming|desktop}" >&2
    exit 1
    ;;
esac
SESSION_HELPER

  sudo chmod +x "$session_helper"
  info "Created $session_helper"

  local sudoers_session="/etc/sudoers.d/gaming-session-switch"

  if [[ -f "$sudoers_session" ]]; then
    info "Removing old sudoers rules to update..."
    sudo rm -f "$sudoers_session"
  fi

  info "Creating sudoers rules for session switching..."

  if sudo tee "$sudoers_session" > /dev/null << 'SUDOERS_SWITCH'
# Gaming Mode - Passwordless session switching and NetworkManager control
# Session switching - uses helper script to avoid sed argument matching issues
%video ALL=(ALL) NOPASSWD: /usr/local/bin/gaming-session-switch
%video ALL=(ALL) NOPASSWD: /usr/bin/systemctl restart sddm
# VT switching to prevent black screen on second gaming mode launch
%video ALL=(ALL) NOPASSWD: /usr/bin/chvt

# NetworkManager control for Steam network access in gamescope session
%wheel ALL=(ALL) NOPASSWD: /usr/bin/systemctl start NetworkManager.service
%wheel ALL=(ALL) NOPASSWD: /usr/bin/systemctl stop NetworkManager.service
%wheel ALL=(ALL) NOPASSWD: /usr/local/bin/gamescope-nm-start
%wheel ALL=(ALL) NOPASSWD: /usr/local/bin/gamescope-nm-stop
SUDOERS_SWITCH
  then
    sudo chmod 0440 "$sudoers_session"
    info "Sudoers rules created successfully"
  else
    err "Failed to create sudoers file"
  fi

  info "Adding Hyprland keybind..."
  local hypr_bindings_conf="${user_home}/.config/hypr/bindings.conf"

  if [[ ! -f "$hypr_bindings_conf" ]]; then
    warn "bindings.conf not found at $hypr_bindings_conf - skipping keybind setup"
    warn "You can manually add: bindd = SUPER SHIFT, S, Gaming Mode, exec, /usr/local/bin/switch-to-gaming"
  else
    # Check if keybind already exists
    if grep -q "switch-to-gaming" "$hypr_bindings_conf" 2>/dev/null; then
      info "Gaming Mode keybind already exists in bindings.conf"
    else
      # Append keybind to bindings.conf
      cat >> "$hypr_bindings_conf" << 'HYPR_GAMING'

# Gaming Mode - Switch to Gamescope session (Steam Big Picture)
bindd = SUPER SHIFT, S, Gaming Mode, exec, /usr/local/bin/switch-to-gaming
HYPR_GAMING
      info "Added Gaming Mode keybind to bindings.conf"
    fi
  fi

  info "Steam compatibility scripts provided by gamescope-session-steam-git"

  info "Verifying NetworkManager integration..."
  echo ""

  local nm_test_ok=true

  # Test if NM can start
  if ! systemctl is-active --quiet NetworkManager.service; then
    info "Testing NetworkManager startup..."
    if sudo systemctl start NetworkManager.service 2>/dev/null; then
      sleep 2
      if nmcli general status &>/dev/null; then
        info "NetworkManager started successfully"
        # Check if it sees network
        if nmcli general status 2>/dev/null | grep -qE "connected|connecting"; then
          info "NetworkManager can see network - Steam network access should work"
        else
          warn "NetworkManager running but shows disconnected"
          warn "This is expected if iwd/systemd-networkd manages your connection"
          info "Steam should still be able to use the network via D-Bus"
        fi
        # Stop it if we started it (gamescope-session will start it when needed)
        sudo systemctl stop NetworkManager.service 2>/dev/null || true
      else
        nm_test_ok=false
        err "NetworkManager started but nmcli not responding"
      fi
    else
      nm_test_ok=false
      err "Failed to start NetworkManager for testing"
    fi
  else
    info "NetworkManager already running - integration should work"
  fi

  echo ""
  echo "================================================================"
  echo "  SESSION SWITCHING CONFIGURED (ChimeraOS)"
  echo "================================================================"
  echo ""
  echo "  Usage:"
  echo "    - Press Super+Shift+S in Hyprland to switch to Gaming Mode"
  echo "    - Press Super+Shift+R in Gaming Mode to return to Hyprland"
  echo "    - (Steam's Power > Exit to Desktop also works as fallback)"
  echo ""
  echo "  ChimeraOS packages installed:"
  echo "    - gamescope-session-git (base session framework)"
  echo "    - gamescope-session-steam-git (Steam session)"
  echo ""
  echo "  Files created/modified:"
  echo "    - ~/.config/environment.d/gamescope-session-plus.conf"
  echo "    - /usr/local/bin/gamescope-session-nm-wrapper"
  echo "    - /usr/share/wayland-sessions/gamescope-session-steam-nm.desktop"
  echo "    - /usr/lib/os-session-select"
  echo "    - /usr/local/bin/switch-to-gaming"
  echo "    - /usr/local/bin/switch-to-desktop"
  echo "    - /usr/local/bin/gaming-keybind-monitor (Super+Shift+R)"
  echo "    - ~/.config/hypr/bindings.conf (keybind added)"
  echo ""
  echo "  NetworkManager integration (Steam network access):"
  echo "    - /usr/local/bin/gamescope-nm-start"
  echo "    - /usr/local/bin/gamescope-nm-stop"
  echo "    - /etc/polkit-1/rules.d/50-gamescope-networkmanager.rules"
  echo "    - /etc/sudoers.d/gaming-session-switch (NM rules added)"

  # Show iwd/systemd-networkd coexistence config if created
  if [[ -f /etc/NetworkManager/conf.d/10-iwd-backend.conf ]]; then
    echo "    - /etc/NetworkManager/conf.d/10-iwd-backend.conf (iwd backend)"
  fi
  if [[ -f /etc/NetworkManager/conf.d/20-unmanaged-systemd.conf ]]; then
    echo "    - /etc/NetworkManager/conf.d/20-unmanaged-systemd.conf (systemd-networkd coexistence)"
  fi
  echo ""

  # Show hybrid graphics info if detected
  if [[ "$HYBRID_GPU" == "true" ]]; then
    echo "  HYBRID GRAPHICS DETECTED:"
    echo "    - Display: ${DISPLAY_GPU} (integrated GPU)"
    echo "    - Render:  ${RENDER_GPU} (discrete GPU)"
    echo ""
    echo "  Gamescope runs on ${DISPLAY_GPU} iGPU for display output."
    echo "  Steam automatically uses ${RENDER_GPU} for game rendering."
    echo ""
    echo "  If a game doesn't use the NVIDIA GPU, add to Steam launch options:"
    echo "    __NV_PRIME_RENDER_OFFLOAD=1 __GLX_VENDOR_LIBRARY_NAME=nvidia %command%"
    echo ""
  fi

  if [[ "$nm_test_ok" != "true" ]]; then
    echo "  WARNING: NetworkManager test failed!"
    echo "  Steam may not have network access in Gaming Mode."
    echo ""
    echo "  Troubleshooting:"
    echo "    1. Ensure NetworkManager is installed: pacman -S networkmanager"
    echo "    2. Check if iwd is running: systemctl status iwd"
    echo "    3. Try manually: sudo systemctl start NetworkManager && nmcli general"
    echo "    4. Check logs: journalctl -u NetworkManager -n 50"
    echo ""
  fi

  # Reload Hyprland config if running
  if command -v hyprctl >/dev/null 2>&1 && hyprctl monitors >/dev/null 2>&1; then
    hyprctl reload >/dev/null 2>&1 && info "Hyprland config reloaded" || true
  fi

  return 0
}

verify_installation() {
  echo ""
  echo "================================================================"
  echo "  GAMING MODE INSTALLATION VERIFICATION"
  echo "================================================================"
  echo ""

  local all_ok=true
  local missing_files=()
  local permission_issues=()

  # Define all files that should be created
  declare -A expected_files=(
    # ChimeraOS session wrapper and scripts
    ["/usr/local/bin/gamescope-session-nm-wrapper"]="755:ChimeraOS session with NM wrapper"
    ["/usr/local/lib/gamescope-gpu/gamescope"]="755:GPU-aware gamescope wrapper"
    ["/usr/local/lib/gamescope-nvidia/gamescope"]="777:NVIDIA gamescope wrapper link (optional)"
    ["/usr/local/bin/gaming-session-switch"]="755:Session switching helper (gaming/desktop)"
    ["/usr/lib/os-session-select"]="755:Steam Exit to Desktop handler"
    ["/usr/local/bin/switch-to-gaming"]="755:Hyprland to Gaming Mode switcher"
    ["/usr/local/bin/switch-to-desktop"]="755:Gaming Mode to Desktop switcher (Super+Shift+R)"
    ["/usr/local/bin/gaming-keybind-monitor"]="755:Keybind monitor for Super+Shift+R"
    ["/usr/local/bin/gamescope-nm-start"]="755:NetworkManager start script"
    ["/usr/local/bin/gamescope-nm-stop"]="755:NetworkManager stop script"
    ["/usr/local/bin/steam-library-mount"]="755:Steam library drive auto-mount script"
    # Steam compatibility scripts - provided by gamescope-session-steam-git
    ["/usr/bin/steamos-session-select"]="755:Steam compatibility (from AUR package)"
    ["/usr/bin/steamos-update"]="755:Steam compatibility (from AUR package)"
    ["/usr/bin/jupiter-biosupdate"]="755:Steam compatibility (from AUR package)"
    ["/usr/bin/steamos-select-branch"]="755:Steam compatibility (from AUR package)"
    # Session files
    ["/usr/share/wayland-sessions/gamescope-session-steam-nm.desktop"]="644:SDDM session entry"
    # ChimeraOS packages (from AUR)
    ["/usr/share/gamescope-session-plus/gamescope-session-plus"]="755:ChimeraOS session launcher (from AUR)"
    # Config files
    ["/etc/sddm.conf.d/zz-gaming-session.conf"]="644:SDDM session switching config"
    ["/etc/polkit-1/rules.d/50-gamescope-networkmanager.rules"]="644:Polkit NM rules"
    ["/etc/polkit-1/rules.d/50-udisks-gaming.rules"]="644:Polkit udisks2 rules (external drive mount)"
    ["/etc/sudoers.d/gaming-session-switch"]="440:Sudoers rules"
    # NetworkManager coexistence (optional - only if iwd/systemd-networkd active)
    ["/etc/NetworkManager/conf.d/10-iwd-backend.conf"]="644:NM iwd backend config (optional)"
    ["/etc/NetworkManager/conf.d/20-unmanaged-systemd.conf"]="644:NM systemd coexistence (optional)"
    # Performance configs
    ["/etc/udev/rules.d/99-gaming-performance.rules"]="644:Udev performance rules"
    ["/etc/sudoers.d/gaming-mode-sysctl"]="440:Performance sudoers"
    ["/etc/security/limits.d/99-gaming-memlock.conf"]="644:Memlock limits"
    ["/etc/pipewire/pipewire.conf.d/10-gaming-latency.conf"]="644:PipeWire low-latency"
    ["/etc/environment.d/99-shader-cache.conf"]="644:Shader cache config"
    # GPU-specific configs (optional - depends on GPU type)
    ["/etc/environment.d/90-nvidia-gamescope.conf"]="644:NVIDIA gamescope env (optional)"
    ["/etc/environment.d/90-hybrid-gaming.conf"]="644:Hybrid graphics gaming env (optional)"
  )

  # Check each file
  echo "  FILE STATUS:"
  echo "  ------------"
  echo ""

  for file in "${!expected_files[@]}"; do
    local expected_perm="${expected_files[$file]%%:*}"
    local description="${expected_files[$file]#*:}"
    local is_optional=false

    [[ "$description" == *"(optional)"* ]] && is_optional=true

    # Use sudo test for files in restricted directories (sudoers.d, polkit rules)
    if sudo test -f "$file" 2>/dev/null; then
      # Get actual permissions (last 3 digits of octal) - need sudo for restricted dirs
      local actual_perm
      actual_perm=$(sudo stat -c "%a" "$file" 2>/dev/null)

      if [[ "$actual_perm" == "$expected_perm" ]]; then
        printf "  ✓ %-55s [%s] OK\n" "$file" "$actual_perm"
      else
        printf "  ⚠ %-55s [%s] (expected %s)\n" "$file" "$actual_perm" "$expected_perm"
        permission_issues+=("$file: has $actual_perm, expected $expected_perm")
        all_ok=false
      fi
    else
      if $is_optional; then
        printf "  - %-55s [SKIPPED] %s\n" "$file" "(optional)"
      else
        printf "  ✗ %-55s [MISSING]\n" "$file"
        missing_files+=("$file: $description")
        all_ok=false
      fi
    fi
  done

  # Check Hyprland keybind
  echo ""
  echo "  HYPRLAND KEYBIND:"
  echo "  -----------------"
  local hypr_bindings="$HOME/.config/hypr/bindings.conf"
  if [[ -f "$hypr_bindings" ]]; then
    if grep -q "switch-to-gaming" "$hypr_bindings" 2>/dev/null; then
      echo "  ✓ Gaming Mode keybind (Super+Shift+S) configured"
    else
      echo "  ✗ Gaming Mode keybind NOT found in bindings.conf"
      all_ok=false
    fi
  else
    echo "  ⚠ bindings.conf not found - keybind needs manual setup"
  fi

  # Check ChimeraOS packages
  echo ""
  echo "  CHIMERAOS PACKAGES:"
  echo "  -------------------"
  if check_package "gamescope-session-git" || check_package "gamescope-session"; then
    echo "  ✓ gamescope-session installed"
  else
    echo "  ✗ gamescope-session NOT installed"
    all_ok=false
  fi
  if check_package "gamescope-session-steam-git" || check_package "gamescope-session-steam"; then
    echo "  ✓ gamescope-session-steam installed"
  else
    echo "  ✗ gamescope-session-steam NOT installed"
    all_ok=false
  fi

  # Check Steam library drive auto-mount support
  echo ""
  echo "  STEAM LIBRARY DRIVE SUPPORT:"
  echo "  -----------------------------"
  if [[ -x "/usr/local/bin/steam-library-mount" ]]; then
    echo "  ✓ steam-library-mount script installed"
  else
    echo "  ✗ steam-library-mount NOT found - external Steam libraries will not auto-mount"
    all_ok=false
  fi
  if check_package "udisks2"; then
    echo "  ✓ udisks2 installed (mount backend)"
  else
    echo "  ✗ udisks2 NOT installed"
    all_ok=false
  fi
  # Use sudo test because polkit rules.d has restricted permissions (root:polkitd)
  if sudo test -f "/etc/polkit-1/rules.d/50-udisks-gaming.rules" 2>/dev/null; then
    echo "  ✓ udisks2 polkit rules configured"
  else
    echo "  ✗ udisks2 polkit rules NOT found"
    all_ok=false
  fi

  # Check keybind monitor dependencies
  echo ""
  echo "  KEYBIND MONITOR (Super+Shift+R):"
  echo "  ---------------------------------"
  local keybind_ok=true

  if check_package "python-evdev"; then
    echo "  ✓ python-evdev installed"
  else
    echo "  ✗ python-evdev NOT installed"
    keybind_ok=false
    all_ok=false
  fi

  if python3 -c "import evdev" 2>/dev/null; then
    echo "  ✓ python-evdev importable"
  else
    echo "  ✗ python-evdev cannot be imported"
    keybind_ok=false
    all_ok=false
  fi

  # Check input group (required for /dev/input access)
  if groups 2>/dev/null | grep -qw input; then
    echo "  ✓ User in 'input' group"
  else
    echo "  ✗ User NOT in 'input' group (required for keybind)"
    keybind_ok=false
    all_ok=false
  fi

  # Test actual input device access
  local -a input_devices=(/dev/input/event*)
  if [[ -e "${input_devices[0]}" ]]; then
    # Try to read one device (requires input group)
    local test_device="${input_devices[0]}"
    if [[ -r "$test_device" ]]; then
      echo "  ✓ Can read input devices"
    else
      echo "  ✗ Cannot read $test_device (permission denied)"
      echo "    (May need to log out/in after adding to input group)"
      keybind_ok=false
      all_ok=false
    fi
  else
    echo "  ⚠ No /dev/input/event* devices found"
  fi

  if $keybind_ok; then
    echo "  → Super+Shift+R keybind should work"
  else
    echo "  → Super+Shift+R keybind will NOT work (use Steam > Power > Exit to Desktop)"
  fi

  # Check GPU configuration
  echo ""
  echo "  GPU CONFIGURATION:"
  echo "  ------------------"

  # Detect GPU setup
  detect_hybrid_graphics

  if [[ "$HYBRID_GPU" == "true" ]]; then
    echo "  ✓ Hybrid graphics detected: ${DISPLAY_GPU} (display) + ${RENDER_GPU} (render)"

    # Check for hybrid config file
    if [[ -f "/etc/environment.d/90-hybrid-gaming.conf" ]]; then
      echo "  ✓ Hybrid gaming environment configured"
    else
      echo "  ⚠ Hybrid gaming environment not found"
      echo "    (Run installer to configure PRIME offload)"
    fi

    # Check that old NVIDIA-only config is not present
    if [[ -f "/etc/environment.d/90-nvidia-gamescope.conf" ]]; then
      if grep -q "GBM_BACKEND=nvidia-drm" "/etc/environment.d/90-nvidia-gamescope.conf" 2>/dev/null; then
        echo "  ⚠ WARNING: NVIDIA-only config present - may conflict with hybrid mode"
        echo "    Consider removing: /etc/environment.d/90-nvidia-gamescope.conf"
        all_ok=false
      fi
    fi
  elif lspci 2>/dev/null | grep -qi nvidia; then
    echo "  ✓ Dedicated NVIDIA GPU detected"

    if [[ -f "/etc/environment.d/90-nvidia-gamescope.conf" ]]; then
      echo "  ✓ NVIDIA gamescope environment configured"
    else
      echo "  ⚠ NVIDIA gamescope environment not found"
    fi
  else
    echo "  ✓ AMD/Intel GPU detected (no special config needed)"
  fi

  # Check GPU wrapper
  if [[ -x "/usr/local/lib/gamescope-gpu/gamescope" ]]; then
    echo "  ✓ GPU-aware gamescope wrapper installed"
  else
    echo "  ⚠ GPU-aware gamescope wrapper not found"
  fi

  # Check user config file
  echo ""
  echo "  USER CONFIG:"
  echo "  ------------"
  local user_conf="$HOME/.config/environment.d/gamescope-session-plus.conf"
  if [[ -f "$user_conf" ]]; then
    echo "  ✓ gamescope-session-plus.conf exists"
  else
    echo "  ✗ gamescope-session-plus.conf NOT found"
    all_ok=false
  fi

  # Check user groups
  echo ""
  echo "  USER GROUPS:"
  echo "  ------------"
  local user_groups
  user_groups=$(groups 2>/dev/null)
  for grp in video input wheel; do
    if echo "$user_groups" | grep -qw "$grp"; then
      printf "  ✓ User is in '%s' group\n" "$grp"
    else
      printf "  ✗ User is NOT in '%s' group\n" "$grp"
      all_ok=false
    fi
  done

  # Check services
  echo ""
  echo "  SERVICE STATUS:"
  echo "  ---------------"
  echo "  NetworkManager: $(systemctl is-active NetworkManager.service 2>/dev/null || echo 'inactive') (should be inactive until gaming mode)"
  echo "  iwd:            $(systemctl is-active iwd.service 2>/dev/null || echo 'inactive')"
  echo "  systemd-networkd: $(systemctl is-active systemd-networkd.service 2>/dev/null || echo 'inactive')"
  echo "  polkit:         $(systemctl is-active polkit.service 2>/dev/null || echo 'inactive')"

  # Test sudo -n for NM control
  echo ""
  echo "  SUDO PERMISSIONS TEST:"
  echo "  ----------------------"
  if sudo -n true 2>/dev/null; then
    echo "  ✓ sudo -n works (passwordless sudo available)"
    if sudo -n -l /usr/local/bin/gamescope-nm-start &>/dev/null; then
      echo "  ✓ Can run gamescope-nm-start without password"
    else
      echo "  ✗ Cannot run gamescope-nm-start without password"
      all_ok=false
    fi
  else
    echo "  ⚠ sudo -n test skipped (requires recent sudo auth)"
    echo "    Run: sudo -v && sudo -n -l /usr/local/bin/gamescope-nm-start"
  fi

  # Summary
  echo ""
  echo "================================================================"
  if $all_ok; then
    echo "  ✓ ALL CHECKS PASSED - Gaming Mode should work correctly"
  else
    echo "  ⚠ SOME ISSUES DETECTED"
    echo ""
    if ((${#missing_files[@]})); then
      echo "  Missing files (${#missing_files[@]}):"
      for f in "${missing_files[@]}"; do
        echo "    - $f"
      done
    fi
    if ((${#permission_issues[@]})); then
      echo ""
      echo "  Permission issues (${#permission_issues[@]}):"
      for p in "${permission_issues[@]}"; do
        echo "    - $p"
      done
    fi
    echo ""
    echo "  Re-run the installer to fix these issues."
  fi
  echo "================================================================"
  echo ""

  $all_ok && return 0 || return 1
}

execute_setup() {
  sudo -k
  sudo -v || die "sudo authentication required"

  validate_environment

  echo ""
  echo "================================================================"
  echo "  WOPR GAMING MODE INSTALLER v${WOPR_VERSION}"
  echo "  Dependencies & GPU Configuration"
  echo "================================================================"
  echo ""

  # Check and install dependencies
  check_steam_dependencies

  # Check for NVIDIA kernel parameters (warn if missing)
  check_nvidia_kernel_params

  # Install NVIDIA Deck-mode environment variables (if NVIDIA GPU detected)
  install_nvidia_deckmode_env

  # Setup performance permissions, shader cache, etc.
  setup_requirements

  # Setup session switching (Hyprland <-> Gamescope)
  setup_session_switching

  # Handle reboot/relogin requirements
  if [ "$NEEDS_REBOOT" -eq 1 ]; then
    echo ""
    echo "================================================================"
    echo "  IMPORTANT: REBOOT REQUIRED"
    echo "================================================================"
    echo ""
    echo "  Bootloader configuration has been updated (nvidia-drm.modeset=1)."
    echo "  You MUST reboot for the kernel parameter to take effect."
    echo ""
    if [ "$NEEDS_RELOGIN" -eq 1 ]; then
      echo "  Additionally, user groups were updated (video/input/wheel)."
    fi
    echo ""
    read -p "Reboot now? [y/N]: " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
      info "Rebooting..."
      sleep 2
      systemctl reboot
    else
      echo ""
      echo "  Remember to reboot before continuing!"
      echo ""
    fi
  elif [ "$NEEDS_RELOGIN" -eq 1 ]; then
    echo ""
    echo "================================================================"
    echo "  IMPORTANT: LOG OUT REQUIRED"
    echo "================================================================"
    echo ""
    echo "  User groups have been updated. You MUST log out and log back in"
    echo "  for the changes to take effect."
    echo ""
    read -r -p "Press Enter to exit (remember to log out)..."
  else
    echo ""
    echo "================================================================"
    echo "  SETUP COMPLETE"
    echo "================================================================"
    echo ""
    echo "  Dependencies, GPU configuration, and session switching are ready."
    echo ""
    echo "  To switch to Gaming Mode: Press Super+Shift+S"
    echo "  To return to Desktop:     Press Super+Shift+R"
    echo ""
  fi

  # Run verification at the end of setup
  echo ""
  read -p "Run installation verification? [Y/n]: " -n 1 -r
  echo
  if [[ ! $REPLY =~ ^[Nn]$ ]]; then
    verify_installation
  fi
}

show_help() {
  echo "WOPR Gaming Mode Installer v${WOPR_VERSION}"
  echo ""
  echo "Usage: $0 [OPTIONS]"
  echo ""
  echo "Options:"
  echo "  --help, -h      Show this help message"
  echo "  --verify, -v    Run verification only (check all files and permissions)"
  echo "  --version       Show version number"
  echo ""
  echo "Without options, runs the full installation/setup process."
  echo ""
  echo "Supported GPU configurations:"
  echo "  - Dedicated NVIDIA GPU"
  echo "  - Dedicated AMD GPU"
  echo "  - Intel integrated GPU"
  echo "  - Hybrid graphics (Intel/AMD iGPU + NVIDIA dGPU) - laptops"
  echo ""
  echo "For hybrid graphics laptops, the installer automatically configures"
  echo "PRIME render offload: iGPU handles display, NVIDIA dGPU renders games."
  echo ""
}

# Parse command line arguments
case "${1:-}" in
  --help|-h)
    show_help
    exit 0
    ;;
  --verify|-v)
    echo "Running verification only..."
    verify_installation
    exit $?
    ;;
  --version)
    echo "WOPR Gaming Mode Installer v${WOPR_VERSION}"
    exit 0
    ;;
  "")
    # No arguments - run full setup
    execute_setup
    ;;
  *)
    echo "Unknown option: $1"
    echo "Use --help for usage information."
    exit 1
    ;;
esac
