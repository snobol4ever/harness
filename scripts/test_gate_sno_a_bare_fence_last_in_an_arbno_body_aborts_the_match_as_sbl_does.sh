#!/usr/bin/env bash
# test_gate_sno_a_bare_fence_last_in_an_arbno_body_aborts_the_match_as_sbl_does.sh -- a bare FENCE as the LAST element of an ARBNO body:
# once an iteration has committed, backtracking into the ARBNO reaches that FENCE, and sbl -bf (p_fen stacks ndabo, p_abc stacks ndabd over
# it) aborts the WHOLE match -- the enclosing alternation's next arm is never tried and the scan does not move on. SCRIP's ARBNO box lowers
# such a body with a fourth operand (the box itself, the "tail seal") and its frame arm dropped the recede edge under that seal: the omega
# popped ONE instance cell and jumped to the enclosing alternation's omega with rsp a cell short of the alternation's record, so the
# alternation's jmp [rsp+16] read a stale return address (SIGSEGV at pc 0x100000002 in both modes). The omega now recedes into the body
# tail's beta, the FENCE's own abort.
# Row snobol4-a-bare-fence-last-in-an-arbno-body-jumps-to-a-wild-pc-where-sbl-aborts-the-match (hq_snobol4).
#
# THE WITNESSES (each its own program, its own verdict; every ref is cut from sbl -bf at run time, never typed):
#   w1 'a' ? (ARBNO('a' FENCE) 'z' | 'a')              one committed iteration, the continuation fails, arm 2 is never tried: FAIL
#   w2 'aa' ? (ARBNO('a' FENCE) 'z' | 'a')             two committed iterations (two instance cells to unwind): FAIL
#   w3 'ab' ? (ARBNO('a' FENCE) 'z' | 'a')             the iteration after the commit fails on the text: FAIL
#   w4 'aab' ? (ARBNO('a' FENCE) 'b' 'c' | 'aab')      the continuation matches 'b' then fails on 'c' after two commits: FAIL
#   w5 'aab' ? (ARBNO('a' FENCE) 'b' | 'aab')          the continuation matches: MATCH (the abort edge is not taken)
#   w6 'x' ? (ARBNO('a' FENCE) 'z' | 'x')              no iteration commits, so nothing aborts and arm 2 matches: MATCH
#   w7 P = ARBNO('a' FENCE) 'z'; 'a' ? (P | 'a')       the same through a stored pattern: FAIL
#   w8 'ab' ? ((ARBNO('a' FENCE) 'z' | 'a') | 'ab')    a second alternation level above: the abort skips it too: FAIL
# arm 0 (CEO-1680, a proper test, no seam): the comparator grades a corrupted copy of sbl's answer and must read it RED.
# arm 1: m3 = sbl.  arm 2: m4 = sbl.  arm 3: the set REACHES the ARBNO frame arm (SCRIP_ARBNO_DIAG), or the gate refuses.
set -u
G=test_gate_sno_a_bare_fence_last_in_an_arbno_body_aborts_the_match_as_sbl_does
HERE="$(cd "$(dirname "$0")" && pwd)"; SD="$HERE/../../SCRIP"; SCRIP="$SD/scrip"
[ -x "$SCRIP" ] || { echo "⛔ REFUSE(rc=2) [$G]: no scrip binary at $SCRIP -- build first (make)"; exit 2; }
"$HERE/util_require_fresh.sh" --gate "$G" "$SCRIP" "${RT_DIR:-$SD/out}/libscrip_rt.so" || exit 2
. "$HERE/lib_oracle_flags.sh"
SBL="$(sbl_correctness_bin)"; [ -x "$SBL" ] || { echo "⛔ REFUSE(rc=2) [$G]: no correctness oracle ($SBL) -- the ref is cut from the oracle at run time, never typed"; exit 2; }
W="$(mktemp -d)"; trap 'rm -rf "$W"' EXIT
names="w1 w2 w3 w4 w5 w6 w7 w8"
prog() { : > "$W/$1.sno"; [ -n "$2" ] && printf '%s\n' "$2" >> "$W/$1.sno"; printf " %s :S(Y)F(N)\nY\tOUTPUT = 'MATCH'\t:(END)\nN\tOUTPUT = 'FAIL'\nEND\n" "$3" >> "$W/$1.sno"; }
prog w1 "" "'a' ? (ARBNO('a' FENCE) 'z' | 'a')"
prog w2 "" "'aa' ? (ARBNO('a' FENCE) 'z' | 'a')"
prog w3 "" "'ab' ? (ARBNO('a' FENCE) 'z' | 'a')"
prog w4 "" "'aab' ? (ARBNO('a' FENCE) 'b' 'c' | 'aab')"
prog w5 "" "'aab' ? (ARBNO('a' FENCE) 'b' | 'aab')"
prog w6 "" "'x' ? (ARBNO('a' FENCE) 'z' | 'x')"
prog w7 " P = ARBNO('a' FENCE) 'z'" "'a' ? (P | 'a')"
prog w8 "" "'ab' ? ((ARBNO('a' FENCE) 'z' | 'a') | 'ab')"
for n in $names; do
    w="$(cd "$W" && timeout -k 5 20 "$SBL" $(sbl_lang_flags) "$n.sno" </dev/null 2>/dev/null)"
    case "$w" in MATCH|FAIL) printf '%s' "$w" > "$W/$n.want";; *) echo "⛔ REFUSE(rc=2) [$G]: the oracle printed '$w' for $n, not MATCH or FAIL -- the arms cannot grade"; exit 2;; esac
    (cd "$W" && timeout -k 5 60 "$SCRIP" --compile -o "$n.s" "$n.sno" </dev/null >/dev/null 2>&1) \
        && gcc -no-pie "$W/$n.s" -L"$SD/out" -lscrip_rt -lm -lpthread -Wl,-rpath,"$SD/out" -o "$W/$n.bin" 2>/dev/null \
        || { echo "⛔ REFUSE(rc=2) [$G]: $n did not compile and link in mode 4"; exit 2; }
done
grade() { [ "$1" = "$2" ]; }
w1want="$(cat "$W/w1.want")"; bad="X$w1want"
grade "$w1want" "$bad" && { echo "⛔ REFUSE(rc=2) [$G]: arm 0 -- the comparator read a corrupted ref ('$bad') as GREEN; it cannot fail"; exit 2; }
echo "== [$G] a bare FENCE last in an ARBNO body, graded against $SBL"
echo "  PASS arm0 the comparator reads a corrupted ref ('$bad') RED"
reached=0; fail=0
for n in $names; do
    want="$(cat "$W/$n.want")"
    v3="$(cd "$W" && timeout -k 5 20 "$SCRIP" "$n.sno" </dev/null 2>&1 | head -c 200)"
    v4="$(cd "$W" && timeout -k 5 20 "$W/$n.bin" -- </dev/null 2>&1 | head -c 200)"
    for m in m3 m4; do
        v="$v3"; [ "$m" = m4 ] && v="$v4"
        if grade "$v" "$want"; then echo "  PASS arm1/2 $n $m = sbl ($want)"; else echo "  ⛔ arm1/2 $n $m RED: got '$v', sbl '$want'"; fail=1; fi
    done
    SCRIP_ARBNO_DIAG=1 "$SCRIP" --compile -o "$W/$n.d.s" "$W/$n.sno" </dev/null 2>&1 | grep -q 'ARBNO-ARM\] ARBNO-FRAME' && reached=$((reached + 1))
done
[ "$reached" -ge 6 ] || { echo "⛔ REFUSE(rc=2) [$G]: arm 3 -- only $reached of 8 witnesses reach the ARBNO frame arm; the set no longer tests the frame"; exit 2; }
echo "  PASS arm3 $reached of 8 witnesses reach the ARBNO frame arm"
[ "$fail" = 0 ] && { echo "OK [$G]: a bare FENCE last in an ARBNO body aborts the match as sbl does, both modes"; exit 0; }
echo "⛔ GATE RED [$G]: a bare FENCE last in an ARBNO body does not answer as sbl"; exit 1
