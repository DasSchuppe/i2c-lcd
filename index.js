'use strict';

const I2cLcd = require('./lib/lcd');
const io = require('socket.io-client');

const lcd = new I2cLcd();

async function start() {
  await lcd.init();
  await lcd.showWelcome();

  // Beispiel Socket-Verbindung zu Volumio
  const socket = io('http://localhost:3000'); // passe URL ggf. an

  socket.on('connect', () => {
    console.log('Verbunden mit Volumio');
  });

  socket.on('pushState', async (state) => {
    if (state.status === 'play') {
      await lcd.showTitle(state.title, state.artist);
    } else {
      await lcd.showWelcome();
    }
  });

  process.on('SIGINT', () => {
    lcd.shutdown();
    process.exit();
  });
}

start().catch(console.error);
