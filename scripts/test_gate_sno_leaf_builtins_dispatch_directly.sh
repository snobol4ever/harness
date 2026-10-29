#!/usr/bin/env bash
export S4E_ONE_RUNNER_FIXTURE="gate arm ${0##*/}: a runner invoked as an instrument fixture, not a board (CEO-523)"
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
# test_gate_sno_leaf_builtins_dispatch_directly.sh -- A SNOBOL4 LEAF SYSTEM FUNCTION IS CALLED THROUGH rt_call_bid_sn4, NOT THE BY-NAME
# WRAPPER LAYERS (ceo 2026-09-24, CEO-1249, the speed campaign). The emitter bakes BID_BAKE_LEAF into the bid word of a call site whose
# name is in g_sn4_leaf_fns (snobol4_system_fns.h: the system functions that never run emitted code -- no EVAL/APPLY/CODE/SORT/DEFINE
# and no I/O -- so no RETURN can unwind through them and no per-call error frame is needed) and calls rt_call_bid_sn4, which goes
# straight to the dispatcher and falls back to the full by-name path whenever &ERROR or &ERRLIMIT is armed (the only modes in which
# the per-call setjmp frame is ever used: core_runtime_error longjmps only when g_error != 0, and the SETEXIT path pushes its own frame).
# THREE ARMS: (1) the emitted .s of a witness carries rt_call_bid_sn4 for SIZE/REPLACE/... and rt_call_arr_bl_sn4 for EVAL (a non-leaf);
# with SCRIP_SN4_DIRECT=0 (the control arm) no site carries rt_call_bid_sn4; (2) a witness exercising every leaf builtin prints the
# oracle's lines in m3 and m4 under both arms; (3) the error modes: with &ERRLIMIT = 1 an error inside a leaf builtin FAILS the statement
# and the program goes on (= the oracle), under both arms. EXIT 0 all arms; 1 a red (named); 2 REFUSED (oracle or binary missing).
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)" || { echo "REFUSE(2): no SCRIP beside harness at $HERE/../../SCRIP (a port root) -- this gate measures SCRIP and cannot from here"; exit 2; }
. "$HERE/lib_oracle_flags.sh"
SBL="$(sbl_correctness_bin)"; [ -x "$SBL" ] || { echo "REFUSED(2): correctness oracle missing ($SBL)"; exit 2; }
[ -x "$ROOT/scrip" ] || { echo "REFUSED(2): $ROOT/scrip not built"; exit 2; }
W="$(mktemp -d)"; trap 'rm -rf "$W"' EXIT
cat > "$W/leaf.sno" <<'SNO'
        s = 'The quick brown fox'
        OUTPUT = SIZE(s) ' ' SUBSTR(s, 5, 5) ' ' REPLACE(s, 'o', '0') ' ' REVERSE('abc') ' ' DUPL('-', 4) ' ' TRIM('ab   ')
        OUTPUT = LPAD('7', 3, '0') ' ' RPAD('7', 3, '.') ' ' INTEGER(12) INTEGER('x') ' ' REMDR(17, 5) ' ' CHAR(65) ' ' DATATYPE(3) ' ' DATATYPE(s)
        OUTPUT = IDENT(s, s) 'i' DIFFER(s, 'x') 'd' LT(1, 2) 'lt' GT(2, 1) 'gt' EQ(3, 3) 'eq' NE(3, 4) 'ne' LE(1, 1) 'le' GE(2, 2) 'ge'
        OUTPUT = LGT('b', 'a') 'lgt' LLT('a', 'b') 'llt' LEQ('a', 'a') 'leq' LNE('a', 'b') 'lne' LGE('b', 'a') 'lge' LLE('a', 'a') 'lle'
        s POS(0) LEN(3) . w1 ' ' SPAN('abcdefghijklmnopqrstuvwxyz') . w2 ' ' BREAK(' ') . w3 ' ' (ANY('f') NOTANY(' ')) . w4 RPOS(0)
        OUTPUT = w1 '|' w2 '|' w3 '|' w4
        s TAB(3) . t1 RTAB(4) . t2 ARBNO('x') . t3 FENCE('fox') . t4
        OUTPUT = t1 '|' t2 '|' t3 '|' t4
        t = TABLE(); t['k'] = 'v'; a = ARRAY('2,3'); a[1,2] = 7
        OUTPUT = ITEM(t, 'k') ' ' ITEM(a, 1, 2) ' ' PROTOTYPE(a) ' ' COPY(a)[1,2] ' ' SIZE(PROTOTYPE(a))
        OUTPUT = (SQRT(16.0) + SIN(0.0) + COS(0.0) + EXP(0.0) + LN(1.0) + ATAN(0.0) + TAN(0.0)) ' ' CHOP(3.7) ' ' (DATE() ? 'date' ) ' ' (TIME() ? 'time')
        OUTPUT = EVAL('1 + 2')
END
SNO
# THE ERROR-MODE ARM IS GRADED AGAINST THE ORACLE since the row snobol4-builtin-argument-errors-are-silent-where-spitbol-raises-them-under-errlimit
# closed: SPITBOL raises an error inside DUPL('x','abc') (90) and SUBSTR('abc','q',1) (193) and, with &ERRLIMIT = 2, fails each statement with
# &ERRTYPE set; SCRIP now raises the same two (the witness read &ERRLIMIT = 1 until 2026-10-09, where the SECOND error is fatal in both, so the
# by-name run stopped at statement 5 and this gate refused: the coo's pass 43).
cat > "$W/errlimit.sno" <<'SNO'
        &ERRLIMIT = 2
        OUTPUT = 'before'
        x = DUPL('x', 'abc')
        OUTPUT = 'after: ' &ERRTYPE ' kept ' x
        y = SUBSTR('abc', 'q', 1)
        OUTPUT = 'after: ' &ERRTYPE ' kept ' y
        OUTPUT = 'end'
END
SNO
red=0
"$SBL" $(sbl_lang_flags) "$W/leaf.sno" < /dev/null > "$W/leaf.ref" 2>&1 || true
[ -s "$W/leaf.ref" ] || { echo "REFUSED(2): the oracle printed nothing for the leaf witness"; exit 2; }
( cd "$W" && timeout -k 5 20 "$SBL" $(sbl_lang_flags) errlimit.sno < /dev/null > "$W/errlimit.ref" 2>&1 ); grep -q '^end$' "$W/errlimit.ref" || { echo "REFUSED(2): the oracle did not run the error-mode witness to its end"; head -4 "$W/errlimit.ref"; exit 2; }
for arm in on off; do
    if [ "$arm" = on ]; then unset SCRIP_SN4_DIRECT; else export SCRIP_SN4_DIRECT=0; fi
    ( cd "$W" && "$ROOT/scrip" --compile --out="$W/leaf_$arm.s" leaf.sno < /dev/null > /dev/null 2>&1 ) || { echo "RED: leaf.sno did not compile (arm $arm)"; red=1; continue; }
    nd=$(grep -cE 'call +(qword ptr \[rip \+ )?rt_call_bid_sn4' "$W/leaf_$arm.s"); nb=$(grep -cE 'call +(qword ptr \[rip \+ )?rt_call_arr_bl_sn4' "$W/leaf_$arm.s")
    if [ "$arm" = on ]; then [ "$nd" -ge 30 ] && [ "$nb" -eq 1 ] && echo "ok  arm on: $nd direct leaf sites, $nb by-name site (EVAL stays by name; the predicates and the pattern builtins inside patterns are their own boxes, so 32 of the witness's 33 by-name sites are leaf calls)" || { echo "RED arm on: direct sites=$nd (want >= 30) by-name sites=$nb (want exactly 1: EVAL)"; red=1; }
    else [ "$nd" -eq 0 ] && echo "ok  arm off: 0 direct sites, $nb by-name sites" || { echo "RED arm off: $nd direct sites under SCRIP_SN4_DIRECT=0"; red=1; }; fi
    for w in leaf errlimit; do
        ( cd "$W" && timeout -k 5 20 "$ROOT/scrip" "$w.sno" < /dev/null > "$W/$w.$arm.m3" 2>&1 ); cmp -s "$W/$w.$arm.m3" "$W/$w.ref" && echo "ok  $w m3 arm $arm = oracle" || { echo "RED $w m3 arm $arm differs from the oracle:"; diff "$W/$w.ref" "$W/$w.$arm.m3" | head -6; red=1; }
        if ( cd "$W" && "$ROOT/scrip" --compile --out="$W/$w.$arm.s" "$w.sno" < /dev/null > /dev/null 2>&1 && gcc "$W/$w.$arm.s" -L"$ROOT/out" -lscrip_rt -lm -Wl,-rpath,"$ROOT/out" -o "$W/$w.$arm.bin" 2>/dev/null ); then
            ( cd "$W" && timeout -k 5 20 "./$w.$arm.bin" < /dev/null > "$W/$w.$arm.m4" 2>&1 ); cmp -s "$W/$w.$arm.m4" "$W/$w.ref" && echo "ok  $w m4 arm $arm = oracle" || { echo "RED $w m4 arm $arm differs from the oracle:"; diff "$W/$w.ref" "$W/$w.$arm.m4" | head -6; red=1; }
        else echo "RED $w m4 arm $arm did not build"; red=1; fi
    done
done
unset SCRIP_SN4_DIRECT
[ "$red" -eq 0 ] && { echo "GATE OK: leaf system functions dispatch directly, the control arm restores the by-name path, and both arms match the oracle in both modes"; exit 0; }
echo "GATE FAILED: see the RED lines above"; exit 1
