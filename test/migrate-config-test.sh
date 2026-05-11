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

test_empty_user_defaults_anonymous() {
    local f
    f="$(with_file "case9" 'USER=""
')"
    run_migrator "$f"
    assert_file_eq 'USER=""
MLAT_USER="Anonymous"
MLAT_ENABLED=true' "$f" "USER='' → MLAT_USER='Anonymous' MLAT_ENABLED=true"
    echo "PASS: empty USER defaults MLAT_USER to Anonymous"
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

# --- MLAT_MARKER → MLAT_PRIVATE migration (co-emit, MLAT_MARKER preserved) ---

test_marker_no_emits_private_true_alongside() {
    local f
    f="$(with_file "case_marker_no" 'LATITUDE=51.5
MLAT_MARKER="no"
DUMP1090=yes
')"
    run_migrator "$f"
    assert_file_eq 'LATITUDE=51.5
MLAT_MARKER="no"
MLAT_PRIVATE=true
DUMP1090=yes' "$f" "MLAT_MARKER=no → MLAT_PRIVATE=true (marker preserved)"
    [[ -f "$f.pre-marker-split" ]] || fail "marker backup not created"
    echo "PASS: MLAT_MARKER=no → MLAT_PRIVATE=true (co-emit)"
}

test_marker_yes_emits_private_false_alongside() {
    local f
    f="$(with_file "case_marker_yes" 'MLAT_MARKER="yes"
')"
    run_migrator "$f"
    assert_file_eq 'MLAT_MARKER="yes"
MLAT_PRIVATE=false' "$f" "MLAT_MARKER=yes → MLAT_PRIVATE=false (marker preserved)"
    echo "PASS: MLAT_MARKER=yes → MLAT_PRIVATE=false (co-emit)"
}

test_marker_uppercase_tolerated() {
    # PHP's reader treats values case-insensitively; the migrator follows.
    local f
    f="$(with_file "case_marker_upper" 'MLAT_MARKER="NO"
')"
    run_migrator "$f"
    assert_file_eq 'MLAT_MARKER="NO"
MLAT_PRIVATE=true' "$f" "MLAT_MARKER=NO (uppercase) → MLAT_PRIVATE=true"
    echo "PASS: MLAT_MARKER uppercase tolerated"
}

test_marker_garbage_strict_fails() {
    local f rc=0
    f="$(with_file "case_marker_garbage" 'MLAT_MARKER="maybe"
')"
    local before
    before="$(cat "$f")"
    run_migrator "$f" 2>/dev/null || rc=$?
    [[ "$rc" -ne 0 ]] || fail "unrecognized MLAT_MARKER not rejected"
    assert_file_eq "$before" "$f" "malformed file unchanged"
    echo "PASS: unrecognized MLAT_MARKER value rejected, file unchanged"
}

test_marker_absent_is_noop() {
    local f
    f="$(with_file "case_no_marker" 'LATITUDE=51.5
DUMP1090=yes
')"
    local before_mtime after_mtime
    before_mtime="$(stat -c %Y "$f" 2>/dev/null || stat -f %m "$f")"
    sleep 1
    run_migrator "$f"
    after_mtime="$(stat -c %Y "$f" 2>/dev/null || stat -f %m "$f")"
    assert_eq "$before_mtime" "$after_mtime" "absent-MLAT_MARKER: mtime preserved"
    [[ ! -f "$f.pre-marker-split" ]] || fail "marker backup created on no-op"
    echo "PASS: MLAT_MARKER absent is no-op"
}

test_marker_wins_over_stale_private() {
    # MLAT_MARKER is the active writer (PHP webconfig); MLAT_PRIVATE in the
    # file is treated as stale and re-derived. Parallels USER → MLAT_USER
    # re-derivation in the existing migration.
    local f
    f="$(with_file "case_marker_both" 'MLAT_PRIVATE=false
MLAT_MARKER="no"
')"
    run_migrator "$f"
    assert_file_eq 'MLAT_MARKER="no"
MLAT_PRIVATE=true' "$f" "MLAT_MARKER wins, MLAT_PRIVATE re-derived to true"
    echo "PASS: MLAT_MARKER wins, stale MLAT_PRIVATE re-derived"
}

test_marker_private_absent_only_marker() {
    # Pure legacy state: only MLAT_MARKER present, no MLAT_PRIVATE yet.
    # Migration creates the canonical alongside.
    local f
    f="$(with_file "case_marker_only" 'LATITUDE=51.5
MLAT_MARKER="no"
DUMP1090=yes
GRAPHS1090=yes
')"
    run_migrator "$f"
    assert_file_eq 'LATITUDE=51.5
MLAT_MARKER="no"
MLAT_PRIVATE=true
DUMP1090=yes
GRAPHS1090=yes' "$f" "MLAT_PRIVATE inserted immediately after MLAT_MARKER"
    echo "PASS: MLAT_PRIVATE emitted on the line after MLAT_MARKER"
}

test_user_and_marker_both_migrate_in_chain() {
    # Chain: USER migration emits MLAT_USER+MLAT_ENABLED at the USER anchor;
    # MLAT_MARKER migration emits MLAT_PRIVATE at the MLAT_MARKER anchor.
    # Both legacy keys are preserved in their original positions.
    local f
    f="$(with_file "case_chain" 'LATITUDE=51.5
USER="alice"
MLAT_MARKER="no"
DUMP1090=yes
')"
    run_migrator "$f"
    assert_file_eq 'LATITUDE=51.5
USER="alice"
MLAT_USER="alice"
MLAT_ENABLED=true
MLAT_MARKER="no"
MLAT_PRIVATE=true
DUMP1090=yes' "$f" "chain: USER → split AND MLAT_MARKER → MLAT_PRIVATE"
    [[ -f "$f.pre-mlat-split" ]] || fail "USER backup missing"
    [[ -f "$f.pre-marker-split" ]] || fail "MARKER backup missing"
    echo "PASS: USER+MLAT_MARKER both migrate in chain"
}

test_marker_backup_not_overwritten() {
    local f
    f="$(with_file "case_marker_backup" 'MLAT_MARKER="no"
')"
    run_migrator "$f"
    local backup_content_1
    backup_content_1="$(cat "$f.pre-marker-split")"
    # Re-migrate after a no-op change. Backup must NOT be touched.
    sleep 1
    run_migrator "$f"
    local backup_content_2
    backup_content_2="$(cat "$f.pre-marker-split")"
    assert_eq "$backup_content_1" "$backup_content_2" "marker backup unchanged on subsequent runs"
    echo "PASS: marker backup written once, never overwritten"
}

test_marker_idempotent() {
    local f
    f="$(with_file "case_marker_idempotent" 'MLAT_MARKER="no"
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
    assert_eq "$first_content" "$second_content" "marker idempotent: content"
    assert_eq "$first_mtime" "$second_mtime" "marker idempotent: mtime preserved"
    echo "PASS: MLAT_MARKER migration idempotent"
}

test_backup_base_env_var_redirects_backups() {
    # install-adsbconfig.sh migrates a random temp file but wants backups
    # at the canonical /boot/airplanes-config.txt location. Without
    # AIRPLANES_CONFIG_BACKUP_BASE, backups would orphan under the temp
    # suffix every save.
    local tmp canonical
    tmp="$WORK_DIR/airplanes-config.txt.XYZ123"
    canonical="$WORK_DIR/airplanes-config.txt"
    printf 'USER="alice"\nMLAT_MARKER="no"\n' > "$tmp"

    AIRPLANES_CONFIG_LOCK_HELD=1 \
    AIRPLANES_CONFIG_BACKUP_BASE="$canonical" \
        "$MIGRATOR" "$tmp"

    [[ -f "$canonical.pre-mlat-split" ]] || fail "USER backup not at canonical base"
    [[ -f "$canonical.pre-marker-split" ]] || fail "MARKER backup not at canonical base"
    [[ ! -f "$tmp.pre-mlat-split" ]] || fail "USER backup leaked to temp path"
    [[ ! -f "$tmp.pre-marker-split" ]] || fail "MARKER backup leaked to temp path"
    echo "PASS: AIRPLANES_CONFIG_BACKUP_BASE redirects backups to canonical path"
}

test_php_two_save_roundtrip() {
    # Codex-flagged scenario: simulate two consecutive PHP webconfig saves.
    # First save: legacy file with MLAT_MARKER, migrator writes MLAT_PRIVATE
    # alongside. Second save: PHP rebuilds from $_POST (it still only writes
    # MLAT_MARKER, no MLAT_PRIVATE), migrator re-derives MLAT_PRIVATE from
    # the rewritten MLAT_MARKER. Privacy posture must survive the round-trip.
    local f
    f="$(with_file "case_php_roundtrip" 'LATITUDE=51.5
USER="alice"
MLAT_MARKER="no"
DUMP1090=yes
')"
    # First PHP save → migrator runs.
    run_migrator "$f"
    grep -qx 'MLAT_PRIVATE=true' "$f" || fail "first save: MLAT_PRIVATE missing"
    grep -qx 'MLAT_MARKER="no"' "$f" || fail "first save: MLAT_MARKER stripped"

    # Simulate PHP's second save: it rebuilds the file from $_POST. The
    # MLAT_PRIVATE line PHP can't see is dropped. MLAT_MARKER survives
    # because the form still writes it. (Order of keys is what PHP would
    # produce after iterating $_POST.)
    cat > "$f" <<'EOF'
LATITUDE=51.5
USER="alice"
MLAT_MARKER=no
DUMP1090=yes
EOF
    run_migrator "$f"
    grep -qx 'MLAT_PRIVATE=true' "$f" || fail "second save: privacy lost after PHP rebuild"
    grep -qx 'MLAT_MARKER=no' "$f" || fail "second save: MLAT_MARKER lost"
    echo "PASS: PHP two-save round-trip preserves privacy via re-derivation"
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
    test_empty_user_defaults_anonymous
    test_malformed_quote_rejected
    test_missing_file_is_noop
    test_backup_not_overwritten
    test_crlf_tolerated
    test_marker_no_emits_private_true_alongside
    test_marker_yes_emits_private_false_alongside
    test_marker_uppercase_tolerated
    test_marker_garbage_strict_fails
    test_marker_absent_is_noop
    test_marker_wins_over_stale_private
    test_marker_private_absent_only_marker
    test_user_and_marker_both_migrate_in_chain
    test_marker_backup_not_overwritten
    test_marker_idempotent
    test_backup_base_env_var_redirects_backups
    test_php_two_save_roundtrip
    echo "All migrate-config tests passed"
}

main "$@"
