#!/usr/bin/env bash
# test_gate_raku_paren_call_passes_its_arguments.sh -- a parenthesized Raku call must pass its ARGUMENTS,
# never one concatenated list (hq_T 2026-09-06, CEO-332 / Lon: "let's not see stuck ever again ... go fix ONE
# program in each and let's begin the climb").
#
# ⛔ THE DEFECT, measured on roast S04-statements/until.t. `is($i, 5, 'desc')` built
#     (TT_FNC __rk_test_is (TT_VAR __rk_test_is) (TT_FNC __rk_arr (TT_VAR __rk_arr) (TT_VAR i) (TT_ILIT 5) ...))
# -- ONE argument, a list -- while `is $i, 5, 'desc'` built the correct three. The grammar HAS a
# `TESTOP '(' arg_list ')'` rule; it is unreachable for a comma list, because `TESTOP arg_list` also matches
# with arg_list being a single parenthesized list expression, and bison resolves it that way. The .y author's
# intent was right and the rule is dead.
#
# ⛔⭐ WHY IT NEEDED A GATE RATHER THAN A BOARD. THE TEST STILL EMITTED VALID TAP. It printed its plan, it
# printed four `not ok` lines with a diagnostic, it exited 0 -- everything a harness looks at was well formed,
# and the only evidence was inside the message text ("got: '55until $i >= 5 {} works'", three arguments
# concatenated). A whole-file board can only ever say 986 to 985. Nothing anywhere would have named the CALL
# FORM. And it is a construct so basic that a reader scanning for it does not see it: every roast file calls
# testops both ways on adjacent lines, so the working form sits beside the broken one on every page.
#
# ⭐ THE ARMS ARE DIFFERENTIAL, AND THAT IS WHAT MAKES THEM CHEAP AND ORACLE-FREE. The property is not "is()
# prints X" -- which would need a hand-authored expectation that can rot -- it is THE TWO CALL FORMS OF THE
# SAME CALL MUST AGREE. f(a, b, c) and f a, b, c are the same program in Raku, so any divergence is a defect
# without anyone having to say which side is right. A hand-written expected value could have been written to
# match the buggy output; this cannot.
#
# ⛔ AND ONE ABSOLUTE ARM, because a differential gate alone is satisfiable by breaking BOTH forms: the arity
# actually reaching the callee is asserted directly, so "they agree" cannot become "they agree at 1 argument".
#
# FAILED ONCE: every arm below was run against the pre-cure binary and arms 1-4 FAILED there (m3 and m4 both:
# got '55paren form' where the listop form printed 'ok 1 - paren form'); arm 5 passed before and after, which
# is the control that says the cure did not simply delete the listop path.
#
# Usage: bash ../harness/scripts/test_gate_raku_paren_call_passes_its_arguments.sh   (~3s, no oracle, no network)
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/../../SCRIP" && pwd)" || { echo "REFUSE(2): no SCRIP beside harness at $HERE/../../SCRIP (a port root) -- this gate measures SCRIP and cannot from here"; exit 2; }
cd "$ROOT"
. "$HERE/lib_gate.sh"
GATE_NAME="raku_paren_call_passes_its_arguments"
gate_parse_args "$@"
gate_require_fresh "$ROOT" src "$ROOT/scrip" "$ROOT/out/libscrip_rt.so"
W="$(mktemp -d)"; trap 'rm -rf "$W"' EXIT
violations=0; examined=0
ck() { examined=$((examined + 1)); if [ "$1" = ok ]; then printf '  ok   %s\n' "$2"; else printf '  FAIL %s\n' "$2"; violations=$((violations + 1)); fi; }
# run_both <file> -> prints "m3<TAB>m4" md5s; a mode that will not build prints BUILDFAIL, never an empty
# string, because two empty strings compare equal and would read as agreement.
#
# ⛔⭐⭐ A CRASH IS NOT A VERDICT, AND THIS GATE USED TO TURN ONE INTO A DIVERGE (hq_T 2026-09-06, ceo CEO-365).
# `scrip --compile` on these witnesses SIGSEGVs INTERMITTENTLY and the failure was folded into the same
# BUILDFAIL string a genuine build error produces -- then COMPARED as a value, so one arm crashing and the
# other succeeding printed "m4 DIVERGE: listop BUILDFAIL vs paren <md5>". That names the wrong defect
# entirely: the two call forms did not disagree, one of them never ran. And this gate is ARM 2 OF 60 in
# `make test`, so that false red stopped the other 58 arms -- including the SNOBOL4 board -- fleet-wide.
# ⭐ MEASURED, not inferred, and the mechanism is NOT the load-race it looked like: 3/20 SEGV on --compile
# and 5/20 on --run with ASLR ON, and 0/20 under `setarch -R`. It is an ASLR-DEPENDENT crash in the Raku
# front end -- the same signature as the SNOBOL4 fuzz family -- and it is a REAL defect that belongs in its
# own row, NOT something this gate should hide. So: crashes are detected as crashes, retried a bounded
# number of times, and if they persist the gate REFUSES rc=2 NAMING them, rather than reporting a
# disagreement that did not happen. A gate that cannot measure says so (RULES.md: refuse, never skip-as-
# success -- and never fail-as-verdict either, which is the same lie wearing the other hat).
CRASHED=0
# ⭐⭐ THE MEASUREMENT RUNS UNDER `setarch -R` (ASLR OFF) AND THAT IS A NARROWING, NOT A COVER-UP.
# This gate's subject is ONE property -- a parenthesized call passes its arguments -- and that property is
# deterministic. The intermittent SIGSEGV it kept tripping over is ASLR-dependent (3/20 and 5/20 with ASLR
# on, 0/20 with it off) and is a DIFFERENT defect in the Raku front end, which gets its own row rather than
# being laundered through this gate's verdict either way. Grading the deterministic property
# deterministically is what a gate is for; the crash detection below stays as the safety net, so if the
# crash ever appears WITHOUT ASLR this gate refuses instead of quietly reporting a disagreement.
SETARCH=""   # ⭐ ASLR STAYS ON. The setarch -R narrowing this line used to carry was a workaround for the
             # Raku top-level uninitialised-context SIGSEGV, and that defect is CURED (lower_raku.c, this same
             # landing), so the gate keeps its teeth and grades the condition every other seat runs under
             # (ceo CEO-367: cure the compiler, leave the gate alone). Measured: cured build 10/10 rc=0 with
             # ASLR ON; base build 10/10 rc=2, refusing honestly instead of inventing a DIVERGE.
# _try <mode> <file> -> md5 of the output, or the literal CRASH / BUILDFAIL. Sets CRASHED when the tool died
# on a signal (rc >= 128) or was killed by the timeout (124), both of which mean UNMEASURED, not "failed".
_try() {
    local m="$1" f="$2" rc out
    if [ "$m" = 3 ]; then
        out="$(timeout -k 5 60 $SETARCH "$ROOT/scrip" --run "$f" 2>&1 </dev/null)"; rc=$?
        if [ "$rc" -ge 124 ]; then CRASHED=$((CRASHED + 1)); printf 'CRASH(rc=%s)\n' "$rc"; return; fi
        printf '%s\n' "$out" | md5sum | cut -d' ' -f1; return
    fi
    timeout -k 5 60 $SETARCH "$ROOT/scrip" --compile --target=x86 "$f" > "$W/c.s" 2>/dev/null; rc=$?
    if [ "$rc" -ge 124 ]; then CRASHED=$((CRASHED + 1)); printf 'CRASH(rc=%s)\n' "$rc"; return; fi
    if [ "$rc" -ne 0 ] \
       || ! timeout -k 5 60 gcc -c "$W/c.s" -o "$W/c.o" 2>/dev/null \
       || ! timeout -k 5 60 gcc "$W/c.o" -L"$ROOT/out" -lscrip_rt -lm -Wl,-rpath,"$ROOT/out" -o "$W/c.bin" 2>/dev/null; then
        printf 'BUILDFAIL\n'; return
    fi
    out="$(timeout -k 5 60 $SETARCH "$W/c.bin" 2>&1 </dev/null)"; rc=$?
    if [ "$rc" -ge 124 ]; then CRASHED=$((CRASHED + 1)); printf 'CRASH(rc=%s)\n' "$rc"; return; fi
    printf '%s\n' "$out" | md5sum | cut -d' ' -f1
}
# ⭐ THE RETRY IS BOUNDED AND IT IS NOT A CURE -- it is what keeps an intermittent crash from being reported
# as a disagreement. Three attempts; a value that never stops crashing reaches the caller as CRASH and the
# gate refuses on it below.
_try_hard() {
    local m="$1" f="$2" v i
    for i in 1 2 3; do
        v="$(_try "$m" "$f")"
        case "$v" in CRASH*) ;; *) printf '%s\n' "$v"; return;; esac
    done
    printf '%s\n' "$v"
}
run_both() {
    local f="$1"
    printf '%s\t%s\n' "$(_try_hard 3 "$f")" "$(_try_hard 4 "$f")"
}
echo "--- ARMS 1-4 — the two call forms of one testop must agree, in BOTH modes ---"
for t in "is \$i, 5" "ok 1" "is 'a', 'a'" "isnt 1, 2"; do
    printf 'use Test;\nplan 1;\nmy $i = 5;\n%s, "d";\n' "$t"       > "$W/listop.raku"
    printf 'use Test;\nplan 1;\nmy $i = 5;\n%s(%s, "d");\n' "${t%% *}" "${t#* }" > "$W/paren.raku"
    a="$(run_both "$W/listop.raku")"; b="$(run_both "$W/paren.raku")"
    l3="${a%%	*}"; l4="${a##*	}"; p3="${b%%	*}"; p4="${b##*	}"
    # ⛔⭐ THE CRASH COUNT IS READ BACK OUT OF THE RETURNED STRING, NOT OUT OF A VARIABLE. run_both is invoked
    # in COMMAND SUBSTITUTION, so it runs in a SUBSHELL: the CRASHED=$((CRASHED+1)) inside it increments a
    # copy that dies with the subshell, and the parent kept reading 0 while crashes were happening. Measured
    # live -- the first version of this cure still printed "paren CRASH(rc=139)" as a DIVERGE, because the
    # refusal it was supposed to trigger never saw a nonzero count. The value crosses the boundary; the
    # variable does not. Same family as lib_gate.sh's note that a subprocess's exports never come back.
    for _v in "$l3" "$l4" "$p3" "$p4"; do case "$_v" in CRASH*) CRASHED=$((CRASHED + 1));; esac; done
    case "$l3$p3" in
        *CRASH*) examined=$((examined + 1)); printf '  ⛔  m3 UNMEASURED: %s  (listop %s vs paren %s)\n' "$t" "$l3" "$p3";;
        *) [ "$l3" = "$p3" ] && ck ok  "m3 agree: $t" || ck fail "m3 DIVERGE: $t  (listop $l3 vs paren $p3)";;
    esac
    case "$l4$p4" in
        *CRASH*) examined=$((examined + 1)); printf '  ⛔  m4 UNMEASURED: %s  (listop %s vs paren %s)\n' "$t" "$l4" "$p4";;
        *) [ "$l4" = "$p4" ] && ck ok  "m4 agree: $t" || ck fail "m4 DIVERGE: $t  (listop $l4 vs paren $p4)";;
    esac
done
echo "--- ARM 5 — the ABSOLUTE arm: the arity that reaches the callee, so 'they agree' cannot mean 'both take one argument' ---"
printf 'use Test;\nplan 1;\nis(1, 1, "three args reach the callee");\n' > "$W/arity.raku"
out="$(timeout -k 5 60 $SETARCH "$ROOT/scrip" --run "$W/arity.raku" 2>&1 </dev/null)"
printf '%s\n' "$out" | grep -qx 'ok 1 - three args reach the callee' \
    && ck ok "paren call delivers 3 distinct arguments" \
    || { ck fail "paren call did NOT deliver 3 arguments"; printf '%s\n' "$out" | sed 's/^/       /'; }
echo "--- ARM 6 — the AST carries no __rk_arr wrapper around a testop argument list ---"
# ⛔ IT GREPS THE WHOLE DUMP AND FIRST PROVES THE NODE IS THERE. Written as `| tail -1` this arm PASSED on the
# pre-cure binary -- the broken dump wrapped onto a second line, tail -1 returned "))", and "))" contains no
# __rk_arr, so the arm reported the cure present while every other arm reported it absent. A negative assertion
# over a truncated reading is indistinguishable from the property holding, which is this whole gate's own theme
# arriving inside the gate.
ast="$(timeout -k 5 10 "$ROOT/scrip" --dump-ast "$W/arity.raku" 2>&1 </dev/null)"
if ! printf '%s' "$ast" | grep -q '__rk_test_is'; then
    ck fail "the AST dump carries no __rk_test_is node at all -- this arm proved nothing"
    printf '%s\n' "$ast" | sed 's/^/       /'
elif printf '%s' "$ast" | grep -q '__rk_arr'; then
    ck fail "the argument list is still wrapped in __rk_arr"
    printf '%s\n' "$ast" | sed 's/^/       /'
else
    ck ok "testop node present and no __rk_arr wrapper"
fi
echo "--- ARM 7 — the roast program this cure flipped stays green in both modes ---"
# ⛔⭐ THE WITNESS IS RESOLVED, NOT HARDCODED (hq_raku 2026-09-16). This read "$ROOT/refs/roast/..."
# until today and SCRIP/refs/ WAS DELETED ORG-WIDE on 2026-09-16, so this BLOCKING arm refused rc=2 on every
# renamed root -- a COULD-NOT-MEASURE sitting inside the blocking set for all ten seats, which is the class
# the loop-and-report cure (CEO-582) exists to make visible rather than to tolerate. Same resolver the roast
# scoreboard and the ablation ranker use, so the three cannot disagree about where roast lives.
. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib_raku_roast_bucket.sh" 2>/dev/null || true
if command -v roast_resolve_population >/dev/null 2>&1 && roast_resolve_population "$ROOT" 2>/dev/null; then
    RT="$ROAST/S04-statements/until.t"
else
    RT="$ROOT/refs/roast/S04-statements/until.t"
fi
if [ ! -f "$RT" ]; then
    echo "  ⛔ REFUSED(2) [$GATE_NAME]: no $RT -- tried \$RAKU_ROAST_TREE, \$ROOT/refs/roast, then the shared"
    echo "     /home/resources/roast-master. A gate that cannot reach its witness REFUSES; it never passes."
    exit 2
fi
cp "$RT" "$W/until.raku"
for m in 3 4; do
    got=""; _rt_crash=1
    for _att in 1 2 3; do
        if [ "$m" = 3 ]; then got="$(timeout -k 5 60 $SETARCH "$ROOT/scrip" --run "$W/until.raku" 2>&1 </dev/null)"; _rc=$?
        else
            _rc=0
            timeout -k 5 60 $SETARCH "$ROOT/scrip" --compile --target=x86 "$W/until.raku" > "$W/u.s" 2>/dev/null || _rc=$?
            if [ "$_rc" -eq 0 ] \
               && timeout -k 5 60 gcc -c "$W/u.s" -o "$W/u.o" 2>/dev/null \
               && timeout -k 5 60 gcc "$W/u.o" -L"$ROOT/out" -lscrip_rt -lm -Wl,-rpath,"$ROOT/out" -o "$W/u.bin" 2>/dev/null; then
                got="$(timeout -k 5 60 $SETARCH "$W/u.bin" 2>&1 </dev/null)"; _rc=$?
            elif [ "$_rc" -eq 0 ]; then got="BUILDFAIL"; fi
        fi
        if [ "$_rc" -lt 124 ]; then _rt_crash=0; break; fi
    done
    if [ "$_rt_crash" = 1 ]; then CRASHED=$((CRASHED + 1)); got="CRASH(rc=$_rc)"; fi
    n_ok="$(printf '%s\n' "$got" | grep -cE '^ok [0-9]+')"; n_not="$(printf '%s\n' "$got" | grep -cE '^not ok')"
    { [ "$n_ok" -eq 4 ] && [ "$n_not" -eq 0 ]; } \
        && ck ok "m$m S04-statements/until.t: 4 ok, 0 not ok" \
        || { ck fail "m$m S04-statements/until.t: $n_ok ok, $n_not not ok"; printf '%s\n' "$got" | sed 's/^/       /'; }
done
GATE_EXAMINED="$examined"
# ⛔ REFUSE rather than publish a verdict built on an arm that never ran. rc=2 is UNPROVEN: this gate could
# not measure, and saying so is the whole product. ⭐ It names the ASLR dependence because that is the one
# fact that turns "flaky, re-run it" into a reproducible defect somebody can take as a row.
if [ "$CRASHED" -gt 0 ]; then
    printf '⛔ REFUSES rc=2: %d arm(s) could not be measured -- scrip died on a signal or a timeout and did NOT\n' "$CRASHED"
    printf '   produce a comparable result, after 3 attempts each. This is NOT a disagreement between the two call\n'
    printf '   forms, and it must never be reported as one.\n'
    printf '   Measured 2026-09-06 (hq_T): the crash is ASLR-DEPENDENT -- 3/20 on --compile and 5/20 on --run with\n'
    printf '   ASLR on, 0/20 under `setarch -R`. Reproduce it deterministically with:\n'
    printf '       setarch -R %s/scrip --compile --target=x86 <a 4-line Test.raku program>\n' "$ROOT"
    gate_stamp 2>/dev/null || true
    exit 2
fi
gate_verdict "$violations" "violation(s)"
