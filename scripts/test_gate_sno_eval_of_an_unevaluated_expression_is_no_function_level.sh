#!/usr/bin/env bash
# test_gate_sno_eval_of_an_unevaluated_expression_is_no_function_level.sh -- AN EXPR THUNK IS NOT A FUNCTION CALL, AND
# THE CALL THAT ENTERS IT HANDS ITS EPILOGUE THE TRUE LEVEL WORD (hq_zetas 2026-10-08, row spine-bake-...-ceo-1362, layer
# 11 d chunk 2a; the cto asked for a witness with a SPITBOL ref for each of the two defects the chunk cured).
#
# DEFECT 1 -- EVAL OF AN UNEVALUATED EXPRESSION COUNTED A FUNCTION LEVEL. The compiler makes *(expr) a thunk procedure
# (EXPR$n, thunk_kind EXPR) registered dyn_scope, and rt_proc_touches_level counted every dyn_scope procedure as a call
# that moves &FNCLEVEL, so OUTPUT = EVAL(*(&FNCLEVEL)) at top level printed 1 where SPITBOL prints 0 (arm a1). The cure is
# the THUNK bit on the procedure record (startup flag 64, rt_proc_set_thunk in mode 3): a thunk keeps dyn_scope 1 for
# every reader that routes it, and only the level accounting, the dyn prologue and the enter road read the bit.
#
# DEFECT 2 -- rt_proc_enter HANDED ITS EPILOGUES A GARBAGE LEVEL WORD. The asm leaf moved the result to rdi:rsi and jumped
# to rt_proc_call_epilogue_gamma(frame0, touched) with rdx unset, so touched was the result's high qword: a string result
# decremented the level, an integer zero did not. Arm a2 reaches the leaf through APPLY('EVAL', thunk) -- the C road
# rt_sno_dtx_value_rec -> rt_call_proc_descr_p -> rt_proc_enter; a plain EVAL(thunk) opens by the tail road, whose level
# word rides in the call word and never reaches this leaf -- with a thunk yielding a string and one yielding the integer 0,
# then EVAL(*(&FNCLEVEL)) inside the function; every &FNCLEVEL must read as SPITBOL's. The leaf now takes touched as its
# third argument and keeps it in one slot, laid out as rt_proc_enter_barrier kept its nsb.
# NON-VACUOUS, MEASURED: with the leaf's gamma landing made to drop the slot (addq $8 in place of popq %rdx) a2 reads
# st/0/0/0/0/0/-1 where SPITBOL reads st/1/0/1/1/1/0, in both modes.
#
# ARM a3 -- THE RE-ENTRY THE SELF-SAVE EXISTED FOR. A thunk re-entered during its own evaluation (F evaluates EVAL(X)
# where X = *(F()), three deep, through EVAL and through a deferred pattern element) with no save and no restore of the
# result cell: the body writes the cell and reads it back with no call in between, so an inner activation cannot clobber
# an outer one's value (the cto's ruling of 2026-10-08). Mode 4 had already run this way since layer 11 c.
#
# MEASURED on the control at origin a71d1a339: a1 printed 1 (SPITBOL 0), a2 st/1/0/1/2/1/0 (SPITBOL st/1/0/1/1/1/0, the
# EVAL(*(&FNCLEVEL)) inside the function one too high); a3 matched. Every arm grades m3 and m4 against SPITBOL.
#
# EXIT: 0 all arms match SPITBOL. 1 an arm regressed. 2 UNPROVEN (no built scrip / no oracle).
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)" || { echo "REFUSE(2): no SCRIP beside harness at $HERE/../../SCRIP (a port root) -- this gate measures SCRIP and cannot from here"; exit 2; }; cd "$ROOT"
. "$HERE/lib_gate.sh" 2>/dev/null || { echo "REFUSING: cannot load lib_gate.sh -- the ONE gate-honesty authority." >&2; exit 3; }
gate_parse_args "$@"
SCRIP="${SCRIP:-$ROOT/scrip}"; RT="${RT_DIR:-$ROOT/out}"
gate_require_exec "$SCRIP" "scrip binary"
gate_require "$RT/libscrip_rt.so" "runtime library"
gate_require_fresh "$ROOT" src "$SCRIP" "$RT/libscrip_rt.so"
T="$(mktemp -d)" || exit 2; trap 'rm -rf "$T"' EXIT
cat > "$T/a1.sno" <<'EOF'
        X = *(&FNCLEVEL)
        OUTPUT = EVAL(X)
END
EOF
cat > "$T/a2.sno" <<'EOF'
        S = *('s' 't')
        Z = *(0)
        X = *(&FNCLEVEL)
        DEFINE('G()')                                  :(GEND)
G       G = APPLY('EVAL', S) '/' &FNCLEVEL '/' APPLY('EVAL', Z) '/' &FNCLEVEL '/' EVAL(X) '/' &FNCLEVEL :(RETURN)
GEND    OUTPUT = G()
        OUTPUT = &FNCLEVEL
END
EOF
cat > "$T/a3.sno" <<'EOF'
        DEFINE('F()')                                  :(FEND)
F       N = N + 1
        F = LT(N,4) 'f' N '(' EVAL(X) ')' N             :S(RETURN)
        F = 'base'                                      :(RETURN)
FEND    N = 0
        X = *(F())
        OUTPUT = EVAL(X)
        N = 0
        P = *(F()) 'z'
        'xf1(f2(f3(base)4)4)4z' P . V
        OUTPUT = V
        D = *(EVAL(X) '+' N)
        N = 0
        OUTPUT = EVAL(D)
END
EOF
ORACLE=/home/resources/x64/bin/sbl
[ -x "$ORACLE" ] || { echo "UNPROVEN(2): correctness oracle absent at $ORACLE -- this gate grades against SPITBOL, never against SCRIP's own output"; exit 2; }
bad=0
for a in a1 a2 a3; do
    want="$("$ORACLE" -bf "$T/$a.sno" < /dev/null 2>&1 | tr '\n' '/')"
    [ -n "$want" ] || { echo "  UNPROVEN $a -- oracle produced no output; refusing to grade SCRIP against nothing"; exit 2; }
    for m in m3 m4; do
        if [ "$m" = m3 ]; then
            got="$(timeout -k 5 20s "$SCRIP" "$T/$a.sno" < /dev/null 2>&1 | tr '\n' '/')"
        else
            "$SCRIP" --compile --out="$T/$a.s" "$T/$a.sno" < /dev/null > /dev/null 2>&1
            gcc "$T/$a.s" -o "$T/$a.x" -L"$RT" -lscrip_rt -Wl,-rpath,"$RT" -lm -lpthread > /dev/null 2>&1 || { echo "  RED  $a $m -- link failed"; bad=1; continue; }
            got="$(timeout -k 5 20s "$T/$a.x" < /dev/null 2>&1 | tr '\n' '/')"
        fi
        if [ "$got" = "$want" ]; then echo "  ok   $a $m -- matches SPITBOL [$want]"
        else echo "  RED  $a $m -- got [$got] want [$want]"; bad=1; fi
    done
done
if [ "$bad" -ne 0 ]; then echo "GATE RED(1) [sno-eval-of-an-unevaluated-expression-is-no-function-level]: a thunk counted a function level, a call road handed its epilogue a wrong level word, or a re-entered thunk lost its value"; exit 1; fi
echo "GATE GREEN(0) [sno-eval-of-an-unevaluated-expression-is-no-function-level]: EVAL of a thunk moves no &FNCLEVEL, the level survives string and integer-zero results, and a re-entered thunk keeps its value, in both modes (6 graded arms)"
exit 0
