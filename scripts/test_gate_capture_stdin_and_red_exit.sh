#!/usr/bin/env bash
# stale-binary preflight (row test-gate-scripts-that-grade-scrip-refuse-on-a-stale-binary-census-widened, hq_T 2026-09-05)
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
# ==============================================================================================
# GATE: capture-oracle-refs feeds the stdin companion, and a RED summary never exits 0.
#
# Row capture-feed-stdin-and-red-exit (hq_B, 2026-08-30) -- the "one edge" ceo kept when the stdin
# freeze was lifted. Two invariants, and each one is a defect this project has already paid for:
#
#   (1) A stdin-bearing stem mints a ref from oracle-WITH-stdin, never from oracle-with-/dev/null.
#       The freeze existed because rung36_jcon_recogn ran unfed, all three arms agreed on EMPTY, and
#       a vacuous 1-byte oracle was minted that would have passed forever (withdrawn, corpus
#       705cd7ad1). Agreement is only evidence when the arms CAN disagree -- so this gate does not
#       merely check that a ref appeared; it checks the ref carries the stdin's own bytes, and it
#       runs the SAME stem with the companion removed as a negative control, which must refuse.
#
#   (2) Any RED in the summary exits non-zero. It printed a full RED table and exited 0 until
#       2026-08-30. "Could not measure" and "measured fine" sharing an exit code is format Law 3's
#       two-audiences shape, and it sat on the very tool that carries Law 4: a human reads the ⛔
#       lines, a script reads rc=0 and marches straight into `convert`.
#
#   (3) LAW 1 ROUND-TRIP: a captured stdin-bearing family must CONVERT with its input intact --
#       .in sidecar written, entry NOT laundered into an XFAIL -- and the converted suite must go
#       red when that sidecar is taken away. A sidecar nothing depends on is not carrying anything.
#
# ⛔ SELF-CONTAINED: every fixture is minted under a mktemp dir and deleted. This gate never reads,
# writes, or grades anything inside corpus/ -- so it cannot be the reason a corpus file changed.
# ==============================================================================================
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(dirname "$HERE")"
HARNESS="$HERE/corpus_suite_harness.py"
. "$HERE/lib_oracle_flags.sh"

fail=0
note() { printf '  %s\n' "$*"; }
ok()   { printf '  ✅ %s\n' "$*"; }
bad()  { printf '  ⛔ %s\n' "$*"; fail=$((fail+1)); }

# ⛔ A TEST THAT CANNOT MEASURE REFUSES WITH rc=2 -- never skip-as-success (RULES.md). Both of these
# are "the instrument is missing", not "the invariant is broken", and the two must not share an exit
# code any more than RED and GREEN may (which is the very thing this gate exists to enforce).
[ -f "$HARNESS" ] || { echo "⛔ GATE REFUSES: corpus_suite_harness.py missing at $HARNESS"; exit 2; }
[ -x "$ROOT/scrip" ] || { echo "⛔ GATE REFUSES: scrip is not built at $ROOT/scrip -- run make"; exit 2; }
ORACLE="$(sbl_correctness_bin 2>/dev/null)" || ORACLE=""
[ -n "$ORACLE" ] && [ -x "$ORACLE" ] || { echo "⛔ GATE REFUSES: no SNOBOL4 correctness oracle (sbl_correctness_bin)"; exit 2; }

TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
STDIN_BYTES="hello_from_stdin_9271"

echo "capture-oracle-refs stdin-feed + red-exit gate -- $(date -u +%FT%TZ)"
echo "  oracle: $ORACLE"

# ---------------------------------------------------------------------- (1) POSITIVE: fed mint
F="$TMP/fed"; mkdir -p "$F"
printf '\tOUTPUT = INPUT\nEND\n'          > "$F/echo_line.sno"
printf '%s\n' "$STDIN_BYTES"              > "$F/echo_line.input"
printf '\tOUTPUT = "no_stdin_here"\nEND\n' > "$F/plain.sno"
out="$(python3 "$HARNESS" capture-oracle-refs "$F" 2>&1)"; rc=$?
# ⛔ CAPTURE FIRST, THEN TEST. `cmd | tail; echo $?` reports the PAGER's status, not the command's --
# the exact trap CLAUDE.md documents and the reason this gate never pipes a command it is grading.
[ "$rc" = 0 ] && ok "all-green capture exits 0" || { bad "all-green capture exited $rc, want 0"; echo "$out" | sed 's/^/      /'; }
if grep -qF "$STDIN_BYTES" "$F/echo_line.ref" 2>/dev/null; then
    ok "minted .ref carries the stdin bytes (fed, not vacuous)"
else
    bad "minted .ref does NOT carry the stdin bytes -- got: $(cat "$F/echo_line.ref" 2>/dev/null | head -1 | cat -v)"
fi

# ------------------------------------------------------- (2) NEGATIVE CONTROL: same stem, unfed
# ⭐ THIS IS THE ARM THAT MAKES (1) MEAN ANYTHING. Identical program, companion removed: if a ref
# still appeared, (1) would prove only that capture writes files, not that it fed anything.
N="$TMP/unfed"; mkdir -p "$N"
cp "$F/echo_line.sno" "$N/echo_line.sno"
out="$(python3 "$HARNESS" capture-oracle-refs "$N" 2>&1)"; rc=$?
[ -e "$N/echo_line.ref" ] && bad "unfed control MINTED a ref -- the empty-agreement refusal did not fire" \
                          || ok "unfed control mints nothing (arms can disagree: fed != unfed)"
[ "$rc" != 0 ] && ok "unfed control (RED) exits non-zero (rc=$rc)" || bad "unfed control printed RED and exited 0"

# ------------------------------------------------------------- (3) RED SUMMARY => rc != 0, mixed
# A family where one stem is fine and one cannot be fed. The green stem must still mint; the exit
# code must still be non-zero. A gate that only tested the all-red case would pass an implementation
# that exits non-zero only when NOTHING was minted.
M="$TMP/mixed"; mkdir -p "$M"
printf '\tOUTPUT = "fine"\nEND\n'  > "$M/fine.sno"
printf '\tOUTPUT = INPUT\nEND\n'   > "$M/ambig.sno"
printf 'a\n' > "$M/ambig.in"; printf 'b\n' > "$M/ambig.input"
out="$(python3 "$HARNESS" capture-oracle-refs "$M" 2>&1)"; rc=$?
[ "$rc" != 0 ] && ok "mixed green+RED capture exits non-zero (rc=$rc)" || bad "mixed green+RED capture exited 0"
[ -e "$M/fine.ref" ]  && ok "the green stem in a RED family still minted" || bad "green stem did not mint"
[ -e "$M/ambig.ref" ] && bad "AMBIGUOUS two-companion stem minted a ref -- it must refuse, not pick one" \
                      || ok "ambiguous two-companion stem refused (no ref)"

# ------------------------------------------------------------------ (4) LAW 1: convert round-trip
C="$TMP/roundtrip"; mkdir -p "$C"
cp "$F/echo_line.sno" "$F/echo_line.input" "$F/echo_line.ref" "$F/plain.sno" "$F/plain.ref" "$C/"
out="$(python3 "$HARNESS" convert "$C" "$C/ALL.sno" "$C/ALL.ref" 2>&1)"; rc=$?
if [ "$rc" = 0 ]; then ok "convert of a stdin-bearing family exits 0"; else bad "convert exited $rc"; echo "$out" | tail -4 | sed 's/^/      /'; fi
[ -s "$C/ALL.in" ] && ok "convert wrote the .in sidecar" || bad "convert wrote NO .in sidecar -- the companion was stranded"
grep -qF "$STDIN_BYTES" "$C/ALL.in" 2>/dev/null && ok ".in sidecar carries the stdin bytes" || bad ".in sidecar does not carry the stdin bytes"
# ⛔ XFAIL IS THE SIGNATURE OF THE OLD DEFECT, NOT AN ACCEPTABLE OUTCOME. Run unfed, a green witness
# goes non-green, convert preserves it verbatim AS XFAIL, byte-equal-or-no-delete is satisfied, and
# the run still prints ✅ "safe to delete the originals". Every check behaved as specified; all of
# them were asked about the same unfed program.
grep -q "^\*-.* echo_line XFAIL$" "$C/ALL.sno" && bad "the stdin entry converted as XFAIL -- it was graded unfed" \
                                               || ok "the stdin entry is NOT XFAIL (it was graded fed)"
board="$(python3 "$HARNESS" run "$C/ALL.sno" "$C/ALL.ref" --modes m3,m4 2>&1 | grep '^SUITE_BOARD ')"
case "$board" in
  *m3_pass=2*m3_fail=0*m4_pass=2*m4_fail=0*) ok "converted suite grades 2/2 green in both modes" ;;
  *) bad "converted suite is not fully green: $board" ;;
esac
# ⭐ AND THE SIDECAR MUST BE LOAD-BEARING. A suite that stays green with its input taken away was
# never being fed by it; the pass would be measuring nothing, which is the whole family of defect
# this gate is about.
mv "$C/ALL.in" "$C/ALL.in.hidden"
board="$(python3 "$HARNESS" run "$C/ALL.sno" "$C/ALL.ref" --modes m3,m4 2>&1 | grep '^SUITE_BOARD ')"
case "$board" in
  *m3_fail=0*m4_fail=0*) bad "suite still green with .in removed -- the sidecar is not load-bearing: $board" ;;
  *) ok "suite goes red with .in removed (the sidecar is load-bearing)" ;;
esac
mv "$C/ALL.in.hidden" "$C/ALL.in"

# ------------------------------------------------------- (5) the no-oracle refusal is a REFUSAL, and it is rc=2
# ⛔ RE-POINTED FROM 3 TO 2 on 2026-09-04 (hq_T, row harness-refusal-exit-code-unified-on-rc-2, ceo CEO-233): the
# harness carried its own local refusal code while lib_gate.sh and every bash gate use 2, and once the stale-binary
# preflight landed inside that same harness -- correctly refusing with 2 -- one tool spoke two refusal codes and no
# caller could ask "did it refuse?" without knowing which refusal it hit. ⭐ THE PROPERTY THIS ARM DEFENDS DID NOT
# CHANGE and is the whole reason it exists: "no oracle wired" must not read as "some stems were RED". That is a
# statement about rc=1, which has not moved; only the refusal's NUMBER moved, onto the one the fleet already tests
# for. An arm that pinned the number instead of the property would have to be edited on every such unification --
# so it now says WHY 2 is not 1, rather than merely that it is 3.
out="$(python3 "$HARNESS" capture-oracle-refs "$F" --lang rebus 2>&1)"; rc=$?
[ "$rc" = 2 ] && ok "unwired --lang refuses with rc=2, the one refusal code (still distinct from a RED rc=1)" \
              || bad "unwired --lang exited $rc, want 2 -- 'no oracle' is COULD NOT MEASURE, never 'some stems were red' (rc=1)"

echo
if [ "$fail" = 0 ]; then echo "✅ GATE OK: capture feeds stdin, proves the feed, refuses what it cannot feed, and never exits 0 on RED."; exit 0; fi
echo "⛔ GATE FAILED: $fail check(s) above."; exit 1
