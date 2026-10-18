#!/usr/bin/env bash
# ../harness/scripts/test_gate_builder_and_grader_agree_on_stdin_companion_spellings.sh -- THE RUNGS BUILDER AND THE
# GRADER ASK THE SAME QUESTION ABOUT A STDIN COMPANION, IN EVERY SPELLING AND IN BOTH LOCATIONS.
# AUTHORS: Lon Jones Cherryholmes · Claude Opus 5   DATE: 2026-09-11
#
# ⛔⭐⭐ THE DEFECT THIS CLOSES, MEASURED BEFORE IT WAS TOUCHED (hq_V 2026-09-11). One question -- "does this
# program have stdin?" -- was written down THREE times with THREE different answers:
#     corpus_suite_harness.loose_stdin_companion()          .stdin  .in  .input   (beside + config/)
#     util_build_rungs_suite.py generalised stdin guard             .in  .input   (beside + config/)
#     util_build_rungs_suite.py snobol4 plain-program guard         .input        (beside + config/)
# and ALL 8 icon stdin companions in this corpus are spelled `config/<stem>.stdin` -- the one spelling the
# BUILDER did not know. A program whose input the builder cannot see is not refused: it is ABSORBED as an
# ordinary pair, the rungs then grades a stdin-reading program against /dev/null, it exits at EOF before
# reaching the behaviour it was written to test, and the auto-xfail path files the starved run as a
# DOCUMENTED red. THERE IS NO XFAIL -- every one of those is a FAIL on the board.
# ⭐ PROVED BOTH DIRECTIONS ON SCRATCH CORPORA ONE BYTE APART, which is what this gate mechanises: the same
# program with `config/w.stdin` was ABSORBED (0 excluded, entry stamped XFAIL) and with `config/w.in` was
# EXCLUDED BY NAME. Same source, same input bytes, same ref; the spelling alone decided.
# ⚠ THE GAP WAS ARMED, NOT LATENT. The 8 icon programs are held out today only by a KEEP.md declaration --
# which is checked BEFORE this guard -- so the builder's rung suites do not move. rung36_jcon_recogn fell through
# the instant its deferral row reached DONE, and the other seven are one retired declaration away each.
#
# ⛔ THE GATE READS THE SPELLINGS FROM THE HARNESS, NEVER FROM A LIST OF ITS OWN. A hand-maintained copy of
# the list is the defect this gate exists to prevent, so adding a spelling to STDIN_COMPANION_SUFFIXES must
# automatically widen the gate. A gate that carried its own fourth copy would drift exactly as the other
# three did, and would read GREEN while doing it.
# ⛔ IT GRADES ON ITS OWN FIXTURES, NEVER ON THE CORPUS RUNGS (CEO-547 part 2): a synthetic corpus per
# spelling, built and torn down here, so the gate is runnable by any seat under ONE RUNNER, ONE BOARD.
#
# EXIT: 0 every spelling in both locations is CARRIED into ALL.in by the builder and found by the grader
#       · 1 a spelling the grader knows is INVISIBLE to the builder (the absorb-unfed defect is back)
#       · 2 REFUSED -- cannot measure (no python3, harness will not import, no spellings, builder not found).
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)" || { echo "REFUSE(2): no SCRIP beside harness at $HERE/../../SCRIP (a port root) -- this gate measures SCRIP and cannot from here"; exit 2; }; cd "$ROOT"
command -v python3 >/dev/null 2>&1 || { echo "REFUSED: no python3 -- cannot measure"; exit 2; }
[ -f "$HERE/util_build_rungs_suite.py" ] || { echo "REFUSED: no util_build_rungs_suite.py -- cannot measure"; exit 2; }
SUFFIXES="$(python3 -c "
import sys
sys.path.insert(0, '$HERE')
try:
    import corpus_suite_harness as h
except Exception as e:
    sys.stderr.write('import: %s\n' % e); sys.exit(2)
s = getattr(h, 'STDIN_COMPANION_SUFFIXES', ())
if not s:
    sys.stderr.write('no STDIN_COMPANION_SUFFIXES\n'); sys.exit(2)
print(' '.join(s))
" 2>&1)" || { echo "REFUSED: cannot read STDIN_COMPANION_SUFFIXES -- $SUFFIXES"; exit 2; }
[ -n "$SUFFIXES" ] || { echo "REFUSED: STDIN_COMPANION_SUFFIXES is empty -- cannot measure"; exit 2; }
WORK="$(mktemp -d)"; trap 'rm -rf "$WORK"' EXIT
FAILED=0; CHECKED=0
# ⛔⭐ BOTH LANGUAGES, BECAUSE THE THIRD COPY OF THE LIST WAS SNOBOL4'S. icon reaches the GENERALISED stdin
# guard and snobol4's bannerless pair reaches the PLAIN-PROGRAM guard, and those two guards held DIFFERENT
# spellings (`.in/.input` vs `.input` alone). An icon-only gate reads green while the snobol4 path still
# absorbs a `.in`-fed program unfed -- exactly the drift that produced this defect.
for LANG in icon snobol4; do
  case "$LANG" in
    icon)    EXT=.icn ;;
    snobol4) EXT=.sno ;;
  esac
for SUF in $SUFFIXES; do
  for WHERE in beside config; do
    T="$WORK/$LANG-$WHERE${SUF//./_}"; D="$T/corpus/tests/$LANG"; mkdir -p "$D/config"
    if [ "$LANG" = icon ]; then
      printf 'procedure main()\n   local line\n   while line := read() do write("got: ", line)\nend\n' > "$D/gate_stdin_probe$EXT"
      printf 'got: alpha\ngot: beta\n' > "$D/gate_stdin_probe.ref"
      printf 'procedure main()\n   write("plain")\nend\n' > "$D/gate_plain_probe$EXT"
    else
      printf '\tOUTPUT = TRIM(INPUT)\n\tOUTPUT = TRIM(INPUT)\nEND\n' > "$D/gate_stdin_probe$EXT"
      printf 'alpha\nbeta\n' > "$D/gate_stdin_probe.ref"
      printf "\tOUTPUT = 'plain'\nEND\n" > "$D/gate_plain_probe$EXT"
    fi
    printf 'plain\n' > "$D/gate_plain_probe.ref"
    if [ "$WHERE" = beside ]; then CP="$D/gate_stdin_probe$SUF"; else CP="$D/config/gate_stdin_probe$SUF"; fi
    printf 'alpha\nbeta\n' > "$CP"
    OUT="$(S4E_HOME="$T" timeout -k 5 120s python3 "$HERE/util_build_rungs_suite.py" --lang "$LANG" --write 2>&1)" || true
    CHECKED=$((CHECKED + 1))
    # ⛔⭐ THE ASSERTION MOVED FROM "THE BUILDER REFUSES IT" TO "THE BUILDER CARRIES IT", 2026-09-11 (hq_V),
    # AND THAT IS A STRENGTHENING, NOT A WEAKENING -- read this before changing it back. The defect this gate
    # was written for is UNCHANGED and is still what it measures: the builder and the grader must answer the
    # same question about a file, or a stdin-reading program is graded against /dev/null. What changed is the
    # ANSWER agreement produces. It used to be "both refuse", because the rungs had no way to carry input;
    # the rungs pair ships ALL.in and the icon rungs was already grading 20 stdin-fed entries while that
    # park went on turning the rest away, so agreement now means THE BUILDER CARRIES WHAT THE GRADER WOULD FEED.
    # ⛔ THE OLD FAILURE IS STILL CAUGHT, and by a STRICTER test: a builder that cannot see this spelling does
    # not refuse the pair -- it absorbs it UNFED, and then ALL.in has no block for the probe and the byte
    # comparison below fails. A builder that sees it but drops the text fails the same arm. The previous form
    # could be satisfied by a refusal for ANY reason; this one can only be satisfied by the input arriving.
    _in="$D/ALL.in"
    _got=""; [ -f "$_in" ] && _got="$(grep -v '^[#*;(/-]*-\{3,\} [0-9]* ' "$_in" 2>/dev/null)"
    if [ -f "$_in" ] && [ "$_got" = "$(cat "$CP")" ]; then
      echo "PASS  $LANG  $WHERE  $SUF  -- builder absorbs it and carries the companion into ALL.in byte-for-byte"
    else
      echo "FAIL  $LANG  $WHERE  $SUF  -- the GRADER finds this companion and the BUILDER does not carry it: the"
      echo "      pair is absorbed and the rungs will grade a stdin-reading program against /dev/null."
      echo "      ALL.in $([ -f "$_in" ] && echo "carries: $(printf '%s' "$_got" | tr '\n' '|')" || echo 'WAS NOT WRITTEN AT ALL')  · companion: $(tr '\n' '|' < "$CP")"
      printf '%s\n' "$OUT" | grep -i 'CANNOT ABSORB\|RUNGS SUITE:' | sed 's/^/      /'
      FAILED=$((FAILED + 1))
    fi
    # the grader's own answer on the identical layout, so the two are compared and not merely asserted
    python3 -c "
import sys, pathlib
sys.path.insert(0, '$HERE')
import corpus_suite_harness as h
src = pathlib.Path('$D/gate_stdin_probe$EXT')
text, path, refusal = h.loose_stdin_companion(src)
if path is None and refusal is None:
    print('FAIL  $LANG  $WHERE  $SUF  -- the GRADER does not see it either; this fixture proves nothing')
    sys.exit(3)
" || FAILED=$((FAILED + 1))
  done
done
done
[ "$CHECKED" -gt 0 ] || { echo "REFUSED: no spelling was exercised -- cannot measure"; exit 2; }
# ⛔⭐ A POPULATION FLOOR, BECAUSE THIS GATE DRAWS ITS FIXTURES FROM THE VERY LIST IT IS TESTING (hq_V
# 2026-09-11, found by MUTATING that list rather than by reading this file). SUFFIXES comes from
# corpus_suite_harness.STDIN_COMPANION_SUFFIXES -- which is right, and is the whole point of asking the one
# authority -- but it means DELETING A SPELLING DELETES ITS FIXTURES TOO: the mutation that removed `.stdin`
# and `.input` took the run from 12 checks to 4 and the gate still printed a green tick. The count was on
# screen and nothing refused, which is this project's own "a criterion that is never evaluated looks exactly
# like one that was satisfied". ⛔ 12 IS NOT A TASTE: 3 spellings (.stdin/.in/.input) x 2 locations (beside,
# config/) x 2 languages (icon, snobol4) is the population this gate was written over, and a smaller one is a
# CAPABILITY THAT WENT AWAY, which must be a loud rc=2 refusal and never a quiet pass. Raise the floor in the
# same landing that adds a spelling; a floor that is never raised is a ratchet nobody turns.
CHECKED_FLOOR=12
[ "$CHECKED" -ge "$CHECKED_FLOOR" ] || { echo "⛔ REFUSED rc=2: only $CHECKED spelling x location x language combination(s) were exercised, against a floor of $CHECKED_FLOOR -- the fixtures are generated FROM corpus_suite_harness.STDIN_COMPANION_SUFFIXES, so a shrunken run means a SPELLING WAS REMOVED and this gate silently stopped covering it. That is not a pass; it is a measurement that did not happen."; exit 2; }
echo "----"
echo "spellings x locations checked: $CHECKED   failures: $FAILED"
[ "$FAILED" -eq 0 ] || { echo "⛔ the builder and the grader disagree about what a stdin companion is"; exit 1; }
echo "✅ builder and grader agree on every stdin companion spelling, beside the source and in config/"
