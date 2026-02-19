Prima. Dan krijg je ‘m hier platte tekst, zodat je ‘m zelf kunt copy-pasten in een `README.md`. Technologie: geweldig als het werkt. Als het niet werkt, is het vooral een hobby.

---

# Pi Zero W WiFi Setup Portal + Spotify Connect (zonder client-id)

Dit project doet twee dingen:

1. **Als de Pi geen WiFi heeft**: hij start een eigen WiFi access point (AP) `RaspberryPiAP` en serveert een webportal op `http://192.168.4.1:3001` om WiFi in te stellen.
2. **Als de Pi wél WiFi heeft**: hij stopt het AP en gebruikt normale client-mode.

Daarna kun je (optioneel) **Spotify streamen via Spotify Connect** met `raspotify` (geen Spotify developer client-id/secret).
Let op: Pi Zero W = **ARMv6**. `raspotify` werkt hier alleen met een oudere, “laatste bekende” versie (kan ooit breken door Spotify updates).

---

## Vereisten

* Raspberry Pi Zero W (v1, **geen** Zero 2 W)
* Raspberry Pi OS Lite (aanrader)
* SD-kaart, voeding, WiFi bereik
* (Voor Spotify Connect) meestal Spotify Premium

---

## Bestanden in deze map

* `setup.sh` – installeert benodigde packages + zet services aan
* `wifi-check.sh` – start/stopt AP afhankelijk van WiFi status
* `portal_server.py` – simpele captive portal API + serve `test.html`
* `test.html` – web UI om een WiFi SSID + wachtwoord op te geven
* `install_spotify_connect_armv6.sh` – installeert `raspotify` (ARMv6 pinned)

---

## Handmatige stappen (doe dit op de Pi)

### 1) Zet de bestanden op de Pi

Maak een map en plaats alle bestanden erin, bijvoorbeeld:

```bash
mkdir -p /home/pi/pi-zero-portal
cd /home/pi/pi-zero-portal
# zet hier setup.sh, wifi-check.sh, portal_server.py, test.html, install_spotify_connect_armv6.sh neer
```

Maak ze uitvoerbaar:

```bash
chmod +x setup.sh wifi-check.sh portal_server.py install_spotify_connect_armv6.sh
```

### 2) Run de installer

```bash
sudo ./setup.sh
```

Dit installeert o.a. `hostapd`, `dnsmasq`, `iw`, en zet twee systemd services aan:

* `pi-wifi-check.service` (AP aan/uit)
* `pi-portal.service` (web portal op poort 3001)

### 3) Eerste keer verbinden (als er nog geen WiFi is)

Als de Pi geen WiFi heeft, maakt hij een AP:

* SSID: **RaspberryPiAP**
* Wachtwoord: **raspberry**
* Portal: **[http://192.168.4.1:3001](http://192.168.4.1:3001)**

Stappen:

1. Verbind met `RaspberryPiAP` vanaf je telefoon/laptop.
2. Open `http://192.168.4.1:3001`
3. Klik **Scan netwerken**, kies jouw SSID, vul wachtwoord in, klik **Verbinden**.
4. Het AP gaat uit en de Pi probeert te verbinden met je gekozen WiFi.

### 4) Vind het IP-adres van de Pi op je normale WiFi

Opties:

**A) Via router (DHCP lijst)**: zoek “raspberrypi” of “PiZero”.

**B) Op de Pi zelf** (als je SSH/console hebt):

```bash
hostname -I
iwgetid -r
```

---

## Spotify Connect installeren (optioneel, geen client-id)

Als de Pi verbonden is met je normale WiFi:

```bash
sudo ./install_spotify_connect_armv6.sh
```

Daarna:

1. Open Spotify op je telefoon.
2. Ga naar **Beschikbare apparaten**.
3. Kies device **PiZero**.

Device-naam aanpassen kan in `/etc/default/raspotify` (variabele `DEVICE_NAME`) en daarna:

```bash
sudo systemctl restart raspotify
```

---

## Debug / status checks

### Services status

```bash
sudo systemctl status pi-wifi-check.service
sudo systemctl status pi-portal.service
sudo systemctl status hostapd dnsmasq
```

### Logs

```bash
sudo journalctl -u pi-portal.service -n 200 --no-pager
sudo journalctl -u pi-wifi-check.service -n 200 --no-pager
sudo journalctl -u hostapd -n 200 --no-pager
sudo journalctl -u dnsmasq -n 200 --no-pager
```

### Handmatig AP opnieuw forceren

```bash
sudo systemctl restart pi-wifi-check.service
```

---

## Bekende beperkingen (Pi Zero W realiteit)

* ARMv6 is oud. Veel moderne packages droppen support.
* `raspotify` draait hier met een **oude pinned versie**. Als Spotify iets wijzigt kan playback stoppen.
* Dit is bewust **Node-vrij** gehouden om ARMv6 library ellende te vermijden.

---

## Verwijderen (als je klaar bent met het leven)

```bash
sudo systemctl disable --now pi-portal.service pi-wifi-check.service || true
sudo rm -f /etc/systemd/system/pi-portal.service /etc/systemd/system/pi-wifi-check.service
sudo systemctl daemon-reload

sudo apt-get remove -y hostapd dnsmasq || true
# Optional:
sudo apt-get remove -y raspotify || true
```

---
