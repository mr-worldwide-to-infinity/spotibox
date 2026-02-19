#!/bin/bash
set -euo pipefail

PROJECT_DIR="/home/pi/pi-zero-portal"
HOSTNAME_LOCAL="spotibox"

if [[ $EUID -ne 0 ]]; then
  echo "Run dit met sudo: sudo ./setup.sh"
  exit 1
fi

echo "[setup] Install packages..."
apt-get update
apt-get install -y \
  hostapd dnsmasq iw wireless-tools iproute2 iptables \
  python3 \
  avahi-daemon libnss-mdns

echo "[setup] Set hostname to ${HOSTNAME_LOCAL}..."
hostnamectl set-hostname "${HOSTNAME_LOCAL}" || true
systemctl enable --now avahi-daemon

echo "[setup] Stop AP services now (we manage them)..."
systemctl stop hostapd || true
systemctl stop dnsmasq || true
systemctl unmask hostapd || true
systemctl enable hostapd dnsmasq

echo "[setup] Create systemd service: pi-portal.service"
cat >/etc/systemd/system/pi-portal.service <<'SVC'
[Unit]
Description=Pi WiFi Captive Portal
After=network.target
Wants=network.target

[Service]
Type=simple
WorkingDirectory=/home/pi/pi-zero-portal
ExecStart=/usr/bin/python3 /home/pi/pi-zero-portal/portal_server.py
Restart=always
RestartSec=2
User=root

[Install]
WantedBy=multi-user.target
SVC

echo "[setup] Create systemd service: pi-wifi-check.service"
cat >/etc/systemd/system/pi-wifi-check.service <<'SVC'
[Unit]
Description=Pi WiFi Check and AP Toggle
After=network.target
Wants=network.target

[Service]
Type=oneshot
ExecStart=/bin/bash /home/pi/pi-zero-portal/wifi-check.sh
User=root
SVC

echo "[setup] Create systemd timer: pi-wifi-check.timer (runs every 10s)"
cat >/etc/systemd/system/pi-wifi-check.timer <<'TMR'
[Unit]
Description=Run Pi WiFi check periodically

[Timer]
OnBootSec=5
OnUnitActiveSec=10
Unit=pi-wifi-check.service

[Install]
WantedBy=timers.target
TMR

echo "[setup] Permissions..."
chmod +x "${PROJECT_DIR}/wifi-check.sh"
chmod +x "${PROJECT_DIR}/portal_server.py"
chmod +x "${PROJECT_DIR}/install_spotify_connect_armv6.sh"

echo "[setup] Install Spotify Connect (ARMv6)..."
# Dit script doet apt + systemd voor raspotify
"${PROJECT_DIR}/install_spotify_connect_armv6.sh" || true

echo "[setup] Enable + start services..."
systemctl daemon-reload
systemctl enable --now pi-portal.service
systemctl enable --now pi-wifi-check.timer

echo "[setup] Kick off first run now..."
systemctl start pi-wifi-check.service || true
systemctl restart pi-portal.service || true

echo ""
echo "[setup] Klaar."
echo " - Als er geen WiFi is: verbind met AP 'RaspberryPiAP' (password: raspberry)"
echo "   Portal: http://192.168.4.1:3001 (en vaak ook http://spotibox.local)"
echo " - Als hij wél op je WiFi zit: http://spotibox.local:3001"
