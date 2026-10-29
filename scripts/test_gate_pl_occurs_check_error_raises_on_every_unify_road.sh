#!/usr/bin/env bash
# test_gate_pl_occurs_check_error_raises_on_every_unify_road.sh -- set_prolog_flag(occurs_check, error) raises
# error(occurs_check(V, T), _) on the asm unify road as swipl does, in both modes, and the raise road's two poll sites are
# found by the chain under forced collections. Row prolog-occurs-check-error-mode-raises-on-the-asm-unify-road-where-it-now-fails
# (cto 2026-10-09): rtx_pl_unify stays non-allocating and unpolled; its FAILURE goes to a cold label that, only when the trail
# header's occurs_check word reads 2, re-runs the pair on the cx road through rt_pl_dop_unify_raise (a PL_CTX_LEAF_BALL leaf that
# builds the ball, unwinds what it bound and arms r15) and then polls -- in pl_arm_unify (bb_call_pl_leaf.cpp, the body =/2 and
# $unify arm) and on bb_unify_value.cpp's L(60) road (a repeated head variable, and a head structure's argument). Before the cure
# every one of shapes 1-7 read "no" (the violation FAILED); shape 8 is a plain failure that must not raise, and the true and false
# modes must not raise either.
#
# THE WITNESS AND ITS REF are ../harness/scripts/gc_witnesses/hb_pl_occurs_check_error_raises_on_the_asm_unify_road.pl and its .ref, cut from
# swipl (three iterations; swipl itself aborts near the seventeenth iteration of a longer loop, so the loop stays short).
# ARMS: (1) mode 3 equals the ref, rc 0; (2) mode 4 equals the ref, rc 0; (3) mode 3 under SCRIP_GC_STRESS=1 and
# SCRIP_GC_CHAIN_CHECK=1 equals the ref with the chain reading frameless 0 and mismatch 0; (4) the same in mode 4.
# FAIL_ONCE=1 grades against a ref with its first raised line removed, so arms 1 and 2 must red.
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)" || { echo "REFUSE(2): no SCRIP beside harness at $HERE/../../SCRIP (a port root) -- this gate measures SCRIP and cannot from here"; exit 2; }; G=pl_occurs_check_error_raises_on_every_unify_road
[ -x "$ROOT/scrip" ] || { echo "GATE REFUSED(2) [$G]: no $ROOT/scrip -- run make"; exit 2; }
[ -n "${SCRIP_BIN:-}" ] || "$HERE/util_require_fresh.sh" --gate "$G" "$ROOT/scrip" "$ROOT/out/libscrip_rt.so" || exit 2
command -v gcc >/dev/null 2>&1 || { echo "GATE REFUSED(2) [$G]: gcc absent"; exit 2; }
SRC="$HERE/gc_witnesses/hb_pl_occurs_check_error_raises_on_the_asm_unify_road.pl"; REF="${SRC%.pl}.ref"
[ -f "$SRC" ] && [ -s "$REF" ] || { echo "GATE REFUSED(2) [$G]: the witness or its ref is missing ($SRC)"; exit 2; }
W="$(mktemp -d "${TMPDIR:-/tmp}/ploc.XXXXXX")" || { echo "GATE REFUSED(2) [$G]: no workdir"; exit 2; }; trap 'rm -rf "$W"' EXIT
cp "$SRC" "$W/w.pl"
if [ "${FAIL_ONCE:-0}" = 1 ]; then awk '!d && /-raised$/ {d=1; next} {print}' "$REF" > "$W/w.ref"; else cp "$REF" "$W/w.ref"; fi
( cd "$W" && "$ROOT/scrip" --compile --out="$W/w.s" "$W/w.pl" < /dev/null > "$W/c.err" 2>&1 ) || { echo "GATE REFUSED(2) [$G]: the witness does not compile ($(head -c 120 "$W/c.err"))"; exit 2; }
gcc -no-pie -o "$W/w.bin" "$W/w.s" -L"$ROOT/out" -lscrip_rt -Wl,-rpath,"$ROOT/out" -lm -lpthread > "$W/link.err" 2>&1 || { echo "GATE REFUSED(2) [$G]: the witness does not link ($(head -c 120 "$W/link.err"))"; exit 2; }
run_arm() {
    local n="$1" mode="$2" stress="$3" rc
    if [ "$mode" = m3 ]; then
        ( cd "$W" && env -u SCRIP_HEAP_KB $stress timeout -k 5 60 "$ROOT/scrip" "$W/w.pl" < /dev/null > "$W/$n.out" 2> "$W/$n.err" ); rc=$?
    else
        ( cd "$W" && env -u SCRIP_HEAP_KB $stress timeout -k 5 60 "$W/w.bin" < /dev/null > "$W/$n.out" 2> "$W/$n.err" ); rc=$?
    fi
    grep -v '^\[GC-' "$W/$n.out" > "$W/$n.txt"
    if [ "$rc" -ne 0 ] || ! cmp -s "$W/$n.txt" "$W/w.ref"; then echo "  RED ($n) $mode${stress:+ $stress}: rc=$rc, the output differs from swipl's:"; diff "$W/w.ref" "$W/$n.txt" | head -6; return 1; fi
    if [ -n "$stress" ]; then
        local fl mm
        fl=$(grep -h -o 'frameless=[0-9]*' "$W/$n.err" "$W/$n.out" | head -1); mm=$(grep -h -o 'mismatch=[0-9]*' "$W/$n.err" "$W/$n.out" | head -1)
        [ -n "$fl" ] && [ -n "$mm" ] || { echo "  RED ($n) $mode $stress: the chain check printed no reading"; return 1; }
        [ "$fl" = frameless=0 ] && [ "$mm" = mismatch=0 ] || { echo "  RED ($n) $mode $stress: the chain reads $fl $mm"; return 1; }
        echo "  ok  ($n) $mode under stress: the swipl lines, the chain reads $fl $mm"
    else
        echo "  ok  ($n) $mode: rc 0, the swipl lines"
    fi
    return 0
}
bad=0
run_arm 1 m3 "" || bad=1
run_arm 2 m4 "" || bad=1
run_arm 3 m3 "SCRIP_GC_STRESS=1 SCRIP_GC_CHAIN_CHECK=1" || bad=1
run_arm 4 m4 "SCRIP_GC_STRESS=1 SCRIP_GC_CHAIN_CHECK=1" || bad=1
TREE="$(git -C "$ROOT" rev-parse --short HEAD 2>/dev/null || echo '?')$(git -C "$ROOT" diff --quiet 2>/dev/null || echo -DIRTY)"
if [ $bad -eq 0 ]; then echo "GATE PASS(0) [$G]: occurs_check error raises on the asm unify road in both modes as swipl does, and the raise road's polls are found by the chain (tree SCRIP=$TREE)"; exit 0; fi
echo "GATE FAIL(1) [$G]: an occurs_check shape answers differently from swipl, or the chain lost a raise-road poll (tree SCRIP=$TREE)"; exit 1
