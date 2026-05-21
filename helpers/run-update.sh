#!/bin/bash
set -e

# /run is mounted noexec on bookworm by default (it was exec-allowed on
# bullseye), so executing /run/bg-update.sh directly fails with
# `Permission denied` on the 2025 Pi-OS fleet. Invoke via /bin/bash so
# the noexec mount option does not block — bash itself is the binary
# being exec'd, and bg-update.sh just needs to be readable.
rm -f /run/bg-update.sh
cp /airplanes/webconfig/helpers/bg-update.sh /run/bg-update.sh

systemd-run --on-active=3 /bin/bash /run/bg-update.sh

sleep 1
exit
