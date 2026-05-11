#!/usr/bin/env bash

airplanes_webconfig_git_branch() {
    local dir="${1:-$(pwd)}"
    if command -v git &>/dev/null && git -C "$dir" rev-parse --is-inside-work-tree &>/dev/null; then
        git -C "$dir" symbolic-ref --quiet --short HEAD 2>/dev/null || true
    fi
}

airplanes_webconfig_detect_channel() {
    local dir="${1:-$(pwd)}"
    local branch
    branch="$(airplanes_webconfig_git_branch "$dir")"
    if [[ "$branch" == "dev" ]]; then
        printf '%s\n' "dev"
    else
        printf '%s\n' "main"
    fi
}

airplanes_webconfig_apply_channel_defaults() {
    local dir="${1:-$(pwd)}"
    local channel="${AIRPLANES_CHANNEL:-${AIRPLANES_WEBCONFIG_CHANNEL_DEFAULT:-}}"
    local update_branch feed_branch webconfig_branch

    if [[ -z "$channel" ]]; then
        channel="$(airplanes_webconfig_detect_channel "$dir")"
    fi

    case "$channel" in
        dev)
            channel="dev"
            update_branch="dev"
            feed_branch="dev"
            webconfig_branch="dev"
            ;;
        *)
            channel="main"
            update_branch="main"
            # Stable legacy-image updates must not pin feed/main here.
            # Leaving AIRPLANES_FEED_BRANCH empty lets airplanes-update's
            # tag-aware bridge resolve the latest stable feed release tag.
            feed_branch=""
            webconfig_branch="master"
            ;;
    esac

    AIRPLANES_CHANNEL="$channel"
    AIRPLANES_UPDATE_BRANCH="${AIRPLANES_UPDATE_BRANCH:-$update_branch}"
    AIRPLANES_FEED_BRANCH="${AIRPLANES_FEED_BRANCH:-$feed_branch}"
    AIRPLANES_WEBCONFIG_BRANCH="${AIRPLANES_WEBCONFIG_BRANCH:-$webconfig_branch}"

    export AIRPLANES_CHANNEL AIRPLANES_UPDATE_BRANCH AIRPLANES_FEED_BRANCH AIRPLANES_WEBCONFIG_BRANCH
}

airplanes_webconfig_load_installed_channel() {
    local env_file="${1:-/airplanes/webconfig/channel.env}"
    local dir="${2:-$(pwd)}"

    if [[ -f "$env_file" ]]; then
        # shellcheck source=/dev/null
        source "$env_file"
    fi
    airplanes_webconfig_apply_channel_defaults "$dir"
}

airplanes_webconfig_write_channel_env() {
    local env_file="$1"
    mkdir -p "$(dirname "$env_file")"
    cat > "$env_file" <<EOF
AIRPLANES_WEBCONFIG_CHANNEL_DEFAULT="$AIRPLANES_CHANNEL"
EOF
}

airplanes_update_script_url() {
    local base="${AIRPLANES_UPDATE_RAW_BASE:-https://raw.githubusercontent.com/airplanes-live/airplanes-update}"
    printf '%s/%s/update-airplanes.sh\n' "${base%/}" "$AIRPLANES_UPDATE_BRANCH"
}

airplanes_webconfig_update_script_url() {
    local base="${AIRPLANES_WEBCONFIG_RAW_BASE:-https://raw.githubusercontent.com/airplanes-live/airplanes-webconfig}"
    printf '%s/%s/update-webconfig.sh\n' "${base%/}" "$AIRPLANES_WEBCONFIG_BRANCH"
}
