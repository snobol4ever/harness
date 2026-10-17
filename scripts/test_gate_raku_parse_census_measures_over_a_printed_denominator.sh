#!/bin/bash
# ../harness/scripts/test_gate_raku_parse_census_measures_over_a_printed_denominator.sh -- THE GATE ON THE PARSE-COVERAGE
# INSTRUMENT (hq_raku 2026-09-16, cto's ask RE parse-coverage-taken-as-68-of-1464-and-the-census-must-be-a-script-on-origin).
#
# ⛔⭐ WHAT IT GRADES AND WHY AN INSTRUMENT NEEDS A GATE AT ALL. util_raku_parse_census.sh exists because a
# figure produced by hand can be produced wrongly by hand again. That argument only holds if the SCRIPT
# cannot go wrong quietly -- a census that silently counted 0, or counted the whole tree, or printed a
# numerator with no denominator beside it, would be the same defect wearing an instrument's clothes and
# would be BELIEVED, because it arrives as output rather than as an opinion.
# ⛔ IT RUNS AGAINST A SYNTHETIC TREE OF KNOWN ANSWER, NEVER AGAINST ROAST: a gate whose expected value is
# whatever the real corpus currently reads is a ratchet, not a gate -- it would go green on any number and
# would have to be edited every time the compiler improved. Here the answer is known by construction (one
# file that parses, one that cannot), so the gate grades the INSTRUMENT and never the coverage.
# ⛔ OFFLINE, sub-second, writes nothing outside its own temp dir.
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
cd "$HERE/../../SCRIP" || exit 2
ROOT=$(pwd)
CENSUS="$HERE/util_raku_parse_census.sh"
[ -x "$ROOT/scrip" ] || { echo "⛔ REFUSE(2): no scrip binary (run: make) -- this gate cannot grade a parser it cannot run" >&2; exit 2; }
# ⛔ AND IT MUST BE A CURRENT BINARY, NOT MERELY A PRESENT ONE (COO-80, row
# instrument-the-nineteen-non-gc-blocking-arms): this gate EXECUTES ./scrip, and
# test_gate_runners_refuse_on_a_stale_binary ARM 15 named it as one of two scrip-executing gates with no
# freshness guard. A parse census taken with a binary older than src/ is a number about a tree it cannot
# name, and rc=2 means "could not measure", never green and never red.
. "$HERE/lib_gate.sh"
gate_require_fresh "$ROOT" src "$ROOT/scrip" "$ROOT/out/libscrip_rt.so"
[ -f "$CENSUS" ] || { echo "⛔ REFUSE(2): $CENSUS not on disk" >&2; exit 2; }
TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT
PASS=0; FAIL=0
ok()   { PASS=$((PASS+1)); printf '  ok   %s\n' "$1"; }
bad()  { FAIL=$((FAIL+1)); printf '  FAIL %s\n' "$1"; }
# The synthetic population: one .t that parses, one that cannot. Extensions matter -- the census walks *.t
# and stages each to a content-identical .raku, which is the step that would make EVERY file read PARSE-FAIL
# if it were ever dropped.
mkdir -p "$TMP/tree/S99-gate"
printf 'say "gate";\n'                    > "$TMP/tree/S99-gate/good.t"
printf 'my $x = ((( ;;; unterminated\n'   > "$TMP/tree/S99-gate/bad.t"
MANI="$TMP/spectest.data.6.c"; printf 'S99-gate/good.t\nS99-gate/bad.t\n' > "$MANI"
run_census() { RAKU_ROAST_TREE="$1" RAKU_ROAST_MANIFEST="$MANI" bash "$CENSUS" "${@:2}" 2>"$TMP/err"; }

# ARM 1 -- it measures, and the headline carries the numerator OVER ITS DENOMINATOR on one line.
out=$(run_census "$TMP/tree"); rc=$?
line=$(printf '%s\n' "$out" | grep '^RAKU_PARSE_COVERAGE PARSED ' || true)
if [ "$rc" = 0 ] && [ -n "$line" ]; then ok "census runs and prints the RAKU_PARSE_COVERAGE headline"; else bad "census rc=$rc and printed no RAKU_PARSE_COVERAGE headline -- got: $(printf '%s' "$out" | head -2)"; fi
case "$line" in
  *"PARSED 1/2 "*) ok "numerator over denominator is 1/2 on a tree built to answer 1/2" ;;
  *) bad "expected 'PARSED 1/2' on a synthetic tree of one parseable and one unparseable file, got: $line" ;;
esac
# ⛔ THE DENOMINATOR IS THE POINT OF THE WHOLE ROW. A numerator printed alone is the shape that let 68 travel
# as a fact for a week with nothing beside it to check it against.
case "$line" in *"/2 "*) ok "the denominator is printed, not implied" ;; *) bad "no denominator in the headline: $line" ;; esac
case "$line" in *"parse_fail=1"*) ok "the parse_fail count is carried beside the numerator" ;; *) bad "no parse_fail= in: $line" ;; esac
# ARM 2 -- it NAMES the files it counted. A fraction cannot be audited; a list can.
if printf '%s\n' "$out" | grep -q 'S99-gate/good.t'; then ok "it names the file in the numerator (S99-gate/good.t)"; else bad "the numerator's file is not listed -- the census printed a fraction nobody can check"; fi
if printf '%s\n' "$out" | grep -q 'S99-gate/bad.t'; then bad "the unparseable file appears in the counted list"; else ok "the unparseable file is not in the numerator's list"; fi
# ARM 3 -- --summary suppresses the list and keeps the headline (the shape the roast board embeds).
sout=$(run_census "$TMP/tree" --summary)
if printf '%s\n' "$sout" | grep -q '^RAKU_PARSE_COVERAGE PARSED ' && ! printf '%s\n' "$sout" | grep -q 'S99-gate/good.t'; then
  ok "--summary keeps the headline and drops the list"
else bad "--summary is not the embeddable shape the roast board greps for"; fi
# ARM 4 -- AN EMPTY POPULATION REFUSES rc=2 AND NEVER PRINTS 0/0. ⭐ This is the arm that matters most: a
# census that cannot find its tree prints a clean-looking sheet, and 0/0 in a report reads as "no problems".
mkdir -p "$TMP/empty"
eout=$(run_census "$TMP/empty"); erc=$?
if [ "$erc" = 2 ] && ! printf '%s\n' "$eout" | grep -q '^RAKU_PARSE_COVERAGE PARSED '; then
  ok "an empty population REFUSES rc=2 and prints no coverage line"
else bad "an empty population gave rc=$erc and printed: $(printf '%s' "$eout" | head -1)"; fi
# ARM 5 -- a named-but-absent tree refuses rc=2 naming the candidates (the resolver's own contract).
nout=$(run_census "$TMP/does-not-exist"); nrc=$?
if [ "$nrc" = 2 ]; then ok "an absent tree REFUSES rc=2"; else bad "an absent tree gave rc=$nrc"; fi
# ARM 6 -- an unknown argument is NAMED, never swallowed (the driver's fall-through, applied to our own tools).
uout=$(run_census "$TMP/tree" --not-an-arg); urc=$?
if [ "$urc" = 2 ] && grep -q "not-an-arg" "$TMP/err"; then ok "an unknown argument REFUSES rc=2 and names itself"; else bad "unknown argument gave rc=$urc without naming it"; fi
# ARM 7 -- the roast board embeds the row rather than leaving it to be inferred (the cto's ask, landed).
# ⛔⭐⭐ THIS ARM WAS WRITTEN AS `grep -q 'util_raku_parse_census.sh' <board>` AND IT WAS GREEN ON A
# BOARD THAT HAD STOPPED CALLING THE CENSUS (hq_raku 2026-09-16, caught by ablating the board's call and
# finding the gate unmoved). The name still appeared -- in the eight-line comment block explaining the call.
# ⭐ THE GENERAL FORM, and it is this file's own subject recurring one level up: an instrument that answers
# a NARROWER question than you think you asked never says so. "Is this string in the file" is not "does this
# file call that script", and the difference is invisible for exactly as long as the two answers agree.
# So the arms below require a NON-COMMENT invocation line, and require the row to reach stdout and the cell.
if grep -qE '^[^#]*bash "\$ROOT/../harness/scripts/util_raku_parse_census\.sh"' "$HERE/raku_roast_scoreboard.sh"; then
  ok "raku_roast_scoreboard.sh INVOKES the census (a non-comment line), beside its run-and-grade cell"
else bad "the roast board does not invoke the census -- the reader is left to infer parse coverage from buckets, which is the derivation this row replaces"; fi
# ⛔⭐ AND THIS ARM WAS FALSE-GREEN TOO, ONE ABLATION LATER AND FOR A SECOND REASON: deleting the
# board's stdout print left the gate green, because the board prints PC_LINE TWICE -- once on stdout with the
# row, once on stderr with the UNMEASURED refusal -- and a pattern that does not exclude `>&2` cannot tell a
# published row from a diagnostic. The trailing-end anchor is what makes this arm about stdout.
# ⛔ THESE THREE ARMS ARE STATIC ON PURPOSE AND SAY SO: running the board end-to-end would be the stronger
# check, and it is refused here because even `--run --limit 2` calls progress_append per file -- a gate that
# writes rows into the progress database to prove a board prints a line has bought its evidence with a side
# effect on everyone else's measurement.
if grep -qE '^[^#]*printf .%s.n. "\$PC_LINE"[[:space:]]*$' "$HERE/raku_roast_scoreboard.sh"; then
  ok "the board PRINTS the census row on its own stdout (not only on the stderr refusal path)"
else bad "the board calls the census but never prints its row on stdout"; fi
# ⛔ $PC_TEXT IS $PC_LINE WITH ITS FRACTION SPELLED 'N of M' (coo 2026-09-25): util_score_row's read-back took PARSED 75/1464 beside
# both-modes 20/1464 as two readings of the roast row and refused every write. The cell still carries the coverage, derived from
# the census line in the same file, so both spellings are accepted -- and PC_TEXT only when it is built from PC_LINE.
if grep -q 'PARSE COVERAGE: \$PC_LINE' "$HERE/raku_roast_scoreboard.sh" \
   || { grep -q 'PARSE COVERAGE: \$PC_TEXT' "$HERE/raku_roast_scoreboard.sh" && grep -qE '^[[:space:]]*PC_TEXT="\$\(printf .%s. "\$PC_LINE"' "$HERE/raku_roast_scoreboard.sh"; }; then
  ok "the published SCORE cell carries the parse-coverage row beside the run fraction"
else bad "the SCORE cell text does not carry the parse-coverage row -- a leaderboard reader is still left to infer it"; fi
printf 'GATE %s(%d)  arms=%d pass=%d fail=%d\n' "$( [ "$FAIL" -eq 0 ] && echo PASS || echo FAIL )" "$FAIL" "$((PASS+FAIL))" "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ] || exit 1
exit 0
