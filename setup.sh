cat > setup.sh <<'EOF'
#!/bin/bash
set -e

# Basic packages for AP + portal + WiFi tooling
apt-get update
apt-get install -y hostapd dnsmasq iw wireless-tools iproute2 python3

# Stop services now; we'll manage them ourselves
systemctl stop hostapd || true
systemctl stop dnsmasq || true

# Enable but do not necessarily start at boot automatically (our scripts will)
systemctl unmask hostapd || true
systemctl enable hostapd dnsmasq

# Create systemd service for portal server
cat >/etc/systemd/system/pi-portal.service <<'SVC'
[Unit]
Description=Pi WiFi Captive Portal
After=network-online.target
Wants=network-online.target

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

# Create systemd service for WiFi/AP check at boot
cat >/etc/systemd/system/pi-wifi-check.service <<'SVC'
[Unit]
Description=Pi WiFi Check and AP Toggle
After=network-online.target
Wants=network-online.target

[Service]
Type=oneshot
ExecStart=/bin/bash /home/pi/pi-zero-portal/wifi-check.sh
RemainAfterExit=yes
User=root

[Install]
WantedBy=multi-user.target
SVC

systemctl daemon-reload
systemctl enable pi-portal.service pi-wifi-check.service

chmod +x /home/pi/pi-zero-portal/wifi-check.sh
chmod +x /home/pi/pi-zero-portal/install_spotify_connect_armv6.sh

# Start now
systemctl restart pi-wifi-check.service
systemctl restart pi-portal.service

echo "Installed. If no WiFi, connect to AP 'RaspberryPiAP' password 'raspberry' and go to http://192.168.4.1:3001/"
EOF
chmod +x setup.sh
