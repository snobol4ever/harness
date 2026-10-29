#!/usr/bin/env bash
# test_gate_sno_a_setexit_trap_enters_its_handler_on_the_statements_failure_path_without_nesting.sh
#
# SPITBOL'S RULE (sbl.min err05-err07): a trapped error runs the SETEXIT handler with the hardware stack reset
# (ssl iniss). Only the continuation is kept (r_cnt, stxoc, stxof), so a handler that leaves by a plain goto leaves
# nothing behind, and :(CONTINUE) resumes at the failure exit of the statement that erred. SCRIP entered the handler
# NESTED (rt_goto_transfer_checked -> rt_chain_enter) on top of the erroring call, the EVAL frames and
# core_runtime_error itself. Every trap whose handler left by a plain goto nested the program one level deeper:
# ERROR 246 after ~480 traps, and inside EVAL's guard each trap held two of g_core_errjmp_stk's 64 entries, so
# raising stopped after 32 (ceo CEO-1419 ticket snobol4-setexit-trapped-errors-leak-stack-to-error-246-and-stop-
# raising-after-32; the ceo's ruling CEO-1422 chose shape B).
# SHAPE B, AS LANDED: core_runtime_error records the handler's resolved code address in g_rtccb[25] and returns, so the
# operation fails and its statement fails. The statement's failure path carries an IR_SETEXIT_TEST box: if g_rtccb[25]
# is set, its inline take sequence (bb_setexit_take; out of line in runtime_eval.c from CEO-1428 until CEO-1468 put it back,
# because a runtime asm entered from a box counts as C-to-BB) clears it, keeps the path (a resume label in the box), rsp, rbp
# and r12 in g_rtccb[26..29], and jumps to the handler.
# :(CONTINUE)/:(SCONTINUE) resolve to rt_setexit_continue_tramp, which restores them and resumes that failure path,
# and :(ABORT) makes the original error fatal. Inside a match a pending trap takes the deferred element's ABORT exit,
# so no alternative runs after the error (the ceo's condition 1). A computed goto's unresolved exit tests the same
# slot. A site that cannot return after an error (heap exhaustion) still enters the handler at once.
# Expectations are cut from sbl -bf AT RUN TIME, both modes; each arm grades the whole stdout. rc=0 clean · rc=1 a
# divergence · rc=2 REFUSAL.
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
B="$HERE/../../SCRIP"
refuse() { echo "⛔ REFUSES rc=2: $*"; exit 2; }
[ -x "$B/scrip" ] || refuse "$B/scrip is not built -- cannot measure"
. "$HERE/lib_oracle_flags.sh" 2>/dev/null || true
SBL="$(sbl_correctness_bin 2>/dev/null || true)"; [ -n "${SBL:-}" ] && [ -x "$SBL" ] || SBL=/home/resources/x64/bin/sbl
[ -x "$SBL" ] || refuse "no sbl oracle -- the expectations are cut from it at run time"
"$HERE/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
D="$(mktemp -d)" || refuse "no scratch dir"
trap 'rm -rf "$D"' EXIT

cat > "$D/many.sno" <<'SNO'
        &TRIM = 1
loop    line = INPUT                                            :F(END)
        &ERRLIMIT = 1000
        SETEXIT('errh')
        r = EVAL(line)                                          :S(ok)
        OUTPUT = 'FAIL'                                         :(loop)
ok      OUTPUT = 'OK ' r                                        :(loop)
errh    OUTPUT = 'ERROR ' &ERRTYPE                              :(loop)
END
SNO
{ yes "+'a'" | head -600; yes "BAL + ARB" | head -40; } > "$D/many.in"
cat > "$D/absorb.sno" <<'SNO'
        &ERRLIMIT = 10
        SETEXIT('H')
        N = 'a'
        'x' ? (*(1 + N) | 'x' $ OUTPUT)                         :S(M)F(F)
M       OUTPUT = 'MATCHED'                                      :(E)
F       OUTPUT = 'FAILED'                                       :(E)
H       OUTPUT = 'TRAP ' &ERRTYPE                               :(CONTINUE)
E       OUTPUT = 'end'
END
SNO
cat > "$D/cont.sno" <<'SNO'
        &ERRLIMIT = 5
        SETEXIT('H')
        A = 'a'
        X = 1 + A                                               :S(S)F(F)
S       OUTPUT = 'S'                                            :(N)
F       OUTPUT = 'F'
N       OUTPUT = 'next ERRLIMIT=' &ERRLIMIT                     :(END)
H       OUTPUT = 'H ' &ERRTYPE                                  :(CONTINUE)
END
SNO
cat > "$D/abort.sno" <<'SNO'
        &ERRLIMIT = 5
        SETEXIT('H')
        OUTPUT = 'before'
        A = 'a'
        X = 1 + A
        OUTPUT = 'not reached'                                  :(END)
H       OUTPUT = 'H ' &ERRTYPE                                  :(ABORT)
END
SNO
cat > "$D/cgoto.sno" <<'SNO'
        SETEXIT(.ERRTRACE)
        &ERRLIMIT = 100
        LBL = 'NOSUCHLABEL'
        X = 1                                                   :($LBL)
        OUTPUT = 'unreachable'                                  :(FIN)
ERRTRACE OUTPUT = 'caught ' &ERRTYPE
FIN     OUTPUT = 'fin'
END
SNO
cat > "$D/unload.sno" <<'SNO'
        DEFINE('MYFN(X)')
        IDENT(MYFN('hello'), 'hello')                           :F(BAD)
        UNLOAD('MYFN')
        &ERRLIMIT = 1
        SETEXIT('OK')
        MYFN('a')
        OUTPUT = 'BAD'                                          :(END)
OK      OUTPUT = 'trapped ' &ERRTYPE                            :(END)
BAD     OUTPUT = 'BAD'                                          :(END)
MYFN    MYFN = X                                                :(RETURN)
END
SNO
cat > "$D/ge.sno" <<'SNO'
        &ERRLIMIT = 10
        Y = GE('abc', 0)                                        :S(S)F(F)
S       OUTPUT = 'S Y=[' Y ']'                                  :(END)
F       OUTPUT = 'F ' &ERRTYPE ' ERRLIMIT=' &ERRLIMIT
END
SNO
cat > "$D/ulnoset.sno" <<'SNO'
        DEFINE('MYFN(X)')
        UNLOAD('MYFN')
        &ERRLIMIT = 1
        MYFN('a')                                               :S(S)F(F)
S       OUTPUT = 'S'                                            :(END)
F       OUTPUT = 'F ' &ERRTYPE                                  :(END)
MYFN    MYFN = X                                                :(RETURN)
END
SNO
ARMS="many absorb cont abort cgoto unload ge ulnoset"
inp() { [ -f "$D/$1.in" ] && echo "$D/$1.in" || echo /dev/null; }
run_scrip() {  # $1 name $2 mode -> stdout
    if [ "$2" = m3 ]; then (cd "$D" && timeout -k 5 60 "$B/scrip" "$1.sno" < "$(inp "$1")" 2>/dev/null)
    else "$B/scrip" --compile --out="$D/$1.s" "$D/$1.sno" </dev/null >/dev/null 2>&1 \
           && gcc -no-pie -o "$D/$1.bin" "$D/$1.s" -L"$B/out" -lscrip_rt -lm -Wl,-rpath,"$B/out" 2>/dev/null \
           || refuse "could not build the m4 arm of $1 -- a toolchain failure, not a verdict"
         (cd "$D" && timeout -k 5 60 "./$1.bin" < "$(inp "$1")" 2>/dev/null); fi
}
for a in $ARMS; do (cd "$D" && timeout -k 5 60 "$SBL" -bf "$a.sno" < "$(inp "$a")" > "$a.sbl" 2>/dev/null); done
[ "$(wc -l < "$D/many.sbl")" = 640 ] || refuse "the oracle answered $(wc -l < "$D/many.sbl") of 640 trapped lines -- the witness is not measuring"
grep -qx "TRAP 2" "$D/absorb.sbl" && grep -qx "FAILED" "$D/absorb.sbl" || refuse "the oracle no longer reads TRAP 2 / FAILED on the absorption witness -- re-read sbl"
grep -qx "F" "$D/cont.sbl" || refuse "the oracle's CONTINUE no longer takes the erring statement's :F -- re-read sbl"
fails=0; arms=0
sed -n '/^abort\.sno([0-9]*) : ERROR/q;p' "$D/abort.sbl" > "$D/abort.cut"; grep -q "^abort\.sno([0-9]*) : ERROR 002" "$D/abort.sbl" || refuse "the oracle's ABORT arm no longer ends in ERROR 002 -- re-read sbl"; cp "$D/abort.cut" "$D/abort.sbl"
for m in m3 m4; do
    for a in $ARMS; do
        arms=$((arms+1)); run_scrip "$a" "$m" > "$D/$a.$m"; rc=$?
        if [ "$a" = abort ] && [ "$rc" = 0 ]; then printf '  FAIL  %s abort    ran CLEAN where sbl dies of the original error\n' "$m"; fails=$((fails+1)); continue; fi
        if [ "$(sed -e :x -e '/^\n*$/{$d;N;bx' -e '}' "$D/$a.sbl")" = "$(sed -e :x -e '/^\n*$/{$d;N;bx' -e '}' "$D/$a.$m")" ]; then printf '  ok    %s %-8s %s lines, as sbl\n' "$m" "$a" "$(wc -l < "$D/$a.sbl")"
        else printf '  FAIL  %s %-8s\n' "$m" "$a"; diff "$D/$a.sbl" "$D/$a.$m" | head -6 | sed 's/^/          /'; fails=$((fails+1)); fi
    done
done
[ "$fails" -eq 0 ] || { echo "⛔ GATE FAILED: $fails of $arms arm(s) red."
    echo "   many: a trap nests again (246) or stops raising (cap); absorb: an alternative ran after the error (bb_match_defer's"
    echo "   pending exit); cont/abort/cgoto/unload: the failure-path box, the continue trampoline, the computed goto's"
    echo "   unresolved exit, or a site that fell through after the error returned."; exit 1; }
echo "✅ GATE OK: $arms arm(s) -- a SETEXIT trap enters its handler on the statement's failure path without nesting: 640 trapped lines, no alternative after the error, CONTINUE and ABORT, both modes"
exit 0
