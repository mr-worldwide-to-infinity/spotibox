# Pi Zero W WiFi Setup Portal + Spotify Connect (spotibox)

Dit project doet automatisch:
1) Geen WiFi? Dan start de Pi een Access Point (AP) "RaspberryPiAP" + captive portal.
2) WiFi gekozen via portal? Dan schakelt hij naar client-mode op jouw WiFi.
3) mDNS/Avahi wordt geïnstalleerd zodat je de Pi op je WiFi kunt bereiken via: spotibox.local
4) Spotify Connect (raspotify) wordt automatisch mee geïnstalleerd (ARMv6).

---

## Vereisten
- Raspberry Pi Zero W (ARMv6)
- Raspberry Pi OS Lite aanbevolen
- Internet tijdens installatie (1e keer)

---

## Installatie (1 commando)
Zet alle bestanden in:
  /home/pi/pi-zero-portal

Bestanden:
- setup.sh
- wifi-check.sh
- portal_server.py
- test.html
- install_spotify_connect_armv6.sh

Maak uitvoerbaar:
  chmod +x setup.sh wifi-check.sh portal_server.py install_spotify_connect_armv6.sh

Run setup:
  sudo ./setup.sh

Klaar. Geen losse handmatige stappen meer.

---

## Gebruik

### Scenario A: Geen WiFi beschikbaar (of credentials nog niet ingesteld)
De Pi start een AP:

SSID: RaspberryPiAP
Wachtwoord: raspberry

Open portal:
- http://192.168.4.1:3001
- vaak werkt ook: http://spotibox.local  (afhankelijk van device/DNS gedrag)

Kies je WiFi, vul wachtwoord in, klik Verbinden.
Daarna gaat het AP uit en probeert de Pi te verbinden met jouw WiFi.

### Scenario B: Pi zit op jouw WiFi
Open portal op je normale netwerk:
- http://spotibox.local:3001

(Als je client geen .local kan: check je router DHCP lijst of gebruik hostname -I op de Pi.)

---

## Spotify Connect
Raspotify wordt automatisch geïnstalleerd door setup.sh.

Gebruik:
1) Open Spotify op je telefoon/laptop
2) Ga naar "Beschikbare apparaten"
3) Kies de Pi (raspotify device)

Let op: dit is Spotify Connect. Je logt dus niet “in via de browser portal”.
Je kiest het apparaat in Spotify.

---

## Debug
Status:
  systemctl status pi-portal.service
  systemctl status pi-wifi-check.timer
  systemctl status hostapd dnsmasq

Logs:
  journalctl -u pi-portal.service -n 200 --no-pager
  journalctl -u pi-wifi-check.service -n 200 --no-pager
  journalctl -u hostapd -n 200 --no-pager
  journalctl -u dnsmasq -n 200 --no-pager

---

## Waarom dit nu wél boot-proof is
De WiFi check draait niet één keer en stopt, maar via een systemd timer elke 10 seconden.
En hij wacht niet op "network-online", want dat kan juist nooit komen als je géén WiFi hebt.
