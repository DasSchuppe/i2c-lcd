'use strict';

const i2c = require('i2c-bus');

class I2cLcd {
  constructor(addr = 0x27, rows = 2, cols = 16) {
    this.addr = addr;
    this.rows = rows;
    this.cols = cols;
    this.bus = null;
  }

  async init() {
    this.bus = i2c.openSync(1);
    await this.clear();
    // Optional: LCD initialisieren (4-Bit-Modus, Cursor, etc.)
    // Das hängt vom spezifischen PCF8574-Controller ab
  }

  async clear() {
    if (!this.bus) return;
    // Einfach alle Zellen mit Leerzeichen füllen
    for (let r = 0; r < this.rows; r++) {
      await this.print(' '.repeat(this.cols), r);
    }
  }

  async print(text, row = 0) {
    if (!this.bus) return;
    const line = (text || '').toString().padEnd(this.cols).slice(0, this.cols);
    // Hier müsstest du die eigentliche I2C-Kommunikation zum Schreiben der Daten auf das LCD implementieren
    // Für PCF8574-Backpack z.B. die 4-Bit-Pakete über I2C senden
    console.log(`[LCD] Row ${row + 1}: "${line}"`); // Debug-Ausgabe
  }

  async showLine(lineNum, text) {
    const row = lineNum === 1 ? 0 : 1;
    await this.print(text, row);
  }

  async showWelcome(line1, line2) {
    await this.showLine(1, line1 || ' Willkommen bei   ');
    await this.showLine(2, line2 || '    Volumio!     ');
  }

  async showTitle(title, artist) {
    await this.showLine(1, (artist || '').toString().slice(0, this.cols));
    await this.showLine(2, (title || '').toString().slice(0, this.cols));
  }

  shutdown() {
    this.clear();
    if (this.bus) {
      this.bus.closeSync();
      this.bus = null;
    }
  }
}

module.exports = I2cLcd;
