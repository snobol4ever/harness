#!/bin/bash
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
# ⭐ RUNG 2 OPENER, SECOND INSTRUMENT, of frame-slot-reuse-a-live-range-in-a-byrd-graph-extends-to-every-point-reachable-by-recession
# (cto, CEO-684 slice 2): THE DUMP MUST BE THE EMITTED FRAME.  --dump-zeta used to run slot assignment in a
# pipeline state the compile and run paths never see: no proc registration, no fl_derive_tier, no zframe mark.
# zls_callee_is_gen() therefore read false for every staged call, the callgen.act quad was not granted in the
# dump while the emitter granted it, and every graph with a staged call to a registered generator callee (every
# Prolog predicate) was printed 16 bytes per such call smaller than the frame the code addresses: r/1 of the
# witness read 448 in the dump and 480 in the emission, its named locals sat at +432..+480 in the code and at
# +400..+448 in the dump, and the field census paired references with the wrong fields.  Every number this row
# had reported (688 / 576 / 448) was the dump's, 32 low.  CURE: the dump path shares the compile path's
# register_procs_all + drive_slots_all (src/driver/scrip.c), emission byte-identical on the Prolog, Icon and
# SNOBOL4 witnesses.  THE CLAIM SPANS TWO SITES (the layout and the emitter), so it is held by this check:
# util_frame_refs_land_in_grants.py grades every literal [rbp+N] of every FN__ body of the Prolog witness against
# the --dump-zeta grant table of the same binary -- a reference below region_end must land in a granted field, a
# reference above it must be in the 64-byte entry header at the top of the carve; the root graph is NOT GRADED
# by name (its carve is not the flat frame).  A finding is a finding, never a lead.
# PINS: (1) every non-root graph graded, none skipped silently; (2) zero findings; (3) r/1 shows the two
# callgen.act quads the old dump never printed (since rung 3(a) the quad is described as 'callgen.act +0' / '+8',
# the two halves the template writes, and sits right after the staged call's result; r/1's block ends at the NEXT graph header of
# whatever name -- it once ended at 'q/1', and when the prelude's graphs numbered between the two the window counted theirs, 23 against 2); (4) the MEASURES line.
# RED-BEFORE (the pre-cure binary, same checker): 20 findings on 160 graded graphs, r/1 ungranted=4 -- [rbp+448],
# +456, +464, +472 addressed by the body and granted to nothing, rc=1.
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"; ROOT="${S4E_HOME:-$(cd "$HERE/../../SCRIP" && pwd)}"; [ -x "$ROOT/scrip" ] || ROOT="$(cd "$HERE/../.." && pwd)/SCRIP"
cd "$ROOT" || exit 2
[ -f ../harness/scripts/util_frame_refs_land_in_grants.py ] || { echo "⛔ REFUSE(2): ../harness/scripts/util_frame_refs_land_in_grants.py is absent -- nothing measured"; exit 2; }
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
python3 ../harness/scripts/util_frame_refs_land_in_grants.py ../harness/scripts/fixtures/frame_r1_witness.pl > "$T/g.txt" 2>&1; rc=$?
[ "$rc" -ne 2 ] || { echo "⛔ REFUSE(2): the checker graded nothing"; sed -n 1,5p "$T/g.txt"; exit 2; }
bad=0
tot="$(grep -E '^; grants TOTAL' "$T/g.txt")"; [ -n "$tot" ] || { echo "⛔ REFUSE(2): no TOTAL line"; sed -n 1,5p "$T/g.txt"; exit 2; }
g="$(printf '%s' "$tot" | sed -n 's/.*graphs=\([0-9]*\).*/\1/p')"; gr="$(printf '%s' "$tot" | sed -n 's/.*graded=\([0-9]*\).*/\1/p')"; f="$(printf '%s' "$tot" | sed -n 's/.*findings=\([0-9]*\).*/\1/p')"
echo "prolog witness: $tot"
[ "$g" -gt 100 ] && [ "$gr" = "$((g - 1))" ] && grep -q "^; grants 'main' NOT GRADED" "$T/g.txt" || { echo "  ⛔ not every non-root graph graded ($gr of $g, root excluded by name)"; grep 'NOT GRADED' "$T/g.txt" | head -5; bad=$((bad+1)); }
[ "$f" = "0" ] || { echo "  ⛔ $f reference(s) land in no grant -- the dump is not the emitted frame"; grep '⛔' "$T/g.txt" | head -8; bad=$((bad+1)); }
grep -qE "^; grants 'r/1' refs=[0-9]+ in_grant=[0-9]+ header=[0-9]+ ungranted=0 " "$T/g.txt" || { echo "  ⛔ r/1 was not graded clean"; grep "'r/1'" "$T/g.txt" | head -3; bad=$((bad+1)); }
n="$(timeout -k 5 20s ./scrip --dump-zeta ../harness/scripts/fixtures/frame_r1_witness.pl </dev/null 2>/dev/null | awk "/^; graph [0-9]+ 'r\/1'/{p=1;next} /^; graph /{p=0} p" | grep -c 'callgen.act +0')"
[ "$n" = "2" ] || { echo "  ⛔ r/1 shows $n callgen.act quad(s), the emitted frame has 2 (one per staged call to a registered generator callee)"; bad=$((bad+1)); }
grep -q '^; grants MEASURES' "$T/g.txt" || { echo "  ⛔ the MEASURES line is missing"; bad=$((bad+1)); }
if [ "$bad" -gt 0 ]; then echo "⛔ GATE FAIL: $bad finding(s) -- --dump-zeta is not the frame the emitter lays out"; exit 1; fi
echo "GATE OK: $gr of $g graphs graded, every [rbp+N] of every body lands in a grant of the same dump, r/1 carries its two callgen.act quads, and the instrument states what it measures"
