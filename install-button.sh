#!/bin/bash
set -e

WORKDIR="/opt/shutdown-button"
VOLUSER="volumio"
SERVICE_NAME="shutdown-button"

echo "=== Raspberry Pi Shutdown Button Installer (GPIO27, rpio) ==="

# 1) Arbeitsverzeichnis anlegen
sudo mkdir -p $WORKDIR
sudo chown -R $VOLUSER:$VOLUSER $WORKDIR

# 2) package.json
sudo tee $WORKDIR/package.json > /dev/null <<'JSON'
{
  "name": "shutdown-button",
  "version": "1.0.0",
  "description": "Raspberry Pi shutdown button via GPIO27",
  "main": "index.js",
  "dependencies": {
    "rpio": "^2.4.2"
  },
  "author": "DasSchuppe",
  "license": "MIT"
}
JSON
sudo chown $VOLUSER:$VOLUSER $WORKDIR/package.json

# 3) index.js
sudo tee $WORKDIR/index.js > /dev/null <<'JS'
'use strict';

const rpio = require('rpio');
const { exec } = require('child_process');

// GPIO27 als Input mit Pull-Up
// Taster zwischen Pin 27 und GND
rpio.open(27, rpio.INPUT, rpio.PULL_UP);

console.log('Shutdown Button Service gestartet. GPIO27 überwacht.');

setInterval(() => {
    if (rpio.read(27) === 0) {  // LOW = Taster gedrückt
        console.log('Shutdown Button gedrückt → System fährt runter');
        exec('sudo shutdown -h now', (err, stdout, stderr) => {
            if (err) console.error('Fehler beim Shutdown:', err);
        });
    }
}, 200);

// sauber schließen bei SIGINT
process.on('SIGINT', () => {
    rpio.close(27);
    process.exit();
});
JS
sudo chown $VOLUSER:$VOLUSER $WORKDIR/index.js

# 4) Node-Module installieren
sudo -u $VOLUSER npm install --prefix $WORKDIR --production

# 5) systemd Service
sudo tee /etc/systemd/system/$SERVICE_NAME.service > /dev/null <<SERVICE
[Unit]
Description=Raspberry Pi Shutdown Button (GPIO27, rpio)
After=multi-user.target

[Service]
ExecStart=/usr/bin/node /opt/shutdown-button/index.js
WorkingDirectory=/opt/shutdown-button
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

echo "=== Shutdown Button Installation Complete ==="
systemctl status $SERVICE_NAME.service --no-pager
