cat > portal_server.py <<'EOF'
#!/usr/bin/env python3
import json
import os
import re
import subprocess
from http.server import BaseHTTPRequestHandler, HTTPServer
from urllib.parse import urlparse

PORT = int(os.environ.get("PORT", "3001"))
STATIC_FILE = os.path.join(os.path.dirname(__file__), "test.html")

WPA_SUPPLICANT = "/etc/wpa_supplicant/wpa_supplicant.conf"

def sh(cmd):
    return subprocess.check_output(cmd, shell=True, text=True, stderr=subprocess.STDOUT).strip()

def list_networks():
    # Uses iwlist (works on Pi OS + ARMv6)
    out = sh("iwlist wlan0 scan 2>/dev/null || true")
    ssids = []
    for line in out.splitlines():
        line = line.strip()
        if "ESSID:" in line:
            ssid = line.split("ESSID:", 1)[1].strip().strip('"')
            if ssid and ssid not in ssids:
                ssids.append(ssid)
    return ssids

def wifi_status():
    ssid = sh("iwgetid -r 2>/dev/null || true")
    ip = sh("hostname -I 2>/dev/null || true").split()
    return {"ssid": ssid if ssid else None, "ip": ip[0] if ip else None}

def ensure_wpa_conf_has_ctrl_interface(text):
    if "ctrl_interface=" in text:
        return text
    # Add at top (safe default)
    return "ctrl_interface=DIR=/var/run/wpa_supplicant GROUP=netdev\nupdate_config=1\n\n" + text

def add_network_to_wpa(ssid, psk):
    # Minimal safe write: remove old network block for same ssid (best-effort), append new one
    try:
        existing = open(WPA_SUPPLICANT, "r", encoding="utf-8").read()
    except FileNotFoundError:
        existing = ""

    existing = ensure_wpa_conf_has_ctrl_interface(existing)

    # Remove network blocks that match ssid (simple regex, not perfect but good enough)
    pattern = re.compile(r'network=\{\s*[^}]*ssid="' + re.escape(ssid) + r'".*?\}', re.DOTALL)
    cleaned = re.sub(pattern, "", existing)

    block = f'\nnetwork={{\n    ssid="{ssid}"\n    psk="{psk}"\n}}\n'
    new_text = cleaned.rstrip() + block

    with open(WPA_SUPPLICANT, "w", encoding="utf-8") as f:
        f.write(new_text)

def switch_to_client_mode():
    # Stop AP services, restart dhcpcd + wpa
    sh("systemctl stop hostapd || true")
    sh("systemctl stop dnsmasq || true")
    sh("rm -f /etc/dnsmasq.d/rpi-ap.conf || true")
    sh("ip addr flush dev wlan0 || true")
    sh("systemctl restart dhcpcd || true")
    sh("systemctl restart wpa_supplicant || true")
    # Ask our wifi-check to re-evaluate later if needed
    sh("systemctl restart pi-wifi-check.service || true")

class Handler(BaseHTTPRequestHandler):
    def _send(self, code=200, content_type="application/json", body=b"{}"):
        self.send_response(code)
        self.send_header("Content-Type", content_type)
        self.send_header("Cache-Control", "no-store")
        self.end_headers()
        self.wfile.write(body)

    def do_GET(self):
        path = urlparse(self.path).path

        if path == "/" or path == "/index.html":
            with open(STATIC_FILE, "rb") as f:
                self._send(200, "text/html; charset=utf-8", f.read())
            return

        if path == "/api/networks":
            data = {"networks": list_networks()}
            self._send(200, "application/json", json.dumps(data).encode("utf-8"))
            return

        if path == "/api/status":
            self._send(200, "application/json", json.dumps(wifi_status()).encode("utf-8"))
            return

        self._send(404, "text/plain; charset=utf-8", b"Not found")

    def do_POST(self):
        path = urlparse(self.path).path
        length = int(self.headers.get("Content-Length", "0"))
        raw = self.rfile.read(length) if length else b"{}"

        if path == "/api/connect":
            try:
                payload = json.loads(raw.decode("utf-8"))
                ssid = payload.get("ssid", "").strip()
                password = payload.get("password", "").strip()
                if not ssid or not password:
                    raise ValueError("ssid/password required")

                add_network_to_wpa(ssid, password)
                switch_to_client_mode()

                self._send(200, "application/json", json.dumps({"ok": True}).encode("utf-8"))
            except Exception as e:
                self._send(400, "application/json", json.dumps({"ok": False, "error": str(e)}).encode("utf-8"))
            return

        self._send(404, "text/plain; charset=utf-8", b"Not found")

def main():
    httpd = HTTPServer(("0.0.0.0", PORT), Handler)
    print(f"Portal server running on :{PORT}")
    httpd.serve_forever()

if __name__ == "__main__":
    main()
EOF
chmod +x portal_server.py
