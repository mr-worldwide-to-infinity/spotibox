cat > install_spotify_connect_armv6.sh <<'EOF'
#!/bin/bash
set -e

echo "Installing raspotify (ARMv6 last-known working version: 0.31.8.1)..."
apt-get update
apt-get install -y curl apt-transport-https ca-certificates

# Add raspotify repo key and list (repo might change; this is the classic method)
curl -sS https://dtcooper.github.io/raspotify/key.asc | apt-key add -

cat >/etc/apt/sources.list.d/raspotify.list <<'LIST'
deb https://dtcooper.github.io/raspotify/ raspotify main
LIST

apt-get update

# Install pinned version (armv6 last supported)
apt-get install -y raspotify=0.31.8.1~librespot2

# Optional: set a nicer device name
sed -i 's/^#\?DEVICE_NAME=.*/DEVICE_NAME="PiZero"/' /etc/default/raspotify || true

systemctl enable raspotify
systemctl restart raspotify

echo "Done. Open Spotify and select device 'PiZero' in Available Devices."
EOF
chmod +x install_spotify_connect_armv6.sh
