#!/usr/bin/env bash
# test_gate_sno_a_fence_before_a_run_or_inside_an_arbno_body_retries_what_follows_it.sh -- FENCE(P) COMMITS P, NOT WHAT
# FOLLOWS IT: after a one-argument FENCE succeeds, an alternation, an ARBNO or an ARB to its RIGHT is still retried when a
# later element fails, exactly as SPITBOL does (hq_snocone 2026-09-27, found under the Snocone and Pascal self-hosted parsers;
# Lon 2026-09-27: "Get the parser_*.sc programs to 100%.").
#
# MECHANISM, measured by ASM-DIFF between a passing and a failing sibling in one mode: src/lower/lower_snobol4.c's TT_SEQ
# lowering builds a fenced sequence RIGHT TO LEFT and, after building FENCE1, re-routes the right-hand run's failure exit into
# the FENCE's beta through right_tail. For a MULTI-element run right_tail held the run's LAST element (its resume node), so the
# last element's omega jumped straight to match_fence1_beta and every alternative between the FENCE and it was skipped:
#     'xabc' ? FENCE('x') ('a' | 'ab') 'c'          SPITBOL succeeds, SCRIP failed in m3 and m4.
# And TT_ARBNO takes its body range (operands 1 and 2, which the emitter scans for the body's tail beta) as the first and the
# last node BUILT, which for a right-to-left fenced body is the wrong end, so resuming an iteration fell to the body's FIRST
# element instead of the inner ARBNO that could grow:
#     '{c:bb}' ? POS(0) '{' ARBNO('c' FENCE('') ':' ARBNO('b')) '}' RPOS(0)       SPITBOL succeeds, SCRIP failed.
# CURE: right_tail is the run's FIRST element for a multi-element run; the fenced TT_SEQ publishes the last node built for its
# rightmost segment with the entry it returns, and ARBNO uses it (entry and that node) when the entry is its own body's.
# AND THE SAME CURE CLOSES hq_snocone's 2026-09-16 row runtime-built-fence-with-an-argument-under-a-nested-arbno-fails-a-match-spitbol-makes
# (witness 11, the finding at .github 9ac79865b): F = FENCE('0'), T = F ARBNO('*' F), X = T ARBNO('+' T) built through INDIRECT
# assignment targets, '0*0' ? POS(0) X RPOS(0) -- SPITBOL matches; SCRIP failed in m3 and m4 on the unpatched tree (A/B on one base).
# STILL OPEN, not armed here (with the cto): ARBNO(P) with the fenced sequence held in a VARIABLE (a PAT$ graph whose fenced
# body root meets the zeta seam-tier check): P1 = 'c' FENCE('+' | '') ':' ARBNO('b'); '{c:bb}' ? POS(0) '{' ARBNO(P1) '}' RPOS(0).
#
# AND WITNESS 12 (hq_snobol4's bisect of rungs entry arbno_fence_span_branch_7 to cc0e5a2a6): ARBNO(FENCE('+') SPAN(d) . L1),
# a fenced body whose rightmost segment ends in a conditional capture -- the ARBNO's range operands must span the WHOLE body in
# the emitter's order (a gamma-first DFS from the body entry), and its resume operand is the body's rightmost tail, or the capture
# record is read as outside the ARBNO (rt_dcap_pump: CORRUPT CAPTURE ENTRY) and the match fails.
# ARMS: (1) mode 3 and (2) mode 4 run one witness program of twelve statements, each printing a YES or NO line; the ref is CUT FROM
# THE ORACLE at run time and every line must match byte for byte. Two control lines (no FENCE; nested ARBNO without a FENCE)
# were green before the cure and must stay green.
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
set -uo pipefail
G="$(basename "${BASH_SOURCE[0]}" .sh)"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)" || { echo "REFUSE(2): no SCRIP beside harness at $HERE/../../SCRIP (a port root) -- this gate measures SCRIP and cannot from here"; exit 2; }
SCRIP="${SCRIP_BIN:-$ROOT/scrip}"; [ -x "$SCRIP" ] || { echo "⛔ GATE REFUSE(2) [$G]: no scrip at $SCRIP"; exit 2; }
LIBDIR="$ROOT/out"; [ -f "$LIBDIR/libscrip_rt.so" ] || { echo "⛔ GATE REFUSE(2) [$G]: no libscrip_rt.so in $LIBDIR"; exit 2; }
SBL="${SBL_BIN:-/home/resources/x64/bin/sbl}"; [ -x "$SBL" ] || { echo "⛔ GATE REFUSE(2) [$G]: no sbl at $SBL -- this gate's ref is CUT FROM THE ORACLE at run time, never typed"; exit 2; }
T=$(mktemp -d) || exit 2; trap 'rm -rf "$T"' EXIT
cat > "$T/w.sno" <<'EOF'
        'xabc' ? FENCE('x') ('a' | 'ab') 'c'                                  :S(Y1)
        OUTPUT = 'NO  1 FENCE(x) (a|ab) c'                                     :(W2)
Y1      OUTPUT = 'YES 1 FENCE(x) (a|ab) c'
W2      'xab' ? FENCE('x') ('a' | 'ab') RPOS(0)                              :S(Y2)
        OUTPUT = 'NO  2 FENCE(x) (a|ab) RPOS(0)'                               :(W3)
Y2      OUTPUT = 'YES 2 FENCE(x) (a|ab) RPOS(0)'
W3      'xybb' ? FENCE('x') 'y' ARBNO('b') RPOS(0)                            :S(Y3)
        OUTPUT = 'NO  3 FENCE(x) y ARBNO(b) RPOS(0)'                           :(W4)
Y3      OUTPUT = 'YES 3 FENCE(x) y ARBNO(b) RPOS(0)'
W4      'xybb' ? 'x' FENCE('') 'y' ARBNO('b') RPOS(0)                         :S(Y4)
        OUTPUT = 'NO  4 x FENCE() y ARBNO(b) RPOS(0)'                          :(W5)
Y4      OUTPUT = 'YES 4 x FENCE() y ARBNO(b) RPOS(0)'
W5      'xybb' ? FENCE('x') 'y' ARB RPOS(0)                                   :S(Y5)
        OUTPUT = 'NO  5 FENCE(x) y ARB RPOS(0)'                                :(W6)
Y5      OUTPUT = 'YES 5 FENCE(x) y ARB RPOS(0)'
W6      P = FENCE('x') 'y' ARBNO('b') RPOS(0)
        'xybb' ? P                                                            :S(Y6)
        OUTPUT = 'NO  6 the same pattern held in a variable'                  :(W7)
Y6      OUTPUT = 'YES 6 the same pattern held in a variable'
W7      '{c:bb}' ? POS(0) '{' ARBNO('c' FENCE('') ':' ARBNO('b')) '}' RPOS(0) :S(Y7)
        OUTPUT = 'NO  7 ARBNO body c FENCE() : ARBNO(b)'                       :(W8)
Y7      OUTPUT = 'YES 7 ARBNO body c FENCE() : ARBNO(b)'
W8      'c:bb' ? POS(0) 'c' FENCE('+' | '') ':' ARBNO('b') RPOS(0)            :S(Y8)
        OUTPUT = 'NO  8 c FENCE(+|) : ARBNO(b) RPOS(0)'                        :(W9)
Y8      OUTPUT = 'YES 8 c FENCE(+|) : ARBNO(b) RPOS(0)'
W9      'xab' ? 'x' ('a' | 'ab') RPOS(0)                                      :S(Y9)
        OUTPUT = 'NO  9 control: no FENCE'                                     :(W10)
Y9      OUTPUT = 'YES 9 control: no FENCE'
W10     'abb' ? POS(0) ARBNO('a' ARBNO('b')) RPOS(0)                          :S(Y10)
        OUTPUT = 'NO  10 control: nested ARBNO, no FENCE'                      :(W11)
Y10     OUTPUT = 'YES 10 control: nested ARBNO, no FENCE'
W11     $('F') = FENCE('0')
        $('T') = F ARBNO('*' F)
        $('X') = T ARBNO('+' T)
        '0*0' ? POS(0) X RPOS(0)                                              :S(Y11)
        OUTPUT = 'NO  11 runtime-built FENCE(0) under nested ARBNO'           :(W12)
Y11     OUTPUT = 'YES 11 runtime-built FENCE(0) under nested ARBNO'
W12     '1+2+3' ? POS(0) SPAN('0123456789') . F1 ARBNO(FENCE('+') SPAN('0123456789') . L1) RPOS(0)   :F(N12)
        IDENT(F1 '/' L1, '1/3')                                               :S(Y12)
N12     OUTPUT = 'NO  12 ARBNO(FENCE(+) SPAN . L1): the capture ends the body' :(END)
Y12     OUTPUT = 'YES 12 ARBNO(FENCE(+) SPAN . L1): the capture ends the body'
END
EOF
( cd "$T" && timeout -k 5 20s "$SBL" -bf w.sno </dev/null ) > "$T/w.ref" 2>&1 || { echo "⛔ GATE REFUSE(2) [$G]: the oracle refused its own witness -- no ref to grade against"; exit 2; }
[ "$(grep -c '^YES' "$T/w.ref")" = 12 ] || { echo "⛔ GATE REFUSE(2) [$G]: the oracle's ref does not read twelve YES lines -- the witness is not the one this gate was minted on"; exit 2; }
RC=0
got="$(timeout -k 5 20s "$SCRIP" "$T/w.sno" </dev/null 2>&1)"
if [ "$got" = "$(cat "$T/w.ref")" ]; then echo "  m3 PASS (12/12 lines byte-identical to the oracle)"
else echo "  m3 FAIL (diverged from the oracle on: $(diff <(echo "$got") "$T/w.ref" | grep '^<' | cut -c3- | tr '\n' '|'))"; RC=1; fi
if "$SCRIP" --compile "$T/w.sno" -o "$T/w.s" </dev/null >/dev/null 2>&1 && gcc -m64 -no-pie -rdynamic "$T/w.s" -Wl,-rpath,"$LIBDIR" -L"$LIBDIR" -lscrip_rt -lm -lpthread -o "$T/w" 2>"$T/ld.log"; then
    got4="$(timeout -k 5 20s "$T/w" </dev/null 2>&1)"
    if [ "$got4" = "$(cat "$T/w.ref")" ]; then echo "  m4 PASS (12/12 lines byte-identical to the oracle)"
    else echo "  m4 FAIL (diverged from the oracle on: $(diff <(echo "$got4") "$T/w.ref" | grep '^<' | cut -c3- | tr '\n' '|'))"; RC=1; fi
else echo "⛔ GATE REFUSE(2) [$G]: mode-4 compile or link failed, so arm 2 measured nothing"; exit 2; fi
if [ "$RC" = 0 ]; then echo "✅ GATE PASS(0) [$G]: what follows a FENCE is retried as SPITBOL retries it, flat and inside an ARBNO body, in both modes (2 arms, 12 witnesses)"
else echo "⛔ GATE FAIL(1) [$G]: a FENCE cut more than its own argument (examined 2 arms, 12 witnesses)"; fi
exit $RC
