#!/bin/bash
# Installs the PHP-rendered airplanes-config.txt into /boot, applying the
# MLAT_USER schema migration before publishing. Wrapped under flock so
# restart-services.sh cannot read a half-migrated file. The temp file is
# adjacent to /boot/airplanes-config.txt so readers never see a
# legacy-only intermediate state at the canonical path.
set -euo pipefail
# AIRPLANES_CONFIG_BACKUP_BASE points backups at the canonical path. Without
# it, migrate-config.sh would write `.pre-mlat-split` / `.pre-marker-split`
# next to the random temp file; mv-to-canonical leaves those backups
# orphaned in /boot under random suffixes, accumulating one per save.
exec flock /var/lock/airplanes-config.lock env \
    AIRPLANES_CONFIG_LOCK_HELD=1 \
    AIRPLANES_CONFIG_BACKUP_BASE=/boot/airplanes-config.txt \
    bash -c '
    set -euo pipefail
    tmp="$(mktemp /boot/airplanes-config.txt.XXXXXX)"
    trap "rm -f \"$tmp\"" EXIT
    cp /tmp/webconfig/airplanes-config.txt "$tmp"
    /airplanes/webconfig/helpers/migrate-config.sh "$tmp"
    chmod --reference=/boot/airplanes-config.txt "$tmp" 2>/dev/null || chmod 0644 "$tmp"
    mv -f "$tmp" /boot/airplanes-config.txt
    trap - EXIT
'
