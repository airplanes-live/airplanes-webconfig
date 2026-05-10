#!/usr/bin/env bash
# Tests for helpers/migrate-config.sh — legacy USER → MLAT_USER+MLAT_ENABLED
# migration on /boot/airplanes-config.txt.
set -euo pipefail

REPO_ROOT="${AIRPLANES_WEBCONFIG_TEST_ROOT:-$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)}"
MIGRATOR="$REPO_ROOT/helpers/migrate-config.sh"
WORK_DIR="$(mktemp -d)"

cleanup() {
    rm -rf "$WORK_DIR"
}
trap cleanup EXIT

fail() {
    echo "ERROR: $*" >&2
    exit 1
}

assert_eq() {
    local expected="$1" actual="$2" label="$3"
    [[ "$actual" == "$expected" ]] || fail "$label: expected '$expected', got '$actual'"
}

assert_file_eq() {
    local expected="$1" file="$2" label="$3"
    local actual
    actual="$(cat "$file")"
    [[ "$actual" == "$expected" ]] || fail "$label:
--- expected ---
$expected
--- got ---
$actual"
}

run_migrator() {
    AIRPLANES_CONFIG_LOCK_HELD=1 "$MIGRATOR" "$@"
}

with_file() {
    # with_file <name> <content>: writes content to $WORK_DIR/<name>
    local name="$1"; shift
    printf '%s' "$1" > "$WORK_DIR/$name"
    printf '%s\n' "$WORK_DIR/$name"
}

test_version_flag() {
    local out rc=0
    out="$(run_migrator --version)" || rc=$?
    assert_eq 0 "$rc" "--version exit code"
    [[ "$out" == migrate-config.sh\ version=* ]] || fail "--version output: '$out'"
    echo "PASS: --version"
}

test_simple_user_migrates() {
    local f
    f="$(with_file "case1" 'LATITUDE=51.5
USER="alice"
DUMP1090=yes
')"
    run_migrator "$f"
    assert_file_eq 'LATITUDE=51.5
USER="alice"
MLAT_USER="alice"
MLAT_ENABLED=true
DUMP1090=yes' "$f" "USER=alice → split"
    [[ -f "$f.pre-mlat-split" ]] || fail "backup not created"
    echo "PASS: USER=alice migrates"
}

test_user_0_disables() {
    local f
    f="$(with_file "case2" 'USER=0
LATITUDE=0
')"
    run_migrator "$f"
    assert_file_eq 'USER="0"
MLAT_USER=""
MLAT_ENABLED=false
LATITUDE=0' "$f" "USER=0 → disabled"
    echo "PASS: USER=0 disables"
}

test_user_disable_keyword() {
    local f
    f="$(with_file "case3" 'USER=disable
')"
    run_migrator "$f"
    assert_file_eq 'USER="disable"
MLAT_USER=""
MLAT_ENABLED=false' "$f" "USER=disable → disabled"
    echo "PASS: USER=disable disables"
}

test_user_unquoted_normalized() {
    local f
    f="$(with_file "case4" 'USER=bob
')"
    run_migrator "$f"
    assert_file_eq 'USER="bob"
MLAT_USER="bob"
MLAT_ENABLED=true' "$f" "unquoted USER gets normalized"
    echo "PASS: unquoted USER normalized"
}

test_split_brain_user_wins() {
    local f
    f="$(with_file "case5" 'USER="alice"
MLAT_USER="bob"
MLAT_ENABLED=true
')"
    run_migrator "$f"
    assert_file_eq 'USER="alice"
MLAT_USER="alice"
MLAT_ENABLED=true' "$f" "split-brain: USER authoritative"
    echo "PASS: split-brain USER wins"
}

test_already_migrated_no_user() {
    local f
    f="$(with_file "case6" 'MLAT_USER="alice"
MLAT_ENABLED=true
DUMP1090=yes
')"
    local before_mtime after_mtime
    before_mtime="$(stat -c %Y "$f" 2>/dev/null || stat -f %m "$f")"
    sleep 1
    run_migrator "$f"
    after_mtime="$(stat -c %Y "$f" 2>/dev/null || stat -f %m "$f")"
    assert_eq "$before_mtime" "$after_mtime" "already-migrated: mtime preserved"
    [[ ! -f "$f.pre-mlat-split" ]] || fail "backup created on already-migrated file"
    echo "PASS: already-migrated is no-op"
}

test_idempotent_second_run() {
    local f
    f="$(with_file "case7" 'USER="alice"
')"
    run_migrator "$f"
    local first_content first_mtime
    first_content="$(cat "$f")"
    first_mtime="$(stat -c %Y "$f" 2>/dev/null || stat -f %m "$f")"
    sleep 1
    run_migrator "$f"
    local second_content second_mtime
    second_content="$(cat "$f")"
    second_mtime="$(stat -c %Y "$f" 2>/dev/null || stat -f %m "$f")"
    assert_eq "$first_content" "$second_content" "idempotent: content"
    assert_eq "$first_mtime" "$second_mtime" "idempotent: mtime preserved"
    echo "PASS: idempotent second run"
}

test_shell_metachars_escaped() {
    local f
    f="$(with_file "case8" 'USER="weird$X`bt`name"
')"
    run_migrator "$f"
    # USER and MLAT_USER must both have shell metachars escaped.
    grep -q 'USER="weird\\\$X\\`bt\\`name"' "$f" || fail "USER not escaped: $(cat "$f")"
    grep -q 'MLAT_USER="weird\\\$X\\`bt\\`name"' "$f" || fail "MLAT_USER not escaped: $(cat "$f")"
    echo "PASS: shell metachars escaped in both USER and MLAT_USER"
}

test_empty_user_degenerate() {
    local f
    f="$(with_file "case9" 'USER=""
')"
    run_migrator "$f"
    assert_file_eq 'USER=""
MLAT_USER=""
MLAT_ENABLED=true' "$f" "USER='' → MLAT_USER='' MLAT_ENABLED=true"
    echo "PASS: empty USER (degenerate) handled"
}

test_malformed_quote_rejected() {
    local f rc=0
    f="$(with_file "case10" 'USER="alice
DUMP1090=yes
')"
    local before
    before="$(cat "$f")"
    run_migrator "$f" 2>/dev/null || rc=$?
    [[ "$rc" -ne 0 ]] || fail "malformed double-quote not rejected"
    assert_file_eq "$before" "$f" "malformed file unchanged"
    echo "PASS: malformed double-quote rejected, file unchanged"
}

test_missing_file_is_noop() {
    local f="$WORK_DIR/does-not-exist.txt"
    local rc=0
    run_migrator "$f" || rc=$?
    assert_eq 0 "$rc" "missing file is no-op"
    [[ ! -f "$f" ]] || fail "missing-file path was created"
    echo "PASS: missing file is no-op"
}

test_backup_not_overwritten() {
    local f
    f="$(with_file "case11" 'USER="alice"
')"
    run_migrator "$f"
    local backup_content_1
    backup_content_1="$(cat "$f.pre-mlat-split")"
    # Modify the live file via second migration (would re-derive)
    # The backup must NOT be touched.
    sleep 1
    run_migrator "$f"
    local backup_content_2
    backup_content_2="$(cat "$f.pre-mlat-split")"
    assert_eq "$backup_content_1" "$backup_content_2" "backup unchanged on subsequent runs"
    echo "PASS: backup written once, never overwritten"
}

test_crlf_tolerated() {
    local f="$WORK_DIR/case12"
    printf 'LATITUDE=51.5\r\nUSER="alice"\r\nDUMP1090=yes\r\n' > "$f"
    run_migrator "$f"
    grep -q '^MLAT_USER="alice"$' "$f" || fail "CRLF source not migrated: $(cat "$f")"
    grep -q '^MLAT_ENABLED=true$' "$f" || fail "CRLF: MLAT_ENABLED missing: $(cat "$f")"
    echo "PASS: CRLF tolerated"
}

main() {
    test_version_flag
    test_simple_user_migrates
    test_user_0_disables
    test_user_disable_keyword
    test_user_unquoted_normalized
    test_split_brain_user_wins
    test_already_migrated_no_user
    test_idempotent_second_run
    test_shell_metachars_escaped
    test_empty_user_degenerate
    test_malformed_quote_rejected
    test_missing_file_is_noop
    test_backup_not_overwritten
    test_crlf_tolerated
    echo "All migrate-config tests passed"
}

main "$@"
