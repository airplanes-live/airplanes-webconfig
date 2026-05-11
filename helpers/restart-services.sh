#!/bin/bash
# Restarts services that consume /boot/airplanes-config.txt. Held under the
# same flock as install-adsbconfig.sh so a restart can never fire while a
# save is mid-cp-or-mid-migrate.

set -euo pipefail

exec flock /var/lock/airplanes-config.lock bash -c '
    restartIfEnabled() {
        if systemctl is-enabled "$1" &>/dev/null; then
            systemctl restart "$1"
        fi
    }

    systemctl restart webconfig

    airplanes-first-run

    services="readsb dump978-fa airplanes-978 airplanes-feed airplanes-mlat webconfig leds"
    for service in $services; do
        restartIfEnabled "$service"
    done
'
