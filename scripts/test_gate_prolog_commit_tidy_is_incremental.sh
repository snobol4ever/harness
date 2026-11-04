#!/usr/bin/env bash
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
# test_gate_prolog_commit_tidy_is_incremental.sh -- A COMMIT'S TRAIL TIDY JUDGES EACH ENTRY ONCE PER SURVIVING CHOICE, NOT ONCE PER COMMIT (the cto, 2026-11-04, R-2122;
# TRIO row 5, hakank_swi_stable_marriage, the second class). x86_pl_tr_tidy (x86_call.cpp), run at every if-then-else commit and cut (bb_bound.cpp's UNMARK arm), walks the
# trail from the surviving choice's mark to the top and drops every entry the trail test would not record under that choice. Before R-2122 every commit walked the whole
# segment again, so a run of commits under one choice (CLP(FD) propagation under a labeling choice point: trigger_prop/1, put_attr/3, do_queue/0) cost the trail's length
# per commit: callgrind on problem 1 of the program read 85 percent of 196 G instructions inside unmark boxes, 34 percent in trigger_prop/1's alone. Now every choice carries its own
# watermark, the trail top after the last walk under it, in the old-value words of its sentinel entry (the entry below its mark: {0, HB, DT_I, watermark}); a walk under r13 whose
# watermark lies between the start and the top begins there, and a backtrack into the choice unwinds below it so the next walk starts at the mark again. The change can only skip
# judging entries an earlier walk under the same choice already judged: keeping an entry is always safe, and no entry is dropped that the full walk kept.
# ARMS: (1) SPEED: tidy.pl (100,000 bindings older than one choice point, then 100,000 if-then-else commits) finishes in mode 3 within 10 s (MEASURED: 14.35 s on 7c9399d32
#           with 1e10 entry visits, 0.45 s after; the bar is a budget, red by a timeout, so a loaded box reads a slow pass as red rather than a quadratic as green)
#       (2) ANSWER: tidysem.pl (commits under findall's backtracking, a failing if-then-else condition after bindings and commits, a throw across commits, b_setval/b_getval
#           entries that carry the KEEP pad) prints swipl's text in mode 3, in mode 4 and in mode 3 under SCRIP_GC_STRESS=1 SCRIP_GC_PLANT_FLIP=1
# RED ONCE WITHOUT A PLANT: on 7c9399d32 arm 1 reads a timeout.
# rc 0 held · rc 1 a bar unmet · rc 2 cannot measure (no scrip, no swipl, a compile or link refused)
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="${S4E_HOME:-$(cd "$HERE/../.." && pwd)}"
NAME=prolog_commit_tidy_is_incremental
refuse() { echo "⛔ REFUSED(2) [$NAME]: $*"; exit 2; }
SCRIP="$ROOT/SCRIP/scrip"
[ -x "$SCRIP" ] || refuse "no $SCRIP"
. "$HERE/lib_oracle_flags.sh" || refuse "lib_oracle_flags.sh is missing"
SW="$(swipl_bin)" || refuse "the swipl oracle accessor refused"
[ -x "$SW" ] || refuse "swipl is not executable: $SW"
T="$(mktemp -d)" || refuse "mktemp failed"; trap 'rm -rf "$T"' EXIT
cat > "$T/tidy.pl" <<'PL'
:- initialization(main).
main :- N = 100000, length(L, N), ( true ; fail ), bind_all(L), commits(N), write(done), nl.
bind_all([]).
bind_all([X|Xs]) :- X = 1, bind_all(Xs).
commits(0) :- !.
commits(N) :- ( N > 0 -> true ; fail ), N1 is N - 1, commits(N1).
PL
cat > "$T/tidysem.pl" <<'PL'
:- initialization(main).
main :- length(L, 2000), fill(L, 0), findall(S, (member(K, [1,2,3]), step(L, K, S)), Ss), writeq(Ss), nl,
        length(M, 300), ( bindmix(M, 1), commits(300), sum_vars(M, S1), S1 > 1000000 -> write(impossible) ; write(backtracked) ), nl,
        ( catch(( length(C, 50), fill(C, 7), commits(50), throw(ball(C)) ), ball(C2), (sum_vars(C2, SC), write(SC))) ), nl,
        g_loop(0, 3000, 0, R), write(R), nl.
fill([], _).
fill([X|Xs], N) :- X = N, N1 is N + 1, fill(Xs, N1).
step(L, K, S) :- bindmix(L, K), commits(500), sum_vars(L, S).
bindmix([], _).
bindmix([X|Xs], K) :- ( var(X) -> X = K ; true ), bindmix(Xs, K).
sum_vars([], 0).
sum_vars([X|Xs], S) :- sum_vars(Xs, S0), ( var(X) -> S is S0 ; S is S0 + X ).
commits(0) :- !.
commits(N) :- ( N > 0 -> true ; fail ), N1 is N - 1, commits(N1).
g_loop(I, N, Acc, R) :- ( I >= N -> R = Acc ; b_setval(k, I), ( I mod 2 =:= 0 -> b_getval(k, V) ; V = 0 ), Acc1 is Acc + V, I1 is I + 1, g_loop(I1, N, Acc1, R) ).
PL
cd "$T" || refuse "cannot enter $T"
rc=0
s=$(date +%s.%N); timeout -k 5 10 "$SCRIP" tidy.pl < /dev/null > tidy.out 2>/dev/null; trc=$?; e=$(date +%s.%N); secs=$(python3 -c "print(round($e - $s, 2))")
if [ "$trc" = 0 ] && [ "$(cat tidy.out)" = done ]; then echo "  ok   arm 1 (SPEED): 100,000 commits over 100,000 trailed bindings in ${secs}s (budget 10 s)"
else echo "  ⛔ FAIL arm 1 (SPEED): rc $trc after ${secs}s (budget 10 s; a timeout is the quadratic tidy)"; rc=1; fi
timeout -k 5 120 "$SW" -q -t halt tidysem.pl < /dev/null > ref.out 2> ref.err || refuse "swipl refused the probe: $(head -c 200 ref.err)"
[ -s ref.out ] || refuse "swipl printed nothing"
timeout -k 5 300 "$SCRIP" tidysem.pl < /dev/null > m3.out 2>/dev/null; m3rc=$?
"$SCRIP" --compile --out=tidysem.s tidysem.pl < /dev/null 2>/dev/null || refuse "the mode-4 compile refused"
gcc tidysem.s -L"$ROOT/SCRIP/out" -lscrip_rt -lm -Wl,-rpath,"$ROOT/SCRIP/out" -o tidysem.bin 2> ld.err || refuse "the link refused: $(head -c 200 ld.err)"
timeout -k 5 300 ./tidysem.bin < /dev/null > m4.out 2>/dev/null; m4rc=$?
SCRIP_GC_STRESS=1 SCRIP_GC_PLANT_FLIP=1 timeout -k 5 900 "$SCRIP" tidysem.pl < /dev/null 2>/dev/null | grep -v '^\[GC-' > st.out; strc=$?
for a in "m3 $m3rc m3.out" "m4 $m4rc m4.out" "m3-stress-flip $strc st.out"; do set -- $a
    if [ "$2" = 0 ] && cmp -s ref.out "$3"; then echo "  ok   arm 2 ($1): stdout equals swipl's ($(wc -l < ref.out) lines)"
    else echo "  ⛔ FAIL arm 2 ($1): rc $2, stdout differs from swipl's: $(diff ref.out "$3" | head -3 | tr '\n' ' ' | cut -c1-200)"; rc=1; fi
done
[ "$rc" = 0 ] && { echo "GATE OK [$NAME]: the commit's trail tidy is incremental (${secs}s for 100,000 commits over 100,000 entries), and commits under backtracking, a failing condition, a throw and global restores agree with swipl in both modes and under the flip plant"; exit 0; }
echo "GATE FAIL [$NAME]"; exit 1
