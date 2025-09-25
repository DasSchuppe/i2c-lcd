#!/bin/bash
set -e

WORKDIR="/opt/shutdown-button"
VOLUSER="volumio"
SERVICE_NAME="shutdown-button"

echo "=== Raspberry Pi Shutdown Button Installer (GPIO17, rpio) ==="

# 1) Arbeitsverzeichnis anlegen
sudo mkdir -p $WORKDIR
sudo chown -R $VOLUSER:$VOLUSER $WORKDIR

# 2) package.json
sudo tee $WORKDIR/package.json > /dev/null <<'JSON'
{
  "name": "shutdown-button",
  "version": "1.0.0",
  "description": "Raspberry Pi shutdown button via GPIO17 (rpio)",
  "main": "index.js",
  "dependencies": {
    "rpio": "^3.3.1"
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

const SHUTDOWN_PIN = 17; // BCM17 / Pin 11

// rpio Setup: Input mit Pullup und Interrupt
rpio.open(SHUTDOWN_PIN, rpio.INPUT, rpio.PULL_UP);

console.log('Shutdown Button Service gestartet. GPIO17 überwacht.');

rpio.poll(SHUTDOWN_PIN, (pin) => {
    console.log('Shutdown Button gedrückt → System fährt runter');
    exec('sudo shutdown -h now', (err, stdout, stderr) => {
        if (err) console.error('Fehler beim Shutdown:', err);
    });
}, rpio.POLL_HIGH); // Trigger beim Drücken (High → Low wegen Pullup)

process.on('SIGINT', () => {
    rpio.close(SHUTDOWN_PIN, rpio.PIN_RESET);
    process.exit();
});
JS
sudo chown $VOLUSER:$VOLUSER $WORKDIR/index.js

# 4) Node-Module installieren
sudo -u $VOLUSER npm install --prefix $WORKDIR --production

# 5) systemd Service
sudo tee /etc/systemd/system/$SERVICE_NAME.service > /dev/null <<SERVICE
[Unit]
Description=Raspberry Pi Shutdown Button (GPIO17, rpio)
After=multi-user.target

[Service]
ExecStart=/usr/bin/node /opt/shutdown-button/index.js
WorkingDirectory=/opt/shutdown-button
Restart=always
User=root
Group=root

[Install]
WantedBy=multi-user.target
SERVICE

# 6) Service aktivieren und starten
sudo systemctl daemon-reload
sudo systemctl enable $SERVICE_NAME.service
sudo systemctl restart $SERVICE_NAME.service

echo "=== Shutdown Button Installation Complete ==="
systemctl status $SERVICE_NAME.service --no-pager
