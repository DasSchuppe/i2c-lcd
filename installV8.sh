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

# 3) lib/lcd.js (non-blocking)
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

function sleep(ms) {
  return new Promise(resolve => setTimeout(resolve, ms));
}

class LCM1602 {
  constructor(addr = 0x27, rows = 2, cols = 16) {
    this.addr = addr;
    this.rows = rows;
    this.cols = cols;
    this.bus = null;
  }

  async init() {
    this.bus = i2c.openSync(1);
    await this.sendCommand(LCD_FUNCTION_SET);
    await this.sendCommand(LCD_DISPLAY_ON);
    await this.sendCommand(LCD_CLEAR_DISPLAY);
    await sleep(50);
    await this.sendCommand(LCD_ENTRY_MODE_SET);
  }

  async sendCommand(cmd) { await this.sendByte(cmd, LCD_CMD); }
  async sendData(data) { await this.sendByte(data.charCodeAt(0), LCD_CHR); }

  async sendByte(bits, mode) {
    const high = (bits & 0xF0) | mode | LCD_BACKLIGHT;
    const low = ((bits << 4) & 0xF0) | mode | LCD_BACKLIGHT;
    await this.writeNibble(high);
    await this.writeNibble(low);
  }

  async writeNibble(bits) {
    this.bus.writeByteSync(this.addr, 0, bits | ENABLE);
    await sleep(2);
    this.bus.writeByteSync(this.addr, 0, bits & ~ENABLE);
    await sleep(2);
  }

  async clear() { await this.sendCommand(LCD_CLEAR_DISPLAY); await sleep(50); }

  async setCursor(line, col) {
    const rowOffsets = [0x00, 0x40, 0x14, 0x54];
    await this.sendCommand(0x80 | (col + rowOffsets[line]));
  }

  async print(text, line = 0) {
    text = text.replace(/[^\x20-\x7E]/g,'').padEnd(this.cols).slice(0,this.cols);
    await this.setCursor(line, 0);
    for (let i=0; i<text.length; i++) {
      await this.sendData(text[i]);
    }
  }

  async showWelcome() {
    await this.clear();
    await this.print(' Willkommen bei   ',0);
    await this.print('    Volumio!     ',1);
  }

  async shutdown() {
    await this.clear();
    if (this.bus) { this.bus.closeSync(); this.bus = null; }
  }
}

module.exports = LCM1602;
JS
sudo chown -R $VOLUSER:$VOLUSER $WORKDIR/lib

# 4) index.js (async LCD)
sudo tee $WORKDIR/index.js > /dev/null <<'JS'
'use strict';
const LCM1602 = require('./lib/lcd');
const io = require('socket.io-client');
const fetch = require('node-fetch');

(async () => {
  const lcd = new LCM1602();
  await lcd.init();
  await lcd.showWelcome();

  let welcomeDone = false;
  let lastTitle = '';
  let lastArtist = '';

  function safeText(text) {
    return text.replace(/[^\x20-\x7E]/g,'').padEnd(16).slice(0,16);
  }

  async function updateLCD(state) {
    const title = state.title || '';
    const artist = state.artist || '';

    if(title === lastTitle && artist === lastArtist) return;

    lastTitle = title;
    lastArtist = artist;

    await lcd.clear();
    if(title) await lcd.print(safeText(title), 0);
    if(artist) await lcd.print(safeText(artist), 1);
  }

  // Welcome 20 Sekunden
  setTimeout(async () => {
    welcomeDone = true;
    try {
      const res = await fetch('http://localhost:3000/api/v1/getState');
      const state = await res.json();
      await updateLCD(state);
    } catch(err) {
      console.log('Error fetching current state:', err);
    }
  }, 20000);

  const socket = io('http://localhost:3000', {transports: ['websocket']});
  socket.on('pushState', async state => {
    if(welcomeDone) await updateLCD(state);
  });

  process.on('SIGINT', async () => {
    await lcd.shutdown();
    process.exit();
  });
})();
JS
sudo chown $VOLUSER:$VOLUSER $WORKDIR/index.js

# 5) Node-Module installieren
sudo -u $VOLUSER npm install --prefix $WORKDIR --production

# 6) systemd Service
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

# 7) Service aktivieren und starten
sudo systemctl daemon-reload
sudo systemctl enable qapass-lcd.service
sudo systemctl restart qapass-lcd.service

echo "=== Installation complete ==="
systemctl status qapass-lcd.service --no-pager
