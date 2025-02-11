#!/bin/bash

cp /tmp/webconfig/airplanes-uiconfig.nmconnection /etc/NetworkManager/system-connections/airplanes-uiconfig.nmconnection
chmod 600 /etc/NetworkManager/system-connections/*
rm -f /tmp/webconfig/airplanes-uiconfig.nmconnection
raspi-config nonint do_wifi_country $(cat /tmp/webconfig/wificountry)
nmcli 
sleep 5
reboot now
