#!/usr/bin/env bash
# test_gate_pl_an_erased_clauses_code_is_reclaimed_once_no_activation_can_reach_it.sh -- ORDER (2) of row
# prolog-the-code-assertz-generates-is-reclaimed-once-nothing-can-reference-it-lon-2026-09-27 (cto 2026-10-11; Lon 2026-09-27, in-chat to
# the cto, verbatim: "make sure that generated code from assertz gets reclaimed when that structure is no longer able to be referenced").
# An erased clause's run-time fragment gives its code pages back (PROT_NONE, then MADV_DONTNEED; its frame maps and site block leave the
# collector's registries; its rt_proc entry, dc entry and alpha cell become a named bomb; its chain offset becomes 0 so the packet walk
# lands on the bomb's first byte) once a pass at a db operation after a collection -- or after 1024 erasures -- finds, over the whole
# frame list of rt_gc_frames_visit (the chain plus the retained frames its typed links reach), (a) no frame whose map lies in the fragment
# and no PTR_CODE word that points into it, and (b) its erase generation below every live walk's: a frame in fragment j belongs to a walk
# that took G > ref(j), so ref(j) + 1 bounds G from below and the erase must be older than that bound. The head slot (the packet entry)
# and an unrecorded fragment are never reclaimed; the clause term stays (the IR_TO db walks of retract and clause read it, and their G is
# not on any map yet).
#
# ARMS, each in mode 3 and mode 4:
#   (1) the row's assert/retract loop at 3000 cycles answers 3000 and its last [PL-RECLAIM] report reads at least 1500 reclaimed, and
#       reclaimed_pages equal to reclaimed (one page a fact).
#   (2) seven witnesses of the cfo's QA (8) equal swipl's output under SCRIP_HEAP_KB=64 SCRIP_GC_STRESS=1 SCRIP_GC_CHAIN_CHECK=3, with
#       the chain walk whole (missing 0, offchain-swept 0, mismatch 0): retract inside a forall over the same predicate (the logical
#       update view), an asserted clause whose body leaves a choice erased and backtracked into, a clause that retracts itself, a cut
#       through a dynamic enumeration, a throw out of an asserted clause, later clauses erased under a live walk that then reaches them,
#       and an erased rule inside findall -- and the throw witness reclaims (reclaimed > 0), so a pass ran and decided.
#       The chain the reclaim trusts must hold every frame that carries heap pointers (CHAIN-CHECK mismatch, CHAIN-WALK mapdiff and the
#       four extra-*-ptrgc classes 0). Two classes read identically on the parent b88166e8c and are tolerated: missing (a frame the chain
#       finds and the marker scan does not; the cut witness, 902 of 929 walks in both modes) and offchain-swept (a marker frame holding no
#       heap pointer that the chain leaves for dead; the mode-4 choice and throw witnesses, 1203 and 100). A walk that stops short refuses
#       the pass (rt_gc_frames_visit returns 0).
#   (3) THE PLANT: SCRIP_GC_PLANT_PL_RECLAIM=1 reclaims what a frame holds or a live walk can still see. Under stress the later-clauses
#       witness dies on the named bomb (the walk enters a reclaimed slot through the chain), the erased-choice witness dies (by the reclaim's own bomb, or by the collector's chain
#       refusing the reclaimed fragment's frame: its site block left the registry with its code, so the pc names no site, or a link's beta names no graph), and both
#       print the plant's [PL-RECLAIM-PLANT] applied banner -- the two protections are what keep arm (2) green.
# FAIL_ONCE=1 requires the throw witness to reclaim nothing, so arm (2) must red.
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)"; G=pl_an_erased_clauses_code_is_reclaimed_once_no_activation_can_reach_it
[ -x "$ROOT/scrip" ] || { echo "GATE REFUSED(2) [$G]: no $ROOT/scrip -- run make"; exit 2; }
[ -n "${SCRIP_BIN:-}" ] || "$HERE/util_require_fresh.sh" --gate "$G" "$ROOT/scrip" "$ROOT/out/libscrip_rt.so" || exit 2
command -v gcc >/dev/null 2>&1 || { echo "GATE REFUSED(2) [$G]: gcc absent"; exit 2; }
W="$(mktemp -d "${TMPDIR:-/tmp}/plrc.XXXXXX")" || { echo "GATE REFUSED(2) [$G]: no workdir"; exit 2; }; trap 'rm -rf "$W"' EXIT
CH=':- initialization(main).'
printf '%s\n' "$CH" ':- dynamic(pi/3).' 'loop(0) :- !.' 'loop(N) :- ( retract(pi(a, 1, M)) -> true ; M = 0 ), M1 is M + 1, assertz(pi(a, 1, M1)), N1 is N - 1, loop(N1).' 'main :- loop(3000), pi(a, 1, V), write(V), nl, halt.' > "$W/w1.pl"
printf '3000\n' > "$W/w1.ref"
printf '%s\n' "$CH" ':- dynamic(f/1).' 'main :- assertz(f(1)), assertz(f(2)), assertz(f(3)), forall(f(X), (retract(f(X)), Y is X + 10, assertz(f(Y)), write(X), nl)), findall(Z, f(Z), L), write(L), nl, halt.' > "$W/w2.pl"
printf '1\n2\n3\n[11,12,13]\n' > "$W/w2.ref"
printf '%s\n' "$CH" ':- dynamic(g/1).' 'churn(0) :- !.' 'churn(N) :- assertz(g(N)), retract(g(N)), N1 is N - 1, churn(N1).' 'main :- assertz(g(first)), retract(g(first)), assertz((g(X) :- member(X, [a, b, c]))), g(A), write(A), nl, ( A == a -> retract((g(_) :- _)), churn(200) ; true ), A == c, !, write(done(A)), nl, halt.' > "$W/w3.pl"
printf 'a\nb\nc\ndone(c)\n' > "$W/w3.ref"
printf '%s\n' "$CH" ':- dynamic(p/1).' 'churn(0) :- !.' 'churn(N) :- assertz(p(N)), retract(p(N)), N1 is N - 1, churn(N1).' 'main :- assertz(p(0)), retract(p(0)), assertz((p(X) :- retract((p(_) :- _)), churn(100), X = done)), p(A), write(A), nl, halt.' > "$W/w4.pl"
printf 'done\n' > "$W/w4.ref"
printf '%s\n' "$CH" ':- dynamic(c/1).' 'churn(0) :- !.' 'churn(N) :- M is 1000 + N, assertz(c(M)), retract(c(M)), N1 is N - 1, churn(N1).' 'main :- assertz(c(0)), retract(c(0)), forall(between(1, 5, I), assertz(c(I))), c(X), X >= 2, !, write(X), nl, retract(c(1)), retract(c(2)), churn(100), findall(Y, c(Y), L), write(L), nl, halt.' > "$W/w5.pl"
printf '2\n[3,4,5]\n' > "$W/w5.ref"
printf '%s\n' "$CH" ':- dynamic(t/1).' 'churn(0) :- !.' 'churn(N) :- M is 1000 + N, assertz(t(M)), retract(t(M)), N1 is N - 1, churn(N1).' 'main :- assertz(t(0)), retract(t(0)), assertz((t(X) :- retract((t(_) :- _)), churn(50), throw(oops(X)))), catch(t(7), oops(V), (write(caught(V)), nl)), churn(50), write(end), nl, halt.' > "$W/w6.pl"
printf 'caught(7)\nend\n' > "$W/w6.ref"
printf '%s\n' "$CH" ':- dynamic(e/1).' 'churn(0) :- !.' 'churn(N) :- M is 1000 + N, assertz(e(M)), retract(e(M)), N1 is N - 1, churn(N1).' 'main :- assertz(e(0)), retract(e(0)), assertz(e(1)), assertz(e(2)), assertz(e(3)), e(X), write(X), nl, ( X == 1 -> retract(e(2)), retract(e(3)), churn(100) ; true ), X == 3, !, write(end), nl, halt.' > "$W/w7.pl"
printf '1\n2\n3\nend\n' > "$W/w7.ref"
printf '%s\n' "$CH" ':- dynamic(r/2).' 'churn(0) :- !.' 'churn(N) :- M is 1000 + N, assertz(r(M, x)), retract(r(M, x)), N1 is N - 1, churn(N1).' 'main :- assertz(r(0, z)), retract(r(0, z)), assertz((r(X, Y) :- between(1, 3, X), Y = v(X))), assertz(r(9, w)), findall(X-Y, (r(X, Y), (X == 1 -> retract((r(_, _) :- between(_, _, _), _)), churn(60) ; true)), L), write(L), nl, halt.' > "$W/w8.pl"
printf '[1-v(1),2-v(2),3-v(3),9-w]\n' > "$W/w8.ref"
for w in w1 w2 w3 w4 w5 w6 w7 w8; do
    ( cd "$W" && "$ROOT/scrip" --compile -o "$W/$w.s" "$W/$w.pl" < /dev/null > "$W/$w.cerr" 2>&1 ) || { echo "GATE REFUSED(2) [$G]: $w does not compile ($(head -c 120 "$W/$w.cerr"))"; exit 2; }
    gcc -no-pie -o "$W/$w.bin" "$W/$w.s" -L"$ROOT/out" -lscrip_rt -Wl,-rpath,"$ROOT/out" -lm -lpthread > "$W/$w.lerr" 2>&1 || { echo "GATE REFUSED(2) [$G]: $w does not link"; exit 2; }
done
run() {
    local w="$1" mode="$2" tag="$3"; shift 3
    if [ "$mode" = m3 ]; then ( cd "$W" && env "$@" timeout -k 5 300 "$ROOT/scrip" "$W/$w.pl" < /dev/null > "$W/$tag.raw" 2> "$W/$tag.err" ); else ( cd "$W" && env "$@" timeout -k 5 300 "$W/$w.bin" < /dev/null > "$W/$tag.raw" 2> "$W/$tag.err" ); fi
    echo $? > "$W/$tag.rc"
    grep -v '^\[GC-' "$W/$tag.raw" > "$W/$tag.out"
}
field() { grep -o " $2=[^ ]*" <<<"$1" | tail -1 | cut -d= -f2; }
same() { [ "$(cat "$W/$2.rc")" = 0 ] && cmp -s "$W/$2.out" "$W/$1.ref"; }
bad=0
for mode in m3 m4; do
    run w1 $mode w1.$mode SCRIP_PL_RECLAIM_REPORT=500
    l=$(grep '^\[PL-RECLAIM\]' "$W/w1.$mode.err" | tail -1); r=$(field "$l" reclaimed); rp=$(field "$l" reclaimed_pages)
    if same w1 w1.$mode && [ -n "$r" ] && [ "$r" -ge 1500 ] && [ "$r" = "$rp" ]; then echo "  ok  (1) $mode: 3000 cycles answer 3000, $r erased facts reclaimed, one page each"
    else echo "  RED (1) $mode: rc=$(cat "$W/w1.$mode.rc"), last report: ${l:-none} -- want 3000 and at least 1500 reclaimed, reclaimed_pages == reclaimed"; bad=1; fi
    for w in w2 w3 w4 w5 w6 w7 w8; do
        run $w $mode $w.$mode.s SCRIP_HEAP_KB=64 SCRIP_GC_STRESS=1 SCRIP_GC_CHAIN_CHECK=3 SCRIP_PL_RECLAIM_REPORT=1
        cw=$(grep -o 'CHAIN-WALK\] SUMMARY.*' "$W/$w.$mode.s.err" | tail -1); cc=$(grep -o 'CHAIN-CHECK\] SUMMARY.*' "$W/$w.$mode.s.err" | tail -1)
        rec=$(field "$(grep '^\[PL-RECLAIM\]' "$W/$w.$mode.s.err" | tail -1)" reclaimed)
        if ! same $w $w.$mode.s; then echo "  RED (2) $mode $w: rc=$(cat "$W/$w.$mode.s.rc"), stdout differs from swipl's: $(head -c 160 "$W/$w.$mode.s.out" | tr '\n' ' ') $(grep -o 'BOMB.*\|fatal signal.*' "$W/$w.$mode.s.err" | head -1 | cut -c1-200)"; bad=1; continue; fi
        if [ -z "$cw" ] || [ -z "$cc" ]; then echo "  RED (2) $mode $w: no chain-walk summary under SCRIP_GC_CHAIN_CHECK=3"; bad=1; continue; fi
        if [ "$(field " $cc" mismatch)" != 0 ] || [ "$(field " $cw" mapdiff)" != 0 ] || [ "$(field " $cw" extra-blob-ptrgc)" != 0 ] || [ "$(field " $cw" extra-gen-ptrgc)" != 0 ] || [ "$(field " $cw" extra-root-ptrgc)" != 0 ] || [ "$(field " $cw" extra-plain-ptrgc)" != 0 ]; then
            echo "  RED (2) $mode $w: a frame holding heap pointers is off the chain the reclaim trusts: $cw | $cc"; bad=1; continue
        fi
        if [ $w = w6 ]; then
            if [ "${FAIL_ONCE:-0}" = 1 ]; then want0=1; else want0=0; fi
            if { [ $want0 = 0 ] && [ "${rec:-0}" -gt 0 ]; } || { [ $want0 = 1 ] && [ "${rec:-0}" = 0 ]; }; then echo "  ok  (2) $mode w6: caught(7), reclaimed $rec after the throw"
            else echo "  RED (2) $mode w6: reclaimed ${rec:-none} -- a pass after the throw must reclaim the churned facts"; bad=1; fi
        fi
    done
    [ $bad = 0 ] && echo "  ok  (2) $mode: seven QA (8) witnesses equal swipl under stress at a 64 KB window, no heap-holding frame off the chain"
done
run w7 m3 w7.plant SCRIP_HEAP_KB=64 SCRIP_GC_STRESS=1 SCRIP_GC_PLANT_PL_RECLAIM=1
run w3 m3 w3.plant SCRIP_HEAP_KB=64 SCRIP_GC_STRESS=1 SCRIP_GC_PLANT_PL_RECLAIM=1
if grep -q '^\[PL-RECLAIM-PLANT\] applied' "$W/w7.plant.err" && grep -q 'a reclaimed run-time Prolog fragment was entered' "$W/w7.plant.err" && [ "$(cat "$W/w7.plant.rc")" != 0 ]; then echo "  ok  (3) the plant reclaims what a live walk can still see: the later-clauses witness dies on the named bomb"
else echo "  RED (3) the planted early reclaim of a slot a live walk can see did not die on the named bomb: rc=$(cat "$W/w7.plant.rc") $(grep -o 'BOMB.*\|fatal signal.*\|PL-RECLAIM-PLANT.*' "$W/w7.plant.err" | head -2 | tr '\n' ' ' | cut -c1-240)"; bad=1; fi
if grep -q '^\[PL-RECLAIM-PLANT\] applied' "$W/w3.plant.err" && [ "$(cat "$W/w3.plant.rc")" != 0 ] && grep -q 'in the code pool\|a frame holds a reclaimed run-time Prolog fragment\|a reclaimed run-time Prolog fragment was entered\|REFUSED: the chain over the maps stops short (nosite)\|REFUSED: the chain over the maps stops short (bad-link)' "$W/w3.plant.err"; then echo "  ok  (3) the plant reclaims what a frame holds: the erased-choice witness dies, named"
else echo "  RED (3) the planted early reclaim of a held fragment did not die by name: rc=$(cat "$W/w3.plant.rc") $(grep -o 'BOMB.*\|fatal signal.*\|PL-RECLAIM-PLANT.*' "$W/w3.plant.err" | head -2 | tr '\n' ' ' | cut -c1-240)"; bad=1; fi
TREE="$(git -C "$ROOT" rev-parse --short HEAD 2>/dev/null || echo '?')$(git -C "$ROOT" diff --quiet 2>/dev/null || echo -DIRTY)"
if [ $bad -eq 0 ]; then echo "GATE PASS(0) [$G]: an erased clause's code is reclaimed once no activation can reach it, in both modes, and the plant shows each protection holds (tree SCRIP=$TREE)"; exit 0; fi
echo "GATE FAIL(1) [$G]: an erased clause's code is not reclaimed, or a reclaim reached code a live activation needs (tree SCRIP=$TREE)"; exit 1
