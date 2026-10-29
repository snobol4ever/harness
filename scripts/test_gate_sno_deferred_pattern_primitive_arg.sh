#!/usr/bin/env bash
# stale-binary preflight (row test-gate-scripts-that-grade-scrip-refuse-on-a-stale-binary-census-widened, hq_T 2026-09-05)
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
# test_gate_sno_deferred_pattern_primitive_arg.sh -- THE DEFERRED-CALL-IN-A-PRIMITIVE CLASS (ceo CEO-441
# item 2, 2026-09-09, authored by hq_I). A pattern primitive's deferred argument -- LEN(*F(0)),
# TAB(*(SIZE(X)-1)), ANY(*F()) -- must be EVALUATED at match time, through the same expression-thunk path
# `*DIFFER(X)` already uses, and never read as the name of a variable.
#
# WHAT WAS WRONG, and it is a guard that tested the wrong property. All five primitive families took a
# variable-name fast path guarded on `inner->v.sval != NULL` rather than on `inner->t == TT_VAR`. A call
# node F(0) ALSO carries a v.sval -- the callee's name -- so `LEN(*F(0))` compiled to a match-time
# `rt_pat_prim_int("F")`, i.e. a lookup of a VARIABLE named F. F was never called. Measured in the
# emitted asm: `lea rdi, [rip + .S0]` with `.S0: .string "F"`. Unset variable -> 0 -> LEN(0).
# An infix inner (SIZE(X)-1) carries NO v.sval, fell past the guard to a path that pushed a deferred
# EXPRESSION OBJECT where the box reads an integer, and SIGSEGV'd (snoflake infix-to-polish, rc=139).
#
# ⛔ ARM 3 IS THE LOAD-BEARING ONE AND IT IS WHY THE RUNTIME MAY NOT SIMPLY DISPATCH THE PROC. When a
# program has BOTH a variable N and a DEFINE'd function N(), SPITBOL reads `LEN(*N)` as the VARIABLE
# (measured on the live oracle: N=2 with N()=7 defined yields a 2-character match). So `rt_sno_dtx_value`,
# which prefers a registered proc, is the WRONG primitive here even though it is the right one for a
# deferred PATTERN. The discriminator has to be the lowerer's intent, carried in-band: a minted thunk is
# spelled with a leading '*', which no SNOBOL4 variable name can start with. Drop arm 3 and the obvious
# runtime-side "cure" passes every other arm while silently breaking name resolution.
#
# ⛔ REFUSES rc=2 rather than skipping: no scrip, no RT, no oracle, or zero probes graded. Prints its
# denominator. Both modes, every probe, graded against `sbl -bf` -- never against a stored ref.
# ⛔ ONE PROBE, ONE STR-PRIMITIVE FAMILY, AND THE SPLIT IS DELIBERATE. SPAN and ANY with deferred
# arguments in the SAME program SIGSEGV in m4 (rc=139; m3 rc=0) -- and they do so with a PLAIN VARIABLE
# argument too, on emitted asm carrying no thunk at all (witness: `SPAN(*CS)` then `ANY(*CS)`, .S0 =
# "CS", zero EXPR$ markers). That is a PRE-EXISTING defect of the m4 cset-primitive frame, not this
# class, so it is filed as its own row and kept out of this verdict: a gate red for a reason outside
# its own claim teaches the next reader to stop believing it. Two of the SAME family is fine (a6).
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; SD="$HERE/../../SCRIP"
SCRIP="$SD/scrip"; RT_DIR="$SD/out"
. "$HERE/lib_oracle_flags.sh" 2>/dev/null || { echo "⛔ REFUSE(rc=2): lib_oracle_flags.sh unloadable"; exit 2; }
SBL="$(sbl_correctness_bin 2>/dev/null || true)"; [ -n "$SBL" ] && [ -x "$SBL" ] || SBL=/home/resources/x64/bin/sbl
[ -x "$SCRIP" ] || { echo "⛔ REFUSE(rc=2): no scrip binary at $SCRIP -- build first (make)"; exit 2; }
[ -f "$RT_DIR/libscrip_rt.so" ] || { echo "⛔ REFUSE(rc=2): no $RT_DIR/libscrip_rt.so"; exit 2; }
[ -x "$SBL" ] || { echo "⛔ REFUSE(rc=2): no SPITBOL oracle at $SBL -- a missing oracle prints a full, plausible, entirely false all-FAIL table"; exit 2; }
W="$(mktemp -d)"; trap 'rm -rf "$W"' EXIT
cat > "$W/a1.sno" <<'EOF'
        DEFINE('F(N)')                                              :(F_END)
F       F = N + 3                                                   :(RETURN)
F_END
        X = 'ABCDEFGHIJ'
        X ? LEN(*F(0)) . Y                                          :F(NO1)
        OUTPUT = 'LEN ' Y
NO1     X ? TAB(*F(1)) . Y                                          :F(NO2)
        OUTPUT = 'TAB ' Y
NO2     X ? RTAB(*F(4)) . Y                                         :F(NO3)
        OUTPUT = 'RTAB ' Y
NO3     X ? POS(*F(-3)) LEN(2) . Y                                  :F(NO4)
        OUTPUT = 'POS ' Y
NO4     OUTPUT = 'a1 done'
END
EOF
cat > "$W/a2.sno" <<'EOF'
        X = 'ABCDEFGHIJ'
        X ? TAB(*(SIZE(X) - 1)) . Y                                 :F(NO1)
        OUTPUT = 'TABEXPR ' Y
NO1     X ? LEN(*(1 + 2)) . Y                                       :F(NO2)
        OUTPUT = 'LENEXPR ' Y
NO2     OUTPUT = 'a2 done'
END
EOF
cat > "$W/a3.sno" <<'EOF'
        DEFINE('N()')                                               :(N_END)
N       N = 7                                                       :(RETURN)
N_END
        N = 2
        X = 'ABCDEFGHIJ'
        X ? LEN(*N) . Y                                             :F(NO1)
        OUTPUT = 'COLLIDE ' Y
NO1     OUTPUT = 'a3 done'
END
EOF
cat > "$W/a4.sno" <<'EOF'
        DEFINE('CS()')                                              :(CS_END)
CS      CS = 'AB'                                                   :(RETURN)
CS_END
        X = 'ABABCDEF'
        X ? SPAN(*CS()) . Y                                         :F(NO1)
        OUTPUT = 'SPAN ' Y
NO1     OUTPUT = 'a4 done'
END
EOF
cat > "$W/a5.sno" <<'EOF'
        DEFINE('CS()')                                              :(CS_END)
CS      CS = 'AB'                                                   :(RETURN)
CS_END
        X = 'ABABCDEF'
        X ? ANY(*CS()) . Y                                          :F(NO1)
        OUTPUT = 'ANY ' Y
NO1     OUTPUT = 'a5 done'
END
EOF
cat > "$W/a6.sno" <<'EOF'
        DEFINE('CS()')                                              :(CS_END)
CS      CS = 'AB'                                                   :(RETURN)
CS_END
        X = 'ABABCDEF'
        X ? BREAK(*CS()) . Y                                        :F(NO1)
        OUTPUT = 'BREAK ' Y
NO1     OUTPUT = 'a6 done'
END
EOF
cat > "$W/a7.sno" <<'EOF'
        DEFINE('CS()')                                              :(CS_END)
CS      CS = 'AB'                                                   :(RETURN)
CS_END
        X = 'ABABCDEF'
        X ? NOTANY(*CS()) . Y                                       :F(NO1)
        OUTPUT = 'NOTANY ' Y
NO1     OUTPUT = 'a7 done'
END
EOF
PASS=0; FAIL=0; N=0; FAILED=""
for a in a1 a2 a3 a4 a5 a6 a7; do
    f="$W/$a.sno"
    ora="$(cd "$W" && timeout -k 5 20s "$SBL" -bf "$f" < /dev/null 2>&1)"; orc=$?
    if [ $orc -ge 124 ]; then echo "⛔ REFUSE(rc=2): the oracle timed out on $a -- cannot measure"; exit 2; fi
    m3="$(cd "$W" && timeout -k 5 20s "$SCRIP" "$f" < /dev/null 2>&1)"; r3=$?
    N=$((N+1)); if [ "$m3" = "$ora" ]; then PASS=$((PASS+1)); else FAIL=$((FAIL+1)); FAILED="$FAILED $a/m3(rc=$r3)"; fi
    if (cd "$W" && timeout -k 5 20s "$SCRIP" --compile --out="$a.s" "$a.sno" >/dev/null 2>&1) \
       && (cd "$W" && gcc -no-pie "$a.s" -o "$a.bin" -L"$RT_DIR" -Wl,-rpath,"$RT_DIR" -lscrip_rt -lm -lpthread >/dev/null 2>&1); then
        m4="$(cd "$W" && timeout -k 5 20s "./$a.bin" < /dev/null 2>&1)"; r4=$?
    else m4="<compile/link failed>"; r4=99; fi
    N=$((N+1)); if [ "$m4" = "$ora" ]; then PASS=$((PASS+1)); else FAIL=$((FAIL+1)); FAILED="$FAILED $a/m4(rc=$r4)"; fi
done
# ARM 5 -- the emitted asm must not name a bare callee as a match-time variable. `LEN(*F(0))` emitting a
# rt_pat_prim_int lookup of the string "F" is the defect's own signature, and it is invisible to a stream
# diff the moment F's value happens to coincide with the call's result.
(cd "$W" && timeout -k 5 20s "$SCRIP" --compile --out=sig.s a1.sno >/dev/null 2>&1) || { echo "⛔ REFUSE(rc=2): could not compile the signature probe"; exit 2; }
SIG=0
if grep -qE '^\.S[0-9]+:[[:space:]]+\.string[[:space:]]+"F"$' "$W/sig.s"; then SIG=1; FAIL=$((FAIL+1)); FAILED="$FAILED arm5/callee-name-emitted-as-a-match-time-variable"; else PASS=$((PASS+1)); fi
N=$((N+1))
[ "$N" -gt 0 ] || { echo "⛔ REFUSE(rc=2): graded zero probes"; exit 2; }
echo "test_gate_sno_deferred_pattern_primitive_arg: PASS=$PASS FAIL=$FAIL of $N (7 probes x 2 modes + 1 asm-signature arm), graded against $SBL -bf"
if [ "$FAIL" -ne 0 ]; then echo "RED:$FAILED"; exit 1; fi
echo "✅ deferred pattern-primitive arguments evaluate through the expression-thunk path in both modes"
exit 0
