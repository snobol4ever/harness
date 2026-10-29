#!/usr/bin/env bash
# test_gate_pl_a_clause_retry_reseeds_only_the_frames_own_local_cells.sh -- A CLAUSE RETRY RESEEDS THE FRAME CELLS ITS LOCALS OWN, NEVER A SLOT THE
# LAYOUT GAVE TO THE SPINE (the cfo, 2026-10-25; hq_packages' FINDING-2026-10-25-hq_packages-library-rbtrees-insert-into-a-non-empty-tree-raises-
# matching-rule-since-the-d3-home-frame-series.md, bisected to the D3 series d29e5e55b..).
#
# MEASURED on origin 5c435f745, both modes: library(rbtrees)' second rb_insert raised existence_error(matching_rule, '$rbtrees_fix_root'(_,_)) --
# fix_root/2 was called with its first argument UNBOUND although insert2/6 had bound it.  The 27-line witness below is the library's own insert
# path as a user program, cut to the shape that still reads red: ONE deep failing fix_right/3 clause (13 locals) before the catch-all.  The
# mechanism, read from the .s: under D3 fix_right/3's 13 locals are SPINE cells and its frame is 128 bytes, yet the retry path after the trail
# unwind (emit.cpp pl_step_reseed_locals) still zeroed [rbp+176..384) -- the frame OFFSETS the vslot table holds for those locals -- 26 stores
# past the frame and the argument block into the caller's live region, which under last-call optimisation is insert/5's frame, where TreeI's
# home cell [rbp+32] sits.  A trivial failing clause (no locals) emits no stores and reads green, which is the control that named the site.
# THE RULE (CEO-1895): the reseed reads the SAME decider the var_ref boxes read -- a local the planner placed on the spine has no frame cell,
# so there is nothing to reseed; only a frame-homed local's cell is written to the null DESCR.
# RED BEFORE (origin 5c435f745): m3 and m4 both print the matching_rule warning and no t2 line.
set -u
GATE_NAME=test_gate_pl_a_clause_retry_reseeds_only_the_frames_own_local_cells
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIP="${SCRIP_BIN:-$HERE/../../SCRIP/scrip}"
RT="${RT_DIR:-$(dirname "$SCRIP")/out}"
refuse() { echo "⛔ REFUSED(2) [$GATE_NAME]: $*" >&2; exit 2; }
[ -x "$SCRIP" ] || refuse "no scrip binary at $SCRIP -- run make first"
[ -n "${SCRIP_BIN:-}" ] || "$HERE/util_require_fresh.sh" --gate "$GATE_NAME" "$SCRIP" "$RT/libscrip_rt.so" || exit 2
TMPD="$(mktemp -d)"; trap 'rm -rf "$TMPD"' EXIT
cat > "$TMPD/w.pl" <<'EOP'
:- initialization(main).
main :- Nil = black('',_,_,''), insert(Nil, 1, a, Nil, T1), write(t1(T1)), nl, insert(T1, 2, b, Nil, T2), write(t2(T2)), nl.
insert(Tree0,Key,Val,Nil,Tree) :-
    insert2(Tree0,Key,Val,Nil,TreeI,_),
    fix_root(TreeI,Tree).
insert2(black('',_,_,''), K, V, Nil, T, Status) =>
    T = red(Nil,K,V,Nil),
    Status = not_done.
insert2(black(L,K0,V0,R), K, V, Nil, NT, Flag) =>
    (   K @< K0
    ->  insert2(L, K, V, Nil, IL, Flag0),
        fix_left(Flag0, black(IL,K0,V0,R), NT, Flag)
    ;   K == K0
    ->  NT = black(L,K0,V,R),
        Flag = done
    ;   insert2(R, K, V, Nil, IR, Flag0),
        fix_right(Flag0, black(L,K0,V0,IR), NT, Flag)
    ).
fix_root(black(L,K,V,R), Root) => Root = black(L,K,V,R).
fix_root(red(L,K,V,R), Root) => Root = black(L,K,V,R).
fix_left(done,T0,T,Done) => T = T0, Done = done.
fix_right(done,T0,T,Done) => T0 = T, Done = done.
fix_right(not_done,Tmp,Final,Done) =>
    fix_right(Tmp,Final,Done).
fix_right(black(red(Ep,KD,VD,De),KC,VC,red(red(Ga,KB,VB,Be),KA,VA,Al)),
          red(black(Ep,KD,VD,De),KC,VC,black(red(Ga,KB,VB,Be),KA,VA,Al)),
          not_done) :- !.
fix_right(T,T,done).
EOP
# swipl 9.0.4 (swipl -q -t halt w.pl), variable names normalised to _V:
WANT="t1(black(black(,_V,_V,),1,a,black(,_V,_V,)))
t2(black(black(,_V,_V,),1,a,red(black(,_V,_V,),2,b,black(,_V,_V,))))"
norm() { sed -E 's/_G[0-9]+|_[0-9]+/_V/g'; }
red=0
out3="$(cd "$TMPD" && timeout 60 "$SCRIP" w.pl < /dev/null 2>&1 | norm)"
if [ "$out3" != "$WANT" ]; then echo "⛔ RED [$GATE_NAME]: m3 printed:"; echo "$out3" | head -3; red=1; else echo "[$GATE_NAME] m3 answers as swipl"; fi
if ! (cd "$TMPD" && timeout 60 "$SCRIP" --compile --out=w.s w.pl < /dev/null > /dev/null 2> w.cerr); then refuse "mode-4 compile failed: $(head -c 200 "$TMPD/w.cerr")"; fi
gcc "$TMPD/w.s" -o "$TMPD/w.bin" -L "$RT" -lscrip_rt -lm -Wl,-rpath,"$RT" 2> "$TMPD/w.lerr" || refuse "mode-4 link failed: $(head -c 200 "$TMPD/w.lerr")"
out4="$(cd "$TMPD" && timeout 60 ./w.bin < /dev/null 2>&1 | norm)"
if [ "$out4" != "$WANT" ]; then echo "⛔ RED [$GATE_NAME]: m4 printed:"; echo "$out4" | head -3; red=1; else echo "[$GATE_NAME] m4 answers as swipl"; fi
[ $red = 0 ] && echo "PASS [$GATE_NAME]: a clause retry reseeds only the frame's own local cells; the second insert's binding survives in both modes"
exit $red
