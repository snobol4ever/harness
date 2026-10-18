#!/usr/bin/env bash
# test_gate_sno_flush_runs_the_recorded_conditional_assignments_then_cuts.sh -- FLUSH, THE FIRST SCRIP-ONLY EXTENSION OF THE
# SNOBOL4 PATTERN LANGUAGE (ceo CEO-1340). LON 2026-09-27, in-chat to hq_snocone, verbatim: "There is ONE HUGE feature which we
# will need now. The feaure is a FLUSH just like FENCE. But FLUSH runs all the conditional assignments up to that point INSTEAD
# of waiting until the end of pattern matching. This is how we will use ONE PATTERN to compile the entire source which is read
# into memory." and "For the oracle set FLUSH = FENCE pattern and all will work the same." His design, verbatim: "It seems you
# should just need a new CAS marker for the flush point. Then there will be two R12 for the end and the begining of the CAS of
# course. And then the where am I so far marker CAS pointer. Done and done."
#
# MECHANISM (hq_snocone 2026-09-28): bb_match_begin pushes one null entry -- the CAS begin marker -- on the deferred-capture
# island above the saved mark; FLUSH lowers as IR_MATCH_FENCE0 carrying literal 3 (every FENCE0 rule of the emitter applies) and
# emits bb_match_flush, which at alpha scans r12 down to the marker (from ANY frame: a stored pattern's deferred graph has its
# own rbp), runs bb_match_end's pump loop over the entries above it -- every conditional assignment recorded so far, in order,
# deferred targets through the same c2bb glue, the rax spill kept off x86_xfer_enter's typed cells -- drops them (r12 back to
# the marker, the pinned island top refreshed) and then cuts exactly as the bare FENCE box; rt_dcap_pump skips the marker, so
# the end box pumps only what came after the last FLUSH. tree_to_sno.c emits FLUSH and prepends FLUSH = FENCE.
#
# ARMS: (1) m3 and (2) m4 on a SNOBOL4 witness of fourteen matches -- succeeding, cut, stored, unevaluated, copied, flushed twice,
# FLUSH first and FLUSH last -- whose ref is CUT FROM THE ORACLE at run time with FLUSH = FENCE prepended (identical output on
# every match that succeeds, Lon's word); (3) the DEFINITION arm, m3 and m4: the two behaviours the oracle CANNOT show, pinned
# by Lon's sentence -- an assignment already performed when the match later fails, and a flushed value visible to a deferred
# target evaluated after the FLUSH -- graded against lines typed from the sentence, the only typed lines in this gate;
# (4) a Snocone witness through scrip --transpile (the prelude comes from the transpiler) graded on the oracle, then m3 and m4;
# (5) the cfo's arms: the witness under SCRIP_GC_EXERCISE=1 SCRIP_GC_STRESS=0 -d16384m reads collections=0, and under
# SCRIP_GC_STRESS=1 its output is unchanged. FAIL-ONCE/PASS-ONCE, MEASURED: on the tree before the box (SCRIP main 51ea208cc, a
# scratch worktree build) FLUSH is a null variable, so arms 1 and 2 diverge at witness 5 (the cut is not made: YES 5 cut where
# the oracle reads NO), the DEFINITION arm fails both lines (X= and seen X=) and arm 4 fails on the missing prelude -- FAIL(1);
# green on the 2026-09-28 landing. (6) hq_snobol4 2026-09-28: &DUMP of a program that never touches FLUSH prints no FLUSH line (sbl has no
# preset), and FLUSH = FENCE dumps FLUSH = PATTERN as the oracle does; FAIL-ONCE measured: arm 6 u reads FAIL with var_dump's skip removed.
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
set -uo pipefail
G="$(basename "${BASH_SOURCE[0]}" .sh)"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)" || { echo "REFUSE(2): no SCRIP beside harness at $HERE/../../SCRIP (a port root) -- this gate measures SCRIP and cannot from here"; exit 2; }
SCRIP="${SCRIP_BIN:-$ROOT/scrip}"; [ -x "$SCRIP" ] || { echo "⛔ GATE REFUSE(2) [$G]: no scrip at $SCRIP"; exit 2; }
LIBDIR="$ROOT/out"; [ -f "$LIBDIR/libscrip_rt.so" ] || { echo "⛔ GATE REFUSE(2) [$G]: no libscrip_rt.so in $LIBDIR"; exit 2; }
SBL="${SBL_BIN:-/home/resources/x64/bin/sbl}"; [ -x "$SBL" ] || { echo "⛔ GATE REFUSE(2) [$G]: no sbl at $SBL -- this gate's refs are CUT FROM THE ORACLE at run time, never typed"; exit 2; }
T=$(mktemp -d) || exit 2; trap 'rm -rf "$T"' EXIT
link4() { "$SCRIP" --compile "$1" -o "$T/$2.s" </dev/null >/dev/null 2>&1 && gcc -m64 -no-pie -rdynamic "$T/$2.s" -Wl,-rpath,"$LIBDIR" -L"$LIBDIR" -lscrip_rt -lm -lpthread -o "$T/$2" 2>"$T/$2.ld.log"; }
cat > "$T/w.sno" <<'EOF'
        DEFINE('NM()')                                :(NM_END)
NM      NM = .X                                       :(RETURN)
NM_END
        X = ; Y = ; Z = ; W =
        'abc' ? 'a' . X FLUSH 'b' . Y                 :S(Y1)F(N1)
Y1      OUTPUT = 'YES 1 ' X Y                         :(W2)
N1      OUTPUT = 'NO  1'
W2      X = ; 'abc' ? FLUSH 'a' . X 'b'               :S(Y2)F(N2)
Y2      OUTPUT = 'YES 2 FLUSH first ' X               :(W3)
N2      OUTPUT = 'NO  2 FLUSH first'
W3      L = ; D = ; 'a1b2c3' ? POS(0) ARBNO(ANY('abc') . L FLUSH ANY('123') . D) RPOS(0)  :S(Y3)F(N3)
Y3      OUTPUT = 'YES 3 in an ARBNO body ' L D         :(W4)
N3      OUTPUT = 'NO  3 in an ARBNO body'
W4      X = ; 'ab' ? 'a' . *NM() FLUSH 'b'            :S(Y4)F(N4)
Y4      OUTPUT = 'YES 4 deferred *NM() target ' X     :(W5)
N4      OUTPUT = 'NO  4 deferred *NM() target'
W5      'abc' ? ('a' | 'ab') FLUSH 'c'                :S(Y5)F(N5)
Y5      OUTPUT = 'YES 5 cut'                          :(W6)
N5      OUTPUT = 'NO  5 cut'
W6      'abc' ? ('a' | 'ab') 'c'                      :S(Y6)F(N6)
Y6      OUTPUT = 'YES 6 control: no cut'              :(W7)
N6      OUTPUT = 'NO  6 control: no cut'
W7      X = ; P = 'a' . X FLUSH 'b'
        'ab' ? P                                      :S(Y7)F(N7)
Y7      OUTPUT = 'YES 7 stored pattern ' X            :(W8)
N7      OUTPUT = 'NO  7 stored pattern'
W8      X = ; Y = ; Z = ; W = ; 'abcd' ? 'a' . W FLUSH 'b' . X FLUSH 'c' . Y 'd' . Z  :S(Y8)F(N8)
Y8      OUTPUT = 'YES 8 flushed twice ' W X Y Z       :(W9)
N8      OUTPUT = 'NO  8 flushed twice'
W9      X = ; N = 'X'; 'ab' ? 'a' . $N FLUSH 'b'      :S(Y9)F(N9)
Y9      OUTPUT = 'YES 9 indirect target ' X           :(W10)
N9      OUTPUT = 'NO  9 indirect target'
W10     X = ; 'ab' ? 'a' . X FLUSH                    :S(Y10)F(N10)
Y10     OUTPUT = 'YES 10 FLUSH last ' X               :(W11)
N10     OUTPUT = 'NO  10 FLUSH last'
W11     X = ; Y = ; 'xab' ? 'x' ('a' . X FLUSH 'b' . Y | 'ab' . Y)  :S(Y11)F(N11)
Y11     OUTPUT = 'YES 11 in an alternative ' X Y      :(W12)
N11     OUTPUT = 'NO  11 in an alternative'
W12     X = ; 'ab' ? *P                               :S(Y12)F(N12)
Y12     OUTPUT = 'YES 12 unevaluated stored pattern ' X   :(W13)
N12     OUTPUT = 'NO  12 unevaluated stored pattern'
W13     X = ; Q = P; 'ab' ? Q                         :S(Y13)F(N13)
Y13     OUTPUT = 'YES 13 copied stored pattern ' X    :(W14)
N13     OUTPUT = 'NO  13 copied stored pattern'
W14     F = FLUSH; 'ab' ? 'a' F 'b'                   :S(Y14)F(N14)
Y14     OUTPUT = 'YES 14 FLUSH held in a variable'    :(END)
N14     OUTPUT = 'NO  14 FLUSH held in a variable'
END
EOF
{ printf '\tFLUSH = FENCE\n'; cat "$T/w.sno"; } > "$T/w_oracle.sno"
( cd "$T" && timeout -k 5 20s "$SBL" -bf w_oracle.sno </dev/null ) > "$T/w.ref" 2>&1 || { echo "⛔ GATE REFUSE(2) [$G]: the oracle refused its own witness -- no ref to grade against"; exit 2; }
[ "$(wc -l < "$T/w.ref")" = 14 ] || { echo "⛔ GATE REFUSE(2) [$G]: the oracle's ref does not read fourteen lines -- the witness is not the one this gate was minted on"; exit 2; }
RC=0
got="$(timeout -k 5 20s "$SCRIP" "$T/w.sno" </dev/null 2>&1)"
if [ "$got" = "$(cat "$T/w.ref")" ]; then echo "  arm 1 m3 PASS (14/14 lines byte-identical to the oracle under FLUSH = FENCE)"
else echo "  arm 1 m3 FAIL (diverged from the oracle on: $(diff <(echo "$got") "$T/w.ref" | grep '^<' | cut -c3- | tr '\n' '|'))"; RC=1; fi
if link4 "$T/w.sno" w; then
    got4="$(timeout -k 5 20s "$T/w" </dev/null 2>&1)"
    if [ "$got4" = "$(cat "$T/w.ref")" ]; then echo "  arm 2 m4 PASS (14/14 lines byte-identical to the oracle under FLUSH = FENCE)"
    else echo "  arm 2 m4 FAIL (diverged from the oracle on: $(diff <(echo "$got4") "$T/w.ref" | grep '^<' | cut -c3- | tr '\n' '|'))"; RC=1; fi
else echo "⛔ GATE REFUSE(2) [$G]: mode-4 compile or link failed, so arm 2 measured nothing"; exit 2; fi
cat > "$T/d.sno" <<'EOF'
        DEFINE('SEE()')                               :(SEE_END)
SEE     OUTPUT = 'seen X=' X                          :(RETURN)
SEE_END
        X = ; Y =
        'abz' ? 'a' . X FLUSH 'b' . Y 'c'             :S(Y1)F(N1)
Y1      OUTPUT = 'YES 1'                              :(W2)
N1      OUTPUT = 'NO  1 X=' X ' Y=' Y
W2      X = ; 'ab' ? 'a' . X FLUSH *SEE() 'b'         :S(Y2)F(N2)
Y2      OUTPUT = 'YES 2 X=' X                         :(END)
N2      OUTPUT = 'NO  2'
END
EOF
printf 'NO  1 X=a Y=\nseen X=a\nYES 2 X=a\n' > "$T/d.def"
gotd="$(timeout -k 5 20s "$SCRIP" "$T/d.sno" </dev/null 2>&1)"
if [ "$gotd" = "$(cat "$T/d.def")" ]; then echo "  arm 3 m3 PASS (the DEFINITION lines: X is assigned at the FLUSH though the match later fails; a target after the FLUSH sees X)"
else echo "  arm 3 m3 FAIL (Lon's definition not met; got: $(echo "$gotd" | tr '\n' '|'))"; RC=1; fi
if link4 "$T/d.sno" d; then
    gotd4="$(timeout -k 5 20s "$T/d" </dev/null 2>&1)"
    if [ "$gotd4" = "$(cat "$T/d.def")" ]; then echo "  arm 3 m4 PASS (the DEFINITION lines)"
    else echo "  arm 3 m4 FAIL (Lon's definition not met; got: $(echo "$gotd4" | tr '\n' '|'))"; RC=1; fi
else echo "⛔ GATE REFUSE(2) [$G]: mode-4 compile or link of the definition witness failed"; exit 2; fi
cat > "$T/s.sc" <<'EOF'
x = ''; y = '';
if ('abc' ? 'a' . x FLUSH 'b' . y) OUTPUT = 'YES 1 ' x y; else OUTPUT = 'NO 1';
x = ''; p = 'a' . x FLUSH 'b';
if ('ab' ? p) OUTPUT = 'YES 2 stored ' x; else OUTPUT = 'NO 2 stored';
if ('abc' ? ('a' | 'ab') FLUSH 'c') OUTPUT = 'YES 3 cut'; else OUTPUT = 'NO 3 cut';
x = ''; y = ''; z = '';
if ('abc' ? 'a' . x FLUSH 'b' . y FLUSH 'c' . z) OUTPUT = 'YES 4 twice ' x y z; else OUTPUT = 'NO 4 twice';
EOF
"$SCRIP" --transpile "$T/s.sc" > "$T/s.sno" 2>/dev/null || { echo "⛔ GATE REFUSE(2) [$G]: scrip --transpile refused the Snocone witness"; exit 2; }
grep -q '^	FLUSH = FENCE$' "$T/s.sno" || { echo "⛔ GATE FAIL(1) [$G]: the transpiled program carries no FLUSH = FENCE prelude, so the oracle cannot run it as Lon said"; exit 1; }
( cd "$T" && timeout -k 5 20s "$SBL" -bf -s64m s.sno </dev/null ) > "$T/s.ref" 2>&1 || { echo "⛔ GATE REFUSE(2) [$G]: the oracle refused the transpiled Snocone witness"; exit 2; }
[ "$(wc -l < "$T/s.ref")" = 4 ] || { echo "⛔ GATE REFUSE(2) [$G]: the oracle's Snocone ref does not read four lines"; exit 2; }
gots="$(timeout -k 5 20s "$SCRIP" "$T/s.sc" </dev/null 2>&1)"
if [ "$gots" = "$(cat "$T/s.ref")" ]; then echo "  arm 4 m3 PASS (Snocone, 4/4 lines byte-identical to the oracle on the transpiled form)"
else echo "  arm 4 m3 FAIL (Snocone diverged: $(diff <(echo "$gots") "$T/s.ref" | grep '^<' | cut -c3- | tr '\n' '|'))"; RC=1; fi
if link4 "$T/s.sc" s; then
    gots4="$(timeout -k 5 20s "$T/s" </dev/null 2>&1)"
    if [ "$gots4" = "$(cat "$T/s.ref")" ]; then echo "  arm 4 m4 PASS (Snocone, 4/4 lines byte-identical to the oracle on the transpiled form)"
    else echo "  arm 4 m4 FAIL (Snocone diverged: $(diff <(echo "$gots4") "$T/s.ref" | grep '^<' | cut -c3- | tr '\n' '|'))"; RC=1; fi
else echo "⛔ GATE REFUSE(2) [$G]: mode-4 compile or link of the Snocone witness failed"; exit 2; fi
gz="$(SCRIP_GC_EXERCISE=1 SCRIP_GC_STRESS=0 timeout -k 5 20s "$SCRIP" -d16384m "$T/w.sno" </dev/null 2>"$T/gz.err")"
if [ "$gz" = "$(cat "$T/w.ref")" ] && grep -q 'collections=0' "$T/gz.err"; then echo "  arm 5 zero-collection PASS (collections=0 under -d16384m, output unchanged)"
else echo "  arm 5 zero-collection FAIL ($(grep -o 'collections=[0-9]*' "$T/gz.err" | head -1 || echo 'no [GC-EXERCISE] line'); output $( [ "$gz" = "$(cat "$T/w.ref")" ] && echo unchanged || echo CHANGED))"; RC=1; fi
gs="$(SCRIP_GC_STRESS=1 timeout -k 5 60s "$SCRIP" "$T/w.sno" </dev/null 2>/dev/null)"
if [ "$gs" = "$(cat "$T/w.ref")" ]; then echo "  arm 5 stress point PASS (SCRIP_GC_STRESS=1, output unchanged)"
else echo "  arm 5 stress point FAIL (SCRIP_GC_STRESS=1 changed the output: $(diff <(echo "$gs") "$T/w.ref" | grep '^<' | cut -c3- | tr '\n' '|'))"; RC=1; fi
printf '        X = 1\n        &DUMP = 1\nEND\n' > "$T/u.sno"; { printf '\tFLUSH = FENCE\n'; cat "$T/u.sno"; } > "$T/p.sno"
for dw in u p; do
    want="$( cd "$T" && timeout -k 5 20s "$SBL" -bf $dw.sno </dev/null 2>&1 | grep '^FLUSH = ' )"
    [ "$dw" = u ] && want=""
    got6="$(timeout -k 5 20s "$SCRIP" "$T/$dw.sno" </dev/null 2>&1 | grep '^FLUSH = ')"
    if link4 "$T/$dw.sno" $dw; then got64="$(timeout -k 5 20s "$T/$dw" </dev/null 2>&1 | grep '^FLUSH = ')"; else echo "⛔ GATE REFUSE(2) [$G]: mode-4 compile or link of the DUMP witness $dw failed"; exit 2; fi
    [ "$dw" = p ] && [ -z "$want" ] && { echo "⛔ GATE REFUSE(2) [$G]: the oracle printed no FLUSH line for FLUSH = FENCE under &DUMP -- nothing to grade the assigned case against"; exit 2; }
    if [ "$got6" = "$want" ] && [ "$got64" = "$want" ]; then echo "  arm 6 DUMP $dw PASS (m3+m4 FLUSH dump line(s) '${want:-none}', as the oracle under the prelude)"
    else echo "  arm 6 DUMP $dw FAIL (want '${want:-none}', m3 '${got6:-none}', m4 '${got64:-none}' -- the untouched preset must not dump; an assigned FLUSH must)"; RC=1; fi
done
if [ "$RC" = 0 ]; then echo "✅ GATE PASS(0) [$G]: FLUSH runs the conditional assignments recorded so far and cuts like FENCE, in both modes, SNOBOL4 and Snocone, stored or written, oracle-identical on every succeeding match and as Lon defined it where the oracle cannot see, and the untouched preset never dumps (6 arms)"
else echo "⛔ GATE FAIL(1) [$G]: FLUSH does not run the recorded conditional assignments at its point, or does not cut, or diverges from the oracle on a succeeding match (examined 6 arms)"; fi
exit $RC
