#!/bin/bash
set -e

WORKDIR="/opt/power-buttons"
SERVICE_NAME="power-buttons"

echo "=== Raspberry Pi Power Buttons Uninstaller ==="

# 1) Service stoppen und deaktivieren
if systemctl is-active --quiet $SERVICE_NAME.service; then
    echo "Stopping service..."
    sudo systemctl stop $SERVICE_NAME.service
fi

if systemctl is-enabled --quiet $SERVICE_NAME.service; then
    echo "Disabling service..."
    sudo systemctl disable $SERVICE_NAME.service
fi

# 2) Service-Datei löschen
if [ -f /etc/systemd/system/$SERVICE_NAME.service ]; then
    echo "Removing service file..."
    sudo rm /etc/systemd/system/$SERVICE_NAME.service
    sudo systemctl daemon-reload
fi

# 3) Arbeitsverzeichnis löschen
if [ -d "$WORKDIR" ]; then
    echo "Removing working directory $WORKDIR..."
    sudo rm -rf "$WORKDIR"
fi

echo "=== Uninstallation complete ==="
