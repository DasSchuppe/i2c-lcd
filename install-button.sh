#!/bin/bash
set -e

# Power-Button Script für Raspberry Pi
# GPIO3: Hardware-Start (Pin 5, wird automatisch vom Pi genutzt)
# GPIO17: Soft-Shutdown (Pin 11)

WORKDIR="/opt/power-buttons"
VOLUSER="volumio"
SERVICE_NAME="power-buttons"

echo "=== Raspberry Pi Power Buttons Installer ==="

# 1) Verzeichnis anlegen
sudo mkdir -p $WORKDIR
sudo chown -R $VOLUSER:$VOLUSER $WORKDIR

# 2) package.json
sudo tee $WORKDIR/package.json > /dev/null <<'JSON'
{
  "name": "power-buttons",
  "version": "1.0.0",
  "description": "Two-button control for Raspberry Pi: soft shutdown and hardware start",
  "main": "index.js",
  "dependencies": {
    "onoff": "^6.0.0"
  },
  "author": "DasSchuppe",
  "license": "MIT"
}
JSON
sudo chown $VOLUSER:$VOLUSER $WORKDIR/package.json

# 3) index.js
sudo tee $WORKDIR/index.js > /dev/null <<'JS'
'use strict';

const Gpio = require('onoff').Gpio;

// GPIO17 als Shutdown-Taster (Pin 11)
const shutdownButton = new Gpio(17, 'in', 'falling', { debounceTimeout: 200 });

shutdownButton.watch((err, value) => {
  if (err) {
    console.error('GPIO Error:', err);
    return;
  }
  console.log("Shutdown button pressed → System fährt herunter");
  require('child_process').exec('sudo shutdown -h now');
});

process.on('SIGINT', () => {
  shutdownButton.unexport();
});
JS
sudo chown $VOLUSER:$VOLUSER $WORKDIR/index.js

# 4) Node-Module installieren
sudo -u $VOLUSER npm install --prefix $WORKDIR --production

# 5) systemd Service
sudo tee /etc/systemd/system/$SERVICE_NAME.service > /dev/null <<'SERVICE'
[Unit]
Description=Raspberry Pi Power Buttons (GPIO17 Shutdown)
After=multi-user.target

[Service]
ExecStart=/usr/bin/node /opt/power-buttons/index.js
WorkingDirectory=/opt/power-buttons
Restart=always
User=volumio
Group=volumio

[Install]
WantedBy=multi-user.target
SERVICE

# 6) Service aktivieren und starten
sudo systemctl daemon-reload
sudo systemctl enable $SERVICE_NAME.service
sudo systemctl restart $SERVICE_NAME.service

echo "=== Power Buttons installation complete ==="
systemctl status $SERVICE_NAME.service --no-pager
