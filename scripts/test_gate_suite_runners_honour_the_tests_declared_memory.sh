#!/usr/bin/env bash
# test_gate_suite_runners_honour_the_tests_declared_memory.sh -- LON'S WORD OF 2026-09-23, MEASURED.
#
# ⛔⭐ THE ROW.  Lon, in-chat to the ceo, verbatim: "Well, each test should have the needed amount of memory in the
# attribute TSV/CSV files." (routed CEO-1167).  Before that word a program whose live set did not fit the shipped
# window was a capacity red and an argument for raising the default for EVERYBODY.  After it, the program DECLARES
# what it needs in its suite's ALL.csv heap_kb column, and the runner exports SCRIP_HEAP_KB FOR THAT PROGRAM ONLY.
#
# ⛔⭐⭐ WHAT THIS GATE REFUSES TO TAKE ON TRUST, AND IT IS THE WHOLE REASON IT EXISTS.  "The runner reads the
# column" is cheap to assert and cheap to believe.  The failure that matters is the SILENT one: a reader that
# returns the default for every entry still produces a green board, because an undeclared program and a program
# whose declaration was dropped run identically.  So arm B does not ask whether the reader ran -- it plants a
# program that CANNOT COMPLETE at the shipped default and CAN at its declared arena, and requires the verdicts to
# differ.  A reader that quietly does nothing fails that arm by construction.  Arm C is its negative control: the
# NEIGHBOUR entry in the same csv, same runner, same loop, must still see the shipped default -- because a reader
# that exports one program's arena over the whole run has not honoured a declaration, it has pinned an arena, which
# is precisely the thing a declaration replaces (util_arena_pin_census.py, CEO-1146).
#
# ⛔⭐ ARM A IS A DRIFT ALARM ON A COPIED CONSTANT.  lib_declared_arena.sh and corpus_suite_harness.py each carry a
# copy of gc_heap.c's GC_HEAP_CAP_KB / GC_HEAP_KB_FLOOR.  A copy of a runtime constant that nothing checks is the
# false-label class this column exists to close, so the #defines are re-read from source here and compared.
#
# ââ­â­ ARM D ENFORCES A RULING, NOT A PREFERENCE: A DECLARATION IS A NUMBER ABOVE THE COMPILED CAP OR IT IS NOT A DECLARATION (ceo CEO-1171, 2026-09-23, ruling on the coo's ask).
# The refusal was asked for rather than assumed -- criterion-writing is not the instruments seat's verb --
# and the answer was that warn-and-pass would mint the false label CEO-1101 exists against. So arm D may
# not be relaxed to a warning by anyone reading this file later; it is law, cited, with its measurement.
# ⛔⭐⭐ ARM D IS THE MEASUREMENT THAT MADE THIS COLUMN HONEST, AND IT IS NOT A STYLE CHECK.  gc_heap.c reads
#     cap_kb = (long)GC_HEAP_CAP_KB; if (cap_kb < kb) cap_kb = kb;
# so SCRIP_HEAP_KB moves the INITIAL WINDOW always and the HARD CAP only once it climbs past 4096.  Measured by the
# coo 2026-09-23 on one binary and one 60000-element Icon witness: 128, 2048 and 4096 all die rc=134 at a cap the
# runtime itself prints as 4096 KB; 4097 moves it to 4100; 8192 completes rc=0.  A cell reading 2048 therefore
# declares NOTHING ABOUT CAPACITY while reading to every consumer exactly like a capacity declaration -- and the
# baton's own guardrail (matched at that arena, NOT matched one step below) is UNPROVABLE for it, because one step
# below carries the same cap and both arms read the same.  Arm D requires that cell to be REFUSED rc=2, not
# silently accepted as a no-op.  Arm D2 requires the runtime to still behave that way, so the day the cap moves
# this gate says so instead of continuing to enforce a rule the runtime no longer has.
#
# ⛔ ARM E IS CEO-1127's EVIDENCE BAR.  Every one of the ten seats grades ENTRIES EXTRACTED STANDALONE.  An
# extracted pair has no sibling ALL.csv, so a declaration that did not travel would mean a program needing 16384 KB
# runs at the shipped 128 in EXACTLY the workflow the fleet cures in, while passing on the board it is published
# from -- two arms disagreeing for a reason neither names.
#
# FAIL_ONCE=1 restores the pre-column world -- all five shell readers (declared_arena_kb, declared_arena_kb_beside,
# declared_stack_kb, declared_stack_kb_beside, declared_memory_table) return nothing for everybody AND the travelling sidecar is not
# written -- and MEASURED 2026-09-23 21:5x (coo, the table arms T and the runner census R added on CEO-1229) it reds exactly fourteen
# arms: B, C3, D1, D1b, E2, H1, H2, S1, S3, S6, T1, T2, T3 and T5 -- RE-MEASURED 2026-09-25 on the CEO-1261 cut, the same fourteen of 35.
# The other twenty-one are green BY CONSTRUCTION under the mutant and are named so nobody reads their green as coverage: A1..A4, A3b, D2 and S4 read the runtime, F reads the shipped tree, E1 names a path,
# C1/C2/H3/S2 describe the reader-off world itself, G, S5 and O1-O4 drive the Python harness, which the mutant leaves alone (arm O's
# own fail-once is measured against a harness without the OOM verdict and recorded at the arm), T4 refuses a
# run that has no table (no reader involved), and R is a census of the runners' source -- its own fail-once is a scratch tree
# holding origin's unwired PAT runner and logtalk grader, where R reds naming exactly those two files and nothing else.
# An arm that has never been seen to fail is an arm that reads "there was never a bug here" (this gate's own law,
# COO-152), and a fail-once that reds for a STAGING reason while claiming to have proved the property is the shape
# COO-153 found three of inside the mechanism built to disprove exactly that -- so the ten are listed, not counted.
# ⛔⭐⭐⭐ RE-CUT 2026-09-25 FOR CEO-1261 (Lon, in-chat to the ceo, verbatim: "Let's set our default stack size and heap size for SCRIP to
# be the same as SPITBOL." and "Ensure that all the test suite programs have the stack size and heap size setting placed into the per-
# program attribute files."). The shipped cap is SPITBOL's -d128m and the stack SPITBOL's -s4m, every program declares both, and a
# heap_kb is the program's MAXIMUM heap (-d; exported as SCRIP_HEAP_CAP_KB), never its window. So the fixture is INVERTED: hungry.icn
# (a 6.4 MB live set) DECLARES 4096 KB, which it cannot fit -- an honoured declaration makes it end in the runtime's out-of-memory
# report naming the 4096 KB cap, while a reader that silently did nothing lets it complete at the 128 MB default, and the arms still
# require the two verdicts to differ. CEO-1171's refusal of a cell at or below the shipped cap (arm D) and the stack floor rule (S3/S4)
# are RETIRED with it: a declaration equal to or below the default is a setting; a heap cell below the 1024 KB window and a stack cell
# below 64 KB are what is refused. The pre-cut file is kept whole in history (SCRIP b547d2ea3); its arms are re-derived, not weakened.
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
set -u
cd "$(dirname "$0")/../../SCRIP" || exit 2
ROOT="$PWD"; HERE="$ROOT/../harness/scripts"; G="suite_runners_honour_the_tests_declared_memory"
checks=0; fails=0
ck() { checks=$((checks+1)); if [ "$1" = ok ]; then echo "  ok   $2"; else fails=$((fails+1)); echo "  FAIL $2"; fi; }
refuse() { echo "⛔ GATE REFUSED(2) [$G]: $1"; exit 2; }
[ -x "$ROOT/scrip" ] || refuse "no ./scrip -- this gate runs real programs at two arenas and cannot measure without one"
[ -f "$ROOT/out/libscrip_rt.so" ] || refuse "no out/libscrip_rt.so"
[ -f "$HERE/lib_declared_arena.sh" ] || refuse "lib_declared_arena.sh is missing -- the runners' one reader is not on this tree, so there is nothing to hold to the contract"
command -v python3 >/dev/null 2>&1 || refuse "no python3 -- the harness reader cannot be exercised"
. "$HERE/lib_declared_arena.sh"
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
ulimit -c 0 2>/dev/null || true
DECL_KB=4096
FIT_KB=16384
echo "GATE $G -- declared arena ${DECL_KB} KB vs the shipped default; fixture in $T (planted, NOT a corpus suite: a gate's own mktemp fixture outside the corpus tree is not a board, CEO-547)"

# ── arm A: the copied constants still match gc_heap.c ──────────────────────────────────────────────────────────
SRC="$ROOT/src/runtime/rt/gc_heap.c"
[ -f "$SRC" ] || refuse "no $SRC to read the constants back out of"
rt_cap=$(sed -n 's/^#define[[:space:]]\+GC_HEAP_CAP_KB[[:space:]]\+\([0-9]\+\).*/\1/p' "$SRC" | head -1)
rt_flr=$(sed -n 's/^#define[[:space:]]\+GC_HEAP_KB_FLOOR[[:space:]]\+\([0-9]\+\).*/\1/p' "$SRC" | head -1)
rt_win=$(sed -n 's/^#define[[:space:]]\+GC_HEAP_KB[[:space:]]\+\([0-9]\+\).*/\1/p' "$SRC" | head -1)
[ -n "$rt_win" ] || refuse "could not read GC_HEAP_KB out of $SRC -- the window a declaration may not go below is the subject of arm D"
[ -n "$rt_cap" ] && [ -n "$rt_flr" ] || refuse "could not read GC_HEAP_CAP_KB / GC_HEAP_KB_FLOOR out of $SRC -- the drift alarm cannot be armed, and an unarmed drift alarm is worse than none"
py_cap=$(python3 -c "import sys;sys.path.insert(0,'$HERE');exec(open('$HERE/corpus_suite_harness.py').read().split('def heap_sidecar_path')[0].split('# ====================================================== declared arena ===')[1]);print(GC_HEAP_CAP_KB)" 2>/dev/null || echo "")
[ "$DECLARED_ARENA_CAP_KB" = "$rt_cap" ] && ck ok "A1 lib_declared_arena.sh cap ($DECLARED_ARENA_CAP_KB) == gc_heap.c GC_HEAP_CAP_KB ($rt_cap)" \
  || ck bad "A1 lib_declared_arena.sh cap=$DECLARED_ARENA_CAP_KB but gc_heap.c says $rt_cap -- a copied runtime constant drifted, which is the false-label class this column exists to close"
grep -q "^GC_HEAP_CAP_KB = $rt_cap\b" "$HERE/corpus_suite_harness.py" && ck ok "A2 corpus_suite_harness.py GC_HEAP_CAP_KB == gc_heap.c ($rt_cap)" \
  || ck bad "A2 corpus_suite_harness.py GC_HEAP_CAP_KB disagrees with gc_heap.c ($rt_cap)"
grep -q "^GC_HEAP_KB_FLOOR = $rt_flr\b" "$HERE/corpus_suite_harness.py" && ck ok "A3 corpus_suite_harness.py GC_HEAP_KB_FLOOR == gc_heap.c ($rt_flr)" \
  || ck bad "A3 corpus_suite_harness.py GC_HEAP_KB_FLOOR disagrees with gc_heap.c ($rt_flr)"
grep -q "^GC_HEAP_KB_DEFAULT = $rt_win\b" "$HERE/corpus_suite_harness.py" && [ "$DECLARED_ARENA_MIN_KB" = "$rt_win" ] && ck ok "A3b the window a declaration may not go below: corpus_suite_harness.py GC_HEAP_KB_DEFAULT and lib_declared_arena.sh DECLARED_ARENA_MIN_KB both == gc_heap.c GC_HEAP_KB ($rt_win)" \
  || ck bad "A3b the window copies drifted: harness GC_HEAP_KB_DEFAULT, lib DECLARED_ARENA_MIN_KB=$DECLARED_ARENA_MIN_KB, gc_heap.c GC_HEAP_KB=$rt_win"

# ── the fixture: a program that does NOT fit the shipped cap, and a neighbour that does ────────────────────────
mkdir -p "$T/pkg"
# ⛔⭐⭐ FEW BIG BLOCKS, NOT MANY SMALL ONES, AND THE FIRST CUT OF THIS GATE GOT IT WRONG IN A WAY THAT COST
# A `done` RUN. The first fixture was 60000 small strings. MEASURED: at the shipped default that does not
# abort quickly -- it THRASHES, because a 128 KB window growing toward the 4096 KB cap collects on almost
# every allocation, and the cost grows superlinearly with the count (8000 entries 1.4s, 15000 4.6s, 25000
# 17.3s, all rc=0; only at 60000 does it finally abort, after ~90s). Four such runs under load 28 blew the
# criterion's own `timeout 300` and the gate returned rc=124. ⛔ AND THE REAL DEFECT WAS NOT THE DURATION:
# the premise arm tested `rc != 0`, so rc=124 (THE TIMEOUT FIRING) read as "the fixture does not fit" --
# a loaded box would have been recorded as a capacity measurement. That is the timeout-and-crash-in-one-
# branch shape the coo cured in this same seat's stack gate one tick earlier (COO-152), reappearing in a
# file written the day after. 200 blocks of 32 KB carry the same 6400 KB live set with ~200 allocations
# instead of 60000: it aborts rc=134 in ~1.5s at the default and completes rc=0 in ~75ms at 16384 KB, so
# the two verdicts are far apart, unambiguous, and cheap enough to sit in the blocking set.
# ⛔ FIX_N IS THE SINGLE SOURCE FOR BOTH THE FIXTURE AND THE STRING ARM G GRADES AGAINST. They were two
# literals for one run of this gate and arm G promptly read FAIL when the fixture was resized -- a gate
# grading its own witness against the PREVIOUS witness's output, which is a red that says nothing about
# the subject. One name, expanded into both.
FIX_N=200
cat > "$T/pkg/hungry.icn" <<EOF
procedure main()
   L := list();
   every i := 1 to $FIX_N do put(L, repl("x", 32768));
   write(*L);
end
EOF
cat > "$T/pkg/frugal.icn" <<'EOF'
procedure main()
   write("frugal");
end
EOF
printf 'rank,entry,origin,package,n_lines,stdin,want_rc,heap_kb\n1,hungry,p__hungry,p,5,0,0,%s\n2,frugal,p__frugal,p,3,0,0,\n' "$DECL_KB" > "$T/pkg/ALL.csv"

# The premise this whole gate rests on, measured rather than assumed: hungry must genuinely NOT fit the default
# and must genuinely fit the declaration. If either stops being true the fixture has stopped being a witness and
# every arm below would be grading a tautology -- so this is a REFUSAL, never a red.
( cd "$T/pkg" && env -u SCRIP_HEAP_KB -u SCRIP_HEAP_MB -u SCRIP_HEAP_CAP_KB -u SCRIP_HEAP_MAX_MB timeout -k 5 60s "$ROOT/scrip" --run hungry.icn >/dev/null 2>"$T/base.err" )
base_rc=$?
( cd "$T/pkg" && env -u SCRIP_HEAP_MB -u SCRIP_HEAP_KB -u SCRIP_HEAP_MAX_MB SCRIP_HEAP_CAP_KB="$DECL_KB" timeout -k 5 60s "$ROOT/scrip" --run hungry.icn >/dev/null 2>"$T/decl.err" )
decl_rc=$?
# ⛔⭐ A TIMEOUT IS NOT A CAPACITY VERDICT AND IS REFUSED HERE RATHER THAN COUNTED. rc=124 says the ceiling
# fired; it cannot tell "this program does not fit" from "this box is at load 28". Testing rc != 0 would
# accept a loaded machine as evidence of a live set, which is the false-label direction. What we claim is the
# RUNTIME'S OWN OUT-OF-MEMORY REPORT naming the shipped cap -- rc 1..127 with `(the GC heap's hard cap is <cap> KB, -d;`
# on stderr (the cto, SCRIP dc739c38a, CTO-164) -- and nothing else will do. ⛔ UNTIL 2026-09-23 22:20 CDT THIS LINE
# DEMANDED rc=134, the SIGABRT the cap used to be, and the cto's cure of that abort made this gate REFUSE rc=2 on
# origin -- in the blocking set, with the row's DONE-WHEN reading "could not measure" -- until the coo re-cut it
# 2026-09-24 (measured 07:0x on 8b6cb3607). A premise that names the old failure's SHAPE dies with its cure; one
# that names the runtime's own statement of the cap does not.
[ "$base_rc" != 124 ] || refuse "the fixture TIMED OUT at the shipped default rather than aborting -- rc=124 is the ceiling firing and cannot be told from a loaded box, so this run measured nothing about capacity (load: $(uptime | sed 's/.*load average: //'))"
[ "$decl_rc" != 124 ] || refuse "the fixture TIMED OUT at ${DECL_KB} KB -- same reason: a ceiling is not a verdict (load: $(uptime | sed 's/.*load average: //'))"
[ "$base_rc" = 0 ] || refuse "the fixture does not complete at the shipped default (rc=$base_rc) -- the declaration's cap cannot be shown to bite against a run that fails anyway [$(grep -m1 -E 'scrip: error|Aborted' "$T/base.err" | cut -c1-160)]"
[ "$decl_rc" -ge 1 ] && [ "$decl_rc" -lt 128 ] && grep -q "(the GC heap's hard cap is ${DECL_KB} KB, -d;" "$T/decl.err" \
  || refuse "the fixture exited rc=$decl_rc under a ${DECL_KB} KB cap without the runtime's out-of-memory report naming that cap [$(grep -m1 -E 'scrip: error|Aborted' "$T/decl.err" | cut -c1-160)] -- it is no longer a witness for a declared heap; grow it or re-measure"
echo "  PREMISE MEASURED: hungry.icn rc=$base_rc at the shipped default (cap ${rt_cap} KB), rc=$decl_rc with the runtime's out-of-memory report at a ${DECL_KB} KB cap -- the two verdicts differ and neither is a timeout, so the arms below can tell a honoured declaration from an ignored one"

# ── arm B: the runner's reader actually changes the verdict ────────────────────────────────────────────────────
if [ "${FAIL_ONCE:-0}" = 1 ]; then
  # Restore the pre-column world: the reader returns nothing for everybody.
  declared_arena_kb() { return 0; }
  declared_arena_kb_beside() { return 0; }
  declared_stack_kb() { return 0; }
  declared_stack_kb_beside() { return 0; }
  declared_memory_table() { return 0; }
fi
b_rc=0
( cd "$T/pkg" && run_at_declared_arena "$T/pkg/ALL.csv" hungry -- env -u SCRIP_HEAP_MB -u SCRIP_HEAP_KB -u SCRIP_HEAP_MAX_MB timeout -k 5 60s "$ROOT/scrip" --run hungry.icn >/dev/null 2>"$T/b.err" ) || b_rc=$?
[ "$b_rc" != 124 ] || refuse "arm B TIMED OUT (rc=124) -- the ceiling fired, so this run cannot say whether the declaration was honoured"
[ "$b_rc" -ge 1 ] && [ "$b_rc" -lt 128 ] && grep -q "(the GC heap's hard cap is ${DECL_KB} KB, -d;" "$T/b.err" && ck ok "B  the declared entry ends in the runtime's out-of-memory report at its declared ${DECL_KB} KB cap through the runner's reader (rc=$b_rc) where the same program completes rc=$base_rc at the shipped default -- the declaration is honoured, and a reader that silently did nothing could not pass this" \
  || ck bad "B  the declared entry read rc=$b_rc through the runner's reader without the report naming its ${DECL_KB} KB cap -- heap_kb=${DECL_KB} was not exported for it"

# ── arm C: the NEIGHBOUR still runs at the shipped default (no leak, no pin) ───────────────────────────────────
seen=$(run_at_declared_arena "$T/pkg/ALL.csv" frugal -- bash -c 'echo "[${SCRIP_HEAP_CAP_KB:-UNSET}|${SCRIP_HEAP_KB:-UNSET}]"')
[ "$seen" = "[UNSET|UNSET]" ] && ck ok "C1 the undeclared neighbour sees SCRIP_HEAP_CAP_KB and SCRIP_HEAP_KB UNSET -- the export is per program, not per run" \
  || ck bad "C1 the undeclared neighbour saw $seen -- one entry's declaration leaked over the loop, which is a runner PINNING an arena (the thing a declaration replaces)"
after="[${SCRIP_HEAP_CAP_KB:-UNSET}]"
[ "$after" = "[UNSET]" ] && ck ok "C2 nothing leaked into the gate's own environment after the declared run" \
  || ck bad "C2 SCRIP_HEAP_CAP_KB=$after leaked out of the declared run into the caller"
seen2=$(run_at_declared_arena "$T/pkg/ALL.csv" hungry -- bash -c 'echo "[${SCRIP_HEAP_CAP_KB:-UNSET}|${SCRIP_HEAP_KB:-UNSET}]"')
[ "$seen2" = "[$DECL_KB|UNSET]" ] && ck ok "C3 the declared entry sees exactly SCRIP_HEAP_CAP_KB=$DECL_KB and no window -- heap_kb is the maximum, never the window" \
  || ck bad "C3 the declared entry saw $seen2, expected [$DECL_KB|UNSET]"

# ── arm D: a cell below the window is REFUSED, and the runtime refuses the same cap itself ──────────────────────────
# ⛔ CEO-1171's rule (a cell at or below the shipped cap grants no capacity and is refused) is RETIRED by CEO-1261: heap_kb is the
# maximum, so 4096 declared under a 131072 default is a real, smaller cap that bites (arm B). What cannot be honoured is a maximum
# below the initial window: D1 refuses it in the reader, D2 proves the runtime refuses the same cap, so the reader's rule is the
# runtime's rule and not a copy that can drift from it.
BADKB=$((rt_win / 2))
printf 'rank,entry,origin,package,n_lines,stdin,want_rc,heap_kb\n1,hungry,p__hungry,p,5,0,0,%s\n' "$BADKB" > "$T/pkg/BAD.csv"
declared_arena_kb "$T/pkg/BAD.csv" hungry >/dev/null 2>"$T/bad.err"; d_rc=$?
[ "$d_rc" = 2 ] && ck ok "D1 heap_kb=$BADKB (below the ${rt_win} KB initial window) is REFUSED rc=2 rather than read as a cap the runtime cannot honour" \
  || ck bad "D1 heap_kb=$BADKB returned rc=$d_rc -- a maximum below the window was accepted"
grep -q "below the ${rt_win} KB initial window" "$T/bad.err" && ck ok "D1b the refusal names WHY, not just THAT" || ck bad "D1b the refusal does not say why: $(head -c 160 "$T/bad.err")"
( cd "$T/pkg" && env -u SCRIP_HEAP_MB -u SCRIP_HEAP_KB -u SCRIP_HEAP_MAX_MB SCRIP_HEAP_CAP_KB="$BADKB" timeout -k 5 60s "$ROOT/scrip" --run hungry.icn >/dev/null 2>"$T/d2.err" )
d2=$?
[ "$d2" != 124 ] || refuse "arm D2 TIMED OUT (rc=124) -- a ceiling is not evidence about the cap rule"
[ "$d2" != 0 ] && grep -q "is BELOW the ${rt_win} KB window and is REFUSED" "$T/d2.err" && ck ok "D2 the runtime refuses the same cap itself (SCRIP_HEAP_CAP_KB=$BADKB under the ${rt_win} KB window: rc=$d2, its own refusal) -- the reader's rule is the runtime's" \
  || ck bad "D2 SCRIP_HEAP_CAP_KB=$BADKB read rc=$d2 [$(head -c 160 "$T/d2.err")] -- gc_heap.c's window rule changed, so arm D1 is enforcing a rule the runtime no longer has"

# ── arm E: the declaration travels with an extracted family (CEO-1127's evidence bar) ──────────────────────────
cat > "$T/fam.icn" <<'EOF'
x
EOF
python3 - "$T" "$DECL_KB" <<'PY' >/dev/null 2>&1
import csv, sys
T, kb = sys.argv[1], sys.argv[2]
with open(T + "/famcsv.csv", "w", newline="") as f:
    w = csv.writer(f, lineterminator="\n")
    w.writerow(["rank","entry","origin","family","kind","xfail","n_lines","heap_kb"])
    w.writerow([1,"e_one","fam__e_one","fam","block",0,3,kb])
    w.writerow([2,"e_two","fam__e_two","fam","block",0,3,""])
PY
e_have=$(python3 -c "
import sys; sys.path.insert(0,'$HERE')
import importlib.util
spec=importlib.util.spec_from_file_location('h','$HERE/corpus_suite_harness.py')
m=importlib.util.module_from_spec(spec)
try:
    spec.loader.exec_module(m)
except SystemExit:
    pass
print(m.heap_sidecar_path('$T/fam.icn'))
" 2>/dev/null)
[ "$e_have" = "$T/fam.heap" ] && ck ok "E1 the harness names a travelling sidecar for an extracted pair ($e_have)" \
  || ck bad "E1 heap_sidecar_path() did not name <stem>.heap beside the pair (got '$e_have')"
# ⛔ UNDER FAIL_ONCE THE SIDECAR IS NOT WRITTEN AT ALL -- that is exactly the pre-column world for an
# extracted pair (extract-family did not carry heap_kb), so E2 must red. Neutering only the SHELL
# reader above would leave this arm green on the Python path and the header's claim that "arms B and E go
# red" would be false about its own mutant, which is the fail-once-that-proves-nothing shape COO-153 found
# three of inside the very mechanism built to disprove it.
[ "${FAIL_ONCE:-0}" = 1 ] || printf '# planted\ne_one\t%s\n' "$DECL_KB" > "$T/fam.heap"
e_read=$(python3 -c "
import sys; sys.path.insert(0,'$HERE')
import importlib.util
spec=importlib.util.spec_from_file_location('h','$HERE/corpus_suite_harness.py')
m=importlib.util.module_from_spec(spec)
try:
    spec.loader.exec_module(m)
except SystemExit:
    pass
d,src=m.heap_declarations('$T/fam.icn')
print('%s|%s' % (d.get('e_one'), 'e_two' in d))
" 2>/dev/null)
[ "$e_read" = "$DECL_KB|False" ] && ck ok "E2 the harness reads the declaration back out of the travelling sidecar ($DECL_KB) and leaves the undeclared entry absent -- a cured seat's standalone run sees the same arena as the board" \
  || ck bad "E2 sidecar read back '$e_read', expected '$DECL_KB|False' -- a declaration would not survive extract-family, so every standalone cure run would silently use the shipped default"

# ── arm G: the PYTHON harness exports at a real run, not merely reads the column ───────────────────────────────
# ⛔⭐ ARMS B AND C PROVE THE SHELL READER; E PROVES THE PYTHON READER CAN READ.  Neither proves that
# corpus_suite_harness.py, which is what grades every rung suite and three of the packages, actually puts the
# value into the environment of the process it runs.  A reader that parses perfectly and threads the value
# nowhere is the exact silent shape this gate was written against, and it would pass A..F.  So arm G runs
# the SAME fixture through run_m3() twice and requires the two verdicts to differ.
g_out=$(python3 - "$T" "$DECL_KB" "$HERE" "$FIX_N" 2>/dev/null <<'PY'
import importlib.util, sys, os
T, kb, HERE = sys.argv[1], int(sys.argv[2]), sys.argv[3]
spec = importlib.util.spec_from_file_location("h", os.path.join(HERE, "corpus_suite_harness.py"))
m = importlib.util.module_from_spec(spec)
try: spec.loader.exec_module(m)
except SystemExit: pass
paths = m.resolve_paths()
want = sys.argv[4]
a = m.run_m3(paths, os.path.join(T, "pkg", "hungry.icn"), want, heap_kb=None).kind
b = m.run_m3(paths, os.path.join(T, "pkg", "hungry.icn"), want, heap_kb=kb).kind
print("%s|%s" % (a, b))
PY
)
case "$g_out" in
  PASS\|PASS) ck bad "G  harness verdicts did not change across the declaration ($g_out) -- heap_kb was parsed and threaded nowhere" ;;
  PASS\|*) ck ok  "G  corpus_suite_harness.py run_m3 verdicts DIFFER across the declaration ($g_out) -- the value reaches the process environment, not just the parser" ;;
  "")      ck bad "G  the harness could not be exercised at all (no output) -- the export is unmeasured, which is not the same as working" ;;
  *)       ck bad "G  harness verdicts did not change across the declaration ($g_out) -- heap_kb was parsed and threaded nowhere" ;;
esac

# ── arm H: a STANDALONE program (a benchmark) declares through the <stem>.heap sidecar beside it ───────────────
# ⭐ (coo 2026-09-23, row instruments-benchmarks-enter-the-suite-grid-...): a benchmark tree has no ALL.csv, so its runners read
# the harness's own sidecar through declared_arena_kb_beside, which CALLS heap_declarations(). H1 requires the verdict to DIFFER
# across the declaration, as B does; H2 requires a bare number to be REFUSED, because the harness reads `16384` with no name as
# an absent declaration and a runner would then grade the program at the shipped default while the file claimed otherwise.
mkdir -p "$T/solo" "$T/solo2" && cp "$T/pkg/hungry.icn" "$T/solo/hungry.icn" && cp "$T/pkg/hungry.icn" "$T/solo2/hungry.icn"
printf 'hungry\t%s\n' "$DECL_KB" > "$T/solo/hungry.heap"
h_kb=$(declared_arena_kb_beside "$T/solo/hungry.icn" 2>/dev/null); h_rc=0
( cd "$T/solo" && if [ -n "$h_kb" ]; then export SCRIP_HEAP_CAP_KB="$h_kb"; fi
  env -u SCRIP_HEAP_MB -u SCRIP_HEAP_KB -u SCRIP_HEAP_MAX_MB timeout -k 5 60s "$ROOT/scrip" --run hungry.icn >/dev/null 2>"$T/h1.err" ) || h_rc=$?
[ "$h_rc" != 124 ] || refuse "arm H1 TIMED OUT (rc=124) -- the ceiling fired, so this run cannot say whether the sidecar was honoured"
[ "$h_rc" -ge 1 ] && [ "$h_rc" -lt 128 ] && grep -q "(the GC heap's hard cap is ${DECL_KB} KB, -d;" "$T/h1.err" && ck ok "H1 a standalone program's hungry.heap (hungry TAB $DECL_KB) is read beside it and the run ends in the out-of-memory report at that cap (rc=$h_rc) where the shipped default completes rc=$base_rc" \
  || ck bad "H1 the standalone program read rc=$h_rc (sidecar read '$h_kb') without the report naming its ${DECL_KB} KB cap -- its .heap sidecar was not honoured"
printf '%s\n' "$DECL_KB" > "$T/solo2/hungry.heap"
declared_arena_kb_beside "$T/solo2/hungry.icn" >/dev/null 2>"$T/bare.err"; h2=$?
[ "$h2" = 2 ] && grep -q 'declares no heap for hungry.icn' "$T/bare.err" && ck ok "H2 a bare-number .heap sidecar is REFUSED rc=2 by name -- never read as 'no declaration'" \
  || ck bad "H2 a bare-number .heap sidecar returned rc=$h2 -- the declaration would vanish silently while the file claimed it"
h3=$(declared_arena_kb_beside "$T/pkg/frugal.icn"); h3_rc=$?
[ "$h3_rc" = 0 ] && [ -z "$h3" ] && ck ok "H3 a program with no sidecar reads nothing (rc=0): the shipped default, not an error" \
  || ck bad "H3 a program with no sidecar read '$h3' rc=$h3_rc"

# ── arm S: THE STACK, THE HEAP'S TWIN (CEO-1225, the coo 2026-09-23) ─────────────────────────────────────────────────────────
# The runtime raises RLIMIT_STACK at init to SCRIP_STACK when set, else to its 64 MB floor (core.c), in BOTH modes. The witness:
# a DEPTH-deep Icon recursion dies with ERROR 246 at the default floor and completes at STK_KB; its neighbour (half as deep)
# completes at the default and dies at 16384k -- the measurement behind the floor rule: SCRIP_STACK REPLACES the floor, so a cell
# below it SHRINKS the stack. A timeout is a refusal here too, never a verdict.
stko="$ROOT/src/runtime/rt/rt_stack_overflow.c"; [ -f "$stko" ] || refuse "no $stko to read the default stack back out of"
c_def=$(sed -n 's/^#define[[:space:]]\+RT_STACK_DEFAULT_BYTES[[:space:]]\+(\([0-9]\+\)L \* 1024L \* 1024L).*/\1/p' "$stko" | head -1)
[ -n "$c_def" ] || refuse "could not read RT_STACK_DEFAULT_BYTES out of $stko -- the drift alarm cannot be armed"
c_flr_kb=$((c_def * 1024))
[ "$c_flr_kb" = 4096 ] && grep -q "^GC_STACK_FLOOR_KB = 4 \* 1024 " "$HERE/corpus_suite_harness.py" && grep -q "^GC_STACK_KB_MIN = $DECLARED_STACK_FLOOR_KB " "$HERE/corpus_suite_harness.py" \
  && ck ok "A4 the default stack copied into corpus_suite_harness.py (GC_STACK_FLOOR_KB) matches rt_stack_overflow.c's RT_STACK_DEFAULT_BYTES ($c_flr_kb KB, SPITBOL's -s4m), and the least declarable stack ($DECLARED_STACK_FLOOR_KB KB) is one number in the lib and the harness" \
  || ck bad "A4 stack drift: rt_stack_overflow.c ${c_flr_kb} KB, lib least $DECLARED_STACK_FLOOR_KB -- a copied runtime constant moved"
STK_KB=262144; DEPTH=200000
mkdir -p "$T/stk"
printf 'procedure f(n);\n   if n = 0 then return 0;\n   return 1 + f(n - 1);\nend\nprocedure main();\n   write(f(%d));\nend\n' "$DEPTH" > "$T/stk/deep.icn"
printf 'procedure f(n);\n   if n = 0 then return 0;\n   return 1 + f(n - 1);\nend\nprocedure main();\n   write(f(%d));\nend\n' $((DEPTH / 25)) > "$T/stk/shallow.icn"
printf 'rank,entry,origin,package,n_lines,stdin,want_rc,heap_kb,stack_kb\n1,deep,p__deep,p,7,0,0,,%s\n2,shallow,p__shallow,p,7,0,0,,\n' "$STK_KB" > "$T/stk/ALL.csv"
runstk() { ( cd "$T/stk" && env -u SCRIP_STACK -u SCRIP_HEAP_KB -u SCRIP_HEAP_MB "$@" timeout -k 5 60s "$ROOT/scrip" --run "$STK_PROG" </dev/null >/dev/null 2>"$T/stk/err" ); }
STK_PROG=deep.icn; runstk; s_base=$?; grep -q 'ERROR 246' "$T/stk/err"; s_base246=$?
STK_PROG=deep.icn; runstk SCRIP_STACK="${STK_KB}k"; s_decl=$?
[ "$s_base" != 124 ] && [ "$s_decl" != 124 ] || refuse "the stack witness TIMED OUT (rc=124) -- a ceiling is not a stack verdict (load: $(uptime | sed 's/.*load average: //'))"
[ "$s_base246" = 0 ] || refuse "the stack witness at the default did not die with ERROR 246 (rc=$s_base) -- it no longer overflows the ${c_flr_kb} KB default, so it witnesses nothing; deepen it"
[ "$s_decl" = 0 ] || refuse "the stack witness does not complete even at ${STK_KB} KB (rc=$s_decl) -- the declaration cannot be shown to buy anything"
echo "  STACK PREMISE MEASURED: deep.icn (depth $DEPTH) rc=$s_base with ERROR 246 at the ${c_flr_kb} KB default, rc=$s_decl at SCRIP_STACK=${STK_KB}k"
s1=0; ( cd "$T/stk" && run_at_declared_arena "$T/stk/ALL.csv" deep -- env -u SCRIP_HEAP_KB timeout -k 5 60s "$ROOT/scrip" --run deep.icn </dev/null >/dev/null 2>&1 ) || s1=$?
[ "$s1" != 124 ] || refuse "arm S1 TIMED OUT (rc=124)"
[ "$s1" = 0 ] && ck ok "S1 the stack_kb=${STK_KB} entry COMPLETES through the runner's reader (rc=0) where it dies at the ${c_flr_kb} KB default (rc=$s_base, ERROR 246)" \
  || ck bad "S1 the stack_kb entry still fails through the runner's reader (rc=$s1) -- the stack declaration was not exported"
s2=$(run_at_declared_arena "$T/stk/ALL.csv" shallow -- bash -c 'echo "[${SCRIP_STACK:-UNSET}]"')
[ "$s2" = "[UNSET]" ] && ck ok "S2 the undeclared neighbour sees SCRIP_STACK UNSET -- the stack export is per program" \
  || ck bad "S2 the undeclared neighbour saw SCRIP_STACK=$s2 -- a stack declaration leaked over the loop"
STKBAD=$((DECLARED_STACK_FLOOR_KB / 2))
printf 'rank,entry,origin,package,n_lines,stdin,want_rc,heap_kb,stack_kb\n1,deep,p__deep,p,7,0,0,,%s\n' "$STKBAD" > "$T/stk/BAD.csv"
declared_stack_kb "$T/stk/BAD.csv" deep >/dev/null 2>"$T/stk/bad.err"; s3=$?
[ "$s3" = 2 ] && grep -q 'least stack a declaration may name' "$T/stk/bad.err" && ck ok "S3 stack_kb=$STKBAD (below the ${DECLARED_STACK_FLOOR_KB} KB least declarable stack) is REFUSED rc=2, naming why" \
  || ck bad "S3 stack_kb=$STKBAD returned rc=$s3 -- a stack no program can run on was accepted"
STK_PROG=shallow.icn; runstk; s4a=$?; STK_PROG=shallow.icn; runstk SCRIP_STACK=256k; s4b=$?; grep -q 'ERROR 246' "$T/stk/err"; s4b246=$?
[ "$s4a" != 124 ] && [ "$s4b" != 124 ] || refuse "arm S4 TIMED OUT (rc=124)"
[ "$s4a" = 0 ] && [ "$s4b" != 0 ] && [ "$s4b246" = 0 ] && ck ok "S4 a declaration BELOW the default is a setting and is honoured as given: the depth-$((DEPTH / 25)) witness completes at the ${c_flr_kb} KB default and dies with ERROR 246 at SCRIP_STACK=256k (CEO-1261 retired the floor rule this arm used to hold)" \
  || ck bad "S4 the stack budget does not follow a smaller declaration (depth $((DEPTH / 25)): default rc=$s4a, 256k rc=$s4b) -- the runtime no longer honours SCRIP_STACK as the program's stack"
s5=$(python3 - "$T/stk" "$STK_KB" "$HERE" "$DEPTH" 2>/dev/null <<'PY'
import importlib.util, sys, os
T, kb, HERE, want = sys.argv[1], int(sys.argv[2]), sys.argv[3], sys.argv[4]
spec = importlib.util.spec_from_file_location("h", os.path.join(HERE, "corpus_suite_harness.py"))
m = importlib.util.module_from_spec(spec)
try: spec.loader.exec_module(m)
except SystemExit: pass
paths = m.resolve_paths()
a = m.run_m3(paths, os.path.join(T, "deep.icn"), want, stack_kb=None).kind
b = m.run_m3(paths, os.path.join(T, "deep.icn"), want, stack_kb=kb).kind
print("%s|%s" % (a, b))
PY
)
case "$s5" in
  PASS\|*) ck bad "S5 the harness read $s5 -- the witness PASSES at the default under run_m3, so this arm proves nothing" ;;
  *\|PASS) ck ok  "S5 corpus_suite_harness.py run_m3 verdicts DIFFER across stack_kb ($s5) -- the stack reaches the process, not just the parser" ;;
  "")      ck bad "S5 the harness could not be exercised (no output)" ;;
  *)       ck bad "S5 harness verdicts did not change across stack_kb ($s5)" ;;
esac
mkdir -p "$T/stk2" && cp "$T/stk/deep.icn" "$T/stk2/deep.icn" && printf 'deep\t%s\n' "$STK_KB" > "$T/stk2/deep.stack"
s6=$(declared_stack_kb_beside "$T/stk2/deep.icn" 2>/dev/null); printf '%s\n' "$STK_KB" > "$T/stk2/deep.stack"; declared_stack_kb_beside "$T/stk2/deep.icn" >/dev/null 2>&1; s6b=$?
[ "$s6" = "$STK_KB" ] && [ "$s6b" = 2 ] && ck ok "S6 a standalone program's deep.stack (deep TAB $STK_KB) is read beside it, and a bare-number .stack is REFUSED rc=2" \
  || ck bad "S6 the .stack sidecar read '$s6' (want $STK_KB) and a bare number returned rc=$s6b (want 2)"

# ── arm T: THE ONE-READ TABLE the package runners grade through (CEO-1229, the coo 2026-09-23) ─────────────────────────────
# declared_memory_table / declared_memory_begin / run_at_declared_table (lib_declared_arena.sh): the harness's own validators, one
# python start per suite and one awk per run, because run_at_declared_arena's two python starts per run are over a minute of a
# 427-program board in two modes. T2 drives a REAL run through the table. T5 is the defect the table's first cut shipped to itself
# and its own refusal arm caught: handed any file, heap_declarations() read the ALL.csv BESIDE it.
mkdir -p "$T/tbl"
printf 'rank,entry,origin,package,n_lines,stdin,want_rc,heap_kb,stack_kb\n1,a,p__a,p,1,0,0,%s,\n2,b,p__b,p,1,0,0,,262144\n3,c,p__c,p,1,0,0,,\n' "$DECL_KB" > "$T/tbl/ALL.csv"
declared_memory_begin "$T/tbl/ALL.csv" "$T/tbl/t.tsv" >/dev/null 2>&1; t1rc=$?
t1=""; for e in a b c; do t1="$t1$(run_at_declared_table "$T/tbl/t.tsv" "$e" -- bash -c 'printf "%s=[%s|%s] " "$0" "${SCRIP_HEAP_CAP_KB:-}" "${SCRIP_STACK:-}"' "$e" 2>/dev/null)"; done
[ "$t1rc" = 0 ] && [ "$t1" = "a=[$DECL_KB|] b=[|262144k] c=[|] " ] && [ -z "${SCRIP_HEAP_CAP_KB:-}${SCRIP_STACK:-}" ] \
  && ck ok "T1 the table exports each entry's own heap and stack and nothing else (a heap only, b stack only, c neither), and nothing leaks into the caller" \
  || ck bad "T1 the table exported '$t1' (begin rc=$t1rc) -- want 'a=[$DECL_KB|] b=[|262144k] c=[|] '"
t2=0; { declared_memory_begin "$T/pkg/ALL.csv" "$T/tbl/pkg.tsv" >/dev/null 2>"$T/t2.err" && ( cd "$T/pkg" && run_at_declared_table "$T/tbl/pkg.tsv" hungry -- env -u SCRIP_HEAP_MB -u SCRIP_HEAP_KB -u SCRIP_HEAP_MAX_MB timeout -k 5 60s "$ROOT/scrip" --run hungry.icn >/dev/null 2>"$T/t2.err" ); } || t2=$?
[ "$t2" != 124 ] || refuse "arm T2 TIMED OUT (rc=124) -- a ceiling is not a verdict"
[ "$t2" -ge 1 ] && [ "$t2" -lt 128 ] && grep -q "(the GC heap's hard cap is ${DECL_KB} KB, -d;" "$T/t2.err" && ck ok "T2 the declared entry ends in the out-of-memory report at its ${DECL_KB} KB cap through the table (rc=$t2) where it completes rc=$base_rc at the shipped default -- the runners' path carries the declaration to a real run" \
  || ck bad "T2 the declared entry read rc=$t2 through the table without the report naming its ${DECL_KB} KB cap -- heap_kb=${DECL_KB} did not reach the run"
t3=""; n3=0
for bad in "1,a,p__a,p,1,0,0,$BADKB," "1,a,p__a,p,1,0,0,,$STKBAD" "1,a,p__a,p,1,0,0,$DECL_KB,
2,a,p__a,p,1,0,0,$FIT_KB,"; do
  n3=$((n3+1)); printf 'rank,entry,origin,package,n_lines,stdin,want_rc,heap_kb,stack_kb\n%s\n' "$bad" > "$T/tbl/bad.csv"; echo stale > "$T/tbl/bad.tsv"
  declared_memory_begin "$T/tbl/bad.csv" "$T/tbl/bad.tsv" >/dev/null 2>&1; r=$?
  { [ "$r" = 2 ] && [ ! -f "$T/tbl/bad.tsv" ]; } || t3="$t3 case$n3(rc=$r)"
done
[ -z "$t3" ] && ck ok "T3 a heap cell below the window, a stack cell below the least declarable stack and an entry declared twice differently each REFUSE rc=2 and leave no table for a run to use" \
  || ck bad "T3 a refused cell was accepted:$t3 (1 heap $BADKB, 2 stack $STKBAD, 3 an entry declared $DECL_KB and $FIT_KB)"
run_at_declared_table "$T/tbl/no_such_table.tsv" a -- true 2>/dev/null; t4=$?
[ "$t4" = 2 ] && ck ok "T4 a run with no table REFUSES rc=2 -- a runner that never built its table cannot grade at the default under a receipt naming declarations" \
  || ck bad "T4 run_at_declared_table without a table returned rc=$t4, want 2"
printf 'rank,entry,origin,package,n_lines,stdin,want_rc,heap_kb,stack_kb\n1,a,p__a,p,1,0,0,,\n' > "$T/tbl/ALL.csv"
printf 'rank,entry,origin,package,n_lines,stdin,want_rc,heap_kb,stack_kb\n1,a,p__a,p,1,0,0,%s,\n' "$DECL_KB" > "$T/tbl/OTHER.csv"
t5="$(declared_memory_table "$T/tbl/OTHER.csv" 2>/dev/null)"
[ "$t5" = "$(printf 'a\t%s\t' "$DECL_KB")" ] && ck ok "T5 the table reads the FILE IT IS HANDED -- OTHER.csv's heap_kb=$DECL_KB, not the undeclared ALL.csv beside it" \
  || ck bad "T5 the table of OTHER.csv read '$t5' -- it read something other than the file it was handed"

# ── arm R: EVERY PACKAGE RUNNER READS THE DECLARATION (CEO-1229: "wire the ten remaining package runners yourself on the SWI pattern,
# each proven on a fixture") ────────────────────────────────────────────────────────────────────────────────────────────
# STRUCTURAL, AND NAMED AS SUCH: it holds each runner's wiring against a later edit that drops it -- every one was PROVEN on a
# fixture by the coo 2026-09-23 (a declared entry passes, the same entry emptied fails, a refused cell refuses; the receipts are in
# the row's baton) -- and it cannot show that the wiring works; arms B, S and T do that.
r_miss=""; r_n=0
need() { local f="$HERE/$1" c; r_n=$((r_n+1)); [ -f "$f" ] || { r_miss="$r_miss $1(missing)"; return; }; c=$(grep -c -- "$3" "$f"); [ "$c" -ge "$4" ] || r_miss="$r_miss $1($2: $c of $4)"; }
for r in test_snobol4_dotnet_suite.sh test_snobol4_spitbol_testpgms_suite.sh test_snobol4_csnobol4_suite.sh test_snoflake_suite.sh test_snobol4_spitbol_x64_suite.sh test_prolog_gnu_suite.sh test_pascal_fpc_suite.sh test_pascal_wirth76_suite.sh test_pascal_pat_suite.sh; do
  need "$r" begin 'declared_memory_begin "\$[A-Z_]*/ALL.csv"' 1; need "$r" runs 'run_at_declared_table "\$DECL"' 2
done
need scorecard_snobol4.sh table 'sc_decl_build' 3; need scorecard_snobol4.sh runs 'run_at_declared_table "\$SC_DECL"' 2
need test_snobol4_gimpel_suite.sh through-the-scorecard 'scorecard_snobol4.sh" run --suites gimpel' 1
need test_snobol4_aisnobol_suite.sh through-the-harness 'corpus_suite_harness.py run "\$SUITE/ALL.sno"' 1
# ⭐ INRIA AND THE LOGTALK GRADER PASS THE DECLARATION AS SWITCHES (the coo 2026-09-28, CEO-1353/1355: both handed the declared heap to
# SCRIP_HEAP_KB, the collector's initial WINDOW, and the stack to SCRIP_STACK): -d<kb>k -s<kb>k after --run in m3, leading the binary in m4.
need test_prolog_inria_suite.sh begin 'declared_memory_begin "\$SUITE/ALL.csv"' 1
need test_prolog_inria_suite.sh m3-switches '"--run"\] + decl_sw(_tidx, fam) + \[prog\]' 2; need test_prolog_inria_suite.sh m4-switches '\[b\] + decl_sw(_tidx, fam)' 2
need test_prolog_logtalk_suite.sh begin 'declared_memory_begin "\$SUITE/ALL.csv"' 1; need test_prolog_logtalk_suite.sh hands-it-over '--decl "\$_decl"' 1
need util_logtalk_grade.py per-case 'sw=decl_switches(decl' 2
need util_logtalk_grade.py m3-switches '\[scrip, "--run"\] + list(sw) + \[prog\]' 1; need util_logtalk_grade.py m4-switches '\[b_out\] + list(sw)' 1
need test_prolog_swi_suite.sh runs 'run_at_declared_arena "\$SWIT/ALL.csv"' 2
# ⭐ THE THREE ICON PACKAGE RUNNERS PASS THE DECLARATION AS SWITCHES (ceo CEO-1353, the coo's census): declared_arena_switches reads both
# cells, and the words ride the m3 command line after --run and the compile args and lead the m4 binary's arguments -- never SCRIP_HEAP_KB.
for r in test_icon_arizona_suite.sh test_icon_ipl_suite.sh test_icon_jcon_suite.sh; do need "$r" heap+stack declared_arena_switches 1; need "$r" m3-switches '--run \$_ca \$_sw ' 1; done
need test_icon_arizona_suite.sh m4-switches '"\$name" \$_sw ' 1; need test_icon_ipl_suite.sh m4-switches '"\$bin4" \$_sw' 2; need test_icon_jcon_suite.sh m4-switches '"\$name" \${_sw4\[@\]' 1
[ -z "$r_miss" ] && ck ok "R  every package runner reads the declared heap and stack ($r_n wiring points across 17 runners and graders: the eight SNOBOL4, Prolog and Pascal loops, the scorecard behind gimpel, the harness behind aisnobol, inria, logtalk and its grader, SWI, and the three Icon runners)" \
  || ck bad "R  a runner lost its wiring:$r_miss"

# ── arm O: A PROPERLY REPORTED OUT-OF-MEMORY IS ITS OWN OUTCOME, RECORDED WITH THE HEAP IT RAN UNDER (CEO-1229 (2)) ───────────
# ⭐⭐ The ceo on this row, 2026-09-23 20:2x, verbatim: "THE PROGRESS WORD IS OOM: a run that ends in a properly reported out-of-memory
# at the heap it ran under, recorded with that heap. It is not PASS and it is not FAIL or CRASH ... the harness lists every OOM program
# by name". The runtime's report is the cto's (dc739c38a). This arm grades the HARNESS end to end on a four-entry Icon suite under
# mktemp (a fixture, never a board, CEO-547; its own scratch progress table): O1 an entry past its DECLARED heap and an undeclared
# one past the shipped cap each read OOM in m3 AND m4, the progress row naming the cap the runtime reported -- the declared heap for
# the first, the shipped cap for the second; O2 THE NEGATIVE CONTROL, an rc=1 wrong answer with no report reads FAIL, and the entry
# that fits its declaration reads PASS -- a classifier that called every rc=1 an OOM, or that ate the declaration, reds here;
# O3 the SUITE_BOARD line keeps each OOM INSIDE <m>_fail and prints <m>_fail_oom beside it (the boards that read that line take
# fail+crash as their red, so an OOM folded out of fail would read green to each of them); O4 OOM_PROGRAMS names each with its cap.
# ⛔ One-line programs: SCRIP's Icon parser refuses a statement that begins a new line after `L := list()` where icont accepts it
# (the cto's report to hq_icon, dc739c38a), and a fixture that does not compile would read FAIL for a reason this arm is not about.
# ⛔ FAIL-ONCE, MEASURED 2026-09-24 by the coo: this arm run against origin 8b6cb3607's harness (no OOM verdict) reds O1, O3 and O4
# and keeps O2 green -- the negative control has nothing to catch on a harness that never says OOM, which is its job, not a gap.
OVER_KB=8192
BIG_N=$((rt_cap / 32 + 200))
[ $((2 * FIX_N * 32)) -gt "$OVER_KB" ] || refuse "arm O's over-declared witness (2 x $FIX_N blocks of 32 KB) no longer exceeds its ${OVER_KB} KB declaration -- grow FIX_N or re-derive OVER_KB"
[ $((BIG_N * 32)) -gt "$rt_cap" ] || refuse "arm O's undeclared witness ($BIG_N blocks of 32 KB) no longer exceeds the ${rt_cap} KB shipped cap"
mkdir -p "$T/oom/tests/icon"
python3 - "$T/oom/tests/icon" "$HERE" "$FIT_KB" "$OVER_KB" "$FIX_N" "$BIG_N" <<'PY2' || refuse "arm O could not write its fixture suite"
import sys
sys.path.insert(0, sys.argv[2])
import corpus_suite_harness as h
d, kb, over, n, big = sys.argv[1], sys.argv[3], sys.argv[4], int(sys.argv[5]), int(sys.argv[6])
grow = 'procedure main(); L := list(); every i := 1 to %d do put(L, repl("x", 32768)); write(*L); end'
ents = [("fits_declared", grow % n, str(n), kb), ("over_declared", grow % (2 * n), str(2 * n), over),
        ("hungry_undeclared", grow % big, str(big), ""), ("wrong_answer", 'procedure main(); write("a"); stop("boom"); end', "b", "")]
src, ref, csv = [], [], ["rank,entry,origin,family,kind,xfail,n_lines,modes,heap_kb,stack_kb"]
for i, (name, prog, want, decl) in enumerate(ents, 1):
    b = h.make_banner_cfg(i, name, "#", "")
    src += [b, prog]; ref += [b, want]
    csv.append('%d,%s,fx__%s,fx,block,0,1,"m3,m4",%s,' % (i, name, name, decl))
for ext, lines in (("icn", src), ("ref", ref), ("csv", csv)):
    with open("%s/ALL.%s" % (d, ext), "w") as f:
        f.write("\n".join(lines) + "\n")
PY2
o_env=(env -u SCRIP_HEAP_KB -u SCRIP_HEAP_MB -u SCRIP_HEAP_CAP_KB -u SCRIP_HEAP_MAX_MB -u RT_OPT)
for v in $(env | sed -n 's/^\(SCRIP_GC[A-Z0-9_]*\)=.*/\1/p'); do o_env+=(-u "$v"); done
o_out="$("${o_env[@]}" S4E_PROGRESS_DB="$T/oom/db.tsv" timeout -k 5 300 python3 "$HERE/corpus_suite_harness.py" run "$T/oom/tests/icon/ALL.icn" "$T/oom/tests/icon/ALL.ref" --lang icon --modes m3,m4 2>/dev/null)"; o_rc=$?
[ "$o_rc" != 124 ] || refuse "arm O's harness run TIMED OUT (rc=124) -- a ceiling is not a verdict (load: $(uptime | sed 's/.*load average: //'))"
[ "$o_rc" = 1 ] || refuse "arm O's harness run exited rc=$o_rc, not the rc=1 a board with non-PASS entries ends in -- it could not grade the fixture"
[ -s "$T/oom/db.tsv" ] || refuse "arm O's harness run appended no progress rows to its scratch table -- nothing to grade"
o_row() { awk -F'\t' -v p="$1" -v m="$2" 'NR==1{for(i=1;i<=NF;i++)c[$i]=i;next} $c["program"]==p && $c["mode"]==m {print $c["outcome"] "|" $c["note"]}' "$T/oom/db.tsv" | tail -1; }
o1=""; for m in m3 m4; do
  r="$(o_row over_declared $m)"; case "$r" in OOM\|*heap_cap_kb=${OVER_KB}\ *|OOM\|*heap_cap_kb=${OVER_KB}) ;; *) o1="$o1 over_declared/$m=[$r]";; esac
  r="$(o_row hungry_undeclared $m)"; case "$r" in OOM\|*heap_cap_kb=${rt_cap}\ *|OOM\|*heap_cap_kb=${rt_cap}) ;; *) o1="$o1 hungry_undeclared/$m=[$r]";; esac
done
[ -z "$o1" ] && ck ok "O1 a program past its declared ${OVER_KB} KB and one past the shipped ${rt_cap} KB cap each read OOM in m3 and m4, the progress row carrying heap_cap_kb= the cap the runtime reported" \
  || ck bad "O1 an out-of-memory run was not recorded as OOM with its heap:$o1"
o2=""; for m in m3 m4; do
  r="$(o_row wrong_answer $m)"; [ "${r%%|*}" = FAIL ] || o2="$o2 wrong_answer/$m=[$r]"
  r="$(o_row fits_declared $m)"; [ "${r%%|*}" = PASS ] || o2="$o2 fits_declared/$m=[$r]"
done
[ -z "$o2" ] && ck ok "O2 NEGATIVE CONTROL: an rc=1 wrong answer with no out-of-memory report reads FAIL, and the entry that fits its ${FIT_KB} KB declaration reads PASS, in both modes" \
  || ck bad "O2 the classifier reached past the runtime's report:$o2"
o_board="$(grep -m1 '^SUITE_BOARD ' <<<"$o_out")"
o_f() { sed -n "s/.* $1=\([0-9]*\).*/\1/p" <<<"$o_board"; }
[ "$(o_f m3_fail)" = 3 ] && [ "$(o_f m4_fail)" = 3 ] && [ "$(o_f m3_fail_oom)" = 2 ] && [ "$(o_f m4_fail_oom)" = 2 ] \
  && ck ok "O3 the SUITE_BOARD line keeps each OOM inside fail and splits it out beside it (m3_fail=3 m3_fail_oom=2, m4_fail=3 m4_fail_oom=2)" \
  || ck bad "O3 the SUITE_BOARD line reads m3_fail=$(o_f m3_fail) m3_fail_oom=$(o_f m3_fail_oom) m4_fail=$(o_f m4_fail) m4_fail_oom=$(o_f m4_fail_oom), want 3/2 in each mode"
o_list="$(grep -m1 '^OOM_PROGRAMS ' <<<"$o_out")"
case "$o_list" in *" n=4: "*"over_declared m3 cap=${OVER_KB}KB"*"over_declared m4 cap=${OVER_KB}KB"*"hungry_undeclared m3 cap=${rt_cap}KB"*"hungry_undeclared m4 cap=${rt_cap}KB"*)
  ck ok "O4 OOM_PROGRAMS names each out-of-memory program by name, mode and the cap it ran under (n=4)" ;;
  *) ck bad "O4 OOM_PROGRAMS does not name the four out-of-memory runs with their caps: [$(cut -c1-220 <<<"${o_list:-no OOM_PROGRAMS line}")]" ;;
esac

# ── arm F: every shipped attribute file carries the column ─────────────────────────────────────────────────────
CORPUS="${S4E_HOME:-$(cd "$ROOT/.." && pwd)}/corpus"
miss=0; tot=0
for f in "$CORPUS"/tests/*/ALL.csv "$CORPUS"/packages/*/*/ALL.csv; do
  [ -f "$f" ] || continue
  tot=$((tot+1)); h1="$(head -1 "$f")"; case "$h1" in *,heap_kb,stack_kb*) ;; *) miss=$((miss+1)); echo "     NO heap_kb,stack_kb: $f";; esac
done
[ "$tot" -gt 0 ] || refuse "found no attribute files under $CORPUS -- cannot measure the population"
[ "$miss" = 0 ] && ck ok "F  all $tot shipped attribute file(s) carry the heap_kb and stack_kb columns, side by side (each converted in ONE landing, so no runner can read a file that lacks one)" \
  || ck bad "F  $miss of $tot attribute file(s) lack the heap_kb,stack_kb columns"

echo "GATE $G: $checks check(s), $fails failure(s) -- population: $tot attribute file(s); heap: 1 planted declared entry, 1 planted neighbour, arena ${DECL_KB} KB vs shipped default (cap ${rt_cap} KB, floor ${rt_flr} KB); stack: a depth-$DEPTH witness at ${STK_KB} KB vs the runtime's ${c_flr_kb} KB floor; OOM: a 4-entry suite through the harness in m3 and m4 (one past its ${OVER_KB} KB declaration, one past the ${rt_cap} KB cap, one fitting ${DECL_KB} KB, one rc=1 wrong answer)"
[ "$fails" = 0 ] || exit 1
exit 0
