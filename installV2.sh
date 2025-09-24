#!/bin/bash
set -e

echo "=== QAPASS/LCM1602 LCD Service Installer ==="

INSTALL_DIR="/opt/qapass-lcd"
SERVICE_FILE="/etc/systemd/system/qapass-lcd.service"

sudo mkdir -p $INSTALL_DIR/lib
sudo chown -R volumio:volumio $INSTALL_DIR

# package.json
cat > $INSTALL_DIR/package.json <<'JSON'
{
  "name": "qapass-lcd-service",
  "version": "1.0.0",
  "main": "index.js",
  "dependencies": {
    "i2c-bus": "^5.2.2",
    "socket.io-client": "^4.7.2"
  }
}
JSON

# lib/lcd.js
cat > $INSTALL_DIR/lib/lcd.js <<'JS'
const i2c = require('i2c-bus');

class LCM1602 {
  constructor(addr = 0x27, busNumber = 1) {
    this.addr = addr;
    this.bus = i2c.openSync(busNumber);
    this.backlight = 0x08;
  }

  sleep(ms) {
    Atomics.wait(new Int32Array(new SharedArrayBuffer(4)), 0, 0, ms);
  }

  write4bits(val) {
    this.bus.writeByteSync(this.addr, 0x00, val | this.backlight);
    this.bus.writeByteSync(this.addr, 0x00, (val | 0x04) | this.backlight);
    this.bus.writeByteSync(this.addr, 0x00, (val & ~0x04) | this.backlight);
  }

  send(val, mode) {
    const high = val & 0xF0;
    const low = (val << 4) & 0xF0;
    this.write4bits(high | mode);
    this.write4bits(low | mode);
  }

  command(cmd) {
    this.send(cmd, 0x00);
  }

  writeChar(ch) {
    this.send(ch.charCodeAt(0), 0x01);
  }

  clear() {
    this.command(0x01);
    this.sleep(2);
  }

  home() {
    this.command(0x02);
    this.sleep(2);
  }

  setCursor(col, row) {
    const rowOffsets = [0x00, 0x40];
    this.command(0x80 | (col + rowOffsets[row]));
  }

  init() {
    this.sleep(50);
    this.write4bits(0x30);
    this.sleep(5);
    this.write4bits(0x30);
    this.sleep(1);
    this.write4bits(0x30);
    this.write4bits(0x20);

    this.command(0x28);
    this.command(0x0C);
    this.command(0x06);
    this.clear();
  }

  print(text) {
    for (let i = 0; i < text.length; i++) {
      this.writeChar(text[i]);
    }
  }

  showTitle(title, artist) {
    this.clear();
    this.setCursor(0, 0);
    this.print((title || '').substring(0, 16));
    this.setCursor(0, 1);
    this.print((artist || '').substring(0, 16));
  }
}

module.exports = LCM1602;
JS

# index.js (Debug-Version)
cat > $INSTALL_DIR/index.js <<'JS'
const LCM1602 = require('./lib/lcd');
const lcd = new LCM1602();

lcd.init();
lcd.showTitle('Willkommen bei', 'Volumio');

const io = require('socket.io-client');
const socket = io("http://localhost:3000");

socket.on('connect', () => {
  console.log("Connected to Volumio");
  socket.emit("getState"); // direkt Status anfordern
});

// Debug: alle Events loggen
socket.onAny((event, data) => {
  console.log("EVENT:", event, data);
});

socket.on('pushState', (state) => {
  console.log("pushState:", state);
  let title = state.title || state.track || state.name || '';
  let artist = state.artist || state.albumartist || state.service || '';
  if (state.status === 'play') {
    lcd.showTitle(title, artist);
  } else {
    lcd.showTitle('Pause', '');
  }
});
JS

# Dependencies installieren
cd $INSTALL_DIR
npm install --production

# Service
cat > $SERVICE_FILE <<'SERVICE'
[Unit]
Description=QAPASS 1602 I2C LCD Service
After=network.target

[Service]
ExecStart=/usr/bin/node /opt/qapass-lcd/index.js
WorkingDirectory=/opt/qapass-lcd
Restart=always
User=volumio
Environment=NODE_ENV=production

[Install]
WantedBy=multi-user.target
SERVICE

# Service aktivieren
sudo systemctl daemon-reload
sudo systemctl enable qapass-lcd.service
sudo systemctl restart qapass-lcd.service

echo "=== Installation complete ==="
systemctl status qapass-lcd.service --no-pager

