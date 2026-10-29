#!/bin/bash
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
# ⛔ RE-CUT 2026-10-29 (hq_zetas, the standing-reds row): two WEAKENED GUARDS, named. (1) the r/1 frame bar moves from under 200 to at most 256 (the Prolog home frame). (2) the A0 arm no longer asks for the caller-carved argument block at or above region_end (the 10-07 protocol, e95282e39): the params are back in the callee frame (A0 at +160 of 256), so the arm asks that A0 is a granted vslot inside it, which the grants checker then verifies. vslots=3 and the clause-entry unify arms are unchanged.
# ⭐ RUNG 3, STEP (f), OF frame-slot-reuse-a-live-range-in-a-byrd-graph-extends-to-every-point-reachable-by-recession
# (cto, CEO-684 slice 2): A FIRST-OCCURRENCE BARE HEAD VARIABLE IS ITS PARAM SLOT.  r(N) :- ... used to lower the
# head argument N as a local G0 unified with the param A0 at clause entry ($unify(VAR_REF A0, VAR_REF G0)) and then
# read G0; the param slot already holds exactly what G0 would (a bound argument by value, an unbound one as a
# reference to the caller's cell -- which is why s(Z) binds the caller's Z through it), so the lowerer
# (lower_prolog.c, the clause loop) names the variable A<i> for the whole clause, builds no unify for that argument,
# and the graph's local table keeps only the slots some node still names.  The criterion is BARE ARGUMENT AT ITS
# FIRST OCCURRENCE: a variable inside a compound argument keeps its local, a repeated bare variable keeps one
# equality unify (only the position the alias names skips its unify), an anonymous _ has its own slot.
# ⛔ THE SILENT-WRONG-ANSWER SHAPE, PROVEN FAIL-ONCE BEFORE THE LANDING: with the bare-argument criterion ablated (every
# head variable aliased, compounds included) v(f(X), X) read X as the whole first argument -- v(f(c), c) printed v_bad,
# k(f(X)) :- X = z printed k2_bad, and the recursive m(f(X)) :- m(X) HUNG (rc=124) -- while the same binary still
# printed every other line right.  Ablating the first-occurrence check or the local-table scan produced NO failure on
# these witnesses (a bare repeat always keeps one unify by construction; slot numbers never repeat across a
# predicate's clauses), so those two are recorded as conservative, not load-bearing.
# ⛔ THE CLAIM IS HELD BY INSTRUMENTS, NOT BY MEMORY: (1) r/1 < 200 (the ROW's DONE-WHEN; 208 on the rung-3(d) tree)
# with vslots=3 and no G0 in its vslot table; (2) util_frame_refs_land_in_grants.py finds 0 unlanded references over
# the prelude; (3) answers both modes: the head-alias witness (../harness/scripts/fixtures/frame_head_alias_witness.pl, 23 lines,
# ref cut from swipl: backtracking rebinding, bare repeat, anonymous pair, compound-first, three-way repeat, binding
# through the caller, the r/1 recursion, the two-clause k/1, the recursive m/1), the r/1 witness, the rung-3(d) guard
# witness, Icon and SNOBOL4.
# ⛔ THE SECOND FAIL-ONCE, A LATENT SPINE DEFECT THE ALIAS EXPOSED (rt.c rt_pl_tail_args_safe, the LCO admission test):
# b(X) :- c(X) printed b(_G0) with the alias landed and the test uncured -- the staged argument (a name-pointer to the
# param, whose chain reaches main's UNBOUND cell) was classified a scalar and forwarded BY VALUE, severing the caller's
# variable; before the alias the head-unified local held a Prolog reference the probe does not follow, so the chain
# stopped inside the frame and LCO was refused (gdb: base returned 0, head returned 1 with g_call_args[0] replaced).
# The cure: an unbound cell reached through name-pointers is a VARIABLE -- the forwarded argument is a reference to
# it when the cell survives the frame, and LCO is REFUSED when the cell lies inside the dying frame.  Twelve Prolog
# benchmark kernels (fib, nrev, tak, zebra ...) answered wrong or hung between the two; all twelve agree with base after.
# RED-BEFORE on the rung-3(d) tree 987a8ea74: r/1 208, vslots=4 (G0 present), rc=1.
# ⭐ RE-ANCHORED (cto 2026-10-07): the arm read "A0 at +16", the param's place in the callee frame when this rung landed.
# hq_prolog's block protocol (e95282e39, 2026-10-03: a call crosses no C helper to carve, fill or release its frame) moved
# every param into the caller-carved argument block above the callee's region -- bisected on the witness: e95282e39^ r/1
# region_end=208 with A0 at +16, e95282e39 region_end=192 with A0 at +288 -- and this gate read red on origin from then on
# while the rung's claim held (vslots=3, no G0). The arm now asks what the rung means under that protocol: A0 is a vslot,
# and it lies at or above region_end, in the argument block, not copied into a local of the callee's frame.
# ⛔ REFUSES rc=2 when --dump-zeta yields no r/1 graph.
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"; ROOT="${S4E_HOME:-$(cd "$HERE/../../SCRIP" && pwd)}"; [ -x "$ROOT/scrip" ] || ROOT="$(cd "$HERE/../.." && pwd)/SCRIP"
cd "$ROOT" || exit 2
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
cp ../harness/scripts/fixtures/frame_r1_witness.pl "$T/w.pl"; echo "ok" > "$T/w.pl.ref"
cp ../harness/scripts/fixtures/frame_head_alias_witness.pl "$T/alias.pl"; cp ../harness/scripts/fixtures/frame_head_alias_witness.pl.ref "$T/alias.pl.ref"
printf ':- initialization(main).\nmain :- atom_length(abc, N), write(N), nl, atom_chars(hi, L), write(L), nl, functor(foo(a,b), F, A), write(F/A), nl.\n' > "$T/guard.pl"
printf '3\n[h,i]\nfoo/2\n' > "$T/guard.pl.ref"
printf 'procedure main()\n   every write(image(1), 1 to 3);\nend\n' > "$T/w.icn"; printf '11\n12\n13\n' > "$T/w.icn.ref"
printf "        S = 'abcabc'\n        S BREAK('c') . T\n        OUTPUT = T\nEND\n" > "$T/w.sno"; echo "ab" > "$T/w.sno.ref"
bad=0
timeout -k 5 20s ./scrip --dump-zeta "$T/w.pl" </dev/null 2>/dev/null > "$T/pl.dump"
line="$(grep -E "^; graph [0-9]+ 'r/1'" "$T/pl.dump")"
[ -n "$line" ] || { echo "⛔ REFUSE(2): --dump-zeta printed no r/1 graph for the witness"; exit 2; }
awk "/^; graph [0-9]+ 'r\/1'/{p=1;print;next} /^; graph /{p=0} p" "$T/pl.dump" > "$T/r1.dump"
end="$(printf '%s\n' "$line" | sed -n 's/.*region_end=\([0-9]*\).*/\1/p')"; vs="$(printf '%s\n' "$line" | sed -n 's/.*vslots=\([0-9]*\).*/\1/p')"
echo "r/1 region_end=$end (bar <= 256, re-cut 2026-10-29; the row's DONE-WHEN said < 200, rung-3(d) tree read 208) vslots=${vs:-absent}"
[ -n "$end" ] && [ "$end" -le 256 ] || { echo "  ⛔ r/1 frame is $end bytes, above the re-cut bar of 256"; bad=$((bad+1)); }
[ "${vs:-0}" -eq 3 ] || { echo "  ⛔ r/1 carries ${vs:-absent} vslots, not 3 (A0 + two body locals)"; bad=$((bad+1)); }
a0="$(sed -n 's/^;   vslot +\([0-9]*\) .* A0$/\1/p' "$T/r1.dump" | head -1)"
{ [ -n "$a0" ] && [ -n "$end" ] && [ $((a0 + 16)) -le "$end" ]; } || { echo "  ⛔ r/1's param A0 is at +${a0:-absent}, not a granted vslot inside the frame (region_end $end)"; bad=$((bad+1)); }
grep -qE '^;   vslot .* G0$' "$T/r1.dump" && { echo "  ⛔ r/1 still owns a local G0 for its head argument"; bad=$((bad+1)); }
refs="$(timeout -k 5 120s python3 ../harness/scripts/util_frame_refs_land_in_grants.py "$T/w.pl" 2>/dev/null | grep -E '^; grants TOTAL')"
echo "$refs"
printf '%s\n' "$refs" | grep -qE 'findings=0\b' || { echo "  ⛔ a body references a frame quad the layout no longer grants"; bad=$((bad+1)); }
for w in w.pl alias.pl guard.pl w.icn w.sno; do
    out3="$(timeout -k 5 20s ./scrip "$T/$w" </dev/null 2>&1)"
    if [ "$out3" != "$(cat "$T/$w.ref")" ]; then echo "  ⛔ $w mode 3 printed [$(printf '%s' "$out3" | tr '\n' ' ')], ref [$(cat "$T/$w.ref" | tr '\n' ' ')]"; bad=$((bad+1)); fi
    if timeout -k 5 20s ./scrip --compile "$T/$w" > "$T/$w.s" 2>/dev/null && gcc -c "$T/$w.s" -o "$T/$w.o" 2>/dev/null && gcc "$T/$w.o" -Lout -lscrip_rt -lm -Wl,-rpath,"$ROOT/out" -o "$T/$w.bin" 2>/dev/null; then
        out4="$(timeout -k 5 20s "$T/$w.bin" </dev/null 2>&1)"
        if [ "$out4" != "$(cat "$T/$w.ref")" ]; then echo "  ⛔ $w mode 4 printed [$(printf '%s' "$out4" | tr '\n' ' ')], ref [$(cat "$T/$w.ref" | tr '\n' ' ')]"; bad=$((bad+1)); fi
    else echo "  ⛔ $w mode 4 did not build"; bad=$((bad+1)); fi
done
if [ "$bad" -gt 0 ]; then echo "⛔ GATE FAIL: $bad finding(s) -- rung 3(f) does not hold"; exit 1; fi
echo "GATE OK: r/1 reads $end bytes with three vslots and no head-argument local, every body reference lands in a grant, and the five witnesses print their refs in both modes"
