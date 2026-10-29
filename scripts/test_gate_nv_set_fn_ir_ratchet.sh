#!/bin/bash
# test_gate_nv_set_fn_ir_ratchet.sh -- the DONE-WHEN of row perf-nv-set-fn-o0-overhead (item 3).
#
# ⭐ WHAT ITEM 3 IS: scope + land a cure for the variable-STORE fast path, or rule it explicitly not worth doing. Items 1 and 2 are CLOSED (item 1 by seat07, 100% of the then-50,492,413 Ir
# attributed; item 2 by seat01, the memo cache is a decisive -O0 win). This gate ratchets the store family's Ir so "a cure landed" becomes a measurement instead of a claim.
#
# ✅⭐⭐ THE RECIPE GAP IS CLOSED (hq_P 2026-09-04, measured). THIS GATE NOW GRADES THE QUANTITY THE ROW ACTUALLY NAMES. The previous revision profiled the COMMITTED roman.sno in mode-3 and pinned
# 122,092 Ir -- an honest number of the WRONG QUANTITY, and it said so in its own header. The committed program runs K = 1001..1010 (TEN iterations), so a direct callgrind of it totals ~35.6M Ir and is
# COMPILE-DOMINATED (__strcmp_avx2 12.65%, bb_emit_x86 8.80%): it profiles the COMPILER, not the roman kernel. THE SCALED RECIPE IS RECOVERED AND IS NOW EXECUTED BELOW -- it was never lost, only
# unrecorded: the row's GOAL line said "Measured N=20000, mode-4" all along, and the *BENCH marker at roman.sno:24 (kernel=ROMAN_RUN check=200 bud=500 flr=20) is what makes N reachable.
# ⭐ RECIPE, VERIFIED REPRODUCIBLE TO THE INSTRUCTION (two runs, bit-identical), ~5 s wall:
#     bench_wrap.sh roman.sno --mode=iter --n=20000   ->   scrip --compile   ->   gcc -no-pie + libscrip_rt.so   ->   valgrind --tool=callgrind on THE BINARY
# ⛔ --mode=iter, NOT --mode=time: a wall-clock deadline under callgrind measures the INSTRUMENT's throughput, not the kernel's (FINDING-2026-08-22-bench-harness-unmeasurable).
# ⛔ MODE-4, NOT MODE-3: mode-3 profiles compiler + kernel in one process, so ~67.5M Ir of compile swamps the signal. Mode-4 profiles the linked binary, where compilation has already happened.
# ⛔ N=20000 IS PART OF THE PIN, NOT A TUNABLE. Changing it invalidates the number. The scale is NOT arbitrary: it is the scale the row's own figures were taken at, confirmed by reproducing the
# published kernel total to within 0.02% (predicted 353,539,093 vs the row's 353,472,366).
# ⛔⛔ AND ROMAN IS **NONLINEAR** IN N, SO A SLOPE IS NOT AVAILABLE HERE AND bench_ir_slope.sh WOULD CORRECTLY PRINT `NONLINEAR`. Measured mode-4 store-family slopes: 588 Ir/iter over N=5000..10000
# vs 700 Ir/iter over N=10000..20000, a 19% divergence. The cause is in the kernel's own definition, not in the instrument: ROMAN_RUN(N) converts 1000+1 .. 1000+N, so the integers -- and therefore
# the numerals, and therefore the work per conversion -- GROW WITH N. That is why this row pins a TOTAL AT FIXED WORK and why N is part of the pin. (RULES.md § FACT RULES: a SLOPE is not a TOTAL.)
#
# ⛔⛔⭐ WHY THE PIN IS A **FAMILY SUM** AND NOT `core.c:NV_SET_fn` -- THIS IS THE LOAD-BEARING CORRECTION, AND IT IS NOT HYPOTHETICAL; IT ALREADY HAPPENED ONCE.
# At SCRIP 702e2d162 ("NV_CELL_IF_FASTSET_fn: one admission funnel for direct-cell stores") the FAST-PATH STORE -- which is precisely what item 3 targets -- WAS SPLIT OUT of NV_SET_fn into its own
# function. NV_SET_fn now CALLS it (17,628,085 Ir inclusive, 183,613x at N=20000). So the bare symbol's flat Ir fell 46,453,125 -> 12,853,648 (3.6x) WITH NO CURE TO THE COST CENTRE THIS ROW OWNS:
# the cost MOVED, it did not go away. A ratchet on the bare symbol would have read that refactor as a 3.6x win and invited a re-pin celebrating it.
# ⭐ THE GENERAL SHAPE, WHICH IS WHY THIS COMMENT IS LONG: AN ACCEPTANCE TEST A **REFACTOR** CAN SATISFY TESTS THE SPELLING, NOT THE MACHINE. It is the same defect hq_B caught on the sibling Prolog
# row, where `grep -c plc_ = 0` was closable by renaming ~200 refs of must-survive code. Here the refactor was innocent and useful (it cured two oracle-graded wrong answers) -- which is the point:
# NOBODY HAS TO BE GAMING THE GATE FOR A SYMBOL-KEYED PIN TO GO QUIETLY WRONG.
# ⭐ THE FAMILY IS THEREFORE EVERY FLAT BUCKET OF THE STORE PATH, SUMMED: core.c:NV_SET_fn + core.c:NV_CELL_IF_FASTSET_fn + the two DWARF-keyed inlined bodies (rt_protected.h:NV_SET_fn, the
# protected-pattern guard; gc_heap.h:NV_SET_fn, the write barrier). Summing by regex is deterministic and is robust to buckets appearing or merging. ⛔ Flat, NOT inclusive: `--inclusive=yes` prints
# TWO entries for NV_SET_fn (one keyed by absolute path, one by the .so) and a pin cannot choose between them without double-counting.
# ⛔ IF A FUTURE PASS SPLITS MORE WORK INTO A **NEW** HELPER, THIS FAMILY LIST MUST GROW IN THE SAME COMMIT -- the PASS path below says so out loud, because that is exactly when it will be ignored.
set -u
R="${S4E_HOME:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"   # D-17 PORTABLE-HOME: the SEAT ROOT is derived from THIS script, never a hardcoded seat (hq_C measured 2026-09-02: the old /home/claude_P default graded hq_P's checkout from hq_C's seat)

PIN=29103103        # store family, mode-4, N=20000, -O0. Measured hq_P 2026-09-04, SCRIP ae9ebfc20. Bit-identical across two runs. Breakdown: NV_SET_fn 12,853,648 + NV_CELL_IF_FASTSET_fn 12,944,539 + rt_protected.h 2,019,666 + gc_heap.h 1,285,250.
NITER=20000         # ⛔ part of the pin, not a tunable -- see the header. roman is NONLINEAR in N.
CENSUS="check: 1102"   # ROMAN_RUN(200) = total numeral length for 1001..1200. The kernel's own deterministic answer; if this is wrong the profile is of a DIFFERENT program.

cd "$R/SCRIP" 2>/dev/null || { echo "⛔ REFUSED (rc=2): no $R/SCRIP"; exit 2; }
[ -x ./scrip ] || { echo "⛔ REFUSED (rc=2): ./scrip is not built -- cannot profile what does not exist"; exit 2; }
[ -f out/libscrip_rt.so ] || { echo "⛔ REFUSED (rc=2): out/libscrip_rt.so missing -- mode-4 links against it"; exit 2; }
SNO="$R/corpus/benchmarks/snobol4/roman.sno"
[ -f "$SNO" ] || { echo "⛔ REFUSED (rc=2): $SNO missing -- the benchmark moved; re-point this gate rather than lowering the pin"; exit 2; }
grep -q '^\*BENCH ' "$SNO" || { echo "⛔ REFUSED (rc=2): $SNO carries no *BENCH marker -- the scaled recipe is unreachable; do NOT fall back to profiling the committed 10-iteration program, that is the recipe gap this gate was rewritten to close"; exit 2; }
[ -x ../harness/scripts/bench_wrap.sh ] || [ -f ../harness/scripts/bench_wrap.sh ] || { echo "⛔ REFUSED (rc=2): ../harness/scripts/bench_wrap.sh missing -- it builds the scaled kernel"; exit 2; }
command -v valgrind >/dev/null && command -v callgrind_annotate >/dev/null || { echo "⛔ REFUSED (rc=2): valgrind/callgrind_annotate not installed -- this gate measures Ir and must not pass on a box that cannot"; exit 2; }
command -v gcc >/dev/null || { echo "⛔ REFUSED (rc=2): gcc missing -- mode-4 needs it to link"; exit 2; }

O="$(mktemp -d)"; trap 'rm -rf "$O"' EXIT
RT="$(cd out && pwd)"
bash ../harness/scripts/bench_wrap.sh "$SNO" --mode=iter --n="$NITER" -o "$O/k.sno" >/dev/null 2>"$O/wrap.err" || { echo "⛔ REFUSED (rc=2): bench_wrap.sh could not build the scaled kernel:"; sed 's/^/    /' "$O/wrap.err"; exit 2; }
./scrip --compile --out="$O/k.s" "$O/k.sno" < /dev/null > "$O/compile.log" 2>&1 || { echo "⛔ REFUSED (rc=2): mode-4 compile of the scaled kernel failed -- see that before reading any number"; tail -5 "$O/compile.log" | sed 's/^/    /'; exit 2; }
gcc -no-pie "$O/k.s" -o "$O/k.bin" -L"$RT" -lscrip_rt -Wl,-rpath,"$RT" -lm -lpthread > "$O/link.log" 2>&1 || { echo "⛔ REFUSED (rc=2): link of the mode-4 kernel failed"; tail -5 "$O/link.log" | sed 's/^/    /'; exit 2; }
timeout -k 5 900s valgrind --tool=callgrind --callgrind-out-file="$O/cg.out" "$O/k.bin" < /dev/null > "$O/run.log" 2>&1 || { echo "⛔ REFUSED (rc=2): the callgrind run itself failed -- see that before reading any number"; exit 2; }

# ⛔ NON-EMPTY IS NOT ALIVE. A binary that crashes early still yields a well-formed cg.out and a plausible, SMALLER Ir figure -- i.e. a spurious PASS on this ratchet. Grade the kernel's own census first.
grep -qF "$CENSUS" "$O/run.log" || { echo "⛔ REFUSED (rc=2): the kernel did not print its census '$CENSUS' -- the profiled run did not do the work, so its Ir is of a DIFFERENT program. Output was:"; grep -v '^==' "$O/run.log" | head -5 | sed 's/^/    /'; exit 2; }
grep -qF "iters: $NITER" "$O/run.log" || { echo "⛔ REFUSED (rc=2): the kernel did not report 'iters: $NITER' -- it ran a different amount of work than the pin was taken at"; grep -v '^==' "$O/run.log" | head -5 | sed 's/^/    /'; exit 2; }

ANN="$O/ann.txt"; callgrind_annotate "$O/cg.out" > "$ANN" 2>/dev/null
FAM='^[[:space:]]*([0-9,]+) \([[:space:]]*[0-9.]+%\)[[:space:]]+([^[:space:]]+:(NV_SET_fn|NV_CELL_IF_FASTSET_fn))([[:space:]]|$)'
NBUCK=$(grep -cE "$FAM" "$ANN")
[ "$NBUCK" -gt 0 ] || { echo "⛔ REFUSED (rc=2): callgrind_annotate reported NO flat bucket for NV_SET_fn or NV_CELL_IF_FASTSET_fn -- the family was inlined away, renamed, or the annotation shape changed. That is NOT a pass; find out which."; exit 2; }
IR=$(grep -E "$FAM" "$ANN" | awk '{gsub(/,/,"",$1); s+=$1} END{printf "%d", s}')
case "${IR:-}" in ''|*[!0-9]*) echo "⛔ REFUSED (rc=2): could not sum the store-family Ir out of callgrind_annotate"; exit 2 ;; esac

echo "store family Ir on roman (mode-4, N=$NITER, -O0): $IR   pinned baseline: $PIN   [$NBUCK bucket(s)]"
grep -E "$FAM" "$ANN" | sed 's/^/    /'
if [ "$IR" -lt "$PIN" ]; then
    echo "PASS: store-family Ir dropped $((PIN - IR)) below the pin."
    echo "⛔ BEFORE RE-PINNING, PROVE THE COST WAS CURED AND NOT MOVED: if this drop came with a NEW helper split out of the store path, that helper belongs in this gate's FAM regex and the drop is not a cure. That refactor has already happened once on this row (702e2d162). List above shows every bucket counted."
    echo "   Re-pin PIN=$IR in this script IN THE SAME COMMIT as the cure, and cite the FINDING."
    exit 0
fi
echo "GATE FAIL(1) [nv_set_fn_ir_ratchet]: store-family Ir is $IR, not below the pinned $PIN -- item 3's cure is not landed"
exit 1
