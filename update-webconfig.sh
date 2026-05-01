#!/bin/bash

set -e
trap 'echo "[ERROR] Error in line $LINENO when executing: $BASH_COMMAND"' ERR

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]:-$0}")" && pwd)"
if [[ -f "$SCRIPT_DIR/helpers/update-channel.sh" ]]; then
    # shellcheck source=helpers/update-channel.sh
    source "$SCRIPT_DIR/helpers/update-channel.sh"
    airplanes_webconfig_apply_channel_defaults "$SCRIPT_DIR"
fi

WEBCONFIG_REPO="${AIRPLANES_WEBCONFIG_REPO:-https://github.com/airplanes-live/airplanes-webconfig.git}"
WEBCONFIG_BRANCH="${AIRPLANES_WEBCONFIG_BRANCH:-master}"

# in case /var/log is full ... delete some logs
echo test > /var/log/.test 2>/dev/null || rm -f /var/log/*.log

function aptInstall() {
    if ! apt install -y --no-install-recommends --no-install-suggests "$@"; then
        apt update
        apt install -y --no-install-recommends --no-install-suggests "$@"
    fi
}

aptInstall git

cd /tmp
updir=/tmp/update-webconfig

rm -rf "$updir"
git clone --depth 1 --single-branch --branch "$WEBCONFIG_BRANCH" "$WEBCONFIG_REPO" "$updir"

cd "$updir"
bash install.sh dont_reset_config


cd /tmp
rm -rf "$updir"

echo "8.3.$(date '+%y%m%d')" > /boot/airplanes-version-webconfig

echo '--------------------------------------------'
echo '        update-webconfig complete.          '
echo '--------------------------------------------'
