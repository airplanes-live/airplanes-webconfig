#!/bin/bash
# Legacy 2025/bookworm feeders migrate to the unified webconfig on the default
# branch. This entry point redirects there; after the first upgrade the
# channel-aware updater takes over and this branch is no longer consulted.
set -euo pipefail

url="https://raw.githubusercontent.com/airplanes-live/airplanes-webconfig/master/update-webconfig.sh"
tmpdir="$(mktemp -d /tmp/airplanes-webconfig-entry.XXXXXX)"
trap 'rm -rf "$tmpdir"' EXIT
entry="$tmpdir/update-webconfig.sh"

if ! wget -q --timeout=30 --tries=3 -O "$entry" "$url" || [[ ! -s "$entry" ]]; then
    echo "[ERROR] failed to fetch $url" >&2
    exit 1
fi

export AIRPLANES_WEBCONFIG_BRANCH=master
cd /tmp
bash "$entry" "$@"
