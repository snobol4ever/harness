#!/usr/bin/env bash
# test_gate_sno_an_operand_pushed_before_a_match_is_read_after_its_frame_is_whacked.sh
#
# THE ROWS (ceo CEO-1466, one cure for both): snobol4-an-alternation-whose-right-operand-is-a-match-loses-its-left-operand-the-pbalt-
# marshal-reads-an-unwritten-stack-slot (the cfo's) and snobol4-an-argument-evaluated-before-a-match-in-a-later-argument-is-read-from-
# the-wrong-stack-slot (the cto's, BLOCKED on it). From the ceo's CEO-1461 seed-1205 GP fault, reduced by hq_icon (FINDING-2026-10-03-
# hq_icon-eval-chain-reads-an-unwritten-stack-slot-as-an-alternation-operand) and the cfo: P = 'k' | ('xyz' ? 'y') then 'zzk' ? P . V
# read V = '' where sbl -bf reads k, in both modes, compiled or EVAL'd; DUPL, REPLACE, LPAD and a three-arm alternation the same way;
# with pointer-shaped stale bytes it was the strlen fault under rcp_of.
# THE CAUSE (the cfo in the emission, the cto in emit.cpp): a call's operand pushed BEFORE a value-context match and read AFTER it was
# addressed 96 bytes too high ([rsp + 176] for a cell at [rsp + 80]): the zd read loop (emit.cpp, the g_zd_read loop) added 64 +
# emit_match_begin_frame_extra for every IR_MATCH_BEGIN between producer and consumer, but every IR_MATCH_END ends in release_pump's
# frame whack (mov rsp, rbp; pop rbp), so a match whose END also lies between them has no frame left on the stack.
# THE CURE (the cto's, b96c81f66, landed by the cfo under CEO-1466): walking back from the consumer, an IR_MATCH_END opens a closed
# region (counted) and nothing inside it, its IR_MATCH_BEGIN included, adds height -- that frame and every byte pushed inside it are
# gone. An operand read INSIDE an open match is unchanged. The cto's own gate, ..._reads_its_own_slot.sh, carries nine direct shapes
# and seven EVAL lines; this one adds the bounds that were never wrong and the crash witness on both EVAL roads.
#
# ARMS, both modes, every expectation cut from sbl -bf at run time: (1) the alternation row's two lines; (2) the cto row's six (an
# alternation, DUPL, REPLACE, a three-arm alternation, LPAD with a nested alternation, and concatenation, which was never wrong);
# (3) the bounds that were never wrong (a match on the left of the alternation, concatenation either side, arithmetic) stay right;
# (4) hq_icon's three-line crash witness through its copy of the infinite_snobol4 evaluator (md5 4ce880cc, embedded verbatim: the
# crash needs the stale bytes this exact driver leaves) on the C road (SCRIP_EVAL_OPEN=0), where mode 3 died SIGSEGV on the parent,
# and on the open road.
# FAIL-ONCE, MEASURED on the parent (SCRIP c0fbd4343 without the cure, rebuilt; the cfo's first, equivalent edit stashed): both rows' DONE-WHENs RED in m3 and m4 (V= ; alt
# right, dupl, replace, alt3 empty, lpad ****) and the crash witness SIGSEGV in mode 3 on the C road. rc=0 clean · rc=1 · rc=2 REFUSAL.
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
m4build() { "$B/scrip" --compile --out="$D/$1.s" "$D/$1.sno" < /dev/null > /dev/null 2>&1 && gcc -no-pie -o "$D/$1.bin" "$D/$1.s" -L "$RT" -lscrip_rt -lm -Wl,-rpath,"$RT" 2> /dev/null; }
cat > "$D/alt.sno" <<'SNO'
        P = 'k' | ('xyz' ? 'y')
        'zzk' ? P . V
        OUTPUT = 'V=' V
        Q = ('xyz' ? 'y') | 'k'
        'zzk' ? Q . W
        OUTPUT = 'W=' W
END
SNO
cat > "$D/args.sno" <<'SNO'
        P = 'k' | ('xyz' ? 'y')
        'zzk' ? P . V
        OUTPUT = 'alt right ' V
        OUTPUT = 'dupl ' DUPL('ab', SIZE('xyz' ? 'y'))
        OUTPUT = 'replace ' REPLACE('abc', ('xyz' ? 'y'), 'Y')
        R = 'k' | ('xyz' ? 'y') | 'm'
        'zzm' ? R . U
        OUTPUT = 'alt3 ' U
        OUTPUT = 'lpad ' LPAD('ab', SIZE('xyz' ? ('x' | 'y')) + 3, '*')
        OUTPUT = 'concat ' 'k' ('xyz' ? 'y')
END
SNO
cat > "$D/bounds.sno" <<'SNO'
        X = 'a' (']' ? *']')
        OUTPUT = 'concat right: [' X ']'
        X = (']' ? *']') 'a'
        OUTPUT = 'concat left: [' X ']'
        Y = SIZE('abc') + SIZE('xyz' ? 'y')
        OUTPUT = 'arith: [' Y ']'
        P = ('xyz' ? 'y') | 'k'
        'zzk' ? P . V                               :F(F2)
        OUTPUT = 'alt left match: [' V ']'          :(END)
F2      OUTPUT = 'alt left match: fails'
END
SNO
for p in alt args bounds; do
    w=$(cd "$D" && timeout -k 5 10 "$SBL" -bf "$p.sno" < /dev/null 2>/dev/null | tr '\n' '|')
    [ -n "$w" ] || refuse "sbl printed nothing for $p"
    g3=$(cd "$D" && timeout -k 5 10 "$B/scrip" "$p.sno" < /dev/null 2>/dev/null | tr '\n' '|')
    m4build "$p" || refuse "$p does not build in mode 4"
    g4=$(cd "$D" && timeout -k 5 10 "./$p.bin" < /dev/null 2>/dev/null | tr '\n' '|')
    n=$((n + 1)); if [ "$w" = "$g3" ] && [ "$w" = "$g4" ]; then echo "  ok    $p agrees with sbl, both modes: $w"; else RC=1; echo "  RED   $p: sbl [$w] m3 [$g3] m4 [$g4]"; fi
done
cat > "$D/ev.sno" <<'SNO'
*  inf_eval.sno -- the evaluator of infinite_snobol4: one SNOBOL4 expression per line of standard input, EVALed, one
*  result line out, so SPITBOL and SCRIP running it on the same lines can be compared line for line. SETEXIT traps
*  every error, EVAL's compile errors included, and the loop keeps going (Lon 2026-10-02).
*  THE VARIABLES a..z BELONG TO THE TEST (Lon 2026-10-02, in-chat to the ceo: "So never use variable a..z since they are
*  used by the test for simplicity."): every name of this program is inf_-prefixed, because SNOBOL4 scope is dynamic and
*  an EVALed (k = 5) would otherwise stomp the evaluator's own counter. A batch's PRE-SET lines give a..z their values
*  and the batch code may stomp on them (Lon: "They can be stomped on. That is the fun of the batch."); state lives for
*  the whole batch, one process per batch. f, g and h are the test's three functions, one per return shape: f(x) is a
*  value (x + 1), g(x) a pattern built at run time (x | 'c'), h(x) a name (.t[x], by NRETURN, failing when t[x] is null).
        &TRIM = 1
        inf_safe = DUPL('.', 32) SUBSTR(&ALPHABET, 33, 95) DUPL('.', 129)
        DEFINE('inf_render(inf_value)inf_dtype')                :(inf_render_end)
inf_render
        inf_dtype = DATATYPE(inf_value)
        inf_render = inf_dtype
        IDENT(inf_dtype, 'STRING')                              :S(inf_render_s)
        IDENT(inf_dtype, 'INTEGER')                             :S(inf_render_n)
        IDENT(inf_dtype, 'REAL')                                :S(inf_render_n)F(RETURN)
inf_render_s
        inf_render = inf_dtype ' ' SIZE(inf_value) ' ' REPLACE(inf_value, &ALPHABET, inf_safe) :(RETURN)
inf_render_n
        inf_render = inf_dtype ' ' inf_value                    :(RETURN)
inf_render_end
        DEFINE('f(inf_arg)')                                    :(inf_f_end)
f       f = inf_arg + 1                                         :(RETURN)
inf_f_end
        DEFINE('g(inf_arg)')                                    :(inf_g_end)
g       g = inf_arg | 'c'                                       :(RETURN)
inf_g_end
        DEFINE('h(inf_arg)')                                    :(inf_h_end)
h       DIFFER(t[inf_arg])                                      :F(FRETURN)
        h = .t[inf_arg]                                         :(NRETURN)
inf_h_end
inf_loop
        inf_line = INPUT                                        :F(END)
        &ERRLIMIT = 1000
        SETEXIT('inf_errh')
        inf_result = EVAL(inf_line)                             :S(inf_ok)
        OUTPUT = 'FAIL'                                         :(inf_loop)
inf_ok  OUTPUT = inf_render(inf_result)                         :(inf_loop)
inf_errh
        OUTPUT = 'ERROR ' &ERRTYPE                              :(inf_loop)
END
SNO
printf '%s\n' '"b" ? LEN(1)^ LEN(2)' 'FENCE' "'(matched [things])' ?&STLIMIT | (']' ? *']')" > "$D/ev.txt"
w=$(cd "$D" && timeout -k 5 10 "$SBL" -bf ev.sno < ev.txt 2>/dev/null | tr '\n' '|')
[ "$w" = "ERROR 233|PATTERN|PATTERN|" ] || refuse "sbl reads the crash witness otherwise: [$w]"
m4build ev || refuse "the crash witness's evaluator does not build in mode 4"
for o in 1; do
    g3=$(cd "$D" && SCRIP_EVAL_OPEN=$o timeout -k 5 20 "$B/scrip" ev.sno < ev.txt 2>&1 | tr '\n' '|')
    g4=$(cd "$D" && SCRIP_EVAL_OPEN=$o timeout -k 5 20 ./ev.bin < ev.txt 2>&1 | tr '\n' '|')
    n=$((n + 1)); if [ "$w" = "$g3" ] && [ "$w" = "$g4" ]; then echo "  ok    crash witness, SCRIP_EVAL_OPEN=$o, both modes: $w (the SCRIP_EVAL_OPEN=0 arm is retired: the C road it re-armed is DELETED under CEO-1576 and bombs by design, ceo CEO-1630)"; else RC=1; echo "  RED   crash witness SCRIP_EVAL_OPEN=$o: sbl [$w] m3 [$g3] m4 [$g4]"; fi
done
[ $RC = 0 ] && echo "GATE PASS(0) [an_operand_pushed_before_a_match_is_read_after_its_frame_is_whacked]: $n arms agree with sbl"
[ $RC = 0 ] || echo "GATE FAIL(1) [an_operand_pushed_before_a_match_is_read_after_its_frame_is_whacked]: an operand read across a closed match differs from sbl"
exit $RC
