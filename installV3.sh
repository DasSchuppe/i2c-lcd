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
    "axios": "^1.7.2"
  },
  "author": "DasSchuppe",
  "license": "MIT"
}
JSON
sudo chown $VOLUSER:$VOLUSER $WORKDIR/package.json

# 3) lib/lcd.js (LCM1602-spezifisch)
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
    // Init sequence für LCM1602
    this.sendCommand(LCD_FUNCTION_SET);
    this.sendCommand(LCD_DISPLAY_ON);
    this.sendCommand(LCD_CLEAR_DISPLAY);
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
    this.sleep(1);
    this.bus.writeByteSync(this.addr, 0, bits & ~ENABLE);
    this.sleep(1);
  }

  sleep(ms) { const end = Date.now() + ms; while(Date.now() < end); }

  clear() { this.sendCommand(LCD_CLEAR_DISPLAY); this.sleep(2); }

  setCursor(line, col) {
    const rowOffsets = [0x00, 0x40, 0x14, 0x54];
    this.sendCommand(0x80 | (col + rowOffsets[line]));
  }

  print(text, line = 0) {
    text = text.toString().padEnd(this.cols).slice(0, this.cols);
    this.setCursor(line, 0);
    for(let i = 0; i < text.length; i++){ this.sendData(text[i]); }
  }

  showWelcome() {
    this.clear();
    this.print(' Willkommen bei   ',0);
    this.print('    Volumio!     ',1);
  }

  showTitle(title, artist) {
    this.clear();
    this.print(artist ? artist.toString().slice(0,this.cols) : '',0);
    this.print(title ? title.toString().slice(0,this.cols) : 'Pause',1);
  }

  shutdown() {
    this.clear();
    if(this.bus){this.bus.closeSync(); this.bus = null;}
  }
}

module.exports = LCM1602;
JS
sudo chown -R $VOLUSER:$VOLUSER $WORKDIR/lib

# 4) index.js mit REST-API Polling
sudo tee $WORKDIR/index.js > /dev/null <<'JS'
'use strict';

const LCM1602 = require('./lib/lcd');
const axios = require('axios');

const lcd = new LCM1602();
lcd.init();
lcd.showWelcome();

// Zeige Willkommensscreen 10 Sekunden
setTimeout(updateState, 10000);

// Funktion zum Abrufen und Anzeigen des aktuellen Songs
async function updateState() {
  try {
    const response = await axios.get('http://localhost:3000/api/v1/getState');
    const state = response.data;
    if(state.status === 'play') {
      lcd.showTitle(state.title, state.artist);
    } else {
      lcd.showTitle('Pause','');
    }
  } catch (err) {
    console.error('Fehler beim Abrufen des State:', err.message);
    lcd.showTitle('Fehler','API');
  }
  // alle 5 Sekunden aktualisieren
  setTimeout(updateState, 5000);
}

// Beende sauber
process.on('SIGINT', () => { lcd.shutdown(); process.exit(); });
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

[Install]
WantedBy=multi-user.target
SERVICE

# 7) Service aktivieren und starten
sudo systemctl daemon-reload
sudo systemctl enable qapass-lcd.service
sudo systemctl restart qapass-lcd.service

echo "=== Installation complete ==="
systemctl status qapass-lcd.service --no-pager

