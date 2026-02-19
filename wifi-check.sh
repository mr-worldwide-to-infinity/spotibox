#!/bin/bash
set -euo pipefail

IFACE="wlan0"
SSID_AP="RaspberryPiAP"
PASS_AP="raspberry"
AP_IP="192.168.4.1"
HOST_LOCAL="spotibox.local"

has_wifi() {
  ssid="$(iwgetid -r 2>/dev/null || true)"
  [[ -n "${ssid}" ]]
}

start_ap() {
  echo "[wifi-check] No WiFi detected. Starting AP..."

  rfkill unblock wifi || true

  systemctl stop wpa_supplicant || true
  systemctl stop dhcpcd || true

  ip link set "$IFACE" down || true
  ip addr flush dev "$IFACE" || true
  ip addr add ${AP_IP}/24 dev "$IFACE"
  ip link set "$IFACE" up

  cat >/etc/dnsmasq.d/rpi-ap.conf <<CONF
interface=${IFACE}
dhcp-range=192.168.4.2,192.168.4.50,255.255.255.0,24h
dhcp-option=option:router,${AP_IP}
dhcp-option=option:dns-server,${AP_IP}

# Captive-ish: stuur ALLE DNS naar de Pi
address=/#/${AP_IP}

# Specifiek: spotibox.local -> AP IP
address=/${HOST_LOCAL}/${AP_IP}

domain-needed
bogus-priv
CONF

  cat >/etc/hostapd/hostapd.conf <<CONF
interface=${IFACE}
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

  if [ -f /etc/default/hostapd ]; then
    sed -i 's|^#\?DAEMON_CONF=.*|DAEMON_CONF="/etc/hostapd/hostapd.conf"|' /etc/default/hostapd
  else
    echo 'DAEMON_CONF="/etc/hostapd/hostapd.conf"' >/etc/default/hostapd
  fi

  # Redirect poort 80 naar portal (3001) zodat captive portal vaker opengaat
  iptables -t nat -C PREROUTING -i "$IFACE" -p tcp --dport 80 -j REDIRECT --to-ports 3001 2>/dev/null \
    || iptables -t nat -A PREROUTING -i "$IFACE" -p tcp --dport 80 -j REDIRECT --to-ports 3001

  systemctl restart dnsmasq
  systemctl restart hostapd

  echo "[wifi-check] AP up: ${SSID_AP}/${PASS_AP} -> http://${AP_IP}:3001/"
}

stop_ap_restore_client() {
  echo "[wifi-check] WiFi detected. Stopping AP and restoring client mode..."

  systemctl stop hostapd || true
  systemctl stop dnsmasq || true
  rm -f /etc/dnsmasq.d/rpi-ap.conf || true

  iptables -t nat -D PREROUTING -i "$IFACE" -p tcp --dport 80 -j REDIRECT --to-ports 3001 2>/dev/null || true

  ip addr flush dev "$IFACE" || true

  systemctl start dhcpcd || true
  systemctl start wpa_supplicant || true
}

if has_wifi; then
  echo "[wifi-check] Connected to: $(iwgetid -r)"
  if systemctl is-active --quiet hostapd; then
    stop_ap_restore_client
  fi
else
  start_ap
fi
