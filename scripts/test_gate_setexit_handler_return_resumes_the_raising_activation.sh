#!/usr/bin/env bash
# test_gate_setexit_handler_return_resumes_the_raising_activation.sh -- row snobol4-a-setexit-handler-runs-at-top-level-so-
# freturn-from-it-is-error-242 (hq_snobol4 2026-09-23, CEO-1215/1218; the X64T math CRASH class of CEO-1214).
#
# MECHANISM, measured with the IPC monitor (spl vs scr: 9 steps agree, step 10 spl emits RETURN probe and scr dies) and gdb:
# core_runtime_error enters a SETEXIT handler NESTED, through rt_goto_transfer_checked -> rt_chain_enter, and rt_chain_enter
# pushes [rt_kw_return_level_zero, rt_kw_return_level_zero] as the function-return wire pair. So a :(RETURN) or :(FRETURN)
# in a handler whose error fired inside a user function jumped to the level-zero sentinel: FRETURN printed ERROR 242
# (the two SnoRungs ReadWrite entries), and a handler that had re-armed SETEXIT trapped that 242 too and re-entered itself
# until a misaligned movaps faulted (X64T math_ln/math_pow; math_div/math_prod under the separate zd_plan hang).
# a22f9c6ed (SETEXIT priority inside EVAL) only routed EVAL-raised errors -- every chks.inc exception -- onto this path;
# the path itself predates it (the no-EVAL arm already SIGSEGVed at 8f567e685).
#
# CURE: every activation entry that pushes a wire pair records its base, r12, the guard floor and the gamma wire in
# rt_stno_stack[level]; rt_kw_return_level_zero, reached from a nested handler at level >= 1 with a record that validates,
# unwinds g_core_errjmp_stk top-down (each guard runs its own cleanup, test_gate_setexit_unwind_every_errjmp_guard_continues
# _the_unwind.sh) and jumped through the activation's real wire (rt_unwind_to_activation, deleted by CEO-1468 once SETEXIT's
# shape B left no path to it; the handler now runs on the statement's failure path). And the const-fold trial is
# speculative (g_error = -2): an armed SETEXIT no longer steals it, and a failed trial is not folded, so EVAL('1 / 0')
# raises its error when the EVAL'd code runs -- the trap used to fire from INSIDE the optimizer, which is what made
# :(CONTINUE) re-trap once (arm 4).
#
# ARMS, each graded in mode 3 and mode 4 against `sbl -bf`, ref cut at run time: (1) FRETURN from a handler, error raised
# directly in the body; (2) RETURN from a handler that re-arms SETEXIT, error raised inside EVAL, three calls; (3) the
# same through an OPSYN'd builtin, which routes every call through the staged-call path (bcps_wire_cross); (4) CONTINUE
# from a handler, error raised inside EVAL; (5) the LEVEL rule -- a handler armed in outer() traps an error raised in
# inner() and runs AT THE RAISING LEVEL (&FNCLEVEL 2, as sbl prints), so its RETURN returns from inner() with inner's value
# and outer() continues. FAIL-ONCE on origin fa27bcdf9 (the tree before the cure), PASS on the cure. (6) EVAL reached by
# name under an armed SETEXIT -- APPLY('EVAL', s) twice on one text, an OPSYN'd EVAL on a text not yet parsed, a syntax
# error -- traps on EVERY call, as sbl does: the open-chain road (SCRIP 96a57a964) opened the chain without raising, and
# the parser's fold refusal of the text's first parse was taken for a syntax error, so the first call of each text failed
# untrapped; arms 2 and 4 went red on dbcfad57b, arm 6 too, and the cure (the by-name glue's open raises the build's
# error, a fold refusal raises its own code) is SCRIP's next landing after dbcfad57b.
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
set -uo pipefail
G="$(basename "${BASH_SOURCE[0]}" .sh)"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)" || { echo "REFUSE(2): no SCRIP beside harness at $HERE/../../SCRIP (a port root) -- this gate measures SCRIP and cannot from here"; exit 2; }
SCRIP="${SCRIP_BIN:-$ROOT/scrip}"; [ -x "$SCRIP" ] || { echo "⛔ GATE REFUSE(2) [$G]: no scrip at $SCRIP"; exit 2; }
LIBDIR="$ROOT/out"; [ -f "$LIBDIR/libscrip_rt.so" ] || { echo "⛔ GATE REFUSE(2) [$G]: no libscrip_rt.so in $LIBDIR"; exit 2; }
SBL="${SBL_BIN:-/home/resources/x64/bin/sbl}"; [ -x "$SBL" ] || { echo "⛔ GATE REFUSE(2) [$G]: no sbl at $SBL -- the ref is CUT FROM THE ORACLE at run time, never typed"; exit 2; }
T=$(mktemp -d) || exit 2; trap 'rm -rf "$T"' EXIT
cat > "$T/w1.sno" <<'EOF'
        DEFINE('probe()')                            :(probe_end)
probe   SETEXIT(.trapped)
        &ERRLIMIT = 10
        divisor = 0
        result = 1 / divisor
        OUTPUT = 'noerror'                           :(RETURN)
trapped OUTPUT = 'trapped'                           :(FRETURN)
probe_end
        probe()                                      :S(worked)
        OUTPUT = 'failed as expected'                :(END)
worked  OUTPUT = 'returned success'
END
EOF
cat > "$T/w2.sno" <<'EOF'
        DEFINE('probe(expr)')                        :(probe_end)
probe   SETEXIT(.trapped)
        &ERRLIMIT = 100
        result = EVAL(expr)                          :F(evalfail)
        OUTPUT = 'value ' result                     :(RETURN)
evalfail OUTPUT = 'evalfail ' &ERRTEXT               :(RETURN)
trapped OUTPUT = 'trapped ' &ERRTEXT
        SETEXIT(.trapped)                            :(RETURN)
probe_end
        probe('1 / 0')
        probe('1 / 0')
        probe('1 / 0')
        OUTPUT = 'done'
END
EOF
sed "s/^        DEFINE('probe(expr)')/        OPSYN('ln','LN')\n        DEFINE('probe(expr)')/; s/probe('1 \/ 0')/probe('ln(-1.0)')/" "$T/w2.sno" > "$T/w3.sno"
sed "s/SETEXIT(.trapped)                            :(RETURN)/SETEXIT(.trapped)                            :(CONTINUE)/" "$T/w2.sno" > "$T/w4.sno"
cat > "$T/w6.sno" <<'EOF'
        &ERRLIMIT = 20
        n = 0
        SETEXIT(.trap)
        r = APPLY('EVAL', '2 / 0')                   :F(f1)
f1      OUTPUT = 'a ' &ERRLIMIT ' n=' n
        SETEXIT(.trap)
        r = APPLY('EVAL', '2 / 0')                   :F(f2)
f2      OUTPUT = 'b ' &ERRLIMIT ' n=' n
        OPSYN('MYEVAL', 'EVAL')
        SETEXIT(.trap)
        r = MYEVAL('3 / 0')                          :F(f3)
f3      OUTPUT = 'c ' &ERRLIMIT ' n=' n
        SETEXIT(.trap)
        r = EVAL('1 +')                              :F(f4)
f4      OUTPUT = 'd ' &ERRLIMIT ' n=' n              :(END)
trap    n = n + 1
        OUTPUT = 'trap ' n ' ' &ERRTEXT              :(CONTINUE)
END
EOF
cat > "$T/w5.sno" <<'EOF'
        DEFINE('outer()')                          :(outer_end)
outer   SETEXIT(.trap)
        &ERRLIMIT = 10
        x = inner()
        OUTPUT = 'outer continues x=[' x ']'       :(RETURN)
trap    OUTPUT = 'trapped ' &ERRTEXT ' level=' &FNCLEVEL   :(RETURN)
outer_end
        DEFINE('inner()')                          :(inner_end)
inner   inner = 'unset'
        y = GE('abc', 0)
        inner = 'finished'                         :(RETURN)
inner_end
        outer()
        OUTPUT = 'done'
END
EOF
RC=0; arms=0
for w in w1 w2 w3 w4 w5 w6; do
    ( cd "$T" && timeout -k 5 20s "$SBL" -bf $w.sno </dev/null ) > "$T/$w.ref" 2>&1 || { echo "⛔ GATE REFUSE(2) [$G]: the oracle refused its own witness $w -- no ref to grade against"; exit 2; }
    [ -s "$T/$w.ref" ] || { echo "⛔ GATE REFUSE(2) [$G]: the oracle printed nothing for $w"; exit 2; }
    ( cd "$T" && timeout -k 5 20s "$SCRIP" $w.sno </dev/null > $w.m3 2>/dev/null ); r=$?; arms=$((arms + 1))
    if [ "$r" -eq 0 ] && cmp -s "$T/$w.m3" "$T/$w.ref"; then echo "  $w m3 PASS"; else echo "  $w m3 FAIL (rc=$r; $(diff "$T/$w.m3" "$T/$w.ref" | grep -c '^[<>]') differing line(s))"; RC=1; fi
    if "$SCRIP" --compile "$T/$w.sno" -o "$T/$w.s" </dev/null >/dev/null 2>&1 && gcc -m64 -no-pie -rdynamic "$T/$w.s" -Wl,-rpath,"$LIBDIR" -L"$LIBDIR" -lscrip_rt -lm -lpthread -o "$T/$w.bin" 2>"$T/ld.log"; then
        ( cd "$T" && timeout -k 5 20s ./$w.bin </dev/null > $w.m4 2>/dev/null ); r=$?; arms=$((arms + 1))
        if [ "$r" -eq 0 ] && cmp -s "$T/$w.m4" "$T/$w.ref"; then echo "  $w m4 PASS"; else echo "  $w m4 FAIL (rc=$r; $(diff "$T/$w.m4" "$T/$w.ref" | grep -c '^[<>]') differing line(s))"; RC=1; fi
    else echo "  $w m4 FAIL (the witness did not compile or link in mode 4)"; RC=1; arms=$((arms + 1)); fi
done
if [ "$RC" = 0 ]; then echo "✅ GATE PASS(0) [$G]: a SETEXIT handler's RETURN/FRETURN/CONTINUE resumes the raising activation; $arms arms byte-identical to the oracle"
else echo "⛔ GATE FAIL(1) [$G]: a SETEXIT handler does not resume the activation that raised the error (examined $arms arms)"; fi
exit $RC
