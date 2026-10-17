#!/bin/bash
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
# ⭐ RUNG 2 OPENER of frame-slot-reuse-a-live-range-in-a-byrd-graph-extends-to-every-point-reachable-by-recession
# (cto, CEO-684 slice 2): AN INSTRUMENT BEFORE A BYTE MOVES.  util_frame_field_reference_census.py pairs every
# granted frame field (--dump-zeta) with the graph's own emitted body (--compile, the FN__<mangled> or main label)
# and counts literal [rbp+N] references plus lea-covered call.argv blocks.  A field with none is NOREF -- a LEAD
# for the rung that grants less, never a verdict: access through another base register or from another body
# is invisible to it, and the instrument says so on every run.
# ⛔ WHAT IT MUST DO TO BE TRUSTED, and what this gate pins:
#   1. every graph of the Prolog witness is censused (161 of 161) -- a graph with no body found is reported, never skipped silently;
#   2. r/1 names its resume quad as NOREF (the lead that remains); the staged call's call.argv, the lead this gate
#      first named (+80 on 09c0e5608, the marshal goes over rsp), was CURED at rung 3(a) and must be ABSENT from the
#      census -- a granted staged argv slot is now a red here.  Original wording of the lead: the frame slot is
#      never addressed; that is the fact rung 2 consumes first, so it is pinned here as a LEAD by name;
#   3. on an rsp-placed frame (the SNOBOL4 witness main) the census REFUSES TO GRADE that graph rather than calling
#      every field NOREF -- a predicate that cannot be evaluated fails closed (cfo, 2026-09-16);
#   4. the MEASURES line (what is and is not seen) is printed on every run.
# RED-BEFORE: the instrument did not exist; a run of this gate on the rung-1 tree refuses rc=2 (no census script).
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"; ROOT="${S4E_HOME:-$(cd "$HERE/../../SCRIP" && pwd)}"; [ -x "$ROOT/scrip" ] || ROOT="$(cd "$HERE/../.." && pwd)/SCRIP"
cd "$ROOT" || exit 2
[ -f ../harness/scripts/util_frame_field_reference_census.py ] || { echo "⛔ REFUSE(2): ../harness/scripts/util_frame_field_reference_census.py is absent -- nothing measured"; exit 2; }
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
printf "        S = 'abcabc'\n        S BREAK('c') . T\n        OUTPUT = T\nEND\n" > "$T/w.sno"
python3 ../harness/scripts/util_frame_field_reference_census.py ../harness/scripts/fixtures/frame_r1_witness.pl > "$T/pl.txt" 2>&1
python3 ../harness/scripts/util_frame_field_reference_census.py "$T/w.sno" > "$T/sno.txt" 2>&1
bad=0
tot="$(grep -E '^; census TOTAL' "$T/pl.txt")"; [ -n "$tot" ] || { echo "⛔ REFUSE(2): no TOTAL line on the Prolog witness"; sed -n 1,5p "$T/pl.txt"; exit 2; }
g="$(printf '%s' "$tot" | sed -n 's/.*graphs=\([0-9]*\).*/\1/p')"; c="$(printf '%s' "$tot" | sed -n 's/.*censused=\([0-9]*\).*/\1/p')"
echo "prolog witness: $tot"
[ "$g" -gt 100 ] && [ "$g" = "$c" ] || { echo "  ⛔ not every graph censused ($c of $g)"; grep 'NOT CENSUSED' "$T/pl.txt" | head -5; bad=$((bad+1)); }
grep -qE "census 'r/1' \+[0-9]+ +16 +DESCR .*call.argv +IR_CALL_PROC_STAGED" "$T/pl.txt" && { echo "  ⛔ r/1 still grants a staged call.argv slot -- the rung-3(a) non-grant is not in the frame"; bad=$((bad+1)); }
grep -qE "census 'r/1' \+[0-9]+ +8 +PTR_CODE +refs=0 +lea=0 +NOREF +resumable-callable" "$T/pl.txt" || { echo "  ⛔ r/1 does not name its resume quad as NOREF (the lead that remains after rung 3(a))"; bad=$((bad+1)); }
grep -q '^; census MEASURES' "$T/pl.txt" || { echo "  ⛔ the MEASURES line is missing"; bad=$((bad+1)); }
grep -qE "census 'main' NOT CENSUSED: the frame is not rbp-addressed" "$T/sno.txt" || { echo "  ⛔ the rsp-placed SNOBOL4 main was graded instead of refused"; grep "'main'" "$T/sno.txt" | head -3; bad=$((bad+1)); }
if [ "$bad" -gt 0 ]; then echo "⛔ GATE FAIL: $bad finding(s) -- the field census is not trustworthy"; exit 1; fi
echo "GATE OK: $c of $g Prolog graphs censused, the staged argv lead is cured and absent, the resume-quad lead is named, the rsp-placed frame is refused, and the instrument states what it measures"
