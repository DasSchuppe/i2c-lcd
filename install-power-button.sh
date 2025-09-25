#!/bin/bash
set -e

WORKDIR="/opt/power-button"
VOLUSER="volumio"
SERVICE_NAME="power-button"

echo "=== Raspberry Pi Power Button Installer (Ein/Aus mit GPIO3) ==="

# 1) Verzeichnis anlegen
sudo mkdir -p $WORKDIR
sudo chown -R $VOLUSER:$VOLUSER $WORKDIR

# 2) package.json
sudo tee $WORKDIR/package.json > /dev/null <<'JSON'
{
  "name": "power-button",
  "version": "1.0.0",
  "description": "Single power button for Raspberry Pi (GPIO3)",
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

// GPIO3 (Pin 5) als Input mit Pullup
// WICHTIG: Pi startet automatisch, wenn Pin 5 kurzzeitig auf GND gezogen wird.
const powerButton = new Gpio(3, 'in', 'falling', { debounceTimeout: 200 });

powerButton.watch((err, value) => {
  if (err) {
    console.error('GPIO Error:', err);
    return;
  }
  console.log("Power button pressed → Shutdown");
  require('child_process').exec('sudo shutdown -h now');
});

process.on('SIGINT', () => {
  powerButton.unexport();
});
JS
sudo chown $VOLUSER:$VOLUSER $WORKDIR/index.js

# 4) Module installieren
sudo -u $VOLUSER npm install --prefix $WORKDIR --production

# 5) systemd Service
sudo tee /etc/systemd/system/$SERVICE_NAME.service > /dev/null <<'SERVICE'
[Unit]
Description=Raspberry Pi Power Button (GPIO3)
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
