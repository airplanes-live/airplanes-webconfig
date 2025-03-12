#!/bin/bash

# remove fr24feed in package form
apt purge -y fr24feed &>/dev/null
# remove the fr24feed updater (should be removed with the package but let's make real sure)
rm -f /etc/cron.d/fr24feed_updater

set -e

if ! id -u fr24 &>/dev/null; then
    adduser --system --no-create-home fr24 || true
    addgroup fr24 || true
    adduser fr24 fr24 || true
fi
cd
rm /tmp/fr24 -rf
mkdir -p /tmp/fr24
cd /tmp

wget -O fr24.deb https://repo-feed.flightradar24.com/rpi_binaries/fr24feed_1.0.48-0_armhf.deb

dpkg -x fr24.deb fr24
cp -f fr24/usr/bin/fr24feed* /usr/bin
# add fr24key="key" from webui
ini ]]; then
    cat >/etc/fr24feed.ini << "EOF"
receiver="beast-tcp"
host="127.0.0.1:30005"
bs="no"
raw="no"
mlat="yes"
mlat-without-gps="yes"
EOF
fi
chmod 666 /etc/fr24feed.ini

cat >/etc/systemd/system/fr24feed.service <<"EOF"
[Unit]
Description=Flightradar24 Trash Feeder
After=network-online.target

[Service]
Type=simple
Restart=always
ExecStartPre=-/bin/rm -f /dev/shm/decoder.txt
ExecStopPost=-/bin/rm -f /dev/shm/decoder.txt

ExecStart=/usr/bin/fr24feed --validate-config --config-file=/etc/fr24feed.ini

User=fr24
PermissionsStartOnly=true
SyslogIdentifier=fr24feed
SendSIGHUP=yes
TimeoutStopSec=5
RestartSec=0
StartLimitInterval=5
StartLimitBurst=20

[Install]
WantedBy=multi-user.target
EOF


systemctl enable fr24feed
if grep -qs fr24key /etc/fr24feed.ini; then
    systemctl restart fr24feed || true
fi
