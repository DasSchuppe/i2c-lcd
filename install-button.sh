#!/bin/bash
set -e

WORKDIR="/opt/shutdown-button"
VOLUSER="volumio"
SERVICE_NAME="shutdown-button"
GPIO_PIN=17   # Du kannst hier auch 27 setzen, je nach Verfügbarkeit

echo "=== Raspberry Pi Shutdown Button Installer (GPIO$GPIO_PIN) ==="

# 1) Arbeitsverzeichnis anlegen
sudo mkdir -p $WORKDIR
sudo chown -R $VOLUSER:$VOLUSER $WORKDIR

# 2) package.json
sudo tee $WORKDIR/package.json > /dev/null <<'JSON'
{
  "name": "shutdown-button",
  "version": "1.0.0",
  "description": "Raspberry Pi shutdown button via GPIO",
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
sudo tee $WORKDIR/index.js > /dev/null <<JS
'use strict';

const Gpio = require('onoff').Gpio;
const { exec } = require('child_process');

const pin = parseInt(process.env.GPIO_PIN) || $GPIO_PIN;

// Input-Pin mit Pullup (Button auf GND)
const shutdownButton = new Gpio(pin, 'in', 'falling', { debounceTimeout: 200 });

console.log('Shutdown Button Service gestartet. GPIO' + pin + ' überwacht.');

shutdownButton.watch((err, value) => {
    if (err) {
        console.error('GPIO Fehler:', err);
        return;
    }
    console.log('Shutdown Button gedrückt → System fährt herunter');
    exec('sudo shutdown -h now', (err, stdout, stderr) => {
        if (err) console.error('Fehler beim Shutdown:', err);
    });
});

// sauber schließen bei SIGINT/SIGTERM
function cleanup() {
    shutdownButton.unexport();
    process.exit();
}

process.on('SIGINT', cleanup);
process.on('SIGTERM', cleanup);
JS
sudo chown $VOLUSER:$VOLUSER $WORKDIR/index.js

# 4) Node-Module installieren
sudo -u $VOLUSER npm install --prefix $WORKDIR --production

# 5) systemd Service
sudo tee /etc/systemd/system/$SERVICE_NAME.service > /dev/null <<SERVICE
[Unit]
Description=Raspberry Pi Shutdown Button (GPIO$GPIO_PIN)
After=multi-user.target

[Service]
ExecStart=/usr/bin/node $WORKDIR/index.js
Environment=GPIO_PIN=$GPIO_PIN
WorkingDirectory=$WORKDIR
Restart=always
User=$VOLUSER
Group=$VOLUSER

[Install]
WantedBy=multi-user.target
SERVICE

# 6) Service aktivieren und starten
sudo systemctl daemon-reload
sudo systemctl enable $SERVICE_NAME.service
sudo systemctl restart $SERVICE_NAME.service

echo "=== Shutdown Button Installation Complete (GPIO$GPIO_PIN) ==="
systemctl status $SERVICE_NAME.service --no-pager
