#!/usr/bin/env bash
# test_gate_pl_an_attributed_variable_wakes_its_goals_on_every_bind_road.sh -- an attributed variable bound on any road wakes its
# goals as swipl does, before the next goal and before an if-then-else commits: head unification of a constant, a structure and a
# repeated variable, =/2 inline and through call/1, a deep unification in either direction, a variable-variable binding in both
# orders and between two attributed variables, a binding made inside a C builtin (functor/3, arg/3, =../2, is/2, atom_length/2),
# memberchk/2 retrying past a woken goal's failure, a failed unification that wakes nothing, unifiable/3 that binds nothing, a woken
# goal that fails the binding, a ball thrown by a woken goal inside catch/3's run-time goal, copy_term/2 copying the attributes,
# freeze/2, frozen/2, dif/2, when/2, put_attr/3, get_attr/3, del_attr/2 and a user attr_unify_hook/2. Row prolog-swi-coroutining-
# and-attributed-variables-freeze-dif-when-put-attr-83-swi-cases (cto 2026-10-10); the design and its reviews are in the row's baton.
#
# THE WITNESS AND ITS REF, cut from swipl 9.0.4 with every variable name normalised to _ (the same sed runs on SCRIP's output):
# ../harness/scripts/fixtures/hb_pl_attvar_wakes_on_every_bind_road.pl, 33 shapes, 48 lines.
# ARMS: (1) mode 3 and (2) mode 4 equal the ref; (3)-(6) mode 3 and mode 4 at a 64 KB window under SCRIP_GC_STRESS=1 and 3 with
# SCRIP_GC_CHAIN_CHECK=3, equal to the ref and reading bad-link 0, offchain-swept 0, mismatch 0 and missing 0 (the attributed
# variable's two-DESCR block, its attribute chain and the wake list are typed heap storage the collector moves under every road).
# (7) THE ZERO-COST ARM: a fixed program that names no attributed-variable predicate (the setup_call_cleanup fixture) emits no
# flag test (cmp edx, 328 = DT_PLVAR | PL_VAR_ATTV after the and with 0x1FF, the attributed bit of a variable's tag word) and no $wakeup in its .s, while the witness's .s carries both (the control).
# FAIL_ONCE=1 grades against a ref with its first woke line removed, so every arm must red.
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)" || { echo "REFUSE(2): no SCRIP beside harness at $HERE/../../SCRIP (a port root) -- this gate measures SCRIP and cannot from here"; exit 2; }; G=pl_an_attributed_variable_wakes_its_goals_on_every_bind_road
[ -x "$ROOT/scrip" ] || { echo "GATE REFUSED(2) [$G]: no $ROOT/scrip -- run make"; exit 2; }
[ -n "${SCRIP_BIN:-}" ] || "$HERE/util_require_fresh.sh" --gate "$G" "$ROOT/scrip" "$ROOT/out/libscrip_rt.so" || exit 2
command -v gcc >/dev/null 2>&1 || { echo "GATE REFUSED(2) [$G]: gcc absent"; exit 2; }
S1="$HERE/fixtures/hb_pl_attvar_wakes_on_every_bind_road.pl"
[ -f "$S1" ] && [ -s "${S1%.pl}.ref" ] || { echo "GATE REFUSED(2) [$G]: the witness or its ref is missing ($S1)"; exit 2; }
W="$(mktemp -d "${TMPDIR:-/tmp}/plattv.XXXXXX")" || { echo "GATE REFUSED(2) [$G]: no workdir"; exit 2; }; trap 'rm -rf "$W"' EXIT
cp "$S1" "$W/r.pl"
if [ "${FAIL_ONCE:-0}" = 1 ]; then awk '!d && / woke / {d=1; next} {print}' "${S1%.pl}.ref" > "$W/r.ref"; else cp "${S1%.pl}.ref" "$W/r.ref"; fi
( cd "$W" && "$ROOT/scrip" --compile --out="$W/r.s" "$W/r.pl" < /dev/null > "$W/r.cerr" 2>&1 ) || { echo "GATE REFUSED(2) [$G]: the witness does not compile ($(head -c 120 "$W/r.cerr"))"; exit 2; }
gcc -o "$W/r.bin" "$W/r.s" -L"$ROOT/out" -lscrip_rt -Wl,-rpath,"$ROOT/out" -lm -lpthread > "$W/r.lerr" 2>&1 || { echo "GATE REFUSED(2) [$G]: the witness does not link"; exit 2; }
run_arm() {
    local n="$1" mode="$2" stress="$3" rc
    if [ "$mode" = m3 ]; then ( cd "$W" && env -u SCRIP_HEAP_KB -u SCRIP_HEAP_MB -u SCRIP_HEAP_CAP_KB -u SCRIP_HEAP_MAX_MB $stress timeout -k 5 300 "$ROOT/scrip" "$W/r.pl" < /dev/null > "$W/$n.out" 2> "$W/$n.err" ); rc=$?
    else ( cd "$W" && env -u SCRIP_HEAP_KB -u SCRIP_HEAP_MB -u SCRIP_HEAP_CAP_KB -u SCRIP_HEAP_MAX_MB $stress timeout -k 5 300 "$W/r.bin" < /dev/null > "$W/$n.out" 2> "$W/$n.err" ); rc=$?; fi
    grep -v '^\[GC-' "$W/$n.out" | sed -E 's/_[A-Z]?[0-9]+/_/g' > "$W/$n.txt"
    if [ "$rc" -ne 0 ] || ! cmp -s "$W/$n.txt" "$W/r.ref"; then echo "  RED ($n) $mode${stress:+ $stress}: rc=$rc, the output differs from swipl's:"; diff "$W/r.ref" "$W/$n.txt" | head -6; return 1; fi
    if [ -n "$stress" ]; then
        local k v reading=""
        for k in bad-link offchain-swept mismatch missing; do
            v=$(grep -h -o "$k=[0-9]*" "$W/$n.err" "$W/$n.out" | head -1)
            [ -n "$v" ] || { echo "  RED ($n) $mode $stress: the chain check printed no $k reading"; return 1; }
            [ "$v" = "$k=0" ] || { echo "  RED ($n) $mode $stress: the chain reads $v"; return 1; }
            reading="$reading $v"
        done
        echo "  ok  ($n) $mode under $stress: the swipl lines, the chain reads$reading"
    else
        echo "  ok  ($n) $mode: rc 0, the swipl lines"
    fi
    return 0
}
bad=0
run_arm 1 m3 "" || bad=1
run_arm 2 m4 "" || bad=1
run_arm 3 m3 "SCRIP_HEAP_KB=64 SCRIP_GC_STRESS=1 SCRIP_GC_CHAIN_CHECK=3" || bad=1
run_arm 4 m3 "SCRIP_HEAP_KB=64 SCRIP_GC_STRESS=3 SCRIP_GC_CHAIN_CHECK=3" || bad=1
run_arm 5 m4 "SCRIP_HEAP_KB=64 SCRIP_GC_STRESS=1 SCRIP_GC_CHAIN_CHECK=3" || bad=1
run_arm 6 m4 "SCRIP_HEAP_KB=64 SCRIP_GC_STRESS=3 SCRIP_GC_CHAIN_CHECK=3" || bad=1
Z="$HERE/fixtures/hb_pl_setup_call_cleanup_runs_its_cleanup_on_every_road.pl"
if [ ! -f "$Z" ]; then echo "  RED (7) the unarmed fixture $Z is missing"; bad=1
elif ! ( cd "$W" && cp "$Z" "$W/z.pl" && "$ROOT/scrip" --compile --out="$W/z.s" "$W/z.pl" < /dev/null > "$W/z.cerr" 2>&1 ); then echo "  RED (7) the unarmed fixture does not compile"; bad=1
else
    za=$(grep -c "cmp *edx, *328" "$W/z.s"); zw=$(grep -c "wakeup" "$W/z.s"); ra=$(grep -c "cmp *edx, *328" "$W/r.s"); rw=$(grep -c "wakeup" "$W/r.s")
    if [ "$za" -ne 0 ] || [ "$zw" -ne 0 ]; then echo "  RED (7) the unarmed program carries $za flag tests and $zw wakeup references"; bad=1
    elif [ "$ra" -eq 0 ] || [ "$rw" -eq 0 ]; then echo "  RED (7) the control read nothing: the witness carries $ra flag tests and $rw wakeup references"; bad=1
    else echo "  ok  (7) unarmed: 0 flag tests, 0 wakeup references; the armed witness: $ra flag tests, $rw wakeup references"; fi
fi
TREE="$(git -C "$ROOT" rev-parse --short HEAD 2>/dev/null || echo '?')$(git -C "$ROOT" diff --quiet 2>/dev/null || echo -DIRTY)"
if [ $bad -eq 0 ]; then echo "GATE PASS(0) [$G]: an attributed variable wakes its goals as swipl does on every bind road in both modes, and its heap storage survives forced collections under the chain check (tree SCRIP=$TREE)"; exit 0; fi
echo "GATE FAIL(1) [$G]: a bind road wakes differently from swipl, or the chain lost a frame under forced collections (tree SCRIP=$TREE)"; exit 1
