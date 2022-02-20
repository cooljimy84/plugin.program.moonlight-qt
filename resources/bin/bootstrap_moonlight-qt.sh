#!/bin/bash

# Only for debugging
# export QT_DEBUG_PLUGINS=1

# To use a specific PulseAudio device:
# export PULSE_SINK="alsa_output.pci-0000_0a_00.1.analog-stereo"

# To disable PulseAudio:
# export PULSE_SERVER="none"

# To use a specific ALSA audio device (after disabling pulse):
# export ALSA_PCM_NAME="hdmi:CARD=PCH,DEV=0"

set -e

. /etc/profile

cd "$(dirname "$0")"

# Get platform and distro
source ./get-platform.sh

# Paths
ADDON_BIN_PATH=$(realpath ".")
HOME="$ADDON_PROFILE_PATH/moonlight-home"
MOONLIGHT_PATH="$ADDON_PROFILE_PATH/moonlight-qt"

# Setup environment
export XDG_RUNTIME_DIR=/var/run/

# Setup library locations
LIB_PATH="$MOONLIGHT_PATH/lib"
export LD_LIBRARY_PATH=/usr/lib/:$LIB_PATH:$LD_LIBRARY_PATH

# Setup QT library locations if present
if [ -d "$LIB_PATH/qt5" ]; then
  echo "Using QT library from $LIB_PATH/qt5..."
  export QML_IMPORT_PATH=$LIB_PATH/qt5/qml/
  export QML2_IMPORT_PATH=$LIB_PATH/qt5/qml/
  export QT_QPA_PLATFORM_PLUGIN_PATH=$LIB_PATH/qt5/plugins/
fi

# Hack to scale interface on 4K display's. QT_SCALE_FACTOR higher than 1.28 corrupts the layout.
if [ -z "$DISPLAY" ]; then
  echo Applying QT custom scaling factor...
  export QT_SCALE_FACTOR=1.28
  export QT_QPA_EGLFS_PHYSICAL_WIDTH=750
  export QT_QPA_EGLFS_PHYSICAL_HEIGHT=422
fi

# Make sure home path exists
mkdir -p "$HOME"

# Enter the Moonlight bin path
cd "$MOONLIGHT_PATH/bin"

# Configure audio output device
CONF_FILE="${HOME}/.config/alsa/asoundrc"
mkdir -p "$(dirname "$CONF_FILE")"
rm -f "$CONF_FILE"

if [ "$PULSE_SERVER" == "none" ] && [ -n "$ALSA_PCM_NAME" ]; then
  echo "Custom ALSA audio device: '$ALSA_PCM_NAME'"

  # Create a template file for ALSA
  cat <<EOT >> "$CONF_FILE"
pcm.!default "%device%"

# The audio channels need to be re-mapped for Moonlight, this seems to be a Kodi issue.
# Please file a bug-report if this mapping differs for you, the easiest way to check the channels is to test them using
# speaker setup from Windows while streaming.
pcm.!surround51 {
  type route
  slave.pcm "%device%"
  ttable {
    0.0= 1
    1.1= 1
    2.4= 1
    3.5= 1
    4.3= 1
    5.2= 1
  }
}

# The mapping for 7.1 is currently unknown (no hardware to test this)
pcm.!surround71 "%device%"
EOT

  # Replace the placeholder with the device name
  sed -i "s/%device%/$ALSA_PCM_NAME/g" "$CONF_FILE"
fi

# Check for distro specific hooks
if [ -d "$ADDON_BIN_PATH/kodi_hooks/$PLATFORM_DISTRO" ]; then
  echo "Using Kodi hooks for $PLATFORM_DISTRO..."
  # Stop kodi using hook
  source "$ADDON_BIN_PATH/kodi_hooks/$PLATFORM_DISTRO/stop.sh"

  # Start kodi when this script exits using trap in hook
  source "$ADDON_BIN_PATH/kodi_hooks/$PLATFORM_DISTRO/start.sh"
fi

# Start moonlight-qt and log to log file
echo "--- Starting Moonlight ---"
./moonlight-qt "$@"
