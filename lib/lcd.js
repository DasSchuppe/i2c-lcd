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
    // Optional: Hier können Initialisierungscodes für PCF8574-LCD kommen
  }

  async clear() {
    if (!this.bus) return;
    for (let r = 0; r < this.rows; r++) {
      await this.print(' '.repeat(this.cols), r);
    }
  }

  async print(text, row = 0) {
    if (!this.bus) return;
    const line = (text || '').toString().padEnd(this.cols).slice(0, this.cols);
    // Hier müsste die eigentliche I2C-Kommunikation implementiert werden
    // z.B. 4-Bit-Mode Befehle an PCF8574 senden
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

  async shutdown() {
    await this.clear();
    if (this.bus) {
      this.bus.closeSync();
      this.bus = null;
    }
  }
}

module.exports = I2cLcd;
