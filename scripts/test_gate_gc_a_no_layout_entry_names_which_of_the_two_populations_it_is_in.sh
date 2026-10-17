#!/usr/bin/env bash
# test_gate_gc_a_no_layout_entry_names_which_of_the_two_populations_it_is_in.sh -- CEO-1025 MADE MECHANICAL, AND ITS
# DISCRIMINATOR CORRECTED ON THE DATA (cto 2026-09-20, MODE TENET; ruling CEO-1025 on hq_prolog's fork).
#
# THE RULING: `no_layout` CONFLATES TWO POPULATIONS WITH OPPOSITE OWNERS.  (a) THE COMPILER REFUSED THE ENTRY --
# nothing emitted, no leaf boundary, no store: a COMPLETENESS debt wearing a GC census's clothes, declared with its
# rung, counted inside the printed denominator, and it gates NO language's completeness under MODE TENET condition
# 1.  (b) THE COMPILER EMITTED THE GRAPH AND THE PLANNER GAVE IT NO FRAME LAYOUT -- boundaries exist and store into
# unmapped slots BY CONSTRUCTION: the cfo's clause, the correctness population, and it DOES gate completeness.
#
# ⛔ THE RULING NAMED `rc=2` AGAINST `rc=1` AS THE SPLIT AND THE DATA SAYS OTHERWISE, WHICH IS WHY THIS GATE GRADES
# THE FACT AND NOT THE rc.  Measured 2026-09-20 over all seven rung suites: prolog's ten read `rc=2 builtin X is not on
# the ladder yet`, and raku's seven read `rc=1 raku parse error` / `lex error` / a role-composition refusal.  BOTH
# ARE REFUSALS THAT EMIT NOTHING.  So rc=1 against rc=2 separates a LADDER refusal from a PARSER refusal -- two
# flavours inside bucket (a) -- and not (a) from (b).  The fact the ruling asked for is DID THIS ENTRY PRODUCE
# EMITTED CODE AT ALL, and the census has always known it directly: a non-zero rc from --dump-zeta is
# NEVER-EMITTED, rc=0 with no frame layout in the dump is EMITTED-NO-LAYOUT, and a timeout is UNMEASURED and is
# folded into neither.  The kind travels as a VALUE from the one place that runs the compiler and is never re-parsed
# out of the message text, because a guard keyed on a spelling is a coincidence and not a guard.
#
# ⭐ THE FLEET READING AT THE LANDING, so nobody re-derives it: 4907 graded, no_layout=18, NEVER-EMITTED=18,
# EMITTED-NO-LAYOUT=0 -- prolog 10, raku 7, snobol4 1, and icon/snocone/pascal/rebus zero.  THE CORRECTNESS
# POPULATION IS EMPTY ACROSS THE FLEET, so `no_layout` gates no language's completeness today.  ⛔ THAT IS NOT A
# CLEAN COLLECTOR AND MUST NOT BE READ AS ONE: hq_raku's 36 programs that answer wrong at SCRIP_GC_STRESS=16 are in
# NEITHER bucket -- those graphs emit, run, exit 0 and print a plausible wrong answer, which is the class itself.
# This gate is HERMETIC and runs the stubs below rather than the rung suites, because the seven-language sweep costs
# minutes and MODE TENET condition 2 charges that to ten seats through an essentially serial set.
set -u
cd "$(dirname "$0")/../../SCRIP" || exit 2
ROOT="$PWD"
TOOL="$ROOT/../harness/scripts/util_zls_frame_map_census.py"
CONSUMER="$ROOT/../harness/scripts/util_gc_census.py"
checks=0; fails=0
ck() { checks=$((checks+1)); if [ "$1" = ok ]; then echo "  ok   $2"; else fails=$((fails+1)); echo "  FAIL $2"; fi; }
refuse() { echo "⛔ GATE REFUSED(2) [gc_a_no_layout_entry_names_which_of_the_two_populations_it_is_in]: $1"; exit 2; }
[ -f "$TOOL" ] || refuse "no $TOOL -- nothing to grade"
[ -f "$CONSUMER" ] || refuse "no $CONSUMER -- the consumer half cannot be graded"
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
printf '        OUTPUT = 1\nEND\n' > "$T/w.sno"
printf '#!/bin/sh\nexit 0\n'                              > "$T/stub_emit.sh"
printf '#!/bin/sh\necho "stub: refused" >&2\nexit 2\n'    > "$T/stub_refuse.sh"
printf '#!/bin/sh\nsleep 30\n'                            > "$T/stub_hang.sh"
chmod +x "$T"/stub_*.sh

# (a)(b)(c) EVERY KIND IS REACHABLE AND LANDS IN EXACTLY ONE BUCKET.  ⛔ A BUCKET NOTHING CAN LAND IN IS NOT A
# BUCKET, and a field that reads zero because it is unreachable is indistinguishable from a field that reads zero
# because the tree is clean -- which is the whole defect CEO-1025 was ruling on, one level up.
for arm in emit:EMITTED-NO-LAYOUT:no_layout_emitted_no_layout refuse:NEVER-EMITTED:no_layout_never_emitted hang:UNMEASURED:no_layout_unmeasured; do
  k="${arm%%:*}"; rest="${arm#*:}"; kind="${rest%%:*}"; field="${rest##*:}"
  out="$(SCRIP="$T/stub_$k.sh" timeout -k 5 120s python3 "$TOOL" --files "$T/w.sno" --timeout 1 2>&1)"
  line="$(printf '%s\n' "$out" | grep -m1 '^ZLS-MAP ')"
  tot="$(printf '%s\n' "$line" | sed -n 's/.* no_layout=\([0-9]*\) .*/\1/p')"
  got="$(printf '%s\n' "$line" | sed -n "s/.* $field=\([0-9]*\).*/\1/p")"
  sum=0
  for f in no_layout_never_emitted no_layout_emitted_no_layout no_layout_unmeasured; do
    v="$(printf '%s\n' "$line" | sed -n "s/.* $f=\([0-9]*\).*/\1/p")"; sum=$((sum + ${v:-0}))
  done
  if [ "${got:-0}" = 1 ] && [ "${tot:-0}" = 1 ] && [ "$sum" = 1 ] && printf '%s\n' "$out" | grep -q "^NO-LAYOUT .*\[$kind\]"; then
    ck ok "($k) a $kind entry is NAMED with its kind and lands in exactly one bucket -- $field=1, no_layout=1, kinds sum to 1"
  else
    ck no "($k) a $kind entry did not land in $field alone: $field=${got:-?} no_layout=${tot:-?} kinds_sum=$sum. $(printf '%s\n' "$out" | grep -m1 '^NO-LAYOUT ' | cut -c1-120)"
  fi
done

# (d) THE ENTRY LINE CARRIES ITS KIND IN THE TAIL AND NEVER AS A LINE PREFIX.  ⛔ MEASURED BY hq_raku THE DAY
# BEFORE: a first cut of the DECLARED field used a NO-LAYOUT-DECLARED prefix, the consumer counted 7 lines against
# no_layout=9 and REFUSED rc=2.  It was right to.  Every NO-LAYOUT line must still begin `NO-LAYOUT `.
out="$(SCRIP="$T/stub_refuse.sh" timeout -k 5 120s python3 "$TOOL" --files "$T/w.sno" --timeout 1 2>&1)"
n_pref="$(printf '%s\n' "$out" | grep -c '^NO-LAYOUT ')"
n_kind="$(printf '%s\n' "$out" | grep -c '^NO-LAYOUT .*\[NEVER-EMITTED\]')"
if [ "$n_pref" = 1 ] && [ "$n_kind" = 1 ]; then
  ck ok "(d) the kind rides in the TAIL: 1 line begins 'NO-LAYOUT ' and carries [NEVER-EMITTED], so the consumer's line count still equals no_layout"
else
  ck no "(d) the kind moved the line prefix -- $n_pref line(s) begin 'NO-LAYOUT ' and $n_kind carry the kind; the consumer counts the prefix and will refuse (hq_raku measured exactly this)"
fi

# (e) THE CONSUMER REFUSES A ZLS-MAP LINE WITH NO KIND FIELDS rather than reading the absent field as zero.
# ⛔ AN ABSENT FIELD READING AS ZERO IS HOW THE CONFLATION LOOKED LIKE A CLEAN SPLIT IN THE FIRST PLACE.
mkdir -p "$T/fakeroot/scripts" "$T/fakeroot/src" "$T/fakeroot/out"
# The consumer runs lib_build_currency.sh at its --root since the coo's 0176b35dd (a census of an unbuilt tree is a
# statement about a different program), so the FAKE root must be a BUILT tree or every arm below refuses rc=2 for the
# wrong reason -- which is exactly how arms e, f and g read red on origin at CEO-1161 (cto). The census's own selftest
# satisfies the guard the same way: the real library sourced, one src/ file older than two fresh artifacts.
cp "$ROOT/../harness/scripts/lib_build_currency.sh" "$T/fakeroot/scripts/"
: > "$T/fakeroot/src/stub.c"; touch -t 202001010000 "$T/fakeroot/src/stub.c"
: > "$T/fakeroot/scrip"; : > "$T/fakeroot/out/libscrip_rt.so"
cat > "$T/fakeroot/scripts/util_zls_frame_map_census.py" <<'STUB'
import sys
print("ZLS-MAP lang=stub graphs=1 words=8 unkinded=0 holes=0 graded=1 no_layout=1 no_layout_declared=0")
print("NO-LAYOUT lang=stub entry=e (rc=2: stub)")
sys.exit(0)
STUB
crc=0
timeout -k 5 120s python3 "$CONSUMER" maps --root "$T/fakeroot" --zls-langs stub > "$T/consumer.out" 2>&1 || crc=$?
if [ "$crc" = 2 ] && grep -q "without the three kind fields" "$T/consumer.out"; then
  ck ok "(e) PLANTED -- a ZLS-MAP line with no kind fields makes the consumer REFUSE(2), not read the split as zero"
else
  ck no "(e) the consumer accepted a ZLS-MAP line carrying no kind fields (rc=$crc): $(grep -m1 'maps/slot-kind' "$T/consumer.out" | cut -c1-140)"
fi

# (f) THE CONSUMER REFUSES KINDS THAT DO NOT SUM TO no_layout -- an entry in no bucket vanishes from BOTH owners'
# work lists, which is worse than either owner having one too many.
cat > "$T/fakeroot/scripts/util_zls_frame_map_census.py" <<'STUB'
import sys
print("ZLS-MAP lang=stub graphs=1 words=8 unkinded=0 holes=0 graded=1 no_layout=3 no_layout_declared=0 "
      "no_layout_never_emitted=1 no_layout_emitted_no_layout=1 no_layout_unmeasured=0")
for i in range(3):
    print(f"NO-LAYOUT lang=stub entry=e{i} (rc=2: stub) [NEVER-EMITTED]")
sys.exit(0)
STUB
crc=0
timeout -k 5 120s python3 "$CONSUMER" maps --root "$T/fakeroot" --zls-langs stub > "$T/consumer2.out" 2>&1 || crc=$?
if [ "$crc" = 2 ] && grep -q "kinds sum to" "$T/consumer2.out"; then
  ck ok "(f) PLANTED -- kinds that do not sum to no_layout make the consumer REFUSE(2) and name the arithmetic"
else
  ck no "(f) the consumer accepted 3 no-layout entries split into 2 kinds (rc=$crc): $(grep -m1 'maps/slot-kind' "$T/consumer2.out" | cut -c1-140)"
fi

# (g) THE CORRECTNESS POPULATION IS GRADED RED AND THE COMPLETENESS DEBT IS NOT.  This is the ruling's whole point:
# the two have OPPOSITE OWNERS, so they cannot share a verdict.
cat > "$T/fakeroot/scripts/util_zls_frame_map_census.py" <<'STUB'
import sys
print("ZLS-MAP lang=stub graphs=1 words=8 unkinded=0 holes=0 graded=1 no_layout=1 no_layout_declared=0 "
      "no_layout_never_emitted=0 no_layout_emitted_no_layout=1 no_layout_unmeasured=0")
print("NO-LAYOUT lang=stub entry=e (no graph in the dump) [EMITTED-NO-LAYOUT]")
sys.exit(0)
STUB
timeout -k 5 120s python3 "$CONSUMER" maps --root "$T/fakeroot" --zls-langs stub > "$T/consumer3.out" 2>&1
red_hit=$(grep -c "EMITTED-NO-LAYOUT IS THE CORRECTNESS POPULATION AND IT IS RED" "$T/consumer3.out")
cat > "$T/fakeroot/scripts/util_zls_frame_map_census.py" <<'STUB'
import sys
print("ZLS-MAP lang=stub graphs=1 words=8 unkinded=0 holes=0 graded=1 no_layout=1 no_layout_declared=0 "
      "no_layout_never_emitted=1 no_layout_emitted_no_layout=0 no_layout_unmeasured=0")
print("NO-LAYOUT lang=stub entry=e (rc=2: stub) [NEVER-EMITTED]")
sys.exit(0)
STUB
timeout -k 5 120s python3 "$CONSUMER" maps --root "$T/fakeroot" --zls-langs stub > "$T/consumer4.out" 2>&1
green_hit=$(grep -c "EMITTED-NO-LAYOUT IS THE CORRECTNESS POPULATION AND IT IS RED" "$T/consumer4.out")
if [ "$red_hit" -ge 1 ] && [ "$green_hit" = 0 ]; then
  ck ok "(g) PLANTED BOTH DIRECTIONS -- one EMITTED-NO-LAYOUT entry is called RED and named as the correctness population; one NEVER-EMITTED entry is NOT, because a completeness debt gates nothing here"
else
  ck no "(g) the two populations share a verdict: emitted-no-layout raised the red banner $red_hit time(s) (want >=1), never-emitted raised it $green_hit time(s) (want 0). They have OPPOSITE OWNERS and cannot share one"
fi

# (i) THE THIRD POPULATION, WHICH IS NOT `no_layout` AT ALL AND WHICH EVERY HOLE-COUNTING INSTRUMENT PASSES BY
# CONSTRUCTION (hq_raku 2026-09-20, measured on gram__G__TOP; reproduced here by a different road and widened).
# ⛔ A GRAPH CAN EMIT, REGISTER A FRAME MAP, AND HAVE NO LAYOUT ENTRY IN IT.  frame_bytes=64 header_bytes=48 with
# FLAT_FRAME_ALLOWANCE 48+16 leaves a value region of exactly ZERO BYTES.  Such a graph is NOT no_layout -- it has
# a map, so it counts inside graphs= and graded= -- and it contributes 0 to fields= and 0 to holes=, so a hole
# census reads it as perfect.  hq_raku's family was corrupt under every collection while
# test_gate_gc_raku_every_frame_slot_has_a_kind printed PASS over 19476 fields and 0 holes.  A ZERO OVER A
# DENOMINATOR OF ZERO, which is harder to notice than a zero over a small denominator because no field in the
# output moves.  MEASURED FLEET-WIDE AT THIS LANDING: 37 graphs -- raku 33 (hq_raku's own count, reached here by
# parsing --dump-zeta rather than by their per-entry map dump), snobol4 2, icon 2.
# ⛔⭐ A ZERO-BYTE REGION IS NOT BY ITSELF A DEFECT AND THIS GATE DOES NOT CALL IT ONE.  A graph with nothing live
# across a safe point has nothing to map: snobol4's two are `main` in simple_program_2 and simple_program_11.  THE
# CORRECTNESS QUESTION IS THE JOIN -- a zero-entry map in a graph that DOES shield a value at a safe point -- and
# that join is NOT BUILT YET (it needs this census's graph names against the unmapped-store census's per-graph
# shielded stores).  Named here as owed rather than counted as clean, which is this row's whole subject matter.
zr_stub="$T/fakeroot2"
mkdir -p "$zr_stub"
cat > "$zr_stub/scrip" <<'STUB'
#!/bin/sh
echo "; graph 0 'zr' flat slots=0 region_end=0 resume=-1 vslots=0 scopes=0"
STUB
chmod +x "$zr_stub/scrip"
out="$(SCRIP="$zr_stub/scrip" timeout -k 5 120s python3 "$TOOL" --files "$T/w.sno" --timeout 5 2>&1)"
zrn="$(printf '%s\n' "$out" | grep -m1 '^ZLS-MAP ' | sed -n 's/.* zero_region_graphs=\([0-9]*\).*/\1/p')"
gr="$(printf '%s\n' "$out" | grep -m1 '^ZLS-MAP ' | sed -n 's/.* graded=\([0-9]*\) .*/\1/p')"
if [ "${zrn:-0}" = 1 ] && [ "${gr:-0}" = 1 ] && printf '%s\n' "$out" | grep -q "^ZERO-REGION .*region_end=0"; then
  ck ok "(i) PLANTED -- a graph that EMITS with a zero-entry frame map is counted (zero_region_graphs=1) and NAMED, while still reading graded=1 and no_layout=0, which is exactly how it hides from a hole census"
else
  ck no "(i) a zero-entry frame map was not counted or not named: zero_region_graphs=${zrn:-?} graded=${gr:-?}. A graph with a map and no entry in it stores every boundary outside any mapped slot BY CONSTRUCTION and no hole count can see it"
fi

# (h) an instrument nobody runs is not an instrument
if grep -q 'test_gate_gc_a_no_layout_entry_names_which_of_the_two_populations_it_is_in.sh' "$ROOT/Makefile" 2>/dev/null; then
  ck ok "(h) this gate is named in the Makefile"
else
  ck no "(h) this gate is not named in the Makefile -- a gate in no runner is not measuring (RULES.md THE INSTRUMENT LAWS)"
fi

echo "population: $checks arm(s) graded, $fails FAIL; hermetic (stub compilers and a stub census root, no rungs)"
[ "$fails" = 0 ] && { echo "GATE PASS [gc_a_no_layout_entry_names_which_of_the_two_populations_it_is_in]: $checks of $checks arms hold"; exit 0; }
echo "⛔ GATE RED [gc_a_no_layout_entry_names_which_of_the_two_populations_it_is_in]: $fails of $checks arms FAIL"; exit 1
