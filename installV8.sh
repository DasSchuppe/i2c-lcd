#!/bin/bash
set -e

WORKDIR="/opt/qapass-lcd"
VOLUSER="volumio"

echo "=== QAPASS / LCM1602 LCD Service Installer ==="
echo "Arbeitsverzeichnis: $WORKDIR"
echo "User: $VOLUSER"

# 1) Verzeichnis erstellen
sudo mkdir -p $WORKDIR/lib
sudo chown -R $VOLUSER:$VOLUSER $WORKDIR

# 2) package.json
sudo tee $WORKDIR/package.json > /dev/null <<'JSON'
{
  "name": "qapass-lcd-service",
  "version": "1.0.0",
  "description": "Display Volumio playback info on LCM1602 I2C LCD",
  "main": "index.js",
  "scripts": {
    "start": "node index.js"
  },
  "dependencies": {
    "i2c-bus": "^5.2.2",
    "socket.io-client": "^4.8.1",
    "node-fetch": "^2.6.7"
  },
  "author": "DasSchuppe",
  "license": "MIT"
}
JSON
sudo chown $VOLUSER:$VOLUSER $WORKDIR/package.json

# 3) lib/lcd.js
sudo tee $WORKDIR/lib/lcd.js > /dev/null <<'JS'
'use strict';
const i2c = require('i2c-bus');

const LCD_CHR = 1;
const LCD_CMD = 0;
const LCD_BACKLIGHT = 0x08;
const ENABLE = 0x04;

const LCD_CLEAR_DISPLAY = 0x01;
const LCD_ENTRY_MODE_SET = 0x06;
const LCD_DISPLAY_ON = 0x0C;
const LCD_FUNCTION_SET = 0x28;

class LCM1602 {
  constructor(addr = 0x27, rows = 2, cols = 16) {
    this.addr = addr;
    this.rows = rows;
    this.cols = cols;
    this.bus = null;
  }

  init() {
    this.bus = i2c.openSync(1);
    this.sendCommand(LCD_FUNCTION_SET);
    this.sendCommand(LCD_DISPLAY_ON);
    this.sendCommand(LCD_CLEAR_DISPLAY);
    this.sleep(50); // LCM1602 braucht etwas Pause nach Clear
    this.sendCommand(LCD_ENTRY_MODE_SET);
  }

  sendCommand(cmd) { this.sendByte(cmd, LCD_CMD); }
  sendData(data) { this.sendByte(data.charCodeAt(0), LCD_CHR); }

  sendByte(bits, mode) {
    const high = (bits & 0xF0) | mode | LCD_BACKLIGHT;
    const low = ((bits << 4) & 0xF0) | mode | LCD_BACKLIGHT;
    this.writeNibble(high);
    this.writeNibble(low);
  }

  writeNibble(bits) {
    this.bus.writeByteSync(this.addr, 0, bits | ENABLE);
    this.sleep(5);
    this.bus.writeByteSync(this.addr, 0, bits & ~ENABLE);
    this.sleep(5);
  }

  sleep(ms) { const end = Date.now() + ms; while(Date.now() < end); }

  clear() { this.sendCommand(LCD_CLEAR_DISPLAY); this.sleep(50); }

  setCursor(line, col) {
    const rowOffsets = [0x00, 0x40, 0x14, 0x54];
    this.sendCommand(0x80 | (col + rowOffsets[line]));
  }

  print(text, line = 0) {
    text = text.toString().padEnd(this.cols).slice(0, this.cols);
    this.setCursor(line, 0);
    for (let i = 0; i < text.length; i++) { this.sendData(text[i]); }
  }

  showWelcome() {
    this.clear();
    this.print(' Willkommen bei   ', 0);
    this.print('    Volumio!     ', 1);
  }

  shutdown() {
    this.clear();
    if (this.bus) { this.bus.closeSync(); this.bus = null; }
  }
}

module.exports = LCM1602;
JS
sudo chown -R $VOLUSER:$VOLUSER $WORKDIR/lib

# 4) lcd-worker.js
sudo tee $WORKDIR/lcd-worker.js > /dev/null <<'JS'
'use strict';
const { parentPort } = require('worker_threads');
const LCM1602 = require('./lib/lcd');

const lcd = new LCM1602();
lcd.init();
lcd.showWelcome();

let lastTitle = '';
let lastArtist = '';

function safeText(text) {
  return text.replace(/[^\x20-\x7E]/g,'').padEnd(16).slice(0,16);
}

parentPort.on('message', state => {
  const title = state.title || '';
  const artist = state.artist || '';

  if (title === lastTitle && artist === lastArtist) return;

  lastTitle = title;
  lastArtist = artist;

  lcd.clear();
  if(title) lcd.print(safeText(title), 0);
  if(artist) lcd.print(safeText(artist), 1);
});
JS
sudo chown $VOLUSER:$VOLUSER $WORKDIR/lcd-worker.js

# 5) index.js
sudo tee $WORKDIR/index.js > /dev/null <<'JS'
'use strict';
const { Worker } = require('worker_threads');
const io = require('socket.io-client');
const fetch = require('node-fetch');

const worker = new Worker('./lcd-worker.js');
worker.on('error', console.error);
worker.on('exit', code => console.log('LCD Worker exit', code));

let welcomeDone = false;

setTimeout(() => {
  welcomeDone = true;
  fetch('http://localhost:3000/api/v1/getState')
    .then(res => res.json())
    .then(state => worker.postMessage(state))
    .catch(err => console.log('Error fetching current state:', err));
}, 20000);

const socket = io('http://localhost:3000', {transports: ['websocket']});
socket.on('pushState', state => {
  if(welcomeDone) worker.postMessage(state);
});

process.on('SIGINT', () => {
  worker.terminate();
});
JS
sudo chown $VOLUSER:$VOLUSER $WORKDIR/index.js

# 6) Node-Module installieren
sudo -u $VOLUSER npm install --prefix $WORKDIR --production

# 7) systemd Service
sudo tee /etc/systemd/system/qapass-lcd.service > /dev/null <<'SERVICE'
[Unit]
Description=QAPASS / LCM1602 I2C LCD Service
After=network.target

[Service]
ExecStart=/usr/bin/node /opt/qapass-lcd/index.js
WorkingDirectory=/opt/qapass-lcd
Restart=always
User=volumio
Group=volumio
CPUQuota=30%
Nice=10

[Install]
WantedBy=multi-user.target
SERVICE

# 8) Service aktivieren und starten
sudo systemctl daemon-reload
sudo systemctl enable qapass-lcd.service
sudo systemctl restart qapass-lcd.service

echo "=== Installation complete ==="
systemctl status qapass-lcd.service --no-pager
