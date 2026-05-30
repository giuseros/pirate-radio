# Pirate Radio

Internet radio on a Raspberry Pi Zero W with a [pHAT Beat](https://shop.pimoroni.com/products/pirate-radio-pi-zero-w-project-kit) board.

## Hardware

- Raspberry Pi Zero W
- Pimoroni pHAT Beat (stereo DAC + amplifier + VU meter LEDs + 6 buttons)
- Raspbian Buster (Debian 10)

## Buttons

| Button | Action |
|--------|--------|
| Vol + / Vol − | Volume up / down |
| Play/Pause | Toggle playback |
| >> (Fast forward) | Next station |
| << (Rewind) | Previous station |
| Power | Shutdown the Pi |

## Playlist

Edit `playlist.m3u` (or `/home/pi/.config/vlc/playlist.m3u` on the Pi) to add or remove stations. Each entry is two lines:

```
#EXTINF:-1,Station Name
http://stream-url-here
```

The current playlist has 10 Italian stations:

1. Rai Radio 1
2. Rai Radio 2
3. Rai Radio 3
4. RTL 102.5
5. Radio 105
6. RDS 100% Grandi Successi
7. Virgin Radio Italia
8. Radio Monte Carlo
9. R101
10. Radio Kiss Kiss

> **Note:** Rai Radio 1 sometimes returns HTTP 403 depending on ISP/network. VLC will skip it automatically and start from Rai Radio 2.

## Install on a fresh Pi

```bash
git clone <this-repo> pirate-radio
cd pirate-radio
bash install.sh
sudo reboot
```

The `install.sh` script:
1. Installs `python3-phatbeat`, `vlc-bin`, `vlc-plugin-base`
2. Disables PulseAudio (it intercepts ALSA and prevents audio reaching the pHAT Beat)
3. Installs the ALSA config that routes audio through the pHAT Beat DAC and VU meter
4. Installs the `vlcd` and `phatbeatd` daemons and registers them as boot services
5. Copies the playlist

## Project structure

```
pirate-radio/
├── install.sh              — one-shot setup script
├── playlist.m3u            — Italian radio stations
├── config/
│   └── asound.conf         — ALSA routing: default → softvol → pivumeter → hw:1,0
├── bin/
│   ├── vlcd                — launches VLC as a headless daemon
│   └── phatbeatd           — listens to pHAT Beat buttons, controls VLC via RC socket
└── services/
    ├── vlcd                — init.d service (waits for network before starting)
    └── phatbeatd           — init.d service (waits for vlcd before starting)
```

## How it works

```
[Internet stream]
      ↓
    VLC  ── RC socket (port 9294) ──→  phatbeatd  ←── pHAT Beat buttons
      ↓
   ALSA default
      ↓
   softvol  (software volume control)
      ↓
   pivumeter  (drives the VU meter LEDs)
      ↓
   hw:1,0  (pHAT Beat I2S DAC → amplifier → speaker)
```

## What was broken (and why)

The original Pimoroni installer had several issues on Raspbian Buster:

| Problem | Fix |
|---------|-----|
| `asound.conf` routed audio to `hw:0,0` (Pi built-in audio) instead of `hw:1,0` (pHAT Beat DAC) | Changed to `hw:1,0` |
| PulseAudio intercepted the ALSA default device and redirected audio back to card 0 | Disabled PulseAudio autospawn and its ALSA hook (`99-pulse.conf`) |
| VLC was not forced to use ALSA, so it defaulted to PulseAudio | Added `--aout alsa` to the VLC command |
| `phatbeatd` crashed with `OSError: Transport endpoint not connected` when VLC's RC socket dropped | Added reconnect logic to `recv()` |
| Neither service waited for the network before starting | Added `$network` to `Required-Start` in both init.d headers |
| `phatbeatd` only retried connecting to VLC for 10 seconds | Increased retry window to 30 seconds |

## Logs

```bash
# VLC log
cat /var/run/vlcd/vlcd.log

# phatbeatd log
cat /var/log/phatbeatd.log
cat /var/log/phatbeatd.err

# Service status
sudo /etc/init.d/vlcd status
sudo /etc/init.d/phatbeatd status
```

## Manual control

VLC exposes an RC interface on port 9294. You can control it directly:

```bash
echo 'next'   | nc -q1 127.0.0.1 9294   # next station
echo 'prev'   | nc -q1 127.0.0.1 9294   # previous station
echo 'pause'  | nc -q1 127.0.0.1 9294   # pause/resume
echo 'status' | nc -q1 127.0.0.1 9294   # show current state
echo 'volume 256' | nc -q1 127.0.0.1 9294  # set volume (0–1024, 512 = 100%)
```
