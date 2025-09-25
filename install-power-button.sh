#!/bin/bash
set -e

WORKDIR="/opt/power-button"
VOLUSER="volumio"
SERVICE_NAME="power-button"
SHUTDOWN_PIN=17   # GPIO17 (Pin 11) für Shutdown-Taster

echo "=== Raspberry Pi Power Button Installer (GPIO17) ==="

# 1) Verzeichnis anlegen
sudo mkdir -p $WORKDIR
sudo chown -R $VOLUSER:$VOLUSER $WORKDIR

# 2) package.json
sudo tee $WORKDIR/package.json > /dev/null <<'JSON'
{
  "name": "power-button",
  "version": "1.0.0",
  "description": "Single power button for Raspberry Pi (custom GPIO)",
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
const shutdownPin = new Gpio(${SHUTDOWN_PIN}, 'in', 'falling', { debounceTimeout: 200 });

shutdownPin.watch((err, value) => {
  if (err) {
    console.error('GPIO Error:', err);
    return;
  }
  console.log("Shutdown button pressed → System will halt");
  require('child_process').exec('sudo shutdown -h now');
});

process.on('SIGINT', () => {
  shutdownPin.unexport();
});
JS
sudo chown $VOLUSER:$VOLUSER $WORKDIR/index.js

# 4) Node-Module installieren
sudo -u $VOLUSER npm install --prefix $WORKDIR --production

# 5) systemd Service
sudo tee /etc/systemd/system/$SERVICE_NAME.service > /dev/null <<SERVICE
[Unit]
Description=Raspberry Pi Power Button (GPIO${SHUTDOWN_PIN})
After=multi-user.target

[Service]
ExecStart=/usr/bin/node /opt/power-button/index.js
WorkingDirectory=/opt/power-button
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

echo "=== Power Button installation complete ==="
systemctl status $SERVICE_NAME.service --no-pager
