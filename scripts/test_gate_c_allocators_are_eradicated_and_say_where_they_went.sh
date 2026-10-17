#!/usr/bin/env bash
# test_gate_c_allocators_are_eradicated_and_say_where_they_went.sh -- THE GATE ON LON'S ERADICATION ORDER
# (coo, CEO-842/843; RULES.md FACT RULE line 29).
#
# LON'S ACCEPTANCE TEST IS TEXTUAL AND IT IS HIS: "Eradicate ALL usage of malloc, calloc, free, and realloc.
# At the end ensure 0 instances found in the SCRIP source base."  So the count must fall to 0 over the WHOLE
# tree -- src/parsers and the checked-in generated flex/bison output included.
#
# ⛔⭐ BUT THE COUNT ALONE IS NOT THE VERDICT, and that is the ceo's own warning (CEO-843, verbatim): "a census
# that only counts the four names would read green on a tree where half the runtime quietly lives outside the
# collector."  The rule names three destinations -- the collected heap WITH A ROOT for anything the running
# program can reach, the compile-time arena for what only the compiler touches, mmap for the collector's own
# bookkeeping -- and THE ARENA MAY NOT HOLD ANYTHING THE RUNTIME CAN REACH.  An arena allocation under
# src/runtime is the same evasion as malloc or a pin, one name further out -- ⛔ BUT ONLY WHEN THE SITE CAME OFF
# THE COLLECTED HEAP, which is the split CEO-846 ordered and which arm (c) now makes.
#
# ⛔ THE RULE IS AUTHORITATIVE WHILE THE CURE DOES NOT EXIST (RULES.md line 29), exactly as it is for xfail, so
# THIS GATE IS RED TODAY BY DESIGN -- 1182 sites at the order.  What it enforces meanwhile is the RATCHET: the
# counts may only fall, and a fall the baseline has not recorded is just as red as a rise, because a ratchet
# nobody tightens is a ratchet that lets the next regression back in.  The gate's own verdict is the ratchet's,
# never the census's; a census RED is the design state, not this gate's failure.
#
# ARMS: (a) the census's own selftest -- planted violations trip, a clean fixture passes, a vacuous zero refuses
#       (b) the census runs on this tree and prints its population (a REFUSAL here is rc=2, never green)
#       (c) ARENA-IN-RUNTIME is 0 -- the anti-evasion clause, the population a four-name grep cannot see
#       (c) THE ARENA CLASS SPLIT (CEO-846): class 1, a site that was on the COLLECTED HEAP and is now in the
#           arena, is the evasion and a HARD red; class 2, a site that was a libc malloc and is now in the
#           arena, is transitional DEBT with the lifetime it already had and is ratcheted to zero instead.
#           Without ../harness/scripts/c_allocator_sites_baseline.tsv the split is not computable and this REFUSES rc=2.
#       (d) the ratchet holds against ../harness/scripts/c_allocator_baseline.tsv
#       (f) MARK THE CONTAINER, NOT ONLY WHAT IT POINTS AT (CFO-96/97) is graded and printed, with its limit
#       (g) WHO OWNS THE BLOCK (CEO-850): a block libc owns handed to the arena's free or to a collector root.
#           Six today, every one named. NOT the twelve-name census, which RULES.md line 29 says lands with its
#           cure -- this names an open door rather than printing a zero over one.
#       (e) the census still ANSWERS both halves of CEO-844: it resolves alias CHAINS and counts the calls made
#           through them, and it reports licence prose APART from the count.  An instrument that goes quiet on
#           either clause reads green while the thing it was built to see walks past it -- the alias chain
#           `#define YYSTACK_ALLOC YYMALLOC` over `#define YYMALLOC malloc` is invisible to a four-name grep AND
#           to one level of alias reading, and the GPL sentence "This program is free software" is not usage.
# FAIL_ONCE=1 blanks the selftest's proof so arm (a) is seen to trip.
# EXIT: 0 every arm · 1 an arm failed · 2 REFUSED (no python3, no census, no baseline).
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CEN="$HERE/util_c_allocator_census.py"
BASE="$HERE/c_allocator_baseline.tsv"
refuse() { echo "⛔ REFUSED-TO-GRADE rc=2: $1"; exit 2; }
command -v python3 >/dev/null 2>&1 || refuse "python3 not on PATH"
[ -f "$CEN" ] || refuse "no census at $CEN"
[ -f "$BASE" ] || refuse "no ratchet baseline at $BASE -- the counts have nothing to be held against"
[ -f "$HERE/c_allocator_sites_baseline.tsv" ] || refuse "no per-file provenance baseline at $HERE/c_allocator_sites_baseline.tsv -- without what each site WAS, an evasion (collected heap -> arena) and transitional debt (malloc -> arena) are indistinguishable, and this gate does not guess"
fails=0; checks=0
ck() { checks=$((checks+1)); if [ "$1" = ok ]; then printf '  ok    %s\n' "$2"; else printf '  FAIL  %s\n' "$2"; fails=$((fails+1)); fi; }
echo "=== gate: the four C allocators leave the tree, and every converted site says where it went ==="

st="$(timeout -k 5 300s python3 "$CEN" --selftest 2>&1)"; strc=$?
[ "${FAIL_ONCE:-0}" = 1 ] && st="(blanked by FAIL_ONCE)"
arms="$(printf '%s\n' "$st" | sed -n 's/^population: \([0-9]*\) selftest arm(s).*/\1/p')"
if [ "$strc" = 0 ] && [ "${arms:-0}" -ge 28 ] 2>/dev/null && printf '%s\n' "$st" | grep -q '^SELFTEST PASS'; then
  ck ok "(a) the census trips on planted violations and refuses a vacuous zero -- $arms selftest arms, 0 FAIL"
else
  ck no "(a) the census selftest did not pass (rc=$strc, arms=${arms:-none}): $(printf '%s\n' "$st" | grep -m2 '  FAIL  ' | tr '\n' ';')"
fi

# ⛔ ONE SCAN, NOT TWO (row instruments-the-allocator-census-preflight-arm-runs-7-to-14-s-..., the cfo 2026-09-24): this
# arm ran `--by-dir` and then `--ratchet`, and each CLI run walked the whole tree again (3.8 s and 4.0 s at load 27, the
# arm 12-14 s against its 5 s preflight budget). The census is now run once, in-process: census(ROOT, by_dir) prints
# exactly what `--by-dir` printed and fills COUNTS, then ratchet(BASE) grades those same counts -- the two functions the
# two runs called, in the same order, so every arm below reads the lines and return codes it read before. A process that
# dies before printing its rc marker keeps its exit status, as a crashed CLI run did.
both="$(timeout -k 5 300s python3 - "$CEN" "$BASE" 2>&1 <<'PY'
import importlib.util, sys
spec = importlib.util.spec_from_file_location("c_allocator_census", sys.argv[1]); m = importlib.util.module_from_spec(spec); spec.loader.exec_module(m)
print("@@CENSUS-RC " + str(m.census(m.ROOT, True, False)), flush=True)
print("@@RATCHET-RC " + str(m.ratchet(sys.argv[2])), flush=True)
PY
)"; prc=$?
out="$(printf '%s\n' "$both" | sed '/^@@CENSUS-RC /,$d')"
crc="$(printf '%s\n' "$both" | sed -n 's/^@@CENSUS-RC \([0-9]*\)$/\1/p' | head -1)"; crc="${crc:-$prc}"
rout="$(printf '%s\n' "$both" | sed -n '/^@@CENSUS-RC /,/^@@RATCHET-RC /p' | sed '1d;/^@@RATCHET-RC /d')"
if [ "$crc" = 2 ]; then
  ck no "(b) the census REFUSED rc=2 on this tree -- it could not measure, which is not a clean zero: $(printf '%s\n' "$out" | grep -m1 'REFUSED')"
else
  ck ok "(b) the census measured this tree: $(printf '%s\n' "$out" | grep -m1 '^CENSUS c-allocators FORBIDDEN' | cut -c1-140)"
fi
printf '%s\n' "$out" | grep -m1 '^CENSUS c-allocators SPLIT' | sed 's/^/    /'
printf '%s\n' "$out" | grep -m1 '^CENSUS c-allocators ALIASES' | sed 's/^/    /'
printf '%s\n' "$out" | grep -m1 '^CENSUS c-allocators DESTINATIONS' | sed 's/^/    /'
printf '%s\n' "$out" | grep -m1 '^CENSUS c-allocators PROSE-RESIDUE' | sed 's/^/    /'
printf '%s\n' "$out" | grep -m1 '^CENSUS c-allocators ARENA-SPLIT' | sed 's/^/    /'
printf '%s\n' "$out" | grep -m1 '^CENSUS c-allocators CONTAINER-UNMARKED' | sed 's/^/    /'
printf '%s\n' "$out" | grep -m1 '^CENSUS c-allocators LIBC-OWNED-MISUSE' | sed 's/^/    /'

# ⛔⭐ (c) THE CLASS SPLIT (CEO-846).  The clause was written as one rule over two different acts and only one
# of them is the evasion, so the TOTAL is not the verdict: what a site WAS decides.  Class 1 -- collected heap
# -> arena -- is the cfo's f62a33aed shape under a new name and is a HARD RED here, named, never ratcheted.
# Class 2 -- libc malloc -> arena -- has the lifetime it already had, removes a forbidden call, and is DEBT
# that arm (d)'s ratchet drives to zero.  ⛔ If the provenance baseline is missing the split is NOT COMPUTABLE
# and this REFUSES rc=2: guessing would either red an honest sweep or admit the exact thing the clause stops.
if printf '%s\n' "$out" | grep -q '^CENSUS c-allocators ARENA-SPLIT REFUSED(2)'; then
  echo "⛔ REFUSED-TO-GRADE rc=2: the per-file provenance baseline is missing, so the arena class split cannot be computed -- $(printf '%s\n' "$out" | grep -m1 'ARENA-SPLIT REFUSED')"
  exit 2
fi
ev="$(printf '%s\n' "$out" | sed -n 's/^CENSUS c-allocators ARENA-SPLIT CLASS-1-EVASION=\([0-9]*\) .*/\1/p' | head -1)"
dbt="$(printf '%s\n' "$out" | sed -n 's/^CENSUS c-allocators ARENA-SPLIT .*CLASS-2-DEBT=\([0-9]*\) .*/\1/p' | head -1)"
av="$(printf '%s\n' "$out" | sed -n 's/^CENSUS c-allocators ARENA-IN-RUNTIME=\([0-9]*\) .*/\1/p' | head -1)"
if [ -z "$ev" ]; then
  ck no "(c) the arena class split did not print -- the instrument cannot tell an evasion from transitional debt, which is the whole question CEO-846 asked it"
elif [ "$ev" = 0 ]; then
  ck ok "(c) CLASS-1-EVASION=0 -- nothing that was on the collected heap has been moved into the arena (ARENA-IN-RUNTIME=${av:-?} of which CLASS-2-DEBT=${dbt:-?} is transitional, ratcheted by arm (d))"
else
  ck no "(c) CLASS-1-EVASION=$ev -- a site that was ON THE COLLECTED HEAP is now in the compile-time arena. THE CURE FOR AN UNROOTED HOLDER IS A ROOT, NEVER A DIFFERENT ALLOCATOR: $(printf '%s\n' "$out" | grep -m3 'CLASS-1-EVASION ' | tr '\n' ';' | cut -c1-300)"
fi

# ⛔ (f) MARK THE CONTAINER, NOT ONLY WHAT IT POINTS AT (CEO-846, the cfo's CFO-96/97).  A root walk that
# visits a container's contents and never the container reads as ROOTED to every census ever written -- this
# gate's own destination column included, which only asks where an allocation went.  Ratcheted by arm (d);
# graded here so the reading is printed rather than buried, WITH the limit stated: it is a syntactic read of
# the *_gc_roots functions and a LIVE=0 from it is not a proof.
# ⛔ (g) WHO OWNS THE BLOCK (CEO-850, RULES.md line 29 as amended).  A block libc owns handed to our arena or
# our collector.  Graded and PRINTED rather than folded into a count, and ratcheted by arm (d) -- it read 6 when
# this arm landed and 0 on origin since a35750d9b, every one named, because naming an open door is the opposite of
# printing a zero over one.  ⛔ AND THE DOORS THEMSELVES ARE COUNTED (coo 2026-09-23, row instruments-the-c-allocator-
# census-knows-open-memstream-...): a libc heap block handed to NOTHING of ours -- a bare strdup in a static table --
# was in no count, and open_memstream was not a door at all, so four live memstream drops read 0 here.  LIBC-DOORS
# is ratcheted by arm (d) beside it, and an instrument silent on either reds this arm.
lom="$(printf '%s\n' "$out" | sed -n 's/^CENSUS c-allocators LIBC-OWNED-MISUSE=\([0-9]*\) .*/\1/p' | head -1)"
doors="$(printf '%s\n' "$out" | sed -n 's/^CENSUS c-allocators LIBC-DOORS=\([0-9]*\) .*/\1/p' | head -1)"
if [ -z "$lom" ] || [ -z "$doors" ]; then
  ck no "(g) the libc-ownership census or the libc-doors census did not print -- the test is WHO OWNS THE BLOCK and an instrument silent on it certifies every cross-allocator drop in the tree"
else
  ck ok "(g) ownership is GRADED and every mismatch named: LIBC-OWNED-MISUSE=$lom and LIBC-DOORS=$doors (both ratcheted by arm (d); ct_drop on a libc pointer reads 32 bytes it does not own -- it can segfault under ASLR and otherwise leaks, CFO-153)"
fi

# ⛔ (h) CLASS 3, RULED-PERMANENT (CEO-856, the cfo's shape).  Class 2 DEBT means "holder not yet rooted" and its
# meaning is that it ratchets to ZERO; CEO-854 ruled five sites permanently and correctly arena, so carrying them as
# debt makes that target unreachable BY CONSTRUCTION -- and a ratchet with an unreachable target teaches the fleet to
# raise baselines instead of curing.  Class 3 is counted, PRINTED, and not driven to zero.  ⛔ THE CITATION IS THE
# WHOLE SAFETY: an entry whose cited ruling does not resolve is a class-1 evasion in disguise, and the census REDS on
# it.  Graded here so the reading is printed rather than inferred from a green line, and so an empty class 3 -- which
# is the correct resting state today -- is visibly empty rather than absent.
c3="$(printf '%s\n' "$out" | sed -n 's/^CENSUS c-allocators CLASS-3-RULED-PERMANENT=\([0-9]*\) .*/\1/p' | head -1)"
if [ -z "$c3" ]; then
  ck no "(h) the class-3 census did not print -- with no third class the ratchet's target is unreachable by construction the moment a site is ruled permanent, and the instrument would be silent about which sites left the ratchet"
elif printf '%s\n' "$out" | grep -q 'CLASS-3 CITATION DOES NOT RESOLVE'; then
  ck no "(h) a CLASS-3 entry cites a ruling that does not resolve -- an entry in class 3 with no ruling behind it is a CLASS 1 EVASION IN DISGUISE: $(printf '%s\n' "$out" | grep -m2 'CLASS-3 CITATION DOES NOT RESOLVE' | tr '\n' ';' | cut -c1-260)"
elif printf '%s\n' "$out" | grep -q 'CLASS-3 CITATIONS NOT MEASURABLE'; then
  ck no "(h) the class-3 citations could not be checked at all -- merge .github and re-run; could-not-measure is never green (this arm is rc=2 shaped and is reported as not-green deliberately)"
else
  ck ok "(h) class 3 is GRADED with every citation resolved: CLASS-3-RULED-PERMANENT=$c3, each site named with the ruling that licensed it, counted and printed but NOT driven to zero (ARENA-IN-RUNTIME=${av:-?} total; the ratcheted number is that minus class 3)"
fi

cu="$(printf '%s\n' "$out" | sed -n 's/^CENSUS c-allocators CONTAINER-UNMARKED LIVE=\([0-9]*\) .*/\1/p' | head -1)"
if [ -z "$cu" ]; then
  ck no "(f) the container census did not print -- an instrument that goes quiet on this property certifies the shape as cured across the whole tree"
else
  ck ok "(f) the container property is GRADED and its reading printed: $(printf '%s\n' "$out" | grep -m1 '^CENSUS c-allocators CONTAINER-UNMARKED' | cut -c1-120) (a syntactic read of *_gc_roots; LIVE=0 would not be a proof, and the gate says so rather than certifying)"
fi

# ⛔ (e) THE TWO CLAUSES OF CEO-844 ARE THEMSELVES A POPULATION, because the failure mode of this instrument is
# not a wrong number, it is SILENCE: drop the chain resolver and the census reads the same 1182 while 15 calls
# through YYSTACK_ALLOC walk past it; fold the licence prose in and the count never reaches 0, which teaches the
# next reader to edit a copyright header.  Both lines must be present, and the prose must be OUT of the count.
al="$(printf '%s\n' "$out" | sed -n 's/^CENSUS c-allocators ALIASES=\([0-9]*\) ALIAS-CALLS=\([0-9]*\) .*/\1 \2/p' | head -1)"
pr="$(printf '%s\n' "$out" | sed -n 's/^CENSUS c-allocators PROSE-RESIDUE=\([0-9]*\) .*/\1/p' | head -1)"
ft="$(printf '%s\n' "$out" | sed -n 's/^CENSUS c-allocators FORBIDDEN total=\([0-9]*\) .*/\1/p' | head -1)"
chain="$(printf '%s\n' "$out" | grep -c ' via .* -> .* -> ' || true)"
if [ -n "$al" ] && [ -n "$pr" ] && [ -n "$ft" ]; then
  ck ok "(e) both halves of CEO-844 are answered: ALIASES/ALIAS-CALLS=$al with $chain resolved multi-level chain(s) named by route, and PROSE-RESIDUE=$pr held APART from the count of $ft -- a licence header is never edited to make a grep read zero"
else
  ck no "(e) the census went QUIET on a CEO-844 clause -- aliases='${al:-missing}' prose='${pr:-missing}' forbidden='${ft:-missing}'; an instrument that stops reporting a population reads green while that population walks past it"
fi

if printf '%s\n' "$rout" | grep -q '^RATCHET GREEN'; then
  ck ok "(d) the ratchet holds: $(printf '%s\n' "$rout" | grep -m1 '^population: .*ratcheted count')"
else
  ck no "(d) the ratchet is not green -- $(printf '%s\n' "$rout" | grep -m3 -E '⛔ WORSE|⭐ BETTER|NOT-MEASURED|^RATCHET (RED|REFUSED)' | tr '\n' ';' | cut -c1-260)"
fi

echo "------------------------------------------------------------"
echo "population: $checks arm(s) graded, $fails FAIL; census rc=$crc (the census being RED is the design state -- the rule is authoritative while the cure does not exist, RULES.md line 29 -- and it is not this gate's verdict)"
if [ "$fails" -ne 0 ]; then echo "⛔ GATE FAIL: $fails of $checks arm(s) failed"; exit 1; fi
echo "✅ GATE PASS [c_allocators_are_eradicated_and_say_where_they_went]: $checks of $checks arms hold"; exit 0
