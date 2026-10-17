#!/usr/bin/env bash
# stale-binary preflight (row test-gate-scripts-that-grade-scrip-refuse-on-a-stale-binary-census-widened, hq_T 2026-09-05)
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
# ⭐⭐ DEFECT-C ACCEPTANCE GATE — the vlist_select ladder, graded so a LUCKY DRAW CANNOT PASS IT.
# Row `defect-c-zop-flat-regime-depth-compensate` (hq_P). Written hq_P 2026-08-27 s276.
#
# ⛔⭐ WHY THIS SCRIPT EXISTS AT ALL — THE CRITERION IT REPLACES COULD BE PASSED BY A BUILD THAT FIXED NOTHING.
# The row's DONE-WHEN was PROSE: "all PASS in both modes under at least two process environment sizes".
# Read literally as one run per size, that bar is a COIN FLIP: seat03 found, and hq_P independently
# reproduced on a different tree, that v04_listappend_growth SIGSEGVs under `env -i` at ~27% and NEVER
# ambient (hq_P measured 8/30 minimal, 0/30 ambient; seat03 8/29 minimal, 0/21 ambient). One run per
# environment therefore passes ~73% of the time against a null fix. A criterion that green-lights a
# do-nothing build three times in four is not a weak criterion, it is a VACUOUS one.
#
# ⭐⭐ THE MEASURED CURE, AND IT IS THE PRODUCT OF TWO THINGS, NOT EITHER ONE:
#     bare + ambient   -> 0/30  flagged   (the defect never manifests; a green run here means nothing)
#     bare + `env -i`  -> 8/30  flagged   (~27% -- real, but a coin flip per run)
#     valgrind + ambient -> 0/5 flagged   (⛔ VALGRIND ALONE CATCHES NOTHING -- it exits 0 and is silent)
#     valgrind + `env -i` -> 8/8 flagged  (✅ 100% DETERMINISTIC, with "Invalid write of size 8 ...
#                                          Address ... is not stack'd, malloc'd or (recently) free'd")
# ⛔ So "just run it under valgrind" is NOT the fix -- ambient valgrind is as blind as an ambient bare run.
# The environment is not incidental to this defect: it positions the out-of-bounds write, and only under
# the minimal environment does valgrind's stricter address-space bookkeeping see it every single time.
# THE GATE THEREFORE GRADES `env -i` + valgrind AS THE PRIMARY DETECTOR and keeps N-rep bare sampling as
# an independent backstop, because a cure that merely moved the write would silence one and not the other.
#
# ⛔ REFUSES rc=2 RATHER THAN SKIPPING: no ./scrip, no valgrind, no witness, no .ref => rc=2, never rc=0.
#    A test that cannot measure must never report success (RULES.md; the `make test` .PHONY trap).
# ⛔ EXPECTED TO FAIL TODAY. The cure is NOT landed, so this gate SHOULD exit 1 on the current tree --
#    that is its own negative test, and the reason it was written before the cure rather than after.
set -u
REPS="${REPS:-20}"
SELF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SELF_DIR/../../SCRIP" && pwd)"
CORPUS="$(cd "$ROOT/../corpus" 2>/dev/null && pwd)" || { echo "⛔ REFUSES (rc=2): no sibling corpus/ beside $ROOT"; exit 2; }
SCRIP="$ROOT/scrip"; RT="$ROOT/out"
W="$(mktemp -d)"; trap 'rm -rf "$W"' EXIT
[ -x "$SCRIP" ]                 || { echo "⛔ REFUSES (rc=2): $SCRIP not built. Run make first -- this is NOT a pass."; exit 2; }
command -v valgrind >/dev/null  || { echo "⛔ REFUSES (rc=2): valgrind absent; the deterministic arm cannot run, so no verdict is possible."; exit 2; }
# ⭐⭐ RE-POINTED TO THE RUNGS (hq_P 2026-08-30; ceo RULING `defect-c-gate-answer`). The loose tree
# corpus/probe/vlist_select is GONE -- probe/ was deleted in the total conversion -- and this gate had been
# REFUSING rc=2 ever since. It refused rather than passing, which is the only reason the ladder was not
# silently green while grading nothing.
# ⛔ NO STANDALONE DUPLICATE IS KEPT. ceo ruled the re-point goes through lib_rungs_extract.sh:
# rungs_extract_family materializes all eight entries as separately-compilable, separately-runnable
# standalone .sno/.ref pairs in a scratch dir, and everything below this line then does EXACTLY what it
# always did, per witness -- own .s, own binary, REPS x `env -i`, own valgrind arm.
# ⭐ THE PROPERTY THIS PRESERVES IS SHAPE, NOT CONTENT, AND THAT DISTINCTION IS THE WHOLE POINT: Defect C is
# environment-SIZE sensitive, so the detector needs PER-WITNESS PROCESS ISOLATION. A consolidated suite is
# one program, one process, one environment, one verdict -- byte-identical content that still cannot
# attribute a fault per witness. Extraction restores the shape the instrument depends on.
# (The general law, adopted beside byte-equal-or-no-delete: the conversion guard protects CONTENT and
# nothing protected SHAPE -- ask whether every instrument that graded a file can still do what it did.)
PROBE="$W/witnesses"
RUNGS_LANG="${RUNGS_LANG:-snobol4}" . "$SELF_DIR/lib_rungs_extract.sh"
rungs_extract_family probe_vlist_select "$PROBE" \
    || { echo "⛔ REFUSES (rc=2): could not extract probe_vlist_select from the rungs pair at $RUNGS_DIR."; exit 2; }
[ -d "$PROBE" ]                 || { echo "⛔ REFUSES (rc=2): witness dir $PROBE does not resolve."; exit 2; }
NAMES="$(cd "$PROBE" && ls *.sno 2>/dev/null | sed 's/\.sno$//' | sort)"
[ -n "$NAMES" ]                 || { echo "⛔ REFUSES (rc=2): zero witnesses in $PROBE -- an empty ladder is not a green one."; exit 2; }
for n in $NAMES; do [ -f "$PROBE/$n.ref" ] || { echo "⛔ REFUSES (rc=2): $n has no .ref oracle -- cannot grade it."; exit 2; }; done
echo "=== DEFECT-C vlist_select LADDER — env -i + valgrind is the primary detector (REPS=$REPS bare backstop) ==="
echo "    tree: $(git -C "$ROOT" log --oneline -1 2>/dev/null | cut -c1-12)   corpus: $(git -C "$CORPUS" log --oneline -1 2>/dev/null | cut -c1-12)   valgrind: $(valgrind --version)"
printf '  %-34s %-8s %-9s %-14s %-16s\n' WITNESS M3 M4-AMB "M4-MIN(bare)" "VALGRIND(OOB/UNI)"
tot_oob=0; tot_uni=0; wit_oob=0; wit_uni=0
fail=0
for n in $NAMES; do
    ref="$PROBE/$n.ref"
    m3="?"; if timeout -k 5 60s "$SCRIP" "$PROBE/$n.sno" < /dev/null > "$W/m3.out" 2>/dev/null; then
        cmp -s "$W/m3.out" "$ref" && m3=PASS || m3=WRONG; else m3=CRASH; fi
    amb="?"; minr="?"; vg="?"
    if timeout -k 5 60s "$SCRIP" --compile -o "$W/$n.s" "$PROBE/$n.sno" < /dev/null >/dev/null 2>&1 \
       && gcc -no-pie "$W/$n.s" -L"$RT" -lscrip_rt -lm -Wl,-rpath,"$RT" -o "$W/$n.bin" 2>/dev/null; then
        if bash -c 'timeout -k 5 60s "$0" < /dev/null > "$1" 2>/dev/null' "$W/$n.bin" "$W/a.out" 2>/dev/null; then cmp -s "$W/a.out" "$ref" && amb=PASS || amb=WRONG; else amb=CRASH; fi
        bad=0; for i in $(seq "$REPS"); do
            if bash -c 'env -i timeout -k 5 60s "$0" < /dev/null > "$1" 2>/dev/null' "$W/$n.bin" "$W/m.out" 2>/dev/null; then cmp -s "$W/m.out" "$ref" || bad=$((bad+1)); else bad=$((bad+1)); fi
        done
        [ "$bad" -eq 0 ] && minr="PASS $REPS/$REPS" || minr="FAIL $bad/$REPS"
        bash -c 'env -i timeout -k 5 300s valgrind -q --error-exitcode=99 "$0" < /dev/null > /dev/null 2> "$1"' "$W/$n.bin" "$W/vg.txt" 2>/dev/null; vrc=$?
        # ⛔⭐ TWO DEFECT CLASSES, COUNTED SEPARATELY (hq_P 2026-08-29, approved by hq_C who owns the witness row).
        # This used to be ONE grep folding `Invalid read/write | Access not within | uninitialised` into a single
        # count, so a red ladder said only "not clean" -- and on a row NAMED for an out-of-bounds write that reads
        # as "Defect C is live". MEASURED: it is not. The OOB signature is 0/8 across every witness while v05
        # carries 6 uninitialised-value reads in the eval-cache/tiny-shim paths, which are a different defect
        # entirely. One number standing for two classes on a row named for one of them is how a reader concludes
        # the wrong thing from a correct gate. ⛔ THE GATE IS NOT WEAKENED: it still fails on EITHER class, so
        # nothing that failed before passes now -- only the REPORT distinguishes them.
        voob=$(grep -cE "Invalid (read|write)|Access not within|is not stack'd" "$W/vg.txt" 2>/dev/null)
        vuni=$(grep -c 'uninitialised' "$W/vg.txt" 2>/dev/null)
        voob=${voob:-0}; vuni=${vuni:-0}
        tot_oob=$((tot_oob+voob)); tot_uni=$((tot_uni+vuni))
        [ "$voob" -gt 0 ] && wit_oob=$((wit_oob+1)); [ "$vuni" -gt 0 ] && wit_uni=$((wit_uni+1))
        if [ "$vrc" -ge 128 ]; then vg="CRASH"; elif [ "$voob" -gt 0 ] || [ "$vuni" -gt 0 ]; then vg="OOB=$voob UNI=$vuni"; elif [ "$vrc" -eq 99 ]; then vg="ERR"; else vg=CLEAN; fi
    else amb=CERR; minr=CERR; vg=CERR; fi
    printf '  %-34s %-8s %-9s %-14s %-16s\n' "$n" "$m3" "$amb" "$minr" "$vg"
    case "$m3$amb$minr$vg" in *WRONG*|*CRASH*|*CERR*|*FAIL*|*ERR*|*OOB=*) fail=$((fail+1));; esac
done
echo "------------------------------------------------------------"
printf '  CLASS SPLIT — Defect-C OOB signature: %d occurrence(s) in %d witness(es)  ·  uninitialised-value: %d in %d\n' "$tot_oob" "$wit_oob" "$tot_uni" "$wit_uni"
if [ "$tot_oob" -eq 0 ] && [ "$tot_uni" -gt 0 ]; then
  echo "  ⭐ READ THIS BEFORE CONCLUDING ANYTHING ABOUT DEFECT C: the OOB signature this row is named for is"
  echo "     ABSENT (0). The red below is the OTHER class. That is NOT evidence the cure landed -- x86_zop's"
  echo "     regime-3/4 raw fallback may be unchanged and merely latent; see the FINDINGs on the row."
fi
if [ "$fail" -eq 0 ]; then echo "✅ GATE OK — full ladder clean in both modes, both environments, and valgrind-clean under env -i."; exit 0; fi
echo "⛔ GATE FAILS — $fail witness(es) not clean. ⭐ EXPECTED until the Defect C cure lands; this is the gate's own negative test."
echo "   ⛔ Do NOT weaken this gate to make it pass, and do NOT re-grade on a single ambient run: ambient is blind to this defect"
echo "      (0/30 bare, 0/5 valgrind) while env -i+valgrind catches it 8/8. A green ambient run is not evidence."
exit 1
