#!/bin/bash
# stale-binary preflight (row test-gate-scripts-that-grade-scrip-refuse-on-a-stale-binary-census-widened, hq_T 2026-09-05)
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
# test_gate_pascal_m3.sh — Pascal M3 (--run) gate
S4E="${S4E_HOME:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"   # D-17 PORTABLE-HOME: the sibling root (all repos + oracles are siblings under ONE root; /home/claude2-style seat roots work with zero env; S4E_HOME overrides)
SCRIP="${SCRIP:-$S4E/SCRIP/scrip}"
CORPUS="${CORPUS:-$S4E/corpus/tests/pascal}"
HARNESS="${HARNESS:-$(dirname "${BASH_SOURCE[0]}")/corpus_suite_harness.py}"
RUNGS_SRC="${RUNGS_SRC:-$CORPUS/ALL.pas}"
RUNGS_REF="${RUNGS_REF:-$CORPUS/ALL.ref}"
# ⭐ REPOINTED (seat04, 2026-08-30, row pascal-master-flatten-and-scrip-test-pas): the old dual mechanism
# (a loose-*.pas loop + a hand-maintained SUITE_FAMILIES list over crosscheck/) is retired now that
# util_build_rungs_suite.py --lang pascal absorbs both shapes into ONE flat ALL.pas/ALL.ref, matching
# test_corpus_snobol4.sh's own cutover. `pcom`/`pint` are gone (confirmed absent, the old skip is dropped).
# ⛔ REVERTED BACK TO THE FLAT PATH (seat04, 2026-08-30) after seat11 (`94c98593`, row pascal-restore-prezeta,
# genuinely well-intentioned) repointed this at `$CORPUS/master/ALL.pas`, believing the flat path "has never
# existed" -- it existed on origin/main a full 30 minutes before that commit (corpus `066a680bb`, 20:16:32,
# vs. `94c98593` at 20:43:53); seat11's own `rungs/` subdir had already been deleted in that same commit as
# superseded, so their fix pointed the gate at a path that was freshly GONE, not one that had never arrived.
# Read as a stale/unpulled local corpus checkout at the time they investigated, not a real conflict.
# ⭐ WHAT SEAT11 FOUND THAT STAYS FIXED, independent of the path mixup: this gate's own all-arms-zero refusal
# (below) could not have caught the rungs silently grading 0 entries, because the STDIN_FAMILIES loop (and
# on m3 the benchmark-witness section) always examines >0 -- exactly the kind of "measured fine" vs. "could
# not measure" collision RULES.md's own gate-witness law exists to forbid. RUNGS_EXAMINED now refuses
# independently, not just as part of the combined check.
# ⛔ FIVE entries stay loose PERMANENTLY, not a residue of this repoint: read1-4 and pb35 read real stdin,
# and the suite format has no stdin-input concept (hq_C's SNOBOL4-side ruling, 2026-08-24 — see KEEP.md
# section 1). The rungs builder independently reaches the same conclusion (ALL.excluded.txt names all 5).
# Register a new permanent stdin exception in BOTH this file and test_gate_pascal_m4.sh's identical list.
STDIN_FAMILIES="read1 read2 read3 read4 pb35"
RESULTS="${RESULTS:-/tmp/m3_results.tsv}"
PASS=0; FAIL=0; NOREF=0; XFAIL=0; EXAMINED=0
echo -e "probe\tclass\tnotes" > "$RESULTS"

for name in $STDIN_FAMILIES; do
    pas="$CORPUS/$name.pas"; ref="$CORPUS/$name.ref"
    EXAMINED=$((EXAMINED+1))
    if [ ! -f "$pas" ] || [ ! -f "$ref" ]; then
        echo -e "$name\tNOREF\t" >> "$RESULTS"
        NOREF=$((NOREF+1)); continue
    fi
    inp="$CORPUS/$name.in"; [ -f "$inp" ] || inp=/dev/null
    out=$(timeout -k 5 8s "$SCRIP" --run "$pas" < "$inp" 2>/dev/null)
    rc=$?
    exp=$(cat "$ref")
    if [ $rc -eq 124 ]; then
        echo -e "$name\tTIMEOUT\t" >> "$RESULTS"
        FAIL=$((FAIL+1))
    elif [ -z "$out" ] && [ $rc -ne 0 ]; then
        echo -e "$name\tEMPTY_rc$rc\t" >> "$RESULTS"
        FAIL=$((FAIL+1))
    elif [ "$out" = "$exp" ]; then
        echo -e "$name\tPASS\t" >> "$RESULTS"
        PASS=$((PASS+1))
    else
        echo -e "$name\tWRONG_rc$rc\t" >> "$RESULTS"
        FAIL=$((FAIL+1))
    fi
done

RUNGS_PASS=0; RUNGS_FAIL=0; RUNGS_EXAMINED=0
if [ -f "$RUNGS_SRC" ] && [ -f "$RUNGS_REF" ]; then
    # Every rung suite entry is graded in this gate's mode: there is no modes column (Lon 2026-09-23, CEO-1218/1230).
    # ⛔⭐ CAPTURE THE HARNESS rc AND ITS stderr -- A REFUSAL IS NOT A RED AND IS NOT A CORPUS DEFECT (hq_B 2026-09-13,
    # row pascal-gates-report-a-one-runner-refusal-as-an-unpopulated-master). `2>/dev/null` here threw away the ONE sentence
    # that said what had happened. Under ONE RUNNER, ONE BOARD (CEO-523) a run of the rungs IS a board, so the harness
    # refuses it rc=2 to every seat but the coo; `board` came back empty, `p` was unset, RUNGS_EXAMINED fell to 0, and the
    # arm at the bottom then accused $RUNGS_SRC of being "a path defect or unpopulated rungs" -- while it sits on disk,
    # populated, 5239 lines. hq_S measured that message, went and checked the corpus, and found it fine (relayed by the coo
    # 2026-09-13). ⭐ THE COST IS NOT THE RED, IT IS THE FALSE CAUSE: a gate that cannot measure must say so and name what
    # stopped it, never nominate a suspect it never looked at. RULES.md § a correct procedure with a false explanation.
    HERR=$(mktemp); board=$(timeout -k 5 120s python3 "$HARNESS" run "$RUNGS_SRC" "$RUNGS_REF" --lang pascal --modes m3 2>"$HERR"); hrc=$?
    if [ $hrc -eq 2 ]; then
        echo "⛔ REFUSED-TO-GRADE rc=2: the harness refused the rungs, so M3 has NO rungs verdict. This gate does not know the rungs is bad and does not say so." >&2
        sed 's/^/    harness said: /' "$HERR" >&2; rm -f "$HERR"
        echo "    the rungs is present and populated -- $RUNGS_SRC ($(wc -l <"$RUNGS_SRC") lines) / $RUNGS_REF ($(wc -l <"$RUNGS_REF") lines); it is NOT what this refusal is about." >&2
        exit 2
    fi
    rm -f "$HERR"
    p=$(grep -oP '(?<=m3_pass=)\d+' <<<"$board"); f=$(grep -oP '(?<=m3_fail=)\d+' <<<"$board")
    crash=$(grep -oP '(?<=m3_crash=)\d+' <<<"$board"); hang=$(grep -oP '(?<=m3_hang=)\d+' <<<"$board")
    unproven=$(grep -oP '(?<=m3_unproven=)\d+' <<<"$board")
    total=$(grep '^SUITE_BOARD ' <<<"$board" | grep -oP '(?<=total=)\d+')
    if [ -z "$p" ]; then
        echo -e "rungs:ALL\tHARNESS_UNPROVEN\t" >> "$RESULTS"
        FAIL=$((FAIL+1))
    else
        RUNGS_EXAMINED=${total:-0}
        bad=$((f + crash + hang + unproven))
        echo -e "rungs:ALL\tPASS=$p FAIL=$f CRASH=$crash HANG=$hang UNPROVEN=$unproven\t" >> "$RESULTS"
        PASS=$((PASS+p)); FAIL=$((FAIL+bad))
        RUNGS_PASS=$p; RUNGS_FAIL=$bad
    fi
else
    echo -e "rungs:ALL\tMISSING\t" >> "$RESULTS"
    FAIL=$((FAIL+1))
fi

# --- INTERIM WITNESS-PAIR CHECK over corpus/benchmarks/pascal (hq_C 2026-08-27, ceo-endorsed) -------------------
# WHY: benchmarks/pascal carries 9 .pas/.ref witness pairs that NO gate reached, so `pascal-uplevel-nested-proc-hang`
# could close DONE+landed and silently un-land with nothing able to say NO. Interim: retires when
# `pascal-refs-regen-from-fpc-oracle` (rank 0) puts this directory on the graded board.
# ⛔ Discovered BY A FILE IT MUST CONTAIN, never `-d` on the container -- the s274 lesson: the container survives a
# re-grid while the contents re-nest, so a `-d` guard passes over an empty/moved corpus and reads as a clean pass.
# The same witness pairs are graded in mode 4 by test_gate_pascal_m4.sh (measured 11/11 in both modes, 2026-09-24).
# ⛔ 7 of the 9 open with `readln(reps)`; feeding /dev/null yields reps=0, an empty loop and a PLAUSIBLE all-zero
# board that is pure instrument error (measured, hq_C 2026-08-27). The `1` below is load-bearing -- do not remove it.
WCORPUS="${WCORPUS:-$S4E/corpus/benchmarks/pascal}"
WITNESS_XFAIL="${WITNESS_XFAIL:-}"   # ⛔ EMPTY, AND THAT IS THE CURED STATE -- THERE IS NO XFAIL (Lon 2026-09-03 21:30). `fbench` sat here since 2026-08-28 blocked on pascal-m4-for-spine-leak-64b-per-iter (nested if/elseif-inside-for SIGSEGV in transitXsurface/traceXline). That row is cured: fbench now matches its .ref, rc=0, measured hq_B 2026-09-13, so the XFAIL_STALE arm below fired exactly as designed and the entry is deleted here. ⭐ THE ARM IS THE POINT AND IT STAYS: an exception list that only permits FAILING lets a cure rot unnoticed, and this one caught its own rot. ⛔ It could only report it to a seat that could reach the witness section at all -- for two weeks every non-coo seat exited 2 at the rungs arm above and never got here, which is how a stale entry survived its own detector.
W_PASS=0; W_FAIL=0; W_EXAMINED=0; W_STALE=0
if [ -f "$WCORPUS/uplevel2.pas" ]; then
    for wpas in "$WCORPUS"/*.pas; do
        wname=$(basename "$wpas" .pas); wref="$WCORPUS/$wname.ref"
        [ -f "$wref" ] || continue
        W_EXAMINED=$((W_EXAMINED+1))
        wout=$(printf '1\n' | timeout -k 5 120s "$SCRIP" --run "$wpas" 2>/dev/null); wrc=$?
        if [ $wrc -eq 0 ] && [ "$wout" = "$(cat "$wref")" ]; then wok=1; else wok=0; fi
        case " $WITNESS_XFAIL " in
            *" $wname "*)
                # ⛔ An exception list that only permits FAILING lets a cure rot unnoticed. A listed witness that
                # PASSES is a RED here: the entry is stale and must be deleted in the same commit as the cure.
                if [ $wok -eq 1 ]; then
                    echo -e "witness:$wname\tXFAIL_STALE\t" >> "$RESULTS"
                    W_STALE=$((W_STALE+1)); FAIL=$((FAIL+1))
                else
                    echo -e "witness:$wname\tXFAIL\t" >> "$RESULTS"
                    XFAIL=$((XFAIL+1))
                fi ;;
            *)
                if [ $wok -eq 1 ]; then
                    echo -e "witness:$wname\tPASS\t" >> "$RESULTS"
                    W_PASS=$((W_PASS+1)); PASS=$((PASS+1))
                else
                    echo -e "witness:$wname\tWRONG_rc$wrc\t" >> "$RESULTS"
                    W_FAIL=$((W_FAIL+1)); FAIL=$((FAIL+1))
                fi ;;
        esac
    done
fi

echo "M3: PASS=$PASS FAIL=$FAIL NOREF=$NOREF XFAIL=$XFAIL (rungs: $RUNGS_EXAMINED entries, $RUNGS_PASS pass / $RUNGS_FAIL fail; stdin-loose: $EXAMINED examined)"
echo "M3 witnesses (benchmarks/pascal): EXAMINED=$W_EXAMINED PASS=$W_PASS FAIL=$W_FAIL XFAIL_STALE=$W_STALE"
# ⛔ RUNGS_EXAMINED refuses ON ITS OWN, not only when every arm is zero (seat11's finding): the stdin-loose
# loop and the benchmark witnesses both always examine >0, so a rung suite-path defect used to hide completely
# behind them -- ~150 entries silently dropped from the board with a clean-looking exit code either way.
if [ $RUNGS_EXAMINED -eq 0 ]; then
    echo "⛔ UNPROVEN: 0 rungs entries examined under $RUNGS_SRC / $RUNGS_REF -- path defect or unpopulated rungs, not a clean pass (this arm cannot hide behind the other two)" >&2
    exit 2
fi
if [ $EXAMINED -eq 0 ] && [ $W_EXAMINED -eq 0 ]; then
    echo "⛔ UNPROVEN: 0 stdin-loose files and 0 benchmark witnesses examined under $CORPUS / $WCORPUS -- corpus-path typo or unpopulated clone, not a clean pass" >&2
    exit 2
fi
[ $FAIL -eq 0 ]
