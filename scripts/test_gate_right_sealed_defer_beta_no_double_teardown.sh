#!/usr/bin/env bash
# test_gate_right_sealed_defer_beta_no_double_teardown.sh -- THE ACCEPTANCE GATE for row
# snobol4-a-right-sealed-defer-tears-down-its-zeta-frame-twice (cto 2026-09-11, CEO-564: the snobol4-rungs
# 16 CRASH + 8 HANG class).
#
# THE DEFECT: a MATCH_DEFER whose referenced pattern is RIGHT-SEALED -- its rightmost element is a FENCE, so
# backtracking into it can never yield another alternative (lower_snobol4.c sno_pat_right_sealed -> nd->seal=1)
# -- is given a ζ-ACTIVATION FRAME by bb_match_defer.cpp: α does `push rbp; mov rbp,rsp`, and BOTH of its exits
# tear it down, γ at L(4) and ω at L(5), each `mov rsp,rbp; pop rbp`. The β (recede) port did the teardown A
# SECOND TIME before failing on to ω. ⛔ β IS ONLY EVER ENTERED AFTER γ HAS ALREADY POPPED THE FRAME -- it is
# the consumer downstream of γ receding back into this box -- so by then rbp holds the CALLER's frame base:
# `mov rsp,rbp` moves rsp to a wild place, `pop rbp` takes a word off it, and the box jumps out with rsp and rbp
# both corrupt. The observed crash is a jump into the middle of the mode-3 slab with rbp=0 and rsp still high,
# which is why it never looked like the stack exhaustion an unbounded ARBNO would produce.
#
# ⛔⭐ THIS GATE GRADES OUTPUT AGAINST THE ORACLE, NEVER EXIT STATUS (ceo CEO-564, on hq_S's measurement that a
# crash row had been "cured" into a silent truncation that every rc-based predicate passed). A program here is
# GREEN only when its stdout is byte-identical to spitbol's on the same source, in BOTH modes. An rc-based arm
# could not tell this cure from a silencing, and that is the whole point of the row.
#
# THE CONTROLS ARE LOAD-BEARING: witnesses 2 and 3 are the same shape ONE FENCE apart from witness 1 -- `G0 =
# LEN(0)` takes seal=2 (the memoised-cell arm, no ζ-frame) and the inline `ARBNO(FENCE(LEN(0)))` never builds a
# DEFER at all. Both were green before this cure and must stay green after it: a cure that reached them would be
# a cure that stopped building the frame, not one that stopped popping it twice.
#
# HERMETIC: every program is written to mktemp. It grades no corpus population and publishes no row, so it is
# not a board (ONE RUNNER, ONE BOARD, CEO-523/CEO-547) and every seat can run it.
# EXIT: 0 all arms · 1 an arm failed · 2 REFUSED (no spitbol oracle, no build, no mktemp).
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/../../SCRIP" && pwd)"
SCRIP="${SCRIP:-$ROOT/scrip}"
ORACLE="${SPITBOL:-$(command -v spitbol 2>/dev/null || true)}"
[ -x "$SCRIP" ] || { echo "⛔ REFUSED-TO-GRADE rc=2: no ./scrip at $SCRIP -- run 'make'"; exit 2; }
[ -n "$ORACLE" ] && [ -x "$ORACLE" ] || { echo "⛔ REFUSED-TO-GRADE rc=2: the spitbol oracle is not on PATH -- this gate compares ANSWERS against it and cannot invent one"; exit 2; }
[ -f "$ROOT/out/libscrip_rt.so" ] || { echo "⛔ REFUSED-TO-GRADE rc=2: out/libscrip_rt.so absent -- mode 4 cannot link"; exit 2; }
W="$(mktemp -d "${TMPDIR:-/tmp}/gate_rsdefer.XXXXXX")" || { echo "⛔ REFUSED-TO-GRADE rc=2: mktemp failed"; exit 2; }
trap 'rm -rf "$W"' EXIT
fails=0; checks=0
ck() { checks=$((checks+1)); if [ "$1" = ok ]; then printf '  ok    %s\n' "$2"; else printf '  FAIL  %s\n' "$2"; fails=$((fails+1)); fi; }

w() { printf '%s\n' "$2" > "$W/$1.sno"; }
TAIL=$'OK        OUTPUT = \'match\'                      :(END)\nNO        OUTPUT = \'nomatch\'\nEND'
w r1_min          "          G0            =  FENCE(LEN(0))
          'ab' ARBNO(*G0) RPOS(0)                          :S(OK)F(NO)
$TAIL"
w r2_ctl_noseal   "          G0            =  LEN(0)
          'ab' ARBNO(*G0) RPOS(0)                          :S(OK)F(NO)
$TAIL"
w r3_ctl_inline   "          'ab' ARBNO(FENCE(LEN(0))) RPOS(0)                          :S(OK)F(NO)
$TAIL"
w r4_fence_empty  "          G0            =  FENCE('')
          'ab' ARBNO(*G0) RPOS(0)                          :S(OK)F(NO)
$TAIL"
w arbno_fence_pos_replace_branch_2 "          G0            =  FENCE(ARBNO(POS(2)))
          P             =  ARBNO(*G0)
          'ab' *P RPOS(0)                          :S(OK)F(NO)
$TAIL"
w arbno_fence_rpos_replace_branch_1 "          G0            =  FENCE('')
          'ab' ARBNO(*G0) RPOS(0)                          :S(OK)F(NO)
$TAIL"
w fence_arb_tab_replace_branch_1 "          G0            =  FENCE(ARB)
          P             =  (*G0) . v1 TAB(2)
          'a b c' *P RPOS(0)                          :S(OK)F(NO)
$TAIL"
w fence_arb_tab_replace_branch_2 "          G0            =  FENCE(ARB)
          G1            =  ((TAB(2)) . v1) . v1
          P             =  (*G0) . v1 *G1
          'a b c' *P RPOS(0)                          :S(OK)F(NO)
$TAIL"

echo "=== gate: a right-sealed DEFER's β must not tear down a ζ-frame its γ already tore down ==="
echo "--- every witness is graded on ITS OUTPUT against spitbol, in both modes; rc is reported, never asserted ---"
for f in "$W"/*.sno; do
    n="$(basename "$f" .sno)"
    want="$(timeout -k 5 20 "$ORACLE" "$f" 2>/dev/null)"; orc=$?
    if [ "$orc" != 0 ]; then ck no "$n: the ORACLE itself did not run (rc=$orc) -- nothing can be graded against it"; continue; fi
    got3="$(timeout -k 5 20 "$SCRIP" "$f" 2>/dev/null)"; rc3=$?
    [ "$got3" = "$want" ] && ck ok "$n m3: output matches the oracle ($(printf '%s' "$want" | head -1), rc=$rc3)" \
                          || ck no "$n m3: oracle says [$(printf '%s' "$want" | tr '\n' '|')] scrip says [$(printf '%s' "$got3" | tr '\n' '|')] rc=$rc3"
    if "$SCRIP" --compile "$f" > "$W/$n.s" 2>/dev/null \
       && gcc -c "$W/$n.s" -o "$W/$n.o" 2>/dev/null \
       && gcc "$W/$n.o" -L"$ROOT/out" -lscrip_rt -lm -Wl,-rpath,"$ROOT/out" -o "$W/$n.bin" 2>/dev/null; then
        got4="$(timeout -k 5 20 "$W/$n.bin" 2>/dev/null)"; rc4=$?
        [ "$got4" = "$want" ] && ck ok "$n m4: output matches the oracle (rc=$rc4)" \
                              || ck no "$n m4: oracle says [$(printf '%s' "$want" | tr '\n' '|')] scrip says [$(printf '%s' "$got4" | tr '\n' '|')] rc=$rc4"
    else
        ck no "$n m4: did not compile-and-link -- a witness that cannot be built cannot be graded"
    fi
done
echo "--- the emitted β of a seal=1 DEFER carries no frame teardown (ASM-DIFF-FIRST, the cure at its site) ---"
# ⛔ THE BEHAVIOURAL ARMS ABOVE CANNOT SEE A REGRESSION THAT REINSTATES THE POP ON A PATH THESE WITNESSES DO NOT
# TAKE. This arm reads the emission itself and NAMES ITS MODE (mode 4, --compile): between the β label of the
# right-sealed DEFER and the ω jump that follows it there must be no `pop rbp`.
asm="$W/r1_min.s"
if [ -s "$asm" ]; then
    seg="$(awk '/^[A-Za-z0-9_.]*match_defer_β:/{f=1} f{print; if(++k>8)exit}' "$asm")"
    [ -n "$seg" ] || { seg="(no match_defer_β label definition found in the emission)"; }
    grep -q 'pop  *rbp' <<<"$seg" && ck no "the seal=1 β still pops rbp -- the double teardown is back: $(printf '%s' "$seg" | tr '\n' ';' | head -c 200)" \
                                  || ck ok "the seal=1 β reaches ω with no frame teardown of its own"
else
    ck no "no mode-4 asm was emitted for the minimal witness, so the emission arm graded nothing"
fi
echo "------------------------------------------------------------"
if [ "$fails" -ne 0 ]; then echo "⛔ GATE FAIL: $fails of $checks check(s) failed"; exit 1; fi
echo "✅ GATE PASS: $checks/$checks checks"; exit 0
