#!/usr/bin/env bash
# test_gate_sno_deferred_goto_from_match_inside_define.sh -- A COMPUTED GOTO OFF A MATCH, INSIDE A DEFINE BODY,
# LEAVES THE STATEMENT AT THE RIGHT STACK DEPTH.
#
# WHAT THIS IS: SNOBOL4 `:S($('L.' OP))` -- a goto whose TARGET IS COMPUTED at run time -- taken from the
# SUCCESS branch of a pattern match, in a statement inside a DEFINE body. The transfer lands on a label in that
# same body, which then runs `:(RETURN)`. Before the cure every b-arm died SIGSEGV 139 in BOTH modes, jumping to
# a value like 0x300000002 -- a DATA word read as a return address, because the deferred-goto chain left the
# stack 16 or 48 bytes deep and :(RETURN) popped the wrong slot.
#
# ⛔ THE DISCRIMINATOR IS THREE-FACTOR AND EVERY c-ARM REMOVES EXACTLY ONE FACTOR. All three were measured, and
# each c-arm was GREEN BEFORE the cure and must stay green after it:
#   c1  the target is a PLAIN LABEL, not computed        -- the same match, the same S branch, no crash
#   c2  the goto is UNCONDITIONAL, not on the S branch   -- computed target, still no crash
#   c3  the whole shape at MAIN LEVEL, not in a DEFINE   -- no activation to return from, no crash
#   c4  the statement is an ASSIGNMENT, not a match      -- no match watermark, no crash
#   c5  the transfer is on the F branch of a FAILED match -- the failure arm was never affected
# A gate carrying only the b-arms would pass just as happily if a later change stopped emitting deferred gotos
# altogether; the c-arms are what force the shapes to stay distinguishable.
#
# ⭐ b1 vs b2 IS THE PAIR THAT PINS THE ARITHMETIC, and it is why one b-arm would not have been enough. They
# differ ONLY in whether the match REPLACES (`X 'a' = ''` vs bare `X 'a'`), which changes the statement's own
# zeta depth from 32 to 16 while the deferred chain adds 48 to both. The correct pop is 64 in BOTH. So a rule
# keyed on the full depth is right for exactly one of them, and a rule keyed on the watermark is right for
# neither: the residual has to be the STATEMENT depth above the match watermark. Two earlier formulas were
# written, built and REFUTED on this pair before the third stood -- `full - wm` fixes b1 and leaves b2 dead,
# plain `full` does the reverse. Keep both arms or the next reader will re-derive a formula that fits one.
#
# ⛔ NON-VACUOUS BY CONSTRUCTION, AND CHEAP TO RE-PROVE: SCRIP_ZD_DEFER_EXIT=0 restores the pre-cure bytes off
# THE SAME BUILD, so no rebuild is needed to see the arms flip. Every b-arm is RED under it and every c-arm
# stays GREEN. Prove that before trusting a green:  SCRIP_ZD_DEFER_EXIT=0 bash <this file>
# THE KILLSWITCH IS DELETED (hq_zetas 2026-10-17, the spine flip, under the cto's review: ZETA HAS NO MODES, and CEO-1680
# allows no seam in SCRIP for a test): the proof above was measured at the cure's landing and stands as history.
#
# ⭐ WHY A GATE AND NOT A BOARD LINE: the SNOBOL4 rungs board CANNOT SEE this cure. Censused at the landing,
# ZERO of 32 sampled corpus SNOBOL4 programs outside the packages reach the arm, and Icon and Prolog emit no
# goto_deferred box at all (0 in 72 programs). The payload that does reach it is aisnobol WANG.sno, which the
# board does not carry. A cure whose only witness lives in one package program needs a gate or it is unpinned.
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
cat > "$T/b1.sno" <<'EOF'
        DEFINE('F(X)PHI')               :(E)
F       OP = 'A'
        X 'a' = ''                      :F(FR)S($('L.' OP))
FR      F = 'nomatch'                   :(RETURN)
L.A     F = 'ok'                        :(RETURN)
E
        OUTPUT = F('abc')
        OUTPUT = 'after'
END
EOF
cat > "$T/b2.sno" <<'EOF'
        DEFINE('F(X)PHI')               :(E)
F       OP = 'A'
        X 'a'                           :F(FR)S($('L.' OP))
FR      F = 'nomatch'                   :(RETURN)
L.A     F = 'ok'                        :(RETURN)
E
        OUTPUT = F('abc')
        OUTPUT = 'after'
END
EOF
cat > "$T/b3.sno" <<'EOF'
        DEFINE('F(X)PHI')               :(E)
F       OP = 'A'
        X (BREAK('.') . PHI) '.' = ''   :F(FR)S($('L.' OP))
FR      F = 'nomatch'                   :(RETURN)
L.A     F = F(PHI)                      :S(RETURN)F(FRETURN)
E
        OUTPUT = F('ab.cd.')
        OUTPUT = 'after'
END
EOF
cat > "$T/c1.sno" <<'EOF'
        DEFINE('F(X)PHI')               :(E)
F       OP = 'A'
        X 'a' = ''                      :F(FR)S(L.A)
FR      F = 'nomatch'                   :(RETURN)
L.A     F = 'ok'                        :(RETURN)
E
        OUTPUT = F('abc')
        OUTPUT = 'after'
END
EOF
cat > "$T/c2.sno" <<'EOF'
        DEFINE('F(X)PHI')               :(E)
F       OP = 'A'
        X 'a' = ''
        $('L.' OP)                      :($('L.' OP))
FR      F = 'nomatch'                   :(RETURN)
L.A     F = 'ok'                        :(RETURN)
E
        OUTPUT = F('abc')
        OUTPUT = 'after'
END
EOF
cat > "$T/c3.sno" <<'EOF'
        OP = 'A'
        X = 'abc'
        X 'a' = ''                      :F(FR)S($('L.' OP))
FR      OUTPUT = 'nomatch'              :(DONE)
L.A     OUTPUT = 'ok'
DONE    OUTPUT = 'after'
END
EOF
cat > "$T/c4.sno" <<'EOF'
        DEFINE('F(X)PHI')               :(E)
F       OP = 'A'
        X = X                           :F(FR)S($('L.' OP))
FR      F = 'nomatch'                   :(RETURN)
L.A     F = 'ok'                        :(RETURN)
E
        OUTPUT = F('abc')
        OUTPUT = 'after'
END
EOF
cat > "$T/c5.sno" <<'EOF'
        DEFINE('F(X)PHI')               :(E)
F       OP = 'A'
        X 'zz' = ''                     :F($('L.' OP))
        F = 'matched'                   :(RETURN)
L.A     F = 'ok'                        :(RETURN)
E
        OUTPUT = F('abc')
        OUTPUT = 'after'
END
EOF
ORACLE=/home/resources/x64/bin/sbl
[ -x "$ORACLE" ] || { echo "UNPROVEN(2): correctness oracle absent at $ORACLE -- this gate grades against SPITBOL, never against SCRIP's own output"; exit 2; }
bad=0; graded=0
for a in b1 b2 b3 c1 c2 c3 c4 c5; do
    want="$("$ORACLE" -bf "$T/$a.sno" < /dev/null 2>&1 | tr '\n' '/')"
    [ -n "$want" ] || { echo "  UNPROVEN $a -- oracle produced no graded output; refusing to grade SCRIP against nothing"; exit 2; }
    for m in m3 m4; do
        if [ "$m" = m3 ]; then
            got="$(timeout -k 5 20s "$SCRIP" "$T/$a.sno" < /dev/null 2>&1 | tr '\n' '/')"
        else
            "$SCRIP" --compile --out="$T/$a.s" "$T/$a.sno" < /dev/null >/dev/null 2>&1
            gcc -no-pie "$T/$a.s" -o "$T/$a.x" -L"$RT" -lscrip_rt -Wl,-rpath,"$RT" -lm -lpthread >/dev/null 2>&1 || { echo "  RED  $a $m -- link failed"; bad=1; continue; }
            got="$(timeout -k 5 20s "$T/$a.x" < /dev/null 2>&1 | tr '\n' '/')"
        fi
        graded=$((graded + 1))
        if [ "$got" = "$want" ]; then echo "  ok   $a $m -- matches SPITBOL [$want]"
        else echo "  RED  $a $m -- got [$got] want [$want]"; bad=1; fi
    done
done
[ "$graded" -eq 16 ] || { echo "UNPROVEN(2): graded $graded arms, expected 16 -- a runner that cannot measure never prints the success shape"; exit 2; }
if [ "$bad" -ne 0 ]; then echo "GATE RED(1) [sno-deferred-goto-from-match-inside-define]: a computed goto off a match inside a DEFINE body left the statement at the wrong stack depth"; exit 1; fi
echo "GATE GREEN(0) [sno-deferred-goto-from-match-inside-define]: $graded graded arms -- a computed goto taken from the success branch of a match inside a DEFINE body lands at the depth :(RETURN) expects, in both modes, with the plain-label, unconditional, main-level, no-match and failed-match controls all holding"
