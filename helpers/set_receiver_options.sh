#!/bin/bash

if [[ "$1" == "/boot/airplanes-env" ]] || [[ "$1" == "/boot/airplanes-978env" ]]; then
    sed -i -e "s|^RECEIVER_OPTIONS=.*$|RECEIVER_OPTIONS=\"$2\"|" "$1"
fi
