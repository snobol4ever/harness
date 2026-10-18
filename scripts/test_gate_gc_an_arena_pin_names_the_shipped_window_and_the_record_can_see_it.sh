#!/usr/bin/env bash
# ⛔⭐⭐ THE GATE THAT HOLDS THE CEO-1146 ARENA SWEEP, and it exists because the sweep's own census had neither a
# selftest nor a recipe that ran it -- the identical pair of holes COO-150 had just cured in util_gc_acceptance.py,
# one instrument later.
#
# WHAT THE SWEEP WAS.  Since CEO-1095 took the shipped arena to 128 KB (GC_HEAP_KB, compiled in, on Lon's word), the
# spelling `SCRIP_HEAP_MB=1` names a 1024 KB window -- EIGHT TIMES the window we ship.  Eighteen gates pinned it
# believing it tightened the arena.  MEASURED HERE over six witnesses at four arenas: MB=1 runs the collector ZERO
# times on four of them and once or twice on the other two, so those gates were grading their stress-0 arms with the
# collector switched off, and the cfo independently caught jcon args.icn reading collections=0 at MB=1 while it is
# RED at the shipped arena with collections=3 -- a live defect the mandated "tiny" arena is blind to.
#
# ⛔ WHY THE SHIPPED 128 KB AND NOT THE 64 KB FLOOR, which is where this sweep was first drafted and where the cto's
# nine went.  64 collects MORE on all six witnesses (50/11/2/1/3/80 against 22/3/1/0/1/26), so exasperation alone
# argues for it -- but on hb_bignum_length.icn a 64 KB pin reads grew=16 and the cfo measured grew=8 on args.icn:
# THE WINDOW GREW, so the run was not the size its own label claims.  A pin the runtime overrides is a false label,
# which is the exact defect class this row exists to close; I printed grew=16 in my own output and read past it, and
# the cfo's message is what sent me back to it.  The deciding law is the THIRTY-THIRD BATCH'S FIRST CLAUSE: the
# exasperation knob is STRESS, NEVER THE ARENA.  So the arena's job is to be the window we ship (CEO-939: a landing
# gate must grade what we ship; SCRIP_HEAP_KB_TINY is already 128; grew is 0 there on all six) and SCRIP_GC_STRESS
# does the exasperating.
#
# ARMS.  (a) the sweep is COMPLETE -- the census of record reads zero gates left to sweep.  (b) THE CENSUS PROVES
# ITSELF on a planted witness per spelling, because a DONE-WHEN that trusts a reader to say ZERO is only as good as
# that reader: the shipped regex read `=1` and `${VAR:-1}` but NOT `${VAR:=1}` and under-reported its own population
# by two gates.  (c) that selftest CAN FAIL.  (d) a KB-pinned run DECLARES ITS ARENA to the progress record -- it did
# not, and sweeping onto a knob the record cannot see would have traded a wrong arena for an invisible one.
# (e) THE KNOB IS A REQUEST AND COLLECTIONS ARE THE EVIDENCE (33rd batch clause 5), measured live on this binary.
# (f) the window the pin asks for is the window the runtime delivers -- grew=0, the disqualifier that chose 128.
# ⛔⭐ SINCE CEO-1261 (Lon 2026-09-25: "Let's set our default stack size and heap size for SCRIP to be the same as SPITBOL.") THE
# SHIPPED WINDOW IS SPITBOL'S -i1m, which is the 1024 KB an MB pin of 1 names, so the swept pins now name the GC-TESTING arena
# (the Makefile's SCRIP_HEAP_KB_TINY, 128 KB -- the literal 24 swept gates pin) rather than the shipped window: arms (e) and (f) read that
# arena out of the Makefile and grade it, and the shipped window is printed beside it, never repeated here.
set -uo pipefail
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)"
G="gc_an_arena_pin_names_the_shipped_window_and_the_record_can_see_it"
SCRIP="${SCRIP_BIN:-$ROOT/scrip}"
checks=0; fails=0
ck() { checks=$((checks+1)); if [ "$1" = ok ]; then echo "  ok   $2"; else fails=$((fails+1)); echo "  FAIL $2"; fi; }
refuse() { echo "⛔ GATE REFUSED(2) [$G]: $1"; exit 2; }
[ -x "$SCRIP" ] || refuse "no scrip binary at $SCRIP -- arms (e) and (f) would have measured nothing"

SHIPPED_KB=$(grep -oE '^#define GC_HEAP_KB[[:space:]]+[0-9]+' "$ROOT/src/runtime/rt/gc_heap.c" | awk '{print $3}')
[ -n "${SHIPPED_KB:-}" ] || refuse "cannot read GC_HEAP_KB out of src/runtime/rt/gc_heap.c -- the shipped window is the subject and it is not assumed here"
echo "=== gate: an arena pin names the shipped window, and the progress record can see it ==="
SWEPT_KB=$(sed -n 's/^SCRIP_HEAP_KB_TINY[[:space:]]*?=[[:space:]]*\([0-9]\+\).*/\1/p' "$ROOT/Makefile" | head -1)
[ -n "${SWEPT_KB:-}" ] || refuse "cannot read SCRIP_HEAP_KB_TINY out of the Makefile -- the GC-testing arena the sweep targets is the subject and it is not assumed here"
echo "    shipped window GC_HEAP_KB=$SHIPPED_KB KB · the GC-testing arena SCRIP_HEAP_KB_TINY=$SWEPT_KB KB (both read, never repeated) · MB=1 resolves to 1024 KB"

# ---- (a) THE SWEEP IS COMPLETE ---------------------------------------------------------------------------------
cen="$(cd "$ROOT" && python3 ../harness/scripts/util_arena_pin_census.py 2>&1)"; crc=$?
[ "$crc" = 2 ] && refuse "the census of record could not measure: $(printf '%s\n' "$cen" | tail -1)"
pop="$(printf '%s\n' "$cen" | grep -m1 '^population:')"
if printf '%s\n' "$cen" | grep -qE '^population: [0-9]+ gate\(s\) examined, [0-9]+ pinned, 0 mine'; then
  ck ok "(a) the sweep is complete -- $pop; every gate still matching an MB=1 form is either the cto's by header seat or SPLIT OUT AND NAMED with its reason in the census"
else
  ck no "(a) the census still names gates to sweep -- $pop. Run ../harness/scripts/util_arena_pin_census.py for the list by name."
fi

# ---- (b) THE CENSUS PROVES ITSELF ------------------------------------------------------------------------------
st="$(cd "$ROOT" && python3 ../harness/scripts/util_arena_pin_census.py --selftest 2>&1)"; strc=$?
arms=$(printf '%s\n' "$st" | grep -cE '^    (ok|RED) ')
if [ "$strc" = 0 ] && [ "${arms:-0}" -ge 10 ]; then
  ck ok "(b) the census proves itself -- $arms planted arms, 0 red, one witness per POSIX default operator (=, :=, :-, -) plus the negative controls (a 512 pin, a 10 pin, a KB pin, a comment mention, a heredoc interior)"
else
  ck no "(b) the census selftest is red or truncated (rc=$strc, $arms arms) -- a reader that cannot classify a planted spelling cannot be trusted to report ZERO. $(printf '%s\n' "$st" | grep -m2 '^    RED')"
fi

# ---- (c) AND THAT SELFTEST CAN FAIL ----------------------------------------------------------------------------
fo="$(cd "$ROOT" && FAIL_ONCE=1 python3 ../harness/scripts/util_arena_pin_census.py --selftest 2>&1)"
if printf '%s\n' "$fo" | grep -q 'FAIL-ONCE PROVED'; then
  ck ok "(c) fail-once proved: restoring the shipped narrow regex turns $(printf '%s\n' "$fo" | grep -oE '[0-9]+ arm\(s\) went red' | head -1) -- a selftest that cannot fail is not a selftest"
else
  ck no "(c) FAIL_ONCE did not trip -- the (b) arms cannot tell the narrow regex from the wide one, so their green proves nothing"
fi

# ---- (d) A KB-PINNED RUN DECLARES ITS ARENA --------------------------------------------------------------------
ax="$(cd "$ROOT" && env -u SCRIP_HEAP_MB SCRIP_HEAP_KB=64 SCRIP_GC_STRESS=3 python3 -c 'import sys; sys.path.insert(0, "../harness/scripts"); import util_progress_append as p; print(",".join("%s=%s"%(k,v) for k,v in sorted(p.gc_axis_env().items())))' 2>&1)"
if printf '%s\n' "$ax" | grep -q 'SCRIP_HEAP_KB=64'; then
  ck ok "(d) a KB-pinned run declares its arena to the progress record -- axis reads [$ax]; before this landing it read SCRIP_GC_STRESS=3 ALONE, so 18 gates were about to move onto a knob the record could not see"
else
  ck no "(d) a KB pin records NO ARENA -- axis reads [$ax]. GC_AXIS_EXACT must name SCRIP_HEAP_KB: the prefix is SCRIP_GC and SCRIP_HEAP_KB matches neither half, so the arena vanishes from every row a swept gate writes."
fi

# ---- (e)(f) THE KNOB IS A REQUEST; COLLECTIONS AND grew ARE THE EVIDENCE ---------------------------------------
W="$HERE/gc_witnesses/hb_scan_nested.icn"
[ -f "$W" ] || W="$(ls "$HERE"/gc_witnesses/*.icn 2>/dev/null | head -1)"
[ -n "${W:-}" ] && [ -f "$W" ] || refuse "no GC witness under ../harness/scripts/gc_witnesses -- arms (e) and (f) grade a live run and will not be inferred from source"
rd() { env -u SCRIP_HEAP_MB -u SCRIP_HEAP_KB "$1"="$2" SCRIP_GC_EXERCISE=1 timeout -k 5 120s "$SCRIP" "$W" 2>&1 >/dev/null | grep -m1 '^\[GC-EXERCISE\]'; }
fld() { printf '%s\n' "$1" | grep -oE "$2=[0-9]+" | head -1 | cut -d= -f2; }
rS="$(rd SCRIP_HEAP_KB "$SWEPT_KB")"; rM="$(rd SCRIP_HEAP_MB 1)"
cS=$(fld "$rS" collections); gS=$(fld "$rS" grew); aS=$(fld "$rS" arena_kb)
cM=$(fld "$rM" collections); aM=$(fld "$rM" arena_kb)
[ -n "${cS:-}" ] && [ -n "${cM:-}" ] || refuse "no GC-EXERCISE receipt from $(basename "$W") -- the run reported nothing to grade (shipped [$rS] · MB=1 [$rM])"
if [ "${cS:-0}" -gt 0 ] && [ "${cM:-1}" -lt "${cS:-0}" ]; then
  ck ok "(e) a knob is a request and collections are the evidence -- $(basename "$W") collects $cS times at the swept window (arena_kb=$aS) against $cM at an MB pin of 1 (arena_kb=$aM). A gate pinning the MB spelling for exasperation got LESS of it than pinning nothing at all."
else
  ck no "(e) the swept window does not out-collect MB=1 on $(basename "$W") -- shipped $cS at arena_kb=$aS, the MB pin $cM at arena_kb=$aM. Either the witness stopped allocating or the arena stopped mattering; a GC arm over an unexercised collector grades nothing."
fi
if [ "${gS:-1}" = 0 ]; then
  ck ok "(f) the pin holds -- grew=0 at the swept window, so arena_kb=$aS is the window the run ACTUALLY had and the label is true. This is the arm that chose $SWEPT_KB KB over the 64 KB floor: 64 collects more but reads grew=16 on hb_bignum_length.icn and grew=8 on the cfo's args.icn, and a window that grows is not the size its own pin claims."
else
  ck no "(f) the pin does NOT hold -- grew=$gS at the swept window on $(basename "$W"), so the run outgrew arena_kb=$aS and every number taken under this label names a configuration the run did not have."
fi

echo
if [ "$fails" = 0 ]; then
  echo "✅ GATE PASS [$G]: $checks check(s) -- the MB=1 population is swept to the shipped window, the census that says so proves itself on a planted witness per spelling and can fail, a KB pin reaches the progress record, and the window the pin asks for is the one the collector actually ran in"
  exit 0
fi
echo "⛔ GATE FAIL($fails) [$G]: $checks check(s), $fails red -- an arena pin that names a window the run did not have is a number wearing a label it did not earn"
exit 1
