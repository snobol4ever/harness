#!/bin/bash
# stale-binary preflight (row test-gate-scripts-that-grade-scrip-refuse-on-a-stale-binary-census-widened, hq_T 2026-09-05)
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
# test_gate_pascal_m4.sh — Pascal M4 (--compile -> gcc -> link -> run) gate
S4E="${S4E_HOME:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"   # D-17 PORTABLE-HOME: the sibling root (all repos + oracles are siblings under ONE root; /home/claude2-style seat roots work with zero env; S4E_HOME overrides)
SCRIP="${SCRIP:-$S4E/SCRIP/scrip}"
CORPUS="${CORPUS:-$S4E/corpus/tests/pascal}"
HARNESS="${HARNESS:-$(dirname "${BASH_SOURCE[0]}")/corpus_suite_harness.py}"
RUNGS_SRC="${RUNGS_SRC:-$CORPUS/ALL.pas}"
RUNGS_REF="${RUNGS_REF:-$CORPUS/ALL.ref}"
# ⭐ REPOINTED (seat04, 2026-08-30, row pascal-master-flatten-and-scrip-test-pas) -- see test_gate_pascal_m3.sh
# for the full rationale (kept byte-identical in substance between the two files, same reason as before).
# ⛔ REVERTED BACK TO THE FLAT PATH (seat04, 2026-08-30) after a stale-checkout mixup briefly pointed this at
# the already-deleted `rungs/` subdir -- see test_gate_pascal_m3.sh for the full timeline (kept
# byte-identical in substance between the two files, same reason as before).
# ⛔ HAND-MAINTAINED -- keep byte-identical to test_gate_pascal_m3.sh's STDIN_FAMILIES list.
STDIN_FAMILIES="read1 read2 read3 read4 pb35"
RESULTS="${RESULTS:-/tmp/m4_results.tsv}"
RT="${RT:-$S4E/SCRIP/out/libscrip_rt.so}"
TMP=$(mktemp -d)
trap "rm -rf $TMP" EXIT
PASS=0; FAIL=0; NOREF=0; XFAIL=0; EXAMINED=0
echo -e "probe\tclass\tnotes" > "$RESULTS"

for name in $STDIN_FAMILIES; do
    pas="$CORPUS/$name.pas"; ref="$CORPUS/$name.ref"
    EXAMINED=$((EXAMINED+1))
    if [ ! -f "$pas" ] || [ ! -f "$ref" ]; then
        echo -e "$name\tNOREF\t" >> "$RESULTS"
        NOREF=$((NOREF+1)); continue
    fi
    asm="$TMP/$name.s"
    obj="$TMP/$name.o"
    exe="$TMP/$name"
    timeout -k 5 8s "$SCRIP" --compile "$pas" < /dev/null > "$asm" 2>/dev/null
    if [ $? -ne 0 ] || [ ! -s "$asm" ]; then
        echo -e "$name\tCOMPILE_FAIL\t" >> "$RESULTS"
        FAIL=$((FAIL+1)); continue
    fi
    gcc -c -o "$obj" "$asm" 2>/dev/null && \
    gcc -o "$exe" "$obj" "$RT" -no-pie -Wl,-rpath,"$(dirname $RT)" 2>/dev/null
    if [ $? -ne 0 ] || [ ! -x "$exe" ]; then
        echo -e "$name\tLINK_FAIL\t" >> "$RESULTS"
        FAIL=$((FAIL+1)); continue
    fi
    inp="$CORPUS/$name.in"; [ -f "$inp" ] || inp=/dev/null
    out=$(timeout -k 5 8s "$exe" < "$inp" 2>/dev/null)
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
    HERR=$(mktemp); board=$(timeout -k 5 180s python3 "$HARNESS" run "$RUNGS_SRC" "$RUNGS_REF" --lang pascal --modes m4 2>"$HERR"); hrc=$?
    if [ $hrc -eq 2 ]; then
        echo "⛔ REFUSED-TO-GRADE rc=2: the harness refused the rungs, so M4 has NO rungs verdict. This gate does not know the rungs is bad and does not say so." >&2
        sed 's/^/    harness said: /' "$HERR" >&2; rm -f "$HERR"
        echo "    the rungs is present and populated -- $RUNGS_SRC ($(wc -l <"$RUNGS_SRC") lines) / $RUNGS_REF ($(wc -l <"$RUNGS_REF") lines); it is NOT what this refusal is about." >&2
        exit 2
    fi
    rm -f "$HERR"
    p=$(grep -oP '(?<=m4_pass=)\d+' <<<"$board"); f=$(grep -oP '(?<=m4_fail=)\d+' <<<"$board")
    crash=$(grep -oP '(?<=m4_crash=)\d+' <<<"$board"); hang=$(grep -oP '(?<=m4_hang=)\d+' <<<"$board")
    unproven=$(grep -oP '(?<=m4_unproven=)\d+' <<<"$board")
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

# --- THE SAME WITNESS PAIRS AS test_gate_pascal_m3.sh, IN MODE 4 (corpus/benchmarks/pascal; measured 11/11, 2026-09-24).
# ⛔ 7 of them open with `readln(reps)`; /dev/null yields reps=0 and a plausible all-zero board, so each is fed `1`.
WCORPUS="${WCORPUS:-$S4E/corpus/benchmarks/pascal}"
W_PASS=0; W_FAIL=0; W_EXAMINED=0
if [ -f "$WCORPUS/uplevel2.pas" ]; then
    for wpas in "$WCORPUS"/*.pas; do
        wname=$(basename "$wpas" .pas); wref="$WCORPUS/$wname.ref"
        [ -f "$wref" ] || continue
        W_EXAMINED=$((W_EXAMINED+1)); wexe="$TMP/w_$wname"
        if timeout -k 5 60s "$SCRIP" --compile "$wpas" < /dev/null > "$wexe.s" 2>/dev/null && [ -s "$wexe.s" ] \
           && gcc -c -o "$wexe.o" "$wexe.s" 2>/dev/null && gcc -o "$wexe" "$wexe.o" "$RT" -no-pie -Wl,-rpath,"$(dirname $RT)" 2>/dev/null; then
            wout=$(printf '1\n' | timeout -k 5 120s "$wexe" 2>/dev/null); wrc=$?
        else wout=""; wrc=254; fi
        if [ $wrc -eq 0 ] && [ "$wout" = "$(cat "$wref")" ]; then
            echo -e "witness:$wname\tPASS\t" >> "$RESULTS"; W_PASS=$((W_PASS+1)); PASS=$((PASS+1))
        else
            echo -e "witness:$wname\tWRONG_rc$wrc\t" >> "$RESULTS"; W_FAIL=$((W_FAIL+1)); FAIL=$((FAIL+1))
        fi
    done
fi

echo "M4: PASS=$PASS FAIL=$FAIL NOREF=$NOREF XFAIL=$XFAIL (rungs: $RUNGS_EXAMINED entries, $RUNGS_PASS pass / $RUNGS_FAIL fail; stdin-loose: $EXAMINED examined)"
echo "M4 witnesses (benchmarks/pascal): EXAMINED=$W_EXAMINED PASS=$W_PASS FAIL=$W_FAIL"
# ⛔ RUNGS_EXAMINED refuses ON ITS OWN (seat11's finding, see test_gate_pascal_m3.sh) -- the stdin-loose loop
# always examines >0, so a rung suite-path defect used to hide completely behind it.
if [ $RUNGS_EXAMINED -eq 0 ]; then
    echo "⛔ UNPROVEN: 0 rungs entries examined under $RUNGS_SRC / $RUNGS_REF -- path defect or unpopulated rungs, not a clean pass (this arm cannot hide behind the other)" >&2
    exit 2
fi
if [ $EXAMINED -eq 0 ] && [ $W_EXAMINED -eq 0 ]; then
    echo "⛔ UNPROVEN: 0 stdin-loose files and 0 benchmark witnesses examined under $CORPUS / $WCORPUS -- corpus-path typo or unpopulated clone, not a clean pass" >&2
    exit 2
fi
[ $FAIL -eq 0 ]
