#!/usr/bin/env bash
# test_gate_sno_a_match_inside_eval_that_fails_after_a_backtrack_point_returns_from_its_chain.sh
#
# THE DEFECT (the cto 2026-10-02, ceo CEO-1419 ticket snobol4-a-match-inside-eval-that-fails-after-a-backtrack-point-or-meets-
# abort-crashes-scrip, found by Lon's infinite_snobol4 demo): EVAL of a pattern match whose last-emitted box keeps state on the
# spine (ARB, BAL, REM, TAB, RTAB, SPAN, BREAK, BREAKX, FENCE of ARB, ABORT) died of SIGSEGV, a general-protection fault on the
# chain's own ret, both modes: 'z' ? ARB FAIL, 'a' ? ABORT. sbl fails or matches.
# THE CAUSE: the chain's outer exits (bb_glue_outer_gamma / _omega) released bb_glue_framed_leave's op_fc_bytes, the per-node
# emission register, read after the node loop had finished -- so the exit popped the LAST EMITTED BOX's state size (ARB: 16)
# on top of the chain's own carve and returned through a word above the return address. An EVAL chain never carves the outer
# glue frame at all (only a legacy main graph enters it).
# THE CURE: the outer exits release exactly what the glue entry carved -- nothing when it was not entered, its carve when it
# was (emit.cpp _glue_carve) -- and the SCRIP_GLUE_SYM killswitch whose default arm was the defect is gone.
#
# Each arm grades the evaluator's line for one text, both modes, against sbl -bf cut AT RUN TIME. rc=0 clean · rc=1 a
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
cat > "$D/ev.sno" <<'SNO'
        &TRIM = 1
loop    line = INPUT                                            :F(END)
        &ERRLIMIT = 1000
        SETEXIT('errh')
        r = EVAL(line)                                          :S(ok)
        OUTPUT = 'FAIL'                                         :(loop)
ok      OUTPUT = DATATYPE(r) ' ' SIZE(r)                        :(loop)
errh    OUTPUT = 'ERROR ' &ERRTYPE                              :(loop)
END
SNO
cat > "$D/lines.txt" <<'TXT'
'z' ? ARB FAIL
'a' ? ABORT
'z' ? BAL FAIL
'1' ? TAB(0) | ARBNO(LEN(1))
'ab' ? 'y' &ARB | &COMPARE
'zz' ? REM FAIL
'zz' ? TAB(1) FAIL
'zz' ? RTAB(0) FAIL
'zz' ? SPAN('z') FAIL
'zz' ? BREAK('q') FAIL
'zz' ? BREAKX('q') FAIL
'zz' ? FENCE(ARB) FAIL
'zz' ? FENCE(ARB)
'zz' ? ABORT 'q'
'zz' ? &BAL FAIL
'zz' ? &REM FAIL
'zz' ? &ABORT
'zz' ? ARB
'zz' ? FAIL
TXT
N=$(wc -l < "$D/lines.txt")
( cd "$D" && timeout -k 5 30 "$SBL" -bf ev.sno < lines.txt > want 2>/dev/null )
[ "$(wc -l < "$D/want")" = "$N" ] || refuse "sbl -bf answered $(wc -l < "$D/want") of $N lines -- no expectation to grade against"
( cd "$D" && timeout -k 5 30 "$B/scrip" ev.sno < lines.txt > m3 2>/dev/null )
( cd "$D" && timeout -k 5 120 "$B/scrip" --compile ev.sno < /dev/null > ev.s 2>/dev/null && gcc -no-pie ev.s -L"$B/out" -lscrip_rt -lm -Wl,-rpath,"$B/out" -o ev.bin 2>/dev/null ) || refuse "mode 4 did not build the evaluator"
( cd "$D" && timeout -k 5 30 ./ev.bin < lines.txt > m4 2>/dev/null )
red=0; i=0
while IFS= read -r t; do
    i=$((i + 1))
    w=$(sed -n "${i}p" "$D/want"); a=$(sed -n "${i}p" "$D/m3"); b=$(sed -n "${i}p" "$D/m4")
    for m in m3 m4; do
        g=$a; [ $m = m4 ] && g=$b
        if [ "$g" = "$w" ]; then echo "  ok   $m  $t  ->  $w"; else echo "  FAIL $m  $t  ->  got '${g:-<none: the run died>}' want '$w'"; red=$((red + 1)); fi
    done
done < "$D/lines.txt"
if [ $red -eq 0 ]; then echo "GATE PASS(0): every match inside EVAL returns from its chain as sbl answers it, $N texts x 2 modes"; exit 0; fi
echo "GATE FAIL(1): $red of $((N * 2)) arm(s) diverge from sbl -bf"; exit 1
