#!/bin/bash
# ⭐ THE ADJUDICATION EVIDENCE TABLE FOR THE csnobol4 DEAD-PIN RE-CUT (ceo CEO-424 / CEO-426 / CEO-427).
#
# WHAT IT IS FOR.  The re-cut moves programs OUT of the SPITBOL baseline where SPITBOL simply lacks the
# feature, and leaves them IN where SPITBOL's own program-level diagnosis is the point (rewind1).  The ceo
# ruled the adjudication is PER PROGRAM and belongs to hq_S (A-P) and hq_R (Q-Z), with hq_B doing the re-cut
# in ONE commit carrying a per-entry identity line.  This script produces the evidence those two seats
# adjudicate FROM, so the table is cut ONCE by one instrument instead of twice by two.
#
# ⛔ (1) THE PREDICATE IS NOT AN rc AND NOT AN ERROR NUMBER (ceo CEO-424, in the coo's words: "NEITHER KEY IS
#     THE FACT, THE FACT IS DID SPITBOL RUN IT CLEAN").  hq_V's classifier keys on `ERROR NNN` and misses
#     rc=0-with-no-number; the outside-baseline file keys on rc=1 and compile refusals and misses these,
#     which COMPILE FINE and die INSIDE the run.  So this script records no verdict of its own: it runs each
#     engine and prints WHAT IT SAID, IN ITS OWN WORDS.  The classification stays with the adjudicating seat.
#
# ⛔ (2) STDIN COMES FROM AFTER THE `END` STATEMENT, via split_at_end, the suite's own convention.  A
#     `</dev/null` run here prints a clean-looking table from a STARVED program: measured, `tab` is 3 lines
#     and "ERROR 235 -- subscripted operand is not table or array" starved, and 277 lines fed.  That trap
#     took hq_P, the cto and the ceo in one night, the last of them while actively looking for it.
#
# ⛔ (3) EVERY ENGINE IS REACHED BY ABSOLUTE PATH, never `command -v` -- none of them is on PATH, and
#     `command -v` answers "is it on PATH", not "does it exist".  A missing engine REFUSES rc=2 rather than
#     printing a plausible all-dead column.
#
# Exit: 0 = evidence printed (it is a report, never a verdict).  2 = REFUSED, could not measure.
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="${S4E_HOME:-$(cd "$HERE/../.." && pwd)}"
SUITE="${SUITE:-$ROOT/corpus/packages/snobol4/csnobol4_suite}"
SCRIP_BIN="${SCRIP_BIN:-$ROOT/SCRIP/scrip}"
SBL="${SBL:-/home/resources/x64/bin/sbl}"
CSNO="${CSNO:-/home/resources/csnobol4/snobol4}"
for p in "$SUITE:suite dir" "$SCRIP_BIN:scrip binary" "$SBL:SPITBOL oracle" "$CSNO:csnobol4 reference engine"; do
    f="${p%%:*}"; what="${p#*:}"
    [ -e "$f" ] || { echo "⛔ REFUSE(2): no $what at $f -- a column I cannot measure must never print as an answer"; exit 2; }
done
pin_is_dead() { grep -aqE ' : ERROR [0-9][0-9][0-9] -- ' "$1" && grep -aqE '^in statement +[0-9]+$' "$1"; }
# FIRST INTERESTING LINE, in the engine's own words: the first error/diagnostic it printed, else a shape.
own_words() {
    local f="$1" n
    n=$(grep -am1 -E ' : ERROR [0-9]+ -- |[Ee]rror|ERROR' "$f" 2>/dev/null | sed 's/[[:space:]]\+/ /g; s/^ //; s/ $//' | cut -c1-72)
    if [ -n "$n" ]; then printf '%s' "$n"; else printf 'no diagnostic; %s line(s)' "$(wc -l < "$f")"; fi
}
T=$(mktemp -d) || exit 2; trap 'rm -rf "$T"' EXIT
echo "CSNOBOL4 DEAD-PIN RE-CUT EVIDENCE -- each engine in its own words, stdin via split_at_end"
echo "suite:  $SUITE"
echo "stamps: SCRIP $(git -C "$ROOT/SCRIP" rev-parse --short HEAD 2>/dev/null)  corpus $(git -C "$ROOT/corpus" rev-parse --short HEAD 2>/dev/null)"
echo "engines: sbl=$SBL (-bf)  csnobol4=$CSNO  scrip=$SCRIP_BIN"
echo
n=0
for ref in "$SUITE"/*.ref; do
    [ -f "$ref" ] || continue
    pin_is_dead "$ref" || continue
    stem=$(basename "$ref" .ref); src="$SUITE/$stem.sno"
    [ -f "$src" ] || { printf '%-12s NO-SOURCE\n' "$stem"; continue; }
    n=$((n+1))
    rm -rf "$T/r"; mkdir -p "$T/r"; cp -rp "$SUITE"/. "$T/r"/ 2>/dev/null || true
    python3 - "$src" "$T/r/$stem.sno" "$T/r/$stem.in" <<'SPLITPY'
import re, sys
lines = open(sys.argv[1], 'r', errors='replace').read().split('\n')
idx = next((i for i, l in enumerate(lines) if re.match(r'^END\s*$', l, re.IGNORECASE)), None)
if idx is None:
    open(sys.argv[2], 'w').write('\n'.join(lines)); open(sys.argv[3], 'w').write('')
else:
    open(sys.argv[2], 'w').write('\n'.join(lines[:idx+1]) + '\n'); open(sys.argv[3], 'w').write('\n'.join(lines[idx+1:]))
SPLITPY
    ( cd "$T/r" && timeout -k 5 20 "$SBL"  -bf "$stem.sno" < "$stem.in" > "$stem.sbl"  2>&1 ); rc_sbl=$?
    ( cd "$T/r" && timeout -k 5 20 "$CSNO"      "$stem.sno" < "$stem.in" > "$stem.cs"   2>&1 ); rc_cs=$?
    ( cd "$T/r" && timeout -k 5 20 "$SCRIP_BIN" "$stem.sno" < "$stem.in" > "$stem.scrip" 2>&1 ); rc_sc=$?
    if cmp -s "$T/r/$stem.cs" "$T/r/$stem.scrip"; then agree="SCRIP==csnobol4 BYTE-IDENTICAL"; else agree="SCRIP differs from csnobol4"; fi
    echo "── $stem"
    printf '   sbl      rc=%-3s %s\n' "$rc_sbl" "$(own_words "$T/r/$stem.sbl")"
    printf '   csnobol4 rc=%-3s %s\n' "$rc_cs"  "$(own_words "$T/r/$stem.cs")"
    printf '   scrip    rc=%-3s %s\n' "$rc_sc"  "$(own_words "$T/r/$stem.scrip")"
    printf '   ⇒ %s\n' "$agree"
done
[ "$n" -gt 0 ] || { echo "⛔ REFUSE(2): zero dead-pinned programs found in $SUITE -- a census over nothing, not a clean suite"; exit 2; }
echo
echo "dead-pinned programs examined: $n   (a report, not a verdict -- the classification is the adjudicating seat's)"
exit 0
