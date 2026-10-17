#!/usr/bin/env bash
export S4E_ONE_RUNNER_FIXTURE="gate arm ${0##*/}: a runner invoked as an instrument fixture, not a board (CEO-523)"
# test_gate_ceo409_mask_is_read_by_the_bash_runners.sh -- GATE (hq_T, ceo CEO-432 item 1).
# ⛔⭐ WHAT WENT WRONG WITHOUT IT: hq_R's CEO-409 mask mechanism landed in corpus_suite_harness.py and was INERT
# for every suite graded by a BASH runner with its own loop -- a `<name>.mask` sidecar dropped beside a csnobol4
# fixture did nothing at all, silently.  That is the worst way for a safety mechanism to be absent: the author
# sees a well-formed green board and concludes the mask was honoured, so the absence CONFIRMS the belief.
# ⭐ AND THE SECOND HALF, WHICH IS WHY THIS GATE CHECKS A DIALECT: the shim exists so the harness and the bash
# runners mask by ONE set of rules.  A re-implementation in awk or sed would agree on every mask anyone happened
# to test and diverge on the first one using \d, (?i) or a lazy quantifier -- one sidecar meaning two different
# things depending on which runner read it, which is the shape nobody debugs because both readers look right.
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SHIM="$HERE/util_apply_ceo409_mask.py"
[ -f "$SHIM" ] || { echo "⛔ GATE REFUSES (rc=2): $SHIM is not on disk -- the shim moved; re-pin rather than grade a name that no longer exists."; exit 2; }
[ -f "$HERE/corpus_suite_harness.py" ] || { echo "⛔ GATE REFUSES (rc=2): corpus_suite_harness.py is not beside the shim -- the shared body moved."; exit 2; }
W="$(mktemp -d)"; trap 'rm -rf "$W"' EXIT
FAIL=0; N=0
arm() { N=$((N+1)); if [ "$1" = 0 ]; then echo "  ✅ $2"; else echo "  ⛔ $2"; FAIL=$((FAIL+1)); fi; }

printf 'alpha\ntime = 1.25\nbeta\n' > "$W/e.ref"

# (A) DEFAULT-OFF IS BYTE-IDENTICAL. No sidecar must mean the identical stream, not merely an equivalent one:
# every rung suite and every package carries no sidecar today, so this is the path essentially all grading takes.
IN=$'alpha\ntime = 9.99\nbeta'
OUT="$(printf '%s' "$IN" | python3 "$SHIM" "$W/e.ref" e "$W/n" 2>/dev/null)"; rc=$?
[ "$rc" = 0 ] && [ "$OUT" = "$IN" ] && [ "$(cat "$W/n")" = 0 ]; arm $? "no sidecar -> stream byte-identical, count 0, rc=0 (default-off)"

# (B) REPLACE, NEVER DELETE. A deleted line would let a MISSING line pass as a masked one -- the fixture that
# prints nothing would match the fixture that prints a clock -- so line COUNT and POSITION must survive.
printf 'e\ttime = [0-9.]+$\tthe wall clock: the oracle prints a different value on every run, measured 5x\n' > "$W/e.mask"
OUT="$(printf '%s' "$IN" | python3 "$SHIM" "$W/e.ref" e "$W/n" 2>/dev/null)"
[ "$(printf '%s\n' "$OUT" | wc -l)" = "$(printf '%s\n' "$IN" | wc -l)" ] \
  && [ "$(printf '%s' "$OUT" | sed -n 2p)" != "time = 9.99" ] \
  && [ "$(printf '%s' "$OUT" | sed -n 1p)" = alpha ] && [ "$(printf '%s' "$OUT" | sed -n 3p)" = beta ] \
  && [ "$(cat "$W/n")" = 1 ]; arm $? "a masked line is REPLACED in place -- line count and position preserved, count=1"

# (C) THE DIALECT IS PYTHON'S, WHICH IS THE WHOLE POINT OF THE SHIM. \d is a python escape and NOT an ERE one;
# an awk/sed re-implementation would silently match a literal 'd' here and mask nothing.
printf 'e\ttime = \\d+\\.\\d+$\tpython-only escape, present to prove the dialect is not an ERE\n' > "$W/e.mask"
OUT="$(printf '%s' "$IN" | python3 "$SHIM" "$W/e.ref" e "$W/n" 2>/dev/null)"
[ "$(cat "$W/n")" = 1 ]; arm $? "a python-only regex escape (\\d) matches -- the shim is not a re-implementation in ERE"

# (D) A MASK NOBODY CAN AUDIT IS REFUSED, AND THE CODE IS 2. ⛔ This arm exists because the refusal SAID rc=2 and
# the process exited 1: SystemExit with a string prints and exits ONE, so the refusal was indistinguishable from a
# measured RED to every caller reading the status. A sentence naming its own exit code is not evidence it uses it.
printf 'e\ttime = [0-9.]+$\t\n' > "$W/e.mask"
printf '%s' "$IN" | python3 "$SHIM" "$W/e.ref" e "$W/n" >/dev/null 2>&1; rc=$?
[ "$rc" = 2 ]; arm $? "a mask row with an empty reason REFUSES rc=2 (not rc=1, which would read as a measured red)"

# (G) A LINE-NUMBER KEY, L<n>, MASKS BY POSITION (CEO-1167): gc2.icn's &collections output shares its digit
# alphabet with legitimate surrounding grammar-generation lines, so no content regex can reach it without
# also matching most of the file (guardrail 4). L2 masks OUTPUT line 2 (1-indexed) regardless of content.
printf 'e\tL2\tampersand-collections is implementation-defined (Icon book, appendix)\n' > "$W/e.mask"
OUT="$(printf '%s' "$IN" | python3 "$SHIM" "$W/e.ref" e "$W/n" 2>/dev/null)"
[ "$(printf '%s\n' "$OUT" | wc -l)" = "$(printf '%s\n' "$IN" | wc -l)" ] \
  && [ "$(printf '%s' "$OUT" | sed -n 2p)" != "time = 9.99" ] \
  && [ "$(printf '%s' "$OUT" | sed -n 1p)" = alpha ] && [ "$(printf '%s' "$OUT" | sed -n 3p)" = beta ] \
  && [ "$(cat "$W/n")" = 1 ]; arm $? "an L<n> line-number key masks OUTPUT line n by position, not by content, count=1"

# (H) L<n> MASKS ONLY LINE n -- a different line carrying the SAME text as line n's original content is left
# alone, proving this is a position match and not a content match that happens to key off line 2's old text.
printf 'e\tL1\tsingle-line position mask, named\n' > "$W/e.mask"
OUT="$(printf '%s' "$IN" | python3 "$SHIM" "$W/e.ref" e "$W/n" 2>/dev/null)"
[ "$(printf '%s' "$OUT" | sed -n 1p)" != "alpha" ] \
  && [ "$(printf '%s' "$OUT" | sed -n 2p)" = "time = 9.99" ] \
  && [ "$(printf '%s' "$OUT" | sed -n 3p)" = beta ] \
  && [ "$(cat "$W/n")" = 1 ]; arm $? "L1 masks only line 1, leaving lines 2 and 3 untouched"

# (E) THE BASH RUNNER READS IT AT ALL -- the inertness this gate is named for. Asserted on the runner's source,
# because the alternative is a twenty-minute suite run to learn a fact a parse settles.
R="$HERE/test_snobol4_csnobol4_suite.sh"
[ -f "$R" ] && grep -q 'util_apply_ceo409_mask.py' "$R"; arm $? "test_snobol4_csnobol4_suite.sh reaches the mask shim (hq_R's landing is not inert here)"

# (F) AND THE RUNNER'S OWN NORMALISATION OBEYS REPLACE-NEVER-DELETE. Its &FILL rule used to be a sed `d`, which
# is the same defect one layer down: both sides lose the line, so an absent line passes as a masked one.
[ -f "$R" ] && ! grep -qE "sed -E[^\n]*-e \"/\^&FILL = '/d\"" "$R"; arm $? "the runner's &FILL rule no longer DELETES a line (replace-never-delete)"

echo "graded $N arm(s)"
if [ "$N" = 0 ]; then echo "⛔ GATE REFUSES (rc=2): graded zero arms."; exit 2; fi
if [ "$FAIL" != 0 ]; then echo "⛔ GATE FAIL: $FAIL of $N arm(s) red"; exit 1; fi
echo "✅ GATE OK: $N/$N -- the CEO-409 mask is read by the bash runner, through the harness's own body, replace-never-delete."
