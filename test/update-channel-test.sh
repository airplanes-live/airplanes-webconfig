#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="${AIRPLANES_WEBCONFIG_TEST_ROOT:-$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)}"
WORK_DIR="$(mktemp -d)"

cleanup() {
    rm -rf "$WORK_DIR"
}
trap cleanup EXIT

# shellcheck source=helpers/update-channel.sh
source "$REPO_ROOT/helpers/update-channel.sh"

fail() {
    echo "ERROR: $*" >&2
    exit 1
}

assert_eq() {
    local expected="$1"
    local actual="$2"
    local label="$3"

    [[ "$actual" == "$expected" ]] || fail "$label: expected '$expected', got '$actual'"
}

reset_channel_env() {
    unset AIRPLANES_CHANNEL
    unset AIRPLANES_WEBCONFIG_CHANNEL_DEFAULT
    unset AIRPLANES_UPDATE_BRANCH
    unset AIRPLANES_FEED_BRANCH
    unset AIRPLANES_WEBCONFIG_BRANCH
    unset AIRPLANES_UPDATE_RAW_BASE
    unset AIRPLANES_WEBCONFIG_RAW_BASE
}

make_checkout() {
    local dir="$1"
    local branch="$2"

    mkdir -p "$dir"
    git -C "$dir" init -q -b "$branch"
    git -C "$dir" config user.email "webconfig-channel@example.invalid"
    git -C "$dir" config user.name "Webconfig Channel Test"
    printf '%s\n' "$branch" > "$dir/.fixture"
    git -C "$dir" add .fixture
    git -C "$dir" commit -q -m "channel fixture"
}

assert_dev_defaults() {
    assert_eq "dev" "$AIRPLANES_CHANNEL" "channel"
    assert_eq "dev" "$AIRPLANES_UPDATE_BRANCH" "update branch"
    assert_eq "dev" "$AIRPLANES_FEED_BRANCH" "feed branch"
    assert_eq "dev" "$AIRPLANES_WEBCONFIG_BRANCH" "webconfig branch"
    assert_eq "https://raw.githubusercontent.com/airplanes-live/airplanes-update/dev/update-airplanes.sh" \
        "$(airplanes_update_script_url)" "update raw URL"
    assert_eq "https://raw.githubusercontent.com/airplanes-live/airplanes-webconfig/dev/update-webconfig.sh" \
        "$(airplanes_webconfig_update_script_url)" "webconfig raw URL"
}

assert_main_defaults() {
    assert_eq "main" "$AIRPLANES_CHANNEL" "channel"
    assert_eq "main" "$AIRPLANES_UPDATE_BRANCH" "update branch"
    assert_eq "" "$AIRPLANES_FEED_BRANCH" "feed branch"
    assert_eq "master" "$AIRPLANES_WEBCONFIG_BRANCH" "webconfig branch"
    assert_eq "https://raw.githubusercontent.com/airplanes-live/airplanes-update/main/update-airplanes.sh" \
        "$(airplanes_update_script_url)" "update raw URL"
    assert_eq "https://raw.githubusercontent.com/airplanes-live/airplanes-webconfig/master/update-webconfig.sh" \
        "$(airplanes_webconfig_update_script_url)" "webconfig raw URL"
}

test_dev_checkout_defaults_to_dev() {
    local checkout="$WORK_DIR/dev-checkout"
    make_checkout "$checkout" dev
    reset_channel_env

    airplanes_webconfig_apply_channel_defaults "$checkout"
    assert_dev_defaults
    echo "dev checkout defaults passed"
}

test_main_checkout_defaults_to_main() {
    local checkout="$WORK_DIR/main-checkout"
    make_checkout "$checkout" master
    reset_channel_env

    airplanes_webconfig_apply_channel_defaults "$checkout"
    assert_main_defaults
    echo "main checkout defaults passed"
}

test_env_overrides_win() {
    local checkout="$WORK_DIR/override-checkout"
    make_checkout "$checkout" dev
    reset_channel_env

    AIRPLANES_CHANNEL=main
    AIRPLANES_UPDATE_BRANCH=custom-update
    AIRPLANES_FEED_BRANCH=custom-feed
    AIRPLANES_WEBCONFIG_BRANCH=custom-webconfig
    airplanes_webconfig_apply_channel_defaults "$checkout"

    assert_eq "main" "$AIRPLANES_CHANNEL" "channel override"
    assert_eq "custom-update" "$AIRPLANES_UPDATE_BRANCH" "update override"
    assert_eq "custom-feed" "$AIRPLANES_FEED_BRANCH" "feed override"
    assert_eq "custom-webconfig" "$AIRPLANES_WEBCONFIG_BRANCH" "webconfig override"
    echo "env override defaults passed"
}

test_installed_channel_env_is_loaded_without_git() {
    local checkout="$WORK_DIR/dev-installed-source"
    local raw_dir="$WORK_DIR/raw-installed-helper"
    local env_file="$WORK_DIR/channel.env"
    make_checkout "$checkout" dev
    mkdir -p "$raw_dir"
    reset_channel_env

    airplanes_webconfig_apply_channel_defaults "$checkout"
    airplanes_webconfig_write_channel_env "$env_file"

    reset_channel_env
    airplanes_webconfig_load_installed_channel "$env_file" "$raw_dir"
    assert_dev_defaults
    echo "installed channel env load passed"
}

main() {
    test_dev_checkout_defaults_to_dev
    test_main_checkout_defaults_to_main
    test_env_overrides_win
    test_installed_channel_env_is_loaded_without_git
    echo "webconfig update channel tests passed"
}

main "$@"
