#!/bin/bash
set -e

rm -f /tmp/bg-update.sh
cp /airplanes/webconfig/helpers/bg-update.sh /tmp/bg-update.sh

systemd-run --uid=root --on-active=3 /tmp/bg-update.sh

sleep 1
exit
