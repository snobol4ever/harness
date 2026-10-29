#!/usr/bin/env bash
# test_gate_sno_a_stored_fenced_pattern_retries_an_alternation_that_an_operand_follows.sh -- A FENCE-BEARING PATTERN HELD IN A VARIABLE OR BUILT AT RUN TIME, WHOSE ALTERNATION IS FOLLOWED BY ONE MORE OPERAND,
# IS STILL RE-ENTERED WHEN A LATER ELEMENT FAILS: the retry reaches the alternation's next arm, and a walk that exhausts it and reaches
# a bare FENCE aborts the whole match, as SPITBOL does (hq_snobol4 2026-09-27, row snobol4-a-stored-fenced-pattern-with-an-operand-
# after-its-alternation-never-backtracks-into-it-tpgm4-two-part-gotos; SPITBOL test program 4's GOTO_FIELD, whose tail is OPT(BLANKS)).
#
# MECHANISM: src/lower/lower_snobol4.c, sno_pat_publish_body_root. A PAT$ or RT$ graph gets its resume root from the carrier build's
# out_brt; 11c73f1e5 made a fenced sequence publish its rightmost segment's resume tail, but the fenced branch admitted a tail only at
# seam tier 1 or 3 (zdp_seam_tier). A trailing operand -- NULL (a deferred variable), '', LEN(0), OPT(BLANKS) -- is tier 2, a beta
# that walks leftward, so the graph was rootless: RPOS(0) could not retry the alternation, and a bare FENCE the walk should reach never
# aborted either -- the pattern failed whole and an outer alternative matched. A tier-2 tail's leftward walk reaches the FENCE only
# after every generator to its right is exhausted, and the FENCE's own beta then aborts: the manual's rule (v3.7 p.126: FENCE fails
# the match when the scanner backs up THROUGH it). The fenced branch now admits tier 2 as well.
#
# WITNESSES (11 lines, the ref CUT FROM THE ORACLE at run time): 1-4 stored, the trailing operand NULL, NULL after FENCE directly,
# LEN(0), ''; 5 run-time built through a user function, test program 4's GOTO_FIELD verbatim in shape; CONTROLS 6 inline, 7 no FENCE,
# 8 a trailing alternation (green before), 9 and 10 the walk reaches the bare FENCE and the WHOLE match aborts though an outer
# alternative would match (NO in SPITBOL), 11 the same with no FENCE (the outer alternative matches, YES).
# FAIL_ONCE (recorded, hq_snobol4 2026-09-27): on f32289815 (the cure absent) m3 AND m4 diverge on 1, 2, 3, 4, 5, 9 and 10 (9 and 10
# read YES: the pattern failed whole and the outer alternative matched); with the cure all 11 lines equal the oracle in both modes.
# THE CTO'S REVIEW (2026-09-27, accepted 5f445d5fd): 12 is the cto's control -- a conditional-capture tail must read V=c, never V=b
# (a skipped capture's stale record); 13-17 widen it: an immediate-capture tail, a capture around a generator, a cursor-capture
# tail, two stacked capture tails, and an abort through the bare FENCE with a capture tail and an outer alternative (sbl NO).
# Witnesses 9, 10 and 17 also guard the fallback first-node root the widening reaches (the cto's note).
# ARMS: (1) mode 3 and (2) mode 4 run the witness; every line must match the oracle byte for byte.
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
set -uo pipefail
G="$(basename "${BASH_SOURCE[0]}" .sh)"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)" || { echo "REFUSE(2): no SCRIP beside harness at $HERE/../../SCRIP (a port root) -- this gate measures SCRIP and cannot from here"; exit 2; }
SCRIP="${SCRIP_BIN:-$ROOT/scrip}"; [ -x "$SCRIP" ] || { echo "⛔ GATE REFUSE(2) [$G]: no scrip at $SCRIP"; exit 2; }
LIBDIR="$ROOT/out"; [ -f "$LIBDIR/libscrip_rt.so" ] || { echo "⛔ GATE REFUSE(2) [$G]: no libscrip_rt.so in $LIBDIR"; exit 2; }
SBL="${SBL_BIN:-/home/resources/x64/bin/sbl}"; [ -x "$SBL" ] || { echo "⛔ GATE REFUSE(2) [$G]: no sbl at $SBL -- this gate's ref is CUT FROM THE ORACLE at run time, never typed"; exit 2; }
T=$(mktemp -d) || exit 2; trap 'rm -rf "$T"' EXIT
cat > "$T/w.sno" <<'EOF'
        DEFINE('OPT(PATTERN)')                                              :(W1)
OPT     OPT = NULL | PATTERN                                               :(RETURN)
W1      G = '(' SPAN('AB') ')'
        S = ':S(A)F(B)'
        P1 = ':' FENCE NULL ('S' G | 'S' G 'F' G) NULL
        S ? POS(0) P1 RPOS(0)                                              :S(Y1)
        OUTPUT = 'NO  1 stored: FENCE, NULL, alternation, then NULL'       :(W2)
Y1      OUTPUT = 'YES 1 stored: FENCE, NULL, alternation, then NULL'
W2      P2 = ':' FENCE ('S' G | 'S' G 'F' G) NULL
        S ? POS(0) P2 RPOS(0)                                              :S(Y2)
        OUTPUT = 'NO  2 stored: FENCE, alternation, then NULL'             :(W3)
Y2      OUTPUT = 'YES 2 stored: FENCE, alternation, then NULL'
W3      P3 = ':' FENCE NULL ('S' G | 'S' G 'F' G) LEN(0)
        S ? POS(0) P3 RPOS(0)                                              :S(Y3)
        OUTPUT = 'NO  3 stored: the trailing operand is LEN(0)'            :(W4)
Y3      OUTPUT = 'YES 3 stored: the trailing operand is LEN(0)'
W4      P4 = ':' FENCE NULL ('S' G | 'S' G 'F' G) ''
        S ? POS(0) P4 RPOS(0)                                              :S(Y4)
        OUTPUT = 'NO  4 stored: the trailing operand is a null literal'    :(W5)
Y4      OUTPUT = 'YES 4 stored: the trailing operand is a null literal'
W5      BLANKS = SPAN(' ')
        P5 = OPT(BLANKS ':' FENCE OPT(BLANKS) ('S' G | 'F' G | 'S' G OPT(BLANKS) 'F' G) OPT(BLANKS))
        S5 = ' ' S
        S5 ? POS(0) P5 RPOS(0)                                             :S(Y5)
        OUTPUT = 'NO  5 run-time built: SPITBOL test program 4 GOTO_FIELD'  :(W6)
Y5      OUTPUT = 'YES 5 run-time built: SPITBOL test program 4 GOTO_FIELD'
W6      S ? POS(0) ':' FENCE NULL ('S' G | 'S' G 'F' G) NULL RPOS(0)       :S(Y6)
        OUTPUT = 'NO  6 control: the same pattern inline'                  :(W7)
Y6      OUTPUT = 'YES 6 control: the same pattern inline'
W7      P7 = ':' NULL ('S' G | 'S' G 'F' G) NULL
        S ? POS(0) P7 RPOS(0)                                              :S(Y7)
        OUTPUT = 'NO  7 control: no FENCE'                                 :(W8)
Y7      OUTPUT = 'YES 7 control: no FENCE'
W8      P8 = ':' FENCE NULL ('S' G | 'S' G 'F' G) (SPAN(' ') | '')
        S ? POS(0) P8 RPOS(0)                                              :S(Y8)
        OUTPUT = 'NO  8 control: the trailing operand is an alternation'   :(W9)
Y8      OUTPUT = 'YES 8 control: the trailing operand is an alternation'
W9      P9 = ':' FENCE NULL ('S' G | 'X') NULL
        S ? POS(0) (P9 | ':' REM) RPOS(0)                                  :S(Y9)
        OUTPUT = 'NO  9 control: the walk reaches the FENCE and the whole match aborts' :(W10)
Y9      OUTPUT = 'YES 9 control: the walk reaches the FENCE and the whole match aborts'
W10     P10 = ':' FENCE NULL ('S' G | 'X') LEN(0)
        S ? POS(0) (P10 | ':' REM) RPOS(0)                                 :S(Y10)
        OUTPUT = 'NO  10 control: the same abort through a LEN(0) tail'    :(W11)
Y10     OUTPUT = 'YES 10 control: the same abort through a LEN(0) tail'
W11     P11 = ':' NULL ('S' G | 'X') NULL
        S ? POS(0) (P11 | ':' REM) RPOS(0)                                 :S(Y11)
        OUTPUT = 'NO  11 control: with no FENCE the outer alternative matches' :(END)
Y11     OUTPUT = 'YES 11 control: with no FENCE the outer alternative matches'
W12     P12 = ':' FENCE ('a' | 'ab') (LEN(1) . V)
        V = ; ':abcd' ? POS(0) P12 'd'                                     :S(Y12)
        OUTPUT = 'NO  12 the cto control: a conditional capture tail'      :(W13)
Y12     OUTPUT = '12 the cto control, conditional capture tail: V=' V
W13     P13 = ':' FENCE ('a' | 'ab') (LEN(1) $ W)
        W = ; ':abcd' ? POS(0) P13 'd'                                     :S(Y13)
        OUTPUT = 'NO  13 an immediate capture tail'                        :(W14)
Y13     OUTPUT = '13 an immediate capture tail: W=' W
W14     P14 = ':' FENCE ('a' | 'ab') ((LEN(1) | LEN(2)) . X)
        X = ; ':abcde' ? POS(0) P14 'e'                                    :S(Y14)
        OUTPUT = 'NO  14 a capture around a generator'                     :(W15)
Y14     OUTPUT = '14 a capture around a generator: X=' X
W15     P15 = ':' FENCE ('a' | 'ab') LEN(1) @C
        C = ; ':abcd' ? POS(0) P15 'd'                                     :S(Y15)
        OUTPUT = 'NO  15 a cursor capture tail'                            :(W16)
Y15     OUTPUT = '15 a cursor capture tail: C=' C
W16     P16 = ':' FENCE ('a' | 'ab') (LEN(1) . Y) (LEN(1) . Z)
        Y = ; Z = ; ':abcde' ? POS(0) P16 'e'                              :S(Y16)
        OUTPUT = 'NO  16 two stacked capture tails'                        :(W17)
Y16     OUTPUT = '16 two stacked capture tails: Y=' Y ' Z=' Z
W17     P17 = ':' FENCE ('a' | 'x') (LEN(1) . Q)
        Q = 'unset'; ':abcd' ? POS(0) (P17 'd' | ':' REM . R)              :S(Y17)
        OUTPUT = 'NO  17 abort through the FENCE with a capture tail'      :(END)
Y17     OUTPUT = 'YES 17 abort through the FENCE with a capture tail: Q=' Q ' R=' R
END
EOF
( cd "$T" && timeout -k 5 20s "$SBL" -bf w.sno </dev/null ) > "$T/w.ref" 2>&1 || { echo "⛔ GATE REFUSE(2) [$G]: the oracle refused its own witness -- no ref to grade against"; exit 2; }
[ "$(grep -c '^YES' "$T/w.ref")" = 9 ] && [ "$(grep -c '^NO  9 ' "$T/w.ref")" = 1 ] && [ "$(grep -c '^NO  10 ' "$T/w.ref")" = 1 ] && grep -qx '12 the cto control, conditional capture tail: V=c' "$T/w.ref" && grep -qx 'NO  17 abort through the FENCE with a capture tail' "$T/w.ref" || { echo "⛔ GATE REFUSE(2) [$G]: the oracle's ref does not read nine YES lines, NO on 9, 10 and 17, and V=c on 12 -- the witness is not the one this gate was minted on"; exit 2; }
RC=0
got="$(cd "$T" && timeout -k 5 20s "$SCRIP" w.sno </dev/null 2>&1)"
if [ "$got" = "$(cat "$T/w.ref")" ]; then echo "  m3 PASS (17/17 lines byte-identical to the oracle)"
else echo "  m3 FAIL (diverged from the oracle on: $(diff <(echo "$got") "$T/w.ref" | grep '^<' | cut -c3- | tr '\n' '|'))"; RC=1; fi
if "$SCRIP" --compile "$T/w.sno" --out="$T/w.s" </dev/null >/dev/null 2>&1 && gcc -m64 -no-pie -rdynamic "$T/w.s" -Wl,-rpath,"$LIBDIR" -L"$LIBDIR" -lscrip_rt -lm -lpthread -o "$T/w" 2>"$T/ld.log"; then
    got4="$(cd "$T" && timeout -k 5 20s ./w </dev/null 2>&1)"
    if [ "$got4" = "$(cat "$T/w.ref")" ]; then echo "  m4 PASS (17/17 lines byte-identical to the oracle)"
    else echo "  m4 FAIL (diverged from the oracle on: $(diff <(echo "$got4") "$T/w.ref" | grep '^<' | cut -c3- | tr '\n' '|'))"; RC=1; fi
else echo "⛔ GATE REFUSE(2) [$G]: mode-4 compile or link failed, so arm 2 measured nothing"; exit 2; fi
if [ "$RC" = 0 ]; then echo "✅ GATE PASS(0) [$G]: a stored or run-time fenced pattern retries an alternation an operand follows, and a walk reaching its bare FENCE aborts the match, as SPITBOL does, in both modes (2 arms, 17 witnesses)"
else echo "⛔ GATE FAIL(1) [$G]: a stored or run-time fenced pattern was failed whole where SPITBOL retries it or aborts through its FENCE (examined 2 arms, 17 witnesses)"; fi
exit $RC
