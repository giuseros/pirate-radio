#!/usr/bin/env bash
# Installs the pirate-radio configuration onto a fresh Raspbian Buster Pi Zero W
# with a pHAT Beat board. Run as the pi user with sudo access.

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

echo "=== Installing pirate-radio ==="

# 1. Install system dependencies
echo "--- Installing packages ---"
sudo apt-get update -q
sudo apt-get install -y python3-phatbeat vlc-bin vlc-plugin-base

# 2. Disable PulseAudio (it intercepts ALSA and breaks the pHAT Beat audio chain)
echo "--- Disabling PulseAudio ---"
sudo systemctl stop pulseaudio 2>/dev/null || true
sudo systemctl disable pulseaudio 2>/dev/null || true
sudo systemctl --global disable pulseaudio 2>/dev/null || true
echo "autospawn = no" | sudo tee -a /etc/pulse/client.conf
if [ -f /etc/alsa/conf.d/99-pulse.conf ]; then
    sudo mv /etc/alsa/conf.d/99-pulse.conf /etc/alsa/conf.d/99-pulse.conf.disabled
fi

# 3. Install ALSA config (routes audio through pHAT Beat DAC + VU meter)
echo "--- Installing ALSA config ---"
sudo cp "$SCRIPT_DIR/config/asound.conf" /etc/asound.conf

# 4. Install VLC launcher and phatbeatd daemon
echo "--- Installing bin scripts ---"
sudo cp "$SCRIPT_DIR/bin/vlcd" /usr/bin/vlcd
sudo chmod +x /usr/bin/vlcd
sudo cp "$SCRIPT_DIR/bin/phatbeatd" /usr/bin/phatbeatd
sudo chmod +x /usr/bin/phatbeatd

# 5. Install init.d service scripts
echo "--- Installing services ---"
sudo cp "$SCRIPT_DIR/services/vlcd" /etc/init.d/vlcd
sudo chmod +x /etc/init.d/vlcd
sudo cp "$SCRIPT_DIR/services/phatbeatd" /etc/init.d/phatbeatd
sudo chmod +x /etc/init.d/phatbeatd
sudo update-rc.d vlcd defaults
sudo update-rc.d phatbeatd defaults
sudo systemctl daemon-reload

# 6. Install playlist
echo "--- Installing playlist ---"
mkdir -p /home/pi/.config/vlc
cp "$SCRIPT_DIR/playlist.m3u" /home/pi/.config/vlc/playlist.m3u

echo ""
echo "=== Done. Reboot to start the radio. ==="
echo "    sudo reboot"
