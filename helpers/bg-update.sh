#!/bin/bash

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]:-$0}")" && pwd)"
CHANNEL_HELPER="$SCRIPT_DIR/update-channel.sh"
if [[ ! -f "$CHANNEL_HELPER" ]]; then
    CHANNEL_HELPER="/airplanes/webconfig/helpers/update-channel.sh"
fi

# shellcheck source=/dev/null
source "$CHANNEL_HELPER"
airplanes_webconfig_load_installed_channel "/airplanes/webconfig/channel.env" "$SCRIPT_DIR"

log=/airplanes/airplanes-update.log
rm -f "$log"
exec &> >(tee -a "$log")

export DEBIAN_FRONTEND=noninteractive
apt update
#apt upgrade -y

AIRPLANES_UPDATE_BRANCH="$AIRPLANES_UPDATE_BRANCH" \
AIRPLANES_FEED_BRANCH="$AIRPLANES_FEED_BRANCH" \
    bash -c "$(wget -nv -O - "$(airplanes_update_script_url)")" >> /tmp/web_display_log

AIRPLANES_WEBCONFIG_BRANCH="$AIRPLANES_WEBCONFIG_BRANCH" \
    bash -c "$(wget -nv -O - "$(airplanes_webconfig_update_script_url)")" >> /tmp/web_display_log

echo "rebooting..."
sleep 5
reboot now
