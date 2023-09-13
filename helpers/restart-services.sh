#!/bin/bash

restartIfEnabled() {
    # check if enabled
    if systemctl is-enabled "$1" &>/dev/null; then
            systemctl restart "$1"
    fi
}

systemctl restart webconfig

airplanes-first-run

services="readsb dump978-fa airplanes-978 airplanes-feed airplanes-mlat webconfig leds"
for service in $services; do
    restartIfEnabled $service
done

