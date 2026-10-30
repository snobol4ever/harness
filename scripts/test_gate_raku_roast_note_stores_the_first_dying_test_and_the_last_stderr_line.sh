#!/bin/bash
# ../harness/scripts/test_gate_raku_roast_note_stores_the_first_dying_test_and_the_last_stderr_line.sh -- hq_raku 2026-10-30, ceo CEO-2030.
#
# ⛔⭐ WHAT IT PINS. A Roast FAIL, CRASH or HANG reading stores, in its note, the first test that did not pass, the rc and the last diagnostic line, so every red has a
# class a rewrite step can claim. Before this the note was the program's FIRST stderr line, and for 148 programs that was the Test epilogue `# You planned N tests, but ran M`:
# the symptom of dying, never the death. The arms grade roast_first_cause on SYNTHETIC stdout and stderr built to order, never on the roast tree, and each arm also grades the
# DONE-WHEN's own predicate (a note that is empty or opens with `# You planned` is a red without a cause). Two wiring arms read the runner, which has no cheap hermetic run.
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
cd "$HERE/../../SCRIP" || exit 2
LIB="${ROAST_BUCKET_LIB:-$HERE/lib_raku_roast_bucket.sh}"
. "$LIB" || { echo "⛔ REFUSE(2): $LIB unavailable" >&2; exit 2; }
command -v roast_first_cause >/dev/null 2>&1 || { echo "⛔ REFUSE(2): $LIB defines no roast_first_cause" >&2; exit 2; }
TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT
PASS=0; FAIL=0
arm() {  # $1=name $2=expected note $3=stdout text $4=stderr text $5=rc
  printf '%s' "$3" > "$TMP/o"; printf '%s' "$4" > "$TMP/e"
  got=$(roast_first_cause "$TMP/o" "$TMP/e" "$5")
  causeless=0; { [ -z "$got" ] || [ "${got#\# You planned}" != "$got" ]; } && causeless=1
  if [ "$got" = "$2" ] && [ "$causeless" = 0 ]; then PASS=$((PASS+1)); printf '  ok   %-56s -> %s\n' "$1" "$got"
  else FAIL=$((FAIL+1)); printf '  FAIL %-56s -> %s (expected %s)\n' "$1" "$got" "$2"; fi
}
arm "the first not ok names its number and description" "first red: test 3 not ok - the third | rc 2 | stderr: # Failed test 'the third'" "1..5
ok 1 - a
ok 2 - b
not ok 3 - the third
not ok 4 - the fourth
" "# Failed test 'the third'
# You failed 2 tests of 5
" 2
arm "an unmet plan names the test it never reached and the die line" "first red: test 3 not reached (ran 2 of 20, last ok: b) | rc 255 | stderr: Cannot resolve caller foo(Int)" "1..20
ok 1 - a
ok 2 - b
" "Cannot resolve caller foo(Int)
# You planned 20 tests, but ran 2
" 255
arm "the Test epilogue alone is not a diagnostic" "first red: test 2 not reached (ran 1 of 3, last ok: a) | rc 255 | stderr: (none)" "1..3
ok 1 - a
" "# You planned 3 tests, but ran 1
" 255
arm "a signal death with no TAP says so" "first red: none, no TAP | rc 139 | stderr: scrip: fatal signal 11 (SIGSEGV)" "" "scrip: fatal signal 11 (SIGSEGV)
" 139
arm "a timeout names the test it hung before" "first red: test 5 not reached (ran 4 of 12) | rc 124 | stderr: (none)" "1..12
ok 1
ok 2
ok 3
ok 4
" "" 124
arm "a not ok with no description names only its number" "first red: test 2 not ok | rc 1 | stderr: (none)" "1..2
ok 1 - a
not ok 2
" "" 1
arm "a non-zero rc with every test ok is named, not blank" "first red: none, every test ran ok | rc 1 | stderr: (none)" "1..1
ok 1 - x
" "" 1
arm "a tab in the diagnostic cannot tear the TSV row" "first red: none, no TAP | rc 1 | stderr: a b" "" "a	b
" 1
arm "a subtest's indented ok lines are not top-level tests" "first red: test 2 not reached (ran 1 of 2, last ok: s) | rc 255 | stderr: (none)" "1..2
ok 1 - s
    ok 1 - inner
" "" 255
if grep -q 'roast_first_cause "\$so" "\$se" "\$rc"' "$HERE/raku_roast_scoreboard.sh"; then PASS=$((PASS+1)); printf '  ok   %s\n' "the runner stores the first cause of a mode-3 red"
else FAIL=$((FAIL+1)); printf '  FAIL %s\n' "the runner does not call roast_first_cause for a mode-3 red"; fi
if grep -q 'roast_first_cause "\$TMP/o4" "\$TMP/e4" "\$rc4"' "$HERE/raku_roast_scoreboard.sh"; then PASS=$((PASS+1)); printf '  ok   %s\n' "the runner stores the first cause of a mode-4 red"
else FAIL=$((FAIL+1)); printf '  FAIL %s\n' "the runner does not call roast_first_cause for a mode-4 red"; fi
printf 'GATE %s(%d)  arms=%d pass=%d fail=%d\n' "$( [ "$FAIL" -eq 0 ] && echo PASS || echo FAIL )" "$FAIL" "$((PASS+FAIL))" "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ] || exit 1
exit 0
