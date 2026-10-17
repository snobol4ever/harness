#!/usr/bin/env bash
# ../harness/scripts/test_gc_stress_suite.sh — the 3-stage GC (MARK/ADJUST/SLIDE) torture matrix.
# Runs corpus/crosscheck/gc/ (one test per collector root family + the exhaustion tortures)
# through BOTH modes at a stress ladder: plain, SCRIP_GC_STRESS=25, =7, =1 (collect every alloc).
# Every cell is oracle-diffed against the SPITBOL-generated .ref.
#
# WHAT plain DOES NOT COVER at the default 512MB heap: natural EXHAUSTION-triggered collection
# (gc_collect_ex(1), the conservative-stack-scan path at the allocation site). To exercise it,
# rebuild with a tiny heap and re-run this script:
#     cd SCRIP && rm -f scrip out/libscrip_rt.so src/runtime/rt/gc_heap.o
#     make -j4 scrip ZCFLAGS="-DZC_HEAP_MB=2" && make libscrip_rt ZCFLAGS="-DZC_HEAP_MB=2"
#     bash ../harness/scripts/test_gc_stress_suite.sh          # 213/214 then force ~30 regenerations each
# (Remember to rebuild default afterward — ZCFLAGS is not a make prerequisite.)
#
# Gate: every cell PASS. Exit 1 on any FAIL.
S4E="${S4E_HOME:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"   # D-17 PORTABLE-HOME: the sibling root (all repos + oracles are siblings under ONE root; /home/claude2-style seat roots work with zero env; S4E_HOME overrides)
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIP="${SCRIP:-$HERE/../../SCRIP/scrip}"
RT_DIR="${RT_DIR:-$HERE/../../SCRIP/out}"
CORPUS="${CORPUS:-$S4E/corpus}"
TIMEOUT="${TIMEOUT:-180}"   # ⛔ was 60 (row dead-suite-path-consumer-sweep): once GCDIR pointed at a real
# population again, 213_gc_exhaustion_churn/214_gc_exhaustion_live_set FAILed at higher stress -- looked
# like a hang at first. Confirmed NOT a bug, same shape as FINDING-2026-08-28-seat06-gc-stress-three-
# demos (demo_porter): SCRIP_GC_STRESS=1/7 forces collection every 1st/7th alloc, and this witness's 30k-
# iteration churn loop is genuinely, not pathologically, slower under that -- measured 213 @ STRESS=25
# 24.1s (suite's own arm, already passing), @ STRESS=7 77.9s CORRECT output (rc=0, byte-identical to
# .ref) under a manual 240s timeout, run 3x at the OLD 60s budget with 100% FAIL(rc=124) every time. 180s
# is >2x the one CONFIRMED worst case (matching the porter finding's own margin convention), enough to
# turn the STRESS=7 cell green. ⛔ STRESS=1 (the suite's most extreme arm) was NOT waited out to
# completion this session -- extrapolating linearly from the STRESS=25->STRESS=7 scaling it plausibly
# needs several more minutes, and a live process check confirmed genuine CPU-bound progress (99.8% CPU,
# not stuck) rather than an infinite loop, but that is evidence pointing the same direction, not a
# confirmed number. STRESS=1 may still FAIL(rc=124) under this budget for these two witnesses -- if so,
# that is this same non-bug, unconfirmed only in its exact duration, not a new defect. Widen further (or
# split GC_STRESS=1 into its own longer-budget arm) only after an actual measured completion time.
# ⛔ WAS `exit 0` ("SKIP scrip not built") until 2026-09-04 -- a test that could not measure reported
# SUCCESS to every caller reading $?, which is the precise false-green lib_gate.sh was written to kill
# (RULES.md: a test that cannot measure REFUSES rc=2, never skip-as-success). Found by the census arm of
# test_gate_runners_refuse_on_a_stale_binary.sh while wiring the staleness preflight -- same class, one
# step earlier: this one could not even say whether a binary EXISTED.
if [ ! -x "$SCRIP" ]; then echo "⛔ REFUSED-TO-GRADE rc=2: scrip not built at $SCRIP" >&2; exit 2; fi
# ⛔⭐ STALE-BINARY PREFLIGHT (row harness-and-ladder-runner-refuse-on-a-stale-binary-like-the-artifact-regen-
# does, ceo -> hq_T 2026-09-04). Existence is not currency: a binary that IS there can still predate the tree
# whose SHA the board will stamp on the verdict. NO LOGIC HERE -- util_require_fresh.sh sources
# gate_require_fresh from lib_gate.sh, the ONE authority (hq_B 4c7253e99), never a second copy.
"$HERE/util_require_fresh.sh" --gate test_gc_stress_suite "$SCRIP" "${RT_DIR:-$HERE/../../SCRIP/out}/libscrip_rt.so" || exit 2
WORKDIR=$(mktemp -d)
trap 'rm -rf "$WORKDIR"' EXIT
# ⛔ GCDIR IS EXTRACTED, NOT A FIXED TREE (row dead-suite-path-consumer-sweep): corpus/crosscheck/gc/ is
# gone -- corpus-suites-consolidation converted its 15 files into the rungs suite, family crosscheck_gc
# (confirmed: 15 origins, matching the conversion commit's own count, not assumed). The old "SKIP no gc
# corpus" fallback was skip-as-success on a genuinely-present population -- RULES.md's own standing rule
# is that a check which cannot measure must REFUSE, never quietly pass; an explicit GCDIR override still
# runs the old loose-directory path unchanged, for anyone testing against a hand-built tree.
if [ -z "${GCDIR:-}" ]; then
    GCDIR="$WORKDIR/gc_src"
    RUNGS_LANG="${RUNGS_LANG:-snobol4}" . "$HERE/lib_rungs_extract.sh"
    rungs_extract_family crosscheck_gc "$GCDIR" || { echo "GATE UNPROVEN(2) [test_gc_stress_suite]: could not extract the crosscheck_gc family from the rungs suite"; exit 2; }
fi
# ⛔⭐ POPULATION FLOOR (row every-board-wrapper-refuses-on-a-zero-population-instead-of-passing-
# vacuously, hq_T 2026-09-04): an EXPLICIT $GCDIR override skips extraction entirely, and every P/F
# counter below reads 0 over a directory with zero .sno files -- TOTAL_FAIL=0 at line 61 was ALREADY
# this file's own vacuous-pass floor before this row named the class; check it here, upstream of the
# 4-stress x 2-mode sweep, so one refusal replaces eight silent all-zero rows.
"$HERE/util_require_population.sh" --gate test_gc_stress_suite "$(ls "$GCDIR"/*.sno 2>/dev/null | wc -l)" 1 "*.sno witnesses under \$GCDIR ($GCDIR)" || exit 2
echo "=== GC stress suite — corpus/crosscheck/gc x {plain,S25,S7,S1} x {m3,m4} ==="
TOTAL_FAIL=0
for sno in "$GCDIR"/*.sno; do
    b=$(basename "${sno%.sno}")
    "$SCRIP" --compile "$sno" > "$WORKDIR/$b.s" 2>/dev/null \
      && gcc -c "$WORKDIR/$b.s" -o "$WORKDIR/$b.o" 2>/dev/null \
      && gcc "$WORKDIR/$b.o" -L"$RT_DIR" -lscrip_rt -lm -Wl,-rpath,"$RT_DIR" -o "$WORKDIR/$b" 2>/dev/null \
      || echo "COMPILE-FAIL $b (mode-4 cells will FAIL)"
done
for S in 0 25 7 1; do
    [ "$S" = 0 ] && lbl="plain   " || lbl="STRESS=$S"
    for MODE in m3 m4; do
        P=0; F=0; FL=""
        for sno in "$GCDIR"/*.sno; do
            b=$(basename "${sno%.sno}")
            ref="${sno%.sno}.ref"
            [ -f "$ref" ] || continue
            if [ "$MODE" = m3 ]; then
                if [ "$S" = 0 ]; then out=$(timeout -k 5 "$TIMEOUT" "$SCRIP" --run "$sno" < /dev/null 2>/dev/null); else out=$(SCRIP_GC_STRESS=$S timeout -k 5 "$TIMEOUT" "$SCRIP" --run "$sno" < /dev/null 2>/dev/null); fi
            else
                [ -x "$WORKDIR/$b" ] || { F=$((F+1)); FL="$FL $b(nc)"; continue; }
                if [ "$S" = 0 ]; then out=$(timeout -k 5 "$TIMEOUT" "$WORKDIR/$b" < /dev/null 2>/dev/null); else out=$(SCRIP_GC_STRESS=$S timeout -k 5 "$TIMEOUT" "$WORKDIR/$b" < /dev/null 2>/dev/null); fi
            fi
            if [ "$out" = "$(cat "$ref")" ]; then P=$((P+1)); else F=$((F+1)); FL="$FL $b"; fi
        done
        echo "  $lbl $MODE: PASS=$P FAIL=$F$FL"
        TOTAL_FAIL=$((TOTAL_FAIL + F))
    done
done
if [ "$TOTAL_FAIL" = 0 ]; then echo "GC STRESS SUITE: ALL GREEN"; exit 0; else echo "GC STRESS SUITE: $TOTAL_FAIL FAILING CELLS"; exit 1; fi
