#!/bin/bash
set -e

WORKDIR="/opt/qapass-lcd"
SERVICE_NAME="qapass-lcd"

echo "=== QAPASS / LCM1602 LCD Service Uninstaller (mit Shutdown-Support) ==="

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
    sudo systemctl reset-failed
fi

# 3) Arbeitsverzeichnis löschen (inkl. shutdown.js, index.js, lib/, node_modules etc.)
if [ -d "$WORKDIR" ]; then
    echo "Removing working directory $WORKDIR..."
    sudo rm -rf "$WORKDIR"
fi

echo "=== Uninstallation complete ==="
