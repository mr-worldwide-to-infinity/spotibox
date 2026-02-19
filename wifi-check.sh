cat > wifi-check.sh <<'EOF'
#!/bin/bash
set -e

SSID_AP="RaspberryPiAP"
PASS_AP="raspberry"
AP_IP="192.168.4.1"

has_wifi() {
  # returns 0 if connected to an AP
  iwgetid -r >/dev/null 2>&1
}

start_ap() {
  echo "[wifi-check] No WiFi detected. Starting AP..."

  # Stop client services to avoid fighting over wlan0
  systemctl stop wpa_supplicant || true
  systemctl stop dhcpcd || true

  # Configure wlan0 static IP for AP mode
  ip link set wlan0 down || true
  ip addr flush dev wlan0 || true
  ip addr add ${AP_IP}/24 dev wlan0
  ip link set wlan0 up

  # dnsmasq config for captive DHCP
  cat >/etc/dnsmasq.d/rpi-ap.conf <<CONF
interface=wlan0
dhcp-range=192.168.4.2,192.168.4.50,255.255.255.0,24h
domain-needed
bogus-priv
CONF

  # hostapd config
  cat >/etc/hostapd/hostapd.conf <<CONF
interface=wlan0
driver=nl80211
ssid=${SSID_AP}
hw_mode=g
channel=7
wmm_enabled=0
auth_algs=1
ignore_broadcast_ssid=0
wpa=2
wpa_passphrase=${PASS_AP}
wpa_key_mgmt=WPA-PSK
rsn_pairwise=CCMP
CONF

  # Ensure hostapd uses our config
  if [ -f /etc/default/hostapd ]; then
    sed -i 's|^#\?DAEMON_CONF=.*|DAEMON_CONF="/etc/hostapd/hostapd.conf"|' /etc/default/hostapd
  else
    echo 'DAEMON_CONF="/etc/hostapd/hostapd.conf"' >/etc/default/hostapd
  fi

  systemctl restart dnsmasq
  systemctl restart hostapd

  echo "[wifi-check] AP up: ${SSID_AP} / ${PASS_AP} at http://${AP_IP}:3001/"
}

stop_ap_restore_client() {
  echo "[wifi-check] WiFi detected. Stopping AP and restoring client mode..."

  systemctl stop hostapd || true
  systemctl stop dnsmasq || true
  rm -f /etc/dnsmasq.d/rpi-ap.conf || true

  ip addr flush dev wlan0 || true

  # Restart normal client networking
  systemctl start dhcpcd || true
  systemctl start wpa_supplicant || true
}

# Main
if has_wifi; then
  echo "[wifi-check] Connected to: $(iwgetid -r)"
  if systemctl is-active --quiet hostapd; then
    stop_ap_restore_client
  fi
else
  start_ap
fi
EOF
chmod +x wifi-check.sh
