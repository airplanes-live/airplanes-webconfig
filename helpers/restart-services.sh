#!/bin/bash

restartIfEnabled() {
    # check if enabled
    if systemctl is-enabled "$1" &>/dev/null; then
            systemctl restart "$1"
    fi
}

systemctl restart webconfig

adsbfi-first-run

services="readsb dump978-fa adsbfi-978 adsbfi-feed adsbfi-mlat webconfig leds"
for service in $services; do
    restartIfEnabled $service
done

