#!/bin/bash
# ../harness/scripts/test_gate_raku_roast_bucket_names_the_stage_the_file_died_in.sh -- hq_raku 2026-09-16.
#
# ⛔⭐⭐ WHAT IT PINS AND WHY A NAME IS WORTH A GATE. roast_bucket() is the ONE authority that says WHY a roast
# file did not grade, and it has now been wrong about that three times in one function: `rc -ge 124` filed
# every SIGSEGV under a bucket named for the CLOCK; the missing lex arm filed 61 front-end failures as UNGRADED-OTHER; and the complement of UNGRADED-PARSE was read as "files that
# parse" and published as 143 when the direct measurement was 66.
# ⭐ THE ONE SENTENCE BEHIND ALL THREE (the cto's ruling, 2026-09-16): A BUCKET NAMED FOR A STAGE NAMES WHAT
# IT CAN RECOGNISE, NOT WHAT THE PROGRAM REACHED. Every failure of this function is a class it had no name
# for landing in a bucket named for a stage the file never got to -- and none of them shows up as a wrong
# TOTAL, which is why no board ever went red over any of the three. A miscount is loud; a misdescription is
# silent and sends the next reader looking for a defect in the wrong stage.
# ⛔ SO THE ARMS BELOW GRADE NAMES, NOT COUNTS, and they grade them on SYNTHETIC stderr built to order --
# never on the roast tree, whose answer changes every time the compiler improves.
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
cd "$HERE/../../SCRIP" || exit 2
. "$HERE/lib_raku_roast_bucket.sh" || { echo "⛔ REFUSE(2): lib_raku_roast_bucket.sh unavailable" >&2; exit 2; }
command -v roast_bucket >/dev/null 2>&1 || { echo "⛔ REFUSE(2): lib_raku_roast_bucket.sh defines no roast_bucket" >&2; exit 2; }
TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT
PASS=0; FAIL=0
arm() {  # $1=name $2=expected bucket $3=stdout text $4=stderr text $5=rc
  printf '%s' "$3" > "$TMP/o"; printf '%s' "$4" > "$TMP/e"
  got=$(roast_bucket "$TMP/o" "$TMP/e" "$5")
  if [ "$got" = "$2" ]; then PASS=$((PASS+1)); printf '  ok   %-46s -> %s\n' "$1" "$got"
  else FAIL=$((FAIL+1)); printf '  FAIL %-46s -> %s (expected %s)\n' "$1" "$got" "$2"; fi
}
# ⛔ THE ARM THIS GATE EXISTS FOR. The two-line shape is the real one our driver emits: `raku lex error ...`
# then a bare `raku: parse error in <file>`. Before the cure this returned UNGRADED-OTHER.
arm "lex error (the real two-line driver shape)" UNGRADED-LEX "" "raku lex error line 7: unexpected char '\$'
raku: parse error in /tmp/case.raku" 1
# ⛔ AND THE ONE-LINE SHAPE, where there is no trailing `parse error in <file>` for anything to latch onto:
# without a lex arm this reaches the TAP classifier and is filed UNGRADED-NO-TAP -- "it ran and emitted
# nothing", said of a file that never lexed.
arm "lex error alone (no second line to latch onto)" UNGRADED-LEX "" "raku lex error line 4: unexpected char '?'" 1
# ⛔ A GENUINE PARSE FAILURE IS NEVER RENAMED -- the arm that keeps the cure from quietly moving 1335 files
# and with them the ablation ranker's entire population.
# ⛔⭐ AND A CORRECTION MADE BY ABLATING RATHER THAN BY REASONING: this comment first claimed the ARM ORDER
# (parse tested before lex) was load-bearing. Swapping the two arms left every arm here green, because the
# driver never puts both phrases on one line -- the order is arbitrary and the claim was false. What IS
# load-bearing is that both arms read head -1 and not the whole stderr: a lex death's SECOND line is a bare
# `parse error in <file>`, so a whole-stderr parse grep swallows all 61 lex files back into UNGRADED-PARSE
# and hands the ranker files whose dying line is not a construct it can ablate. Ablating that arm reds the
# first arm below, which is how this was found. ⭐ A comment asserting that something matters is a claim like
# any other, and the way to check it is to break the thing and watch.
arm "parse error stays UNGRADED-PARSE" UNGRADED-PARSE "" "raku parse error line 15: syntax error" 1
# ⛔⭐ THE SHAPE THE DRIVER ACTUALLY EMITS TODAY (hq_raku 2026-09-27, ceo CEO-1318). Every fixture above is the
# flex/bison parser's wording, which no binary has printed since the hand-written parser swapped in (SCRIP
# 2d9817261): a refusal now opens with the POSITIONED `<file>:<line>:<col>: raku syntax error: <why>` and the bare
# `raku: parse error in <file>` is line 2. This gate stayed green on the old fixtures while the real shape read
# UNGRADED-NO-TAP -- a pinned shape nobody emits proves the function, never the instrument. The line arm pins
# roast_err_line on the same shape, where the message itself says `line 1` about the opener: the ranker must key
# the construct on the line the parse DIED on (2), not the line the message mentions.
arm "the hand-written parser's refusal is UNGRADED-PARSE" UNGRADED-PARSE "" "/tmp/case.raku:2:1: raku syntax error: Unable to parse parenthesized expression; couldn't find final ')' (corresponding starter was at line 1)
raku: parse error in /tmp/case.raku" 1
el=$(roast_err_line "/tmp/case.raku:2:1: raku syntax error: Unable to parse parenthesized expression; couldn't find final ')' (corresponding starter was at line 1)")
if [ "$el" = 2 ]; then PASS=$((PASS+1)); printf '  ok   %-46s -> %s\n' "the dying line of a positioned refusal" "$el"
else FAIL=$((FAIL+1)); printf '  FAIL %-46s -> %s (expected 2)\n' "the dying line of a positioned refusal" "$el"; fi
arm "emitter refusal stays UNGRADED-EMITTER" UNGRADED-EMITTER "" "emitter does not yet cover IR_FOO" 1
# The three the function already got wrong once, pinned so the cure above cannot undo the cure below it.
arm "SIGSEGV is a CRASH, not a TIMEOUT" UNGRADED-CRASH "" "" 139
arm "SIGABRT is a CRASH, not a TIMEOUT" UNGRADED-CRASH "" "" 134
arm "rc=124 alone is the TIMEOUT" UNGRADABLE-TIMEOUT "" "" 124
# The graded arms, so a rename can never silently shrink what counts as graded.
arm "clean TAP is GRADED-PASS" GRADED-PASS "1..1
ok 1 - x" "" 0
arm "a not-ok is GRADED-FAIL" GRADED-FAIL "1..1
not ok 1 - x" "" 1
# ⛔ EXIT 255 IS RAKUDO'S TEST STATUS FOR AN UNMET PLAN, NOT A SIGNAL DEATH (hq_raku 2026-10-04): a plan with fewer tests run is a FAIL the TAP shows, and 134 or 139 stay crashes.
arm "an unmet plan (rc 255) with TAP is GRADED-FAIL" GRADED-FAIL "1..3
ok 1 - x" "# You planned 3 tests, but ran 1" 255
arm "a SIGSEGV (rc 139) with a signal message is UNGRADED-CRASH" UNGRADED-CRASH "1..3
ok 1 - x" "scrip: fatal signal 11 (SIGSEGV)" 139
arm "a file with 200 failures (rc 200, TAP present) is GRADED-FAIL" GRADED-FAIL "1..3
not ok 1 - x" "# You failed 200 tests of 300" 200
arm "rc 139 with no TAP is UNGRADED-CRASH" UNGRADED-CRASH "" "" 139
# ⛔ UNGRADED-LEX MUST CARRY THE UNGRADED- PREFIX. The inventory computes graded/ungraded/ungradable by
# prefix and REFUSES if the three do not sum to the population, so a bucket named `LEX-FAIL` would not
# merely read oddly -- it would break the census identity and refuse the whole board.
case "$(roast_bucket "$TMP/o" "$TMP/e" 1 2>/dev/null)" in *) : ;; esac
printf '%s' "raku lex error line 1: x" > "$TMP/e"; : > "$TMP/o"
b=$(roast_bucket "$TMP/o" "$TMP/e" 1)
case "$b" in
  UNGRADED-*) PASS=$((PASS+1)); printf '  ok   %-46s -> %s\n' "the lex bucket keeps the UNGRADED- prefix" "$b" ;;
  *) FAIL=$((FAIL+1)); printf '  FAIL %-46s -> %s: the inventory splits by prefix and refuses when the parts do not sum to the whole\n' "the lex bucket keeps the UNGRADED- prefix" "$b" ;;
esac
# ⛔ AND THE CONTRACT IN THE HEADER MUST NAME IT. A bucket the header does not list is one the next reader
# will treat as a typo -- this file's own docstring is the only place the value set is written down.
if grep -q 'UNGRADED-LEX' "$HERE/lib_raku_roast_bucket.sh" && sed -n '1,20p' "$HERE/lib_raku_roast_bucket.sh" | grep -q 'UNGRADED-LEX'; then
  PASS=$((PASS+1)); printf '  ok   %s\n' "the header contract lists UNGRADED-LEX"
else FAIL=$((FAIL+1)); printf '  FAIL %s\n' "the header contract does not list UNGRADED-LEX -- the value set and the code disagree"; fi
printf 'GATE %s(%d)  arms=%d pass=%d fail=%d\n' "$( [ "$FAIL" -eq 0 ] && echo PASS || echo FAIL )" "$FAIL" "$((PASS+FAIL))" "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ] || exit 1
exit 0
