#!/bin/bash
# Installs the PHP-rendered airplanes-config.txt into /boot, applying the
# MLAT_USER schema migration before publishing. Wrapped under flock so
# restart-services.sh cannot read a half-migrated file. The temp file is
# adjacent to /boot/airplanes-config.txt so readers never see a
# legacy-only intermediate state at the canonical path.
set -euo pipefail
exec flock /var/lock/airplanes-config.lock env AIRPLANES_CONFIG_LOCK_HELD=1 bash -c '
    set -euo pipefail
    tmp="$(mktemp /boot/airplanes-config.txt.XXXXXX)"
    trap "rm -f \"$tmp\"" EXIT
    cp /tmp/webconfig/airplanes-config.txt "$tmp"
    /airplanes/webconfig/helpers/migrate-config.sh "$tmp"
    chmod --reference=/boot/airplanes-config.txt "$tmp" 2>/dev/null || chmod 0644 "$tmp"
    mv -f "$tmp" /boot/airplanes-config.txt
    trap - EXIT
'
