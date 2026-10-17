#!/bin/bash
# stale-binary preflight (row test-gate-scripts-that-grade-scrip-refuse-on-a-stale-binary-census-widened, hq_T 2026-09-05)
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
# test_gate_zd_omega_head_acceptance.sh — acceptance gate for the row
# zd-omega-head-per-op-filter-one-cause-behind-boolptr-boolidx-and-the-spine-leaks
# (postoffice task: zd-omega-head-per-op-filter-one-cause-behind-boolptr-boolidx-and-the-spine-leaks.task.md)
#
# hq_B root-caused: zd_omega_head (emit.cpp:2498) is a PER-OP FILTER admitting only IR_CMP_TEST while
# Pascal's relop lowers to its sibling IR_BINOP_TEST (RULES.md NO-PER-OP-FILTER). One cause, four tracked
# failures: boolptr, boolidx (same defect via an array lvalue), and the bubble/quick mode-4 spine leaks
# (their own row's one-line description, "zd_plan misses IR_BINOP_TEST merge points", was right all along).
# This row was minted with NO runnable DONE-WHEN; this script IS that DONE-WHEN, per the row's own NEXT.
#
# Checks, in order, REFUSING rc=2 on any missing prerequisite (a missing binary or corpus file is a
# refusal to grade, never a silent pass -- RULES.md "A MISSING PREREQUISITE IS A REFUSAL"):
#   1. STRUCTURAL   -- the exact known-bad single-op admission string named in the FINDING is gone from
#                      zd_omega_head. A regression witness, not a proof the replacement is correct.
#   2. NAMED WITNESSES -- boolptr + boolidx byte-match their .ref in BOTH m3 and m4 (surgical: this row is
#                      about these two names, not the whole Pascal board -- deep5/pb34 are separate,
#                      already-tracked defects and must not gate this row either way). Since corpus efb71c7a9
#                      (2026-09-06) both live in corpus/tests/pascal/ALL.pas; the arm extracts them by origin
#                      through corpus_suite_harness.py, the one reader, byte-identical to the files they were.
#   2b. REGRESSION DETECTOR -- a_plainvar + f_const_then_relop (hq_B's FINDING, inline, not corpus fixtures):
#                      the naive 2-line candidate cure passes boolptr/boolidx while silently regressing
#                      a_plainvar, so checking only the two named failures would wave a wrong fix through.
#   3. SPINE LEAK   -- bubble + quick, mode 4, 5/5 runs each under `setarch -R` (fixed address layout):
#                      rc=0 and output byte-matches the checked-in .ref every time. A real per-iteration
#                      $rsp leak crashes before a full-size sort completes, so 5/5 clean full-size runs is
#                      sufficient behavioural evidence without re-deriving seat12/seat02's instruction trace.
#   4. RETIRED 2026-10-01 (the coo): the shared-node control battery ran five boards as a fixture -- the
#                      SNOBOL4 master, the Icon rungs (floor 232), the Raku smoke, the Prolog crosscheck (a
#                      fail-set pinned 09-02) and the polyglot demos. Under ONE TESTING OFFICER (CEO-1342)
#                      the coo's SUITE TABLE is that verdict and a fixture may not grade the shared corpus,
#                      so the arm could only refuse once arm 2 read again.
#
# ⛔ THIS GATE DOES NOT BUILD. Run `make pristine` yourself first for a real verdict (HQ-27) -- running a
# board and a build in the same tree is independently forbidden (RULES.md s268), and this row's own history
# (a live claim on pascal-restore-prezeta touching this exact code) is the direct witness of why that
# matters: do not run this gate concurrently with a build in the same working tree.
#
# Exit: 0 all green · 1 measured and something failed · 2 refused to grade (prerequisite missing).
set -u
S4E="${S4E_HOME:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
cd "$(dirname "$0")/../../SCRIP"
SCRIP="${SCRIP:-$PWD/scrip}"
RT="${RT:-$PWD/out/libscrip_rt.so}"
PASCAL_TESTS="${PASCAL_TESTS:-$S4E/corpus/tests/pascal}"
PASCAL_BENCH="${PASCAL_BENCH:-$S4E/corpus/benchmarks/pascal}"

[ -x "$SCRIP" ] || { echo "⛔ REFUSE(2): no executable $SCRIP -- build first (make pristine)" >&2; exit 2; }
[ -f "$RT" ] || { echo "⛔ REFUSE(2): no $RT -- run make libscrip_rt first" >&2; exit 2; }
for f in "$PASCAL_TESTS/ALL.pas" "$PASCAL_TESTS/ALL.ref" "$PASCAL_TESTS/ALL.csv" \
         "$PASCAL_BENCH/bubble.pas" "$PASCAL_BENCH/bubble.ref" "$PASCAL_BENCH/quick.pas" "$PASCAL_BENCH/quick.ref"; do
    [ -f "$f" ] || { echo "⛔ REFUSE(2): missing witness file $f" >&2; exit 2; }
done
command -v setarch >/dev/null || { echo "⛔ REFUSE(2): setarch not on PATH -- needed for the spine-leak arm" >&2; exit 2; }
. "$(dirname "$0")/lib_gate.sh"   # gate_three_way: absent-line-is-UNPROVEN, never a zd_omega_head verdict

TMP=$(mktemp -d)
trap "rm -rf $TMP" EXIT
for name in boolptr boolidx; do   # arm 2's witnesses, by origin, from the master they were absorbed into
    python3 ../harness/scripts/corpus_suite_harness.py extract "$PASCAL_TESTS/ALL.pas" "$PASCAL_TESTS/ALL.ref" --origin "$name" "$TMP/$name.pas" \
        --out-ref "$TMP/$name.ref" --out-in "$TMP/$name.in" > /dev/null 2>&1 && [ -s "$TMP/$name.pas" ] && [ -s "$TMP/$name.ref" ] \
        || { echo "⛔ REFUSE(2): the harness could not extract origin $name from $PASCAL_TESTS/ALL.pas" >&2; exit 2; }
done
FAIL=0
UNPROVEN=0
report() { # report <name> <ok:0|1> <detail>
    if [ "$2" -eq 0 ]; then echo "✅ PASS $1 -- $3"; else echo "⛔ FAIL $1 -- $3"; FAIL=$((FAIL+1)); fi
}
# report_unproven <name> <detail> -- the third outcome (row a-refusal-reported-in-the-vocabulary-of-a-
# red-absent-line-read-as-unparseable): a sub-run this arm depends on could not be measured (killed,
# timed out, refused). That is NOT a zd_omega_head regression and must never be tallied into FAIL --
# but it is also not a pass, so it must not be silently swallowed either. gate_three_way already put the
# real cause on stderr; this just keeps the running total honest.
report_unproven() { echo "🟡 UNPROVEN $1 -- $2"; UNPROVEN=$((UNPROVEN+1)); }

# --- 1. STRUCTURAL: the exact known-bad per-op shape must be gone ------------------------------------------
# ⛔⭐ REWRITTEN BY hq_C 2026-09-05. The previous clause grepped for ONE HISTORICAL BAD STRING (the
# IR_CMP_TEST-only spelling). Adding IR_IDENT/IR_DIFFER/IR_BINOP_TEST to the list made that grep MISS, so this
# clause reported ✅ PASS from 2026-08-29 to 2026-09-04 while the per-op filter was still sitting there with
# four ops in it -- a false green that survived six sessions and let seat05 re-derive the whole mechanism from
# SNOBOL4. A structural clause that names the KNOWN-BAD form passes the moment anyone writes a DIFFERENT bad
# form. Assert the SHAPE OF THE CURE instead: no op-identity branch anywhere in the predicate.
# RE-CUT 2026-10-14 by hq_zetas on the cto's ruling of road (a) for row spine-zd-omega-test-kind-...-ceo-1389: the shape of the cure is
# the IR family query -- ir_decides_own_failure_kind, declared once in src/ir/IR.h with every member of the call family -- read
# together with the ω port; SCRIP_ZD_TESTFAM and SCRIP_ZD_MATCHDIAMOND, which selected members per op at run time, are deleted.
predline=$(grep -h 'static int zd_omega_test_kind' src/emitter/emit.cpp)
if [ -z "$predline" ]; then
    report structural-zd-omega-head 1 "zd_omega_test_kind not found at all -- this clause can no longer grade the predicate; repoint the gate rather than reading its silence as a pass"
elif printf '%s' "$predline" | grep -qE '(^|[^_[:alnum:]])op[[:space:]]*==|->op[[:space:]]*=='; then
    report structural-zd-omega-head 1 "zd_omega_test_kind STILL ADMITS BY OP IDENTITY (RULES.md NO PER-OP FILTER) -- an op list of ANY length is the defect, not just the historical one-op spelling: $predline"
elif ! printf '%s' "$predline" | grep -q 'ω\.node'; then
    report structural-zd-omega-head 1 "zd_omega_test_kind no longer branches on op identity but does not consult the ω port either -- a predicate that admits everything is not the family fix: $predline"
elif ! printf '%s' "$predline" | grep -q 'ir_decides_own_failure_kind('; then
    report structural-zd-omega-head 1 "zd_omega_test_kind does not ask the IR's own-failure family (ir_decides_own_failure_kind, src/ir/IR.h) -- the cto's ruling on 1c (2026-10-14): the family is a closed definition owned by the IR, read with the ω port: $predline"
elif { ! grep -q '^static inline int ir_decides_own_failure_kind(IR_e t)' src/ir/IR.h; } || { grep -hE 'IR_(CMP_TEST|IDENT|DIFFER|BINOP_TEST|MATCH_BEGIN)' src/emitter/emit.cpp | grep -q 'zd_omega'; }; then
    report structural-zd-omega-head 1 "the own-failure family is not declared once in src/ir/IR.h, or zd_plan names a family member beside it -- an op list in the planner is the defect this arm retires"
else
    report structural-zd-omega-head 0 "zd_omega_test_kind admits by the IR's own-failure family read with the ω port (ir_decides_own_failure_kind, declared once in src/ir/IR.h), never by an op list"
fi

# --- helpers: compile+link mirrors test_gate_pascal_m4.sh exactly (same RT, same flags) ---------------------
compile_link() { # compile_link <pas> <exe-out> -> rc 0 on success
    local pas=$1 exe=$2 asm="$TMP/$(basename "$pas" .pas).s" obj="$TMP/$(basename "$pas" .pas).o"
    timeout -k 5 8s "$SCRIP" --compile "$pas" < /dev/null > "$asm" 2>/dev/null || return 1
    [ -s "$asm" ] || return 1
    gcc -c -o "$obj" "$asm" 2>/dev/null && gcc -o "$exe" "$obj" "$RT" -no-pie -Wl,-rpath,"$(dirname "$RT")" 2>/dev/null
}

# --- 2. Named Pascal witnesses: boolptr + boolidx, BOTH modes -----------------------------------------------
for name in boolptr boolidx; do
    pas="$TMP/$name.pas"; ref="$TMP/$name.ref"; inp="$TMP/$name.in"; [ -s "$inp" ] || inp=/dev/null
    out3=$(timeout -k 5 8s "$SCRIP" --run "$pas" < "$inp" 2>/dev/null); rc3=$?
    if [ "$rc3" -eq 0 ] && [ "$out3" = "$(cat "$ref")" ]; then report "pascal-$name-m3" 0 "byte-matches .ref"; else report "pascal-$name-m3" 1 "rc=$rc3, does not match .ref"; fi
    exe="$TMP/$name.exe"
    if compile_link "$pas" "$exe"; then
        out4=$(timeout -k 5 8s "$exe" < "$inp" 2>/dev/null); rc4=$?
        if [ "$rc4" -eq 0 ] && [ "$out4" = "$(cat "$ref")" ]; then report "pascal-$name-m4" 0 "byte-matches .ref"; else report "pascal-$name-m4" 1 "rc=$rc4, does not match .ref"; fi
    else
        report "pascal-$name-m4" 1 "compile or link failed"
    fi
done

# --- 2b. REGRESSION DETECTOR: a_plainvar + f_const_then_relop (hq_B's FINDING, both modes) -------------------
# ⛔ NOT corpus fixtures, deliberately -- hq_B kept these OUT of corpus/tests/pascal on purpose (mid-bisect,
# moving the denominator was explicitly avoided), so they are embedded here rather than committed as .pas/.ref.
# hq_B's own words: "a_plainvar is the cheapest regression detector found so far" -- the naive 2-line candidate
# cure (admit IR_BINOP_TEST + relax the >0 guard) passes boolptr/boolidx while silently REGRESSING this one,
# because the omega arm's temp write and the merge read land at different zd_plan depths. A gate that only
# checks boolptr/boolidx would wave the naive cure through; this block is what stops that.
inline_witness() { # inline_witness <name> <src-var> <expected>
    # Compares with whitespace stripped: Pascal's default writeln(integer) right-pads to a field width
    # (SCRIP included), which is incidental formatting, not the thing this witness is checking -- the
    # witness cares which DIGIT printed, not its column width.
    local name=$1 src="$2" expected="$3" pas="$TMP/$name.pas" want; want=$(printf '%s' "$expected" | tr -d '[:space:]')
    printf '%s\n' "$src" > "$pas"
    local out3 rc3 got3; out3=$(timeout -k 5 8s "$SCRIP" --run "$pas" < /dev/null 2>/dev/null); rc3=$?; got3=$(printf '%s' "$out3" | tr -d '[:space:]')
    if [ "$rc3" -eq 0 ] && [ "$got3" = "$want" ]; then report "$name-m3" 0 "matches expected"; else report "$name-m3" 1 "rc=$rc3 got=[$out3] want=[$expected]"; fi
    local exe="$TMP/$name.exe"
    if compile_link "$pas" "$exe"; then
        local out4 rc4 got4; out4=$(timeout -k 5 8s "$exe" < /dev/null 2>/dev/null); rc4=$?; got4=$(printf '%s' "$out4" | tr -d '[:space:]')
        if [ "$rc4" -eq 0 ] && [ "$got4" = "$want" ]; then report "$name-m4" 0 "matches expected"; else report "$name-m4" 1 "rc=$rc4 got=[$out4] want=[$expected]"; fi
    else
        report "$name-m4" 1 "compile or link failed"
    fi
}
inline_witness a_plainvar \
'program a(output); var b : boolean; i : integer;
begin i := 7; b := i > 3; if b then writeln(1) else writeln(0);
              b := i < 3; if b then writeln(1) else writeln(0) end.' \
"1
0"
inline_witness f_const_then_relop \
'program f(output); type rp = ^rec; rec = record f : boolean end; var p : rp; i : integer;
begin i := 7; new(p); p^.f := true;  if p^.f then writeln(1) else writeln(0);
                      p^.f := i < 3; if p^.f then writeln(1) else writeln(0) end.' \
"1
0"

# --- 3. bubble + quick, mode 4, 5/5 under setarch -R --------------------------------------------------------
# ⛔ FIXED 2026-09-02 (seat16): both kernels open `readln(reps)` (test_bench_pascal_timed.sh:6, every
# reps-capable Pascal benchmark) -- `< /dev/null` on a run that reads stdin overrides silently and reads
# EOF instead of a real value (CLAUDE.md's own named trap, seat05 2026-09-01: "the redirect overrides the
# pipe, the program reads EOF and prints a plausible answer"), which is exactly what happened here: this
# arm reported 0/5 CLEAN on BOTH kernels even against a tree with Site 1 (bubble's spine leak) already
# fixed. `echo 1` matches every other script that runs these two kernels (calling-convention-depth-tracked's
# own DONE-WHEN, pascal-quick-m4-wrong-checksum-crash-masked's own DONE-WHEN, test_bench_pascal_timed.sh)
# and is the input bubble.ref/quick.ref were generated against.
for name in bubble quick; do
    pas="$PASCAL_BENCH/$name.pas"; ref="$PASCAL_BENCH/$name.ref"; exe="$TMP/$name.bench.exe"
    if compile_link "$pas" "$exe"; then
        hits=0
        for i in 1 2 3 4 5; do
            out=$(echo 1 | setarch "$(uname -m)" -R timeout -k 5 30s "$exe" 2>/dev/null); rc=$?
            [ "$rc" -eq 0 ] && [ "$out" = "$(cat "$ref")" ] && hits=$((hits+1))
        done
        if [ "$hits" -eq 5 ]; then report "pascal-$name-m4-5x" 0 "5/5 clean under setarch -R (no crash => no observable spine drift)"; else report "pascal-$name-m4-5x" 1 "$hits/5 clean under setarch -R"; fi
    else
        report "pascal-$name-m4-5x" 1 "compile or link failed"
    fi
done

# --- 4. retired 2026-10-01 (see the header): the cross-language verdict is the coo's SUITE TABLE, never a fixture's board run.

# ⛔ UNPROVEN OUTRANKS BOTH: checked-and-clean and checked-and-bad are exit 0/1 as always, but "could not
# check" must never collapse into either (row a-refusal-reported-in-the-vocabulary-of-a-red-absent-line-
# read-as-unparseable) -- rc=2 here is the SAME UNPROVEN vocabulary this gate's own arms just propagated.
if [ "$UNPROVEN" -gt 0 ]; then
    echo "=== $UNPROVEN CHECK(S) UNPROVEN, $FAIL CHECK(S) FAILED -- UNPROVEN is not a pass, and it is not this row's fault either; re-run the named sub-scripts standalone ==="
    exit 2
fi
echo "=== $([ "$FAIL" -eq 0 ] && echo ALL GREEN || echo "$FAIL CHECK(S) FAILED") ==="
[ "$FAIL" -eq 0 ]
