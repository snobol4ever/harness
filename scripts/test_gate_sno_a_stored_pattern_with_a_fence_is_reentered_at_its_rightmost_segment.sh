#!/usr/bin/env bash
# test_gate_sno_a_stored_pattern_with_a_fence_is_reentered_at_its_rightmost_segment.sh -- A PATTERN HELD IN A VARIABLE OR BUILT AT
# RUN TIME THAT CARRIES A FENCE IS STILL RE-ENTERED WHEN A LATER ELEMENT FAILS: backtracking into it resumes its rightmost segment, as
# SPITBOL does, instead of failing it whole (hq_snocone 2026-09-27; Lon 2026-09-27: "Get the parser_*.sc programs to 100%.").
#
# MECHANISM: src/lower/lower_snobol4.c gives a stored (PAT$) or runtime-built (RT$) pattern graph a resume root, body_root, from the
# carrier build's out_brt (sno_pat_carrier_build -> sno_pat_publish_body_root). Two roads left it NULL, so an outer ARBNO or
# alternation could not re-enter the pattern and failed it whole:
#  (i) a TOP-LEVEL fenced sequence took the sno_pat_node road and published no out_brt at all; now the fenced TT_SEQ hands back its
#      rightmost segment's own resume tail (scx_t.seq_rtail, the n_rt sno_seq_nary gives a run: its rightmost generator), and the
#      fenced branch keeps its seam-tier gate (1 or 3) -- the cto's ruling 2026-09-27: a redo of a sequence re-enters its rightmost
#      segment. Witnesses 1, 2 and 7 (hq_snobol4's fence-then-operand-then-alternation row, from SPITBOL test program 4's GOTO_FIELD).
#  (ii) a pattern with NO top-level FENCE but one NESTED inside an element (a keyword Id = ANY(..) FENCE(SPAN(..) | epsilon) under an
#      immediate assignment) was counted fenced by sno_pat_contains_fence at any depth, so its tier-2 tail was refused and the graph
#      was rootless: the switch row of parser_snocone.sc (ctl_switch, ctl_switch_default), where backtracking into the switch's
#      ARBNO(*CaseArm | *DefaultArm) could not re-enter the arm to grow its inner ARBNO(*Command). Now such a pattern takes the
#      fence-free road's root. Witness 8.
# CONTROLS that must stay as SPITBOL answers: 3 (no FENCE), 4 (rightmost segment all literals: tier 2, stays rootless), 5 (the FENCE
# is the rightmost element: sealed, the match FAILS in SPITBOL too), 6 (an ARBNO then a literal), 9 (a literal tail).
#
# ARMS: (1) mode 3 and (2) mode 4 run one witness program of nine statements, each printing a YES or NO line; the ref is CUT FROM THE
# ORACLE at run time and every line must match byte for byte.
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
set -uo pipefail
G="$(basename "${BASH_SOURCE[0]}" .sh)"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)" || { echo "REFUSE(2): no SCRIP beside harness at $HERE/../../SCRIP (a port root) -- this gate measures SCRIP and cannot from here"; exit 2; }
SCRIP="${SCRIP_BIN:-$ROOT/scrip}"; [ -x "$SCRIP" ] || { echo "⛔ GATE REFUSE(2) [$G]: no scrip at $SCRIP"; exit 2; }
LIBDIR="$ROOT/out"; [ -f "$LIBDIR/libscrip_rt.so" ] || { echo "⛔ GATE REFUSE(2) [$G]: no libscrip_rt.so in $LIBDIR"; exit 2; }
SBL="${SBL_BIN:-/home/resources/x64/bin/sbl}"; [ -x "$SBL" ] || { echo "⛔ GATE REFUSE(2) [$G]: no sbl at $SBL -- this gate's ref is CUT FROM THE ORACLE at run time, never typed"; exit 2; }
T=$(mktemp -d) || exit 2; trap 'rm -rf "$T"' EXIT
cat > "$T/w.sno" <<'EOF'
        P1 = 'c' FENCE('+' | '') ':' ARBNO('b')
        '{c:bb}' ? POS(0) '{' ARBNO(P1) '}' RPOS(0)                        :S(Y1)
        OUTPUT = 'NO  1 ARBNO(P1), P1 = c FENCE(+|) : ARBNO(b)'               :(W2)
Y1      OUTPUT = 'YES 1 ARBNO(P1), P1 = c FENCE(+|) : ARBNO(b)'
W2      P2 = 'c' FENCE('') ':' ARBNO('b')
        '{c:bb}' ? POS(0) '{' ARBNO(P2) '}' RPOS(0)                        :S(Y2)
        OUTPUT = 'NO  2 ARBNO(P2), P2 = c FENCE() : ARBNO(b)'                 :(W3)
Y2      OUTPUT = 'YES 2 ARBNO(P2), P2 = c FENCE() : ARBNO(b)'
W3      P3 = 'c' ':' ARBNO('b')
        '{c:bb}' ? POS(0) '{' ARBNO(P3) '}' RPOS(0)                        :S(Y3)
        OUTPUT = 'NO  3 control: no FENCE'                                    :(W4)
Y3      OUTPUT = 'YES 3 control: no FENCE'
W4      P4 = 'c' FENCE('') ':' 'b'
        '{c:bc:b}' ? POS(0) '{' ARBNO(P4) '}' RPOS(0)                      :S(Y4)
        OUTPUT = 'NO  4 control: rightmost segment all literals'              :(W5)
Y4      OUTPUT = 'YES 4 control: rightmost segment all literals'
W5      P5 = 'c' ':' FENCE('b' | 'bb')
        '{c:bb}' ? POS(0) '{' ARBNO(P5) '}' RPOS(0)                        :S(Y5)
        OUTPUT = 'NO  5 control: the FENCE is the rightmost element'          :(W6)
Y5      OUTPUT = 'YES 5 control: the FENCE is the rightmost element'
W6      P6 = 'c' FENCE('') ':' ARBNO('b') 'x'
        '{c:bbx}' ? POS(0) '{' ARBNO(P6) '}' RPOS(0)                       :S(Y6)
        OUTPUT = 'NO  6 control: rightmost segment an ARBNO then a literal'   :(W7)
Y6      OUTPUT = 'YES 6 control: rightmost segment an ARBNO then a literal'
W7      G = '(' SPAN('AB') ')'
        PV = ':' FENCE NULL ('S' G | 'S' G 'F' G)
        ':S(A)F(B)' ? POS(0) PV RPOS(0)                                    :S(Y7)
        OUTPUT = 'NO  7 bare FENCE, an operand, an alternation, in a variable' :(W8)
Y7      OUTPUT = 'YES 7 bare FENCE, an operand, an alternation, in a variable'
W8      L = 'abcdefghijklmnopqrstuvwxyz'
        (ID = (ANY(L) FENCE(SPAN(L) | epsilon)))
        (ARM = ((((ID $ TX) ':') ARBNO('b')) (epsilon . TT)))
        '{a:bb}' ? POS(0) '{' ARBNO(*ARM) '}' RPOS(0)                      :S(Y8)
        OUTPUT = 'NO  8 a FENCE nested in an element, an inner ARBNO, a tier-2 tail' :(W9)
Y8      OUTPUT = 'YES 8 a FENCE nested in an element, an inner ARBNO, a tier-2 tail'
W9      (ARM9 = ((((ID $ TX) ':') ARBNO('b')) ('')))
        '{a:bb}' ? POS(0) '{' ARBNO(*ARM9) '}' RPOS(0)                     :S(Y9)
        OUTPUT = 'NO  9 control: the same arm with a literal tail'            :(END)
Y9      OUTPUT = 'YES 9 control: the same arm with a literal tail'
END
EOF
( cd "$T" && timeout -k 5 20s "$SBL" -bf w.sno </dev/null ) > "$T/w.ref" 2>&1 || { echo "⛔ GATE REFUSE(2) [$G]: the oracle refused its own witness -- no ref to grade against"; exit 2; }
[ "$(grep -c '^YES' "$T/w.ref")" = 8 ] && [ "$(grep -c '^NO  5 ' "$T/w.ref")" = 1 ] || { echo "⛔ GATE REFUSE(2) [$G]: the oracle's ref does not read eight YES lines and NO on 5 -- the witness is not the one this gate was minted on"; exit 2; }
RC=0
got="$(timeout -k 5 20s "$SCRIP" "$T/w.sno" </dev/null 2>&1)"
if [ "$got" = "$(cat "$T/w.ref")" ]; then echo "  m3 PASS (9/9 lines byte-identical to the oracle)"
else echo "  m3 FAIL (diverged from the oracle on: $(diff <(echo "$got") "$T/w.ref" | grep '^<' | cut -c3- | tr '\n' '|'))"; RC=1; fi
if "$SCRIP" --compile "$T/w.sno" -o "$T/w.s" </dev/null >/dev/null 2>&1 && gcc -m64 -no-pie -rdynamic "$T/w.s" -Wl,-rpath,"$LIBDIR" -L"$LIBDIR" -lscrip_rt -lm -lpthread -o "$T/w" 2>"$T/ld.log"; then
    got4="$(timeout -k 5 20s "$T/w" </dev/null 2>&1)"
    if [ "$got4" = "$(cat "$T/w.ref")" ]; then echo "  m4 PASS (9/9 lines byte-identical to the oracle)"
    else echo "  m4 FAIL (diverged from the oracle on: $(diff <(echo "$got4") "$T/w.ref" | grep '^<' | cut -c3- | tr '\n' '|'))"; RC=1; fi
else echo "⛔ GATE REFUSE(2) [$G]: mode-4 compile or link failed, so arm 2 measured nothing"; exit 2; fi
if [ "$RC" = 0 ]; then echo "✅ GATE PASS(0) [$G]: a stored or run-time pattern carrying a FENCE is re-entered at its rightmost segment as SPITBOL re-enters it, in both modes (2 arms, 9 witnesses)"
else echo "⛔ GATE FAIL(1) [$G]: a stored or run-time pattern carrying a FENCE was failed whole where SPITBOL re-enters it (examined 2 arms, 9 witnesses)"; fi
exit $RC
