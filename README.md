# QAPASS / LCM1602 LCD Service for Volumio

Display the current playback information from Volumio on a **16x2 I2C LCD (LCM1602)**.

---

## Features

- Shows current track **title** and **artist**.
- Automatic update every **5 seconds**.
- Works without modifying Volumio core.
- Easy installation via `install.sh`.
- Clean uninstallation via `uninstall.sh`.

---

## Requirements

- Volumio 3+
- Raspberry Pi (any model with I2C support)
- 16x2 LCD with I2C backpack
- Node.js installed on Volumio (comes preinstalled)

---

## Installation

```bash
git clone https://github.com/<your-username>/qapass-lcd.git
cd qapass-lcd
sudo bash install.sh
```
After installation, the service will automatically start and display track info.

## Uninstallation

```bash
Code kopieren
sudo bash uninstall.sh
```
This will stop the service and remove all files.

## Usage
The LCD will automatically update every 5 seconds.

The first 20 seconds show a welcome message:

Willkommen bei
    Volumio!
 
## Customization
Change I2C address in lib/lcd.js (default: 0x27)

Change update interval by editing the setInterval in index.js

License
MIT License
Author: DasSchuppe
