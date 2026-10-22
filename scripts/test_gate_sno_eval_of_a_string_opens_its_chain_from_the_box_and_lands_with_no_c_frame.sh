#!/usr/bin/env bash
# test_gate_sno_eval_of_a_string_opens_its_chain_from_the_box_and_lands_with_no_c_frame.sh
#
# THE ROW (cto mint 2026-09-21, the cfo's): c2bb-the-eval-code-chain-road-is-the-one-measured-live-c-to-bb-left-in-the-cto-half-
# convert-it-to-open-and-land. EVAL of a string at an IR_CALL "EVAL" site reached its chain through C: the by-name dispatcher, EVAL_fn,
# eval_string_transient and eval_chain_run_guarded stayed on the stack while rt_chain_enter_v jumped into the box and took it back
# (the C2BB trace read chain.eval.v and chain.eval.guarded on OUTPUT = EVAL("3 + 4")).
# THE CURE: the site calls rt_eval_open (cache lookup or build, frame push, EVAL$ = FAIL, the EVAL stage), enters the chain through
# bb_glue_enter_chain_ret (the chain ret's through one pushed slot, as rt_chain_enter_v's chains do) and calls rt_eval_land (read
# EVAL$, restore it, keep or release the chain, restore g_error). rax = 0 is a DECLINE (a non-string, a numeric text, a text that does
# not build, SCRIP_EVAL_FAILS=0 or SCRIP_EVAL_OPEN=0) and the site falls back to the by-name C call, which owns every such case.
# THE UNWIND, MEASURED (the baton's first step): only core_setexit_handler_return sets SNO_LVL_UNWIND, and it unwinds only when
# g_setexit_resume >= 0, which only sno_setexit_fire_on_end sets, and core_setexit_on_end() is 0 -- so NO live path unwinds across an
# EVAL today. An error inside EVAL is quiet under the EVAL stage and the handler fires on the failure path of the statement holding
# the EVAL (IR_SETEXIT_TEST, after the EVAL has landed: a gdb trace reads open, land, then the handler); the out-of-memory road fires
# at once but its handler RETURN ends in error 242 on both roads. The eval_frames_unwind hook this landing first carried was deleted
# with the jump it guarded (rt_unwind_to_activation, CEO-1468): a path that sets SNO_LVL_UNWIND again is re-minted from its own red.
# ARMS, each both modes unless named: (A) the road -- the witness writes a C2BB trace with a positive control (EVAL(*X), a via.dtx
# crossing this row does not touch) and no chain.eval line; with SCRIP_EVAL_OPEN=0 the same program writes chain.eval lines, so the
# arm can see the road it grades (REFUSE when it cannot). (B) the emission -- the mode-4 text calls rt_eval_open and rt_eval_land.
# (C) seven SETEXIT/EVAL programs and a routing program agree with sbl -bf cut at run time (a handler RETURN and FRETURN out of a
# function whose EVAL failed, a handler inside a function the EVAL called, CONTINUE after an error inside EVAL, nested EVAL, quoted,
# parenthesised, numeric and deferred texts). (D) the stage the open road sets is gone after the EVAL lands: after a handler RETURN
# out of a function whose EVAL failed, an error at &ERRLIMIT 0 is fatal exactly as in the same program without the EVAL (sbl stalls on
# the EVAL form, its own defect, so the control is the no-EVAL program). (E) the collector: a 40-pass EVAL loop with nested EVAL and heap churn
# agrees with sbl at SCRIP_GC_STRESS=1 and really collects.
# FAIL-ONCE, MEASURED: arm (A) reads RED on the parent (8a3517809, measured with the open road switched off on this binary and on the
# parent's own DONE-WHEN: 2 chain.eval crossings); (B) has no rt_eval_open on the parent. rc=0 clean · rc=1 a divergence · rc=2 REFUSAL.
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
RT="$B/out"; RC=0; n=0
m3() { (cd "$D" && timeout -k 5 60 "$B/scrip" "$1.sno" < /dev/null 2>&1); }
m4() { "$B/scrip" --compile -o "$D/$1.s" "$D/$1.sno" < /dev/null > /dev/null 2>&1 && gcc -no-pie -o "$D/$1.bin" "$D/$1.s" -L "$RT" -lscrip_rt -lm -Wl,-rpath,"$RT" 2> /dev/null \
      || { echo "M4-BUILD-FAILED"; return; }; (cd "$D" && timeout -k 5 60 "./$1.bin" < /dev/null 2>&1); }
ok()  { n=$((n + 1)); echo "  ok    $*"; }
red() { n=$((n + 1)); RC=1; echo "  RED   $*"; }
cat > "$D/road.sno" <<'SNO'
        OUTPUT = EVAL("3 + 4")
        X = 5
        OUTPUT = EVAL(*X)
END
SNO
for o in 1 0; do (cd "$D" && SCRIP_EVAL_OPEN=$o SCRIP_C2BB_TRACE="$D/road$o.tr" timeout -k 5 60 "$B/scrip" road.sno < /dev/null > "$D/road$o.out" 2>&1); done
[ -s "$D/road1.tr" ] || refuse "the positive control EVAL(*X) wrote no C2BB line -- the trace is not honoured, so arm A cannot measure"
grep -q 'chain\.eval' "$D/road0.tr" 2>/dev/null || refuse "with SCRIP_EVAL_OPEN=0 the program wrote no chain.eval line -- the arm cannot see the C road it grades"
if [ "$(tr '\n' '|' < "$D/road1.out")" = "7|5|" ] && ! grep -q 'chain\.eval' "$D/road1.tr"; then ok "A road: EVAL(\"3 + 4\") prints 7 with no chain.eval crossing ($(cut -f1 "$D/road1.tr" | sort -u | tr '\n' ' ')written by the control; the switch-off run writes $(grep -c 'chain\.eval' "$D/road0.tr"))"
else red "A road: out [$(tr '\n' '|' < "$D/road1.out")] trace [$(cut -f1 "$D/road1.tr" | tr '\n' ' ')]"; fi
"$B/scrip" --compile -o "$D/road.s" "$D/road.sno" < /dev/null > /dev/null 2>&1 || refuse "the witness does not compile in mode 4"
if grep -q 'rt_eval_open' "$D/road.s" && grep -q 'rt_eval_land' "$D/road.s"; then ok "B emission: the mode-4 text calls rt_eval_open and rt_eval_land"; else red "B emission: no rt_eval_open/rt_eval_land call in the mode-4 text"; fi
cat > "$D/u1.sno" <<'SNO'
        DEFINE('F()')
        &ERRLIMIT = 5
        SETEXIT(.H)
        OUTPUT = 'F=' F()                   :F(FF)
        OUTPUT = 'after'                    :(END)
FF      OUTPUT = 'F failed'                 :(END)
F       Z = 0
        F = EVAL('1 / Z')
        OUTPUT = 'in F after EVAL ' F       :(RETURN)
H       OUTPUT = 'handler ' &ERRTYPE ' level ' &FNCLEVEL     :(RETURN)
END
SNO
sed 's/:(RETURN)$/:(FRETURN)/' "$D/u1.sno" | sed '0,/:(FRETURN)/s//:(RETURN)/' > "$D/u2.sno"
cat > "$D/u3.sno" <<'SNO'
        DEFINE('F()')
        DEFINE('G()')
        &ERRLIMIT = 5
        SETEXIT(.H)
        OUTPUT = 'F=' F()                   :F(FF)
        OUTPUT = 'after ' EVAL('2 + 3')     :(END)
FF      OUTPUT = 'F failed'                 :(END)
F       F = EVAL('G()')
        OUTPUT = 'in F after EVAL ' F       :(RETURN)
G       Z = 0
        G = 1 / Z
        OUTPUT = 'in G after error'         :(RETURN)
H       OUTPUT = 'handler ' &ERRTYPE ' level ' &FNCLEVEL     :(RETURN)
END
SNO
cat > "$D/u4.sno" <<'SNO'
        &ERRLIMIT = 5
        SETEXIT(.H)
        Z = 0
        X = EVAL('1 / Z')                   :S(S1)F(F1)
S1      OUTPUT = 'eval succeeded ' X        :(N1)
F1      OUTPUT = 'eval failed'
N1      OUTPUT = 'next ' &ERRLIMIT          :(END)
H       OUTPUT = 'handler ' &ERRTYPE ' level ' &FNCLEVEL     :(CONTINUE)
END
SNO
cat > "$D/u6.sno" <<'SNO'
        DEFINE('F()')
        &ERRLIMIT = 5
        SETEXIT(.H)
        OUTPUT = 'F=' F()                   :F(FF)
        OUTPUT = 'after'                    :(END)
FF      OUTPUT = 'F failed'                 :(END)
F       Z = 0
        F = EVAL('1 / Z')                   :F(F2)
        OUTPUT = 'in F after EVAL ' F       :(RETURN)
F2      OUTPUT = 'in F eval failed'         :(RETURN)
H       OUTPUT = 'handler ' &ERRTYPE ' level ' &FNCLEVEL     :(CONTINUE)
END
SNO
cat > "$D/u7.sno" <<'SNO'
        DEFINE('F()')
        &ERRLIMIT = 5
        SETEXIT(.H)
        OUTPUT = 'F=' F()                   :F(FF)
        OUTPUT = 'after ' EVAL('6 * 7')     :(END)
FF      OUTPUT = 'F failed'                 :(END)
F       Z = 0
        F = EVAL("EVAL('1 / Z') 'x'")       :F(F2)
        OUTPUT = 'in F after EVAL ' F       :(RETURN)
F2      OUTPUT = 'in F eval failed'         :(RETURN)
H       OUTPUT = 'handler ' &ERRTYPE ' level ' &FNCLEVEL     :(RETURN)
END
SNO
cat > "$D/u10.sno" <<'SNO'
        DEFINE('F()')
        &ERRLIMIT = 5
        SETEXIT(.H)
        OUTPUT = 'F=' F()                   :F(FF)
        Z = 0
        Y = 1 / Z
        OUTPUT = 'after error, errlimit ' &ERRLIMIT   :(END)
FF      OUTPUT = 'F failed'                 :(END)
F       Z = 0
        F = 1 / Z
        OUTPUT = 'in F after EVAL ' F       :(RETURN)
H       OUTPUT = 'handler ' &ERRTYPE ' level ' &FNCLEVEL     :(RETURN)
END
SNO
cat > "$D/o4.sno" <<'SNO'
        X = 'a b'
        OUTPUT = EVAL("'(' X ')'")
        OUTPUT = EVAL('(3)')
        OUTPUT = EVAL("'q'")
        OUTPUT = EVAL('12')
        OUTPUT = EVAL(' 12')
        OUTPUT = EVAL('1.5')
        OUTPUT = EVAL('-7')
        OUTPUT = EVAL('*X') ' ' DATATYPE(EVAL('*X'))
END
SNO
for p in u1 u2 u3 u4 u6 u7 u10 o4; do
    w=$(cd "$D" && timeout -k 5 10 "$SBL" -bf "$p.sno" < /dev/null 2>/dev/null | grep -v '^$' | tr '\n' '|')
    [ -n "$w" ] || refuse "sbl printed nothing for $p"
    g3=$(m3 "$p" | grep -v '^$' | tr '\n' '|'); g4=$(m4 "$p" | grep -v '^$' | tr '\n' '|')
    if [ "$w" = "$g3" ] && [ "$w" = "$g4" ]; then ok "C $p agrees with sbl: $w"; else red "C $p: sbl [$w] m3 [$g3] m4 [$g4]"; fi
done
cat > "$D/s1.sno" <<'SNO'
        DEFINE('F()')
        &ERRLIMIT = 1
        SETEXIT(.H)
        OUTPUT = 'F=' F()
        &ERRLIMIT = 0
        Z = 0
        Y = 1 / Z
        OUTPUT = 'not reached'              :(END)
F       Z = 0
        F = EVAL('1 / Z')
        OUTPUT = 'in F after EVAL'          :(RETURN)
H       OUTPUT = 'handler ' &ERRTYPE        :(RETURN)
END
SNO
sed 's/        F = EVAL(.1 \/ Z.)/        F = 1 \/ Z/' "$D/s1.sno" > "$D/s0.sno"
grep -q "F = 1 / Z" "$D/s0.sno" || refuse "the no-EVAL control did not build"
for m in m3 m4; do
    a=$($m s1 | grep -v '^$' | grep -v '^  at ' | tr '\n' '|'); c=$($m s0 | grep -v '^$' | grep -v '^  at ' | tr '\n' '|')
    if [ "$a" = "$c" ] && printf '%s' "$a" | grep -q 'error 14:' && ! printf '%s' "$a" | grep -q 'not reached'; then ok "D $m the stage is cleared by the unwind: $a"
    else red "D $m with EVAL [$a] without [$c]"; fi
done
cat > "$D/gs.sno" <<'SNO'
        SUBJ = 'alpha beta gamma delta epsilon zeta eta theta iota kappa'
        N = 0
LOOP    N = N + 1
        SUBJ ('beta' . B)
        JUNK = SUBJ SUBJ SUBJ SUBJ SUBJ SUBJ SUBJ SUBJ
        R = EVAL('3 + 4')
        D = EVAL("DUPL('ab', N) 'x'")
        T = "DUPL('cd', 7)"
        Q = EVAL('SIZE(EVAL(T)) + N')
        LT(N, 40)                                             :S(LOOP)
        OUTPUT = 'R=' R ' B=' B ' N=' N ' D=' SIZE(D) ' Q=' Q
END
SNO
w=$(cd "$D" && timeout -k 5 10 "$SBL" -bf gs.sno < /dev/null 2>/dev/null | tr '\n' '|')
[ "$w" = "R=7 B=beta N=40 D=81 Q=54|" ] || refuse "sbl reads the collector witness otherwise: [$w]"
g3=$(cd "$D" && SCRIP_GC_STRESS=1 SCRIP_GC_MAPS=1 timeout -k 5 120 "$B/scrip" gs.sno < /dev/null 2> "$D/gs.maps" | tr '\n' '|')
coll=$(grep -c '^\[GC-WALK\] pop=' "$D/gs.maps")
[ "$coll" -gt 0 ] || refuse "the collector witness collected zero times at SCRIP_GC_STRESS=1 -- arm E cannot measure"
m4 gs > /dev/null; g4=$(cd "$D" && SCRIP_GC_STRESS=1 timeout -k 5 120 ./gs.bin < /dev/null 2>/dev/null | tr '\n' '|')
if [ "$w" = "$g3" ] && [ "$w" = "$g4" ]; then ok "E collector: SCRIP_GC_STRESS=1 agrees with sbl in both modes over $coll collections: $w"; else red "E collector: sbl [$w] m3 [$g3] m4 [$g4]"; fi
[ $RC = 0 ] && echo "GATE PASS(0) [eval_of_a_string_opens_its_chain_from_the_box_and_lands_with_no_c_frame]: $n arms"
[ $RC = 0 ] || echo "GATE FAIL(1) [eval_of_a_string_opens_its_chain_from_the_box_and_lands_with_no_c_frame]: an EVAL site's road, its unwind or its answer differs"
exit $RC
