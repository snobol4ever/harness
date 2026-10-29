#!/usr/bin/env bash
# test_gate_sno_a_static_thunk_carries_no_name_and_every_reader_reaches_it_by_its_record.sh -- A COMPILED UNEVALUATED EXPRESSION
# HAS NO NAME STRING AT RUN TIME (hq_zetas 2026-10-09, row spine-bake-every-call-and-deferred-pattern-address-no-by-name-lookup-at-
# run-time-ceo-1362, chunk 2b-ii; Lon 2026-09-29, in-chat to the ceo, verbatim: "You should have no by-name lookup for FUNCTION
# CALLS. Nor by-name lookup for *DEFERRED_PATTERN references.").
#
# THE LAW: a static thunk (*expr, the compiler's EXPR$n) is identified by its star record and its registry slot, never by a name.
# In mode 4 its startup record carries name 0 (rt_proc_register_rec gives it an unhashed slot), its star record carries no string
# (or, for a stage variable *X, the variable's own *X, which DUMP prints), and its result variable's GVA slot is hidden (.quad 0
# in __gva_names). Every reader that once took the name takes the record: a deferred pattern (rt_defer_open_rec), a pattern
# primitive's deferred argument (rt_pat_prim_open, LEN POS RPOS TAB RTAB ANY NOTANY BREAK SPAN BREAKX), an immediate or
# conditional capture into *f() (c_rt_cap_open, the capture pump), EVAL, DUMP, and the run-time pattern compiler (a DT_X inside a
# pattern built at run time defers through an OPQ$ cell, as a DT_P does, whose value the matcher evaluates by its record).
#
# THE ARMS: a1 every primitive with a deferred argument plus a run-time built pattern; a2 stage variables, EVAL and DUMP's *X;
# a3 immediate and conditional captures into *G() and *$T; a4 cursor captures @*$('CUR' N) and @*G() in a statement, a stored
# pattern and a pattern built at run time (SNO$PCUR hands the record as a DSTAR-REF literal; rt_at_cursor opens it; this arm is graded on its asm only, because rt_at_cursor enters the thunk from C and that road is a
# named bomb under CEO-1576 until the ceo's C-to-BB row re-roads it); a5 captures
# into *G() and *$('X' N) inside patterns built at run time (SNO$PBC hands the record the same way; the run-time compiler takes the
# record as its capture target and bb_dstar_rec_addr returns it as itself). Each runs in m3 and m4 against sbl -bf AT RUN TIME (a2 compares the
# dump up to its keyword section), and each program's mode-4 asm must name no thunk (EXPR$ or EXPRNM$).
#
# EXIT: 0 green. 1 an arm differs from SPITBOL or its asm names a thunk. 2 cannot measure.
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)" || { echo "REFUSE(2): no SCRIP beside harness at $HERE/../../SCRIP (a port root) -- this gate measures SCRIP and cannot from here"; exit 2; }; cd "$ROOT"
. "$HERE/lib_gate.sh" 2>/dev/null || { echo "REFUSING: cannot load lib_gate.sh -- the ONE gate-honesty authority." >&2; exit 3; }
gate_parse_args "$@"
SCRIP="${SCRIP:-$ROOT/scrip}"; RT="${RT_DIR:-$ROOT/out}"
gate_require_exec "$SCRIP" "scrip binary"
gate_require "$RT/libscrip_rt.so" "runtime library"
gate_require_fresh "$ROOT" src "$SCRIP" "$RT/libscrip_rt.so"
T="$(mktemp -d)" || exit 2; trap 'rm -rf "$T"' EXIT
cat > "$T/a1.sno" <<'SNO'
        S = 'abcdefgh'
        N = 2
        C = 'de'
        S LEN(*(N + 1)) . R1
        OUTPUT = 'LEN ' R1
        S POS(*(N + 1)) REM . R2
        OUTPUT = 'POS ' R2
        S RPOS(*(N + 1)) . R3 REM
        S TAB(*(N + 2)) . R4
        OUTPUT = 'TAB ' R4
        S RTAB(*(N - 1)) . R5
        OUTPUT = 'RTAB ' R5
        S BREAK(*(C 'f')) . R6
        OUTPUT = 'BREAK ' R6
        S ARB SPAN(*(C 'f')) . R7
        OUTPUT = 'SPAN ' R7
        S ANY(*(C 'x')) . R8
        S ARB ANY(*(C 'x')) . R8
        OUTPUT = 'ANY ' R8
        S NOTANY(*(C 'abc')) . R9
        OUTPUT = 'NOTANY ' R9
        S BREAKX(*(C 'f')) . R10
        OUTPUT = 'BREAKX ' R10
        S LEN(*N) . R11
        OUTPUT = 'LENV ' R11
        Y = *LEN(N + 1)
        P = 'a' Y
        S P . R12
        OUTPUT = 'RTPAT ' R12
        Z = *(N * 2)
END
SNO
cat > "$T/a2.sno" <<'SNO'
        N = 3
        Y = *N
        W = *(N + 1)
        V = EVAL('*N')
        Q = 'abcdef'
        Q LEN(3) . R
        OUTPUT = R ' ' EVAL(Y) ' ' EVAL(W) ' ' EVAL(V)
        DEFINE('F()')
        T = *F()
        N = 5
        OUTPUT = EVAL(Y) ' ' EVAL(T)
        P = POS(0) LEN(*N) . R2
        Q P
        OUTPUT = R2
        DUMP(1)                                  :(END)
F       F = N * 10                               :(RETURN)
END
SNO
cat > "$T/a3.sno" <<'SNO'
        DEFINE('G(K)')
        S = 'hello world'
        S BREAK(' ') $ *G('A')
        S BREAK(' ') . *G('B')
        T = 'HV'
        S BREAK(' ') $ *$T
        S ' ' REM . *G('C')
        OUTPUT = A ' ' B ' ' HV ' ' C
        S BREAK(' ') $ OUTPUT $ *G('D') FAIL
        OUTPUT = D
                                          :(END)
G       G = .$K                           :(NRETURN)
END
SNO
cat > "$T/a4.sno" <<'SNO'
        DEFINE('G(K)')
        N = 2
        'ABCDE' 'CD' @*$('CUR' N)
        OUTPUT = 'CUR2=' CUR2
        'ABCDE' 'B' @*G('CG')
        OUTPUT = 'CG=' CG
        P = 'C' @*G('CP')
        'ABCDE' P
        OUTPUT = 'CP=' CP
        Q = LEN(1) @*$('CQ' N)
        'ABCDE' ARB Q 'E'
        OUTPUT = 'CQ2=' CQ2
                                          :(END)
G       G = .$K                           :(NRETURN)
END
SNO
cat > "$T/a5.sno" <<'SNO'
        DEFINE('G(K)')
        N = 7
        P = LEN(2) . *G('PA') LEN(1) $ *G('PB')
        'ABCDE' P
        OUTPUT = 'PA=' PA ' PB=' PB
        Q = BREAK('D') . *$('X' N)
        'ABCDE' Q
        OUTPUT = 'X7=' X7
        R = 'B' LEN(1) . *G('RV')
        'ABCDE' R
        OUTPUT = 'RV=' RV
                                          :(END)
G       G = .$K                           :(NRETURN)
END
SNO
ORACLE=/home/resources/x64/bin/sbl
[ -x "$ORACLE" ] || { echo "UNPROVEN(2): correctness oracle absent at $ORACLE -- this gate grades against SPITBOL, never against SCRIP's own output"; exit 2; }
bad=0
for a in a4; do
    "$SCRIP" --compile --out="$T/$a.s" "$T/$a.sno" < /dev/null > /dev/null 2>&1 || { echo "  RED  $a -- does not compile"; bad=1; continue; }
    n=$(grep -cE 'EXPR(NM)?\$' "$T/$a.s")
    if [ "$n" -ne 0 ]; then echo "  RED  $a m4 -- the asm names a thunk on $n line(s): $(grep -m1 -E 'EXPR(NM)?\$' "$T/$a.s")"; bad=1; else echo "  ok   $a m4 -- the asm names no thunk (asm only: its runs reach rt_at_cursor's C road, a named bomb under CEO-1576)"; fi
done
for a in a1 a2 a3 a5; do
    want="$("$ORACLE" -bf "$T/$a.sno" < /dev/null 2>&1 | sed '/dump of keyword values/,$d' | tr '\n' '/')"
    [ -n "$want" ] || { echo "  UNPROVEN $a -- oracle produced no output; refusing to grade SCRIP against nothing"; exit 2; }
    for m in m3 m4; do
        if [ "$m" = m3 ]; then
            got="$(timeout -k 5 20s "$SCRIP" "$T/$a.sno" < /dev/null 2>&1 | sed '/dump of keyword values/,$d' | tr '\n' '/')"
        else
            "$SCRIP" --compile --out="$T/$a.s" "$T/$a.sno" < /dev/null > /dev/null 2>&1
            n=$(grep -cE 'EXPR(NM)?\$' "$T/$a.s")
            if [ "$n" -ne 0 ]; then echo "  RED  $a $m -- the asm names a thunk on $n line(s): $(grep -m1 -E 'EXPR(NM)?\$' "$T/$a.s")"; bad=1; fi
            gcc "$T/$a.s" -o "$T/$a.x" -L"$RT" -lscrip_rt -Wl,-rpath,"$RT" -lm -lpthread > /dev/null 2>&1 || { echo "  RED  $a $m -- link failed"; bad=1; continue; }
            got="$(timeout -k 5 20s "$T/$a.x" < /dev/null 2>&1 | sed '/dump of keyword values/,$d' | tr '\n' '/')"
        fi
        if [ "$got" = "$want" ]; then echo "  ok   $a $m -- matches SPITBOL"
        else echo "  RED  $a $m -- got [$got] want [$want]"; bad=1; fi
    done
done
if [ "$bad" -ne 0 ]; then echo "GATE RED(1) [sno-a-static-thunk-carries-no-name]: a reader still reaches a thunk by its name, or a thunk's name reached the asm"; exit 1; fi
echo "GATE GREEN(0) [sno-a-static-thunk-carries-no-name]: every deferred reader reaches a nameless thunk by its record, in both modes, against SPITBOL"
exit 0
