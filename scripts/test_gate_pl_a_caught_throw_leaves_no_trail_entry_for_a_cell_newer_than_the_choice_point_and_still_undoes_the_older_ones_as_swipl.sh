#!/usr/bin/env bash
# test_gate_pl_a_caught_throw_leaves_no_trail_entry_for_a_cell_newer_than_the_choice_point_and_still_undoes_the_older_ones_as_swipl.sh -- A LOOP THAT CATCHES A BALL WITH
# A COMPOUND CATCHER HOLDING A VARIABLE RUNS IN CONSTANT SPACE, AND A BINDING THE HANDLER MADE TO AN OLDER VARIABLE IS STILL UNDONE (hq_prolog 2026-11-01, row
# prolog-a-catch-throw-loop-retains-memory-per-caught-throw-and-dies-at-a-4-mb-heap-after-300000-iterations-swipl-runs-it-in-constant-space).
#
# rt_pl_catch_handle_c unifies the catcher with the ball under a FAKE frame (frame_hi 0, the context copy c2) so that every binding is trailed and a failed unify can be
# unwound. On success it kept all of those entries: two 32-byte entries per caught throw that nothing ever popped in a deterministic loop (the trail top grew 64 bytes per
# iteration, read in gdb at hits 100 and 900), each rooting the catcher's compound, so `t(N) :- catch(throw(oops(N)), oops(_), true), M is N-1, t(M).` died at -d4096k after
# about 300,000 iterations where swipl runs it flat (an atom, an integer or a bare-variable catcher never bound a cell, so those loops were fine). Now a successful unify
# drops the entries the REAL context (the caller's choice point) would not have logged (plc_catch_trim, the same pl_tr_needs_log_bind test every ordinary bind uses); an entry
# for a cell older than the choice point, an attributed or residue entry, and any unify that woke an attributed variable keep their entries.
#
# THE ARMS, each in mode 3 and mode 4, wants cut from swipl 9.0.4 on 2026-11-01: (1) the loop of one million caught throws under -d4096k -s4096k prints done; (2) eight probes of
# what the handler's bindings must still do (undone by a throw to an outer catch, undone on backtracking, kept for the continuation, kept across a rethrow).
# FAIL-ONCE, measured on the parent (SCRIP 9630adb14): the loop dies with the heap's hard cap in both modes; the probes agree with swipl on the parent as well (they are the
# guard against the cure dropping an entry it must keep, not the red).
# rc=0 equal to swipl · rc=1 a divergence · rc=2 REFUSAL (no build, no gcc).  ~25 s.
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
B="$HERE/../../SCRIP"
G=test_gate_pl_a_caught_throw_leaves_no_trail_entry_for_a_cell_newer_than_the_choice_point_and_still_undoes_the_older_ones_as_swipl
refuse() { echo "⛔ REFUSED(2) [$G]: $*"; exit 2; }
[ -x "$B/scrip" ] || refuse "$B/scrip is not built"
[ -f "$B/out/libscrip_rt.so" ] || refuse "out/libscrip_rt.so is not built -- mode 4 cannot link"
"$HERE/util_require_fresh.sh" --gate "$G" || exit $?
D="$(mktemp -d)" || refuse "no scratch dir"
trap 'rm -rf "$D"' EXIT
cat > "$D/loop.pl" <<'PL'
t(0) :- !.
t(N) :- catch(throw(oops(N)), oops(_), true), M is N - 1, t(M).
:- t(1000000), write(done), nl.
PL
cat > "$D/sound.pl" <<'PL'
t1 :- catch(( catch(throw(f(1)), f(Z), true), throw(done) ), done, true), ( var(Z) -> write(t1_unbound) ; write(t1_bound(Z)) ), nl.
t2 :- ( member(A, [1,2,3]), catch(throw(f(A)), f(Z), true), Z == 2 -> write(t2(Z)) ; write(t2_none) ), nl.
t3 :- ( catch(throw(f(1)), f(Z), true), fail ; var(Z), write(t3_unbound_after_fail) ), nl.
t4 :- catch(( catch(( catch(throw(g(1)), g(W), true), throw(h(W)) ), h(V), ( V == 1 -> throw(i(V)) ; true ) ) ), i(U), true ), ( var(W) -> write(t4_w_unbound) ; write(t4_w(W)) ), write(u(U)), nl.
t5 :- X = f(_), catch(throw(k(2)), k(A), true), X = f(A), write(t5(X)), nl.
t6 :- ( catch(throw(f(1)), f(Z), true), Z == 1, throw(again) ; true ), write(t6_reached), nl.
t7 :- catch(( member(A, [1,2]), catch(throw(f(A)), f(Z), true), Z >= 2, throw(found(Z)) ), found(R), true), write(t7(R)), nl.
t8 :- ( catch(( catch(throw(f(1)), f(Z), true), Z == 2 ), _, true) -> write(t8_yes) ; write(t8_no) ), nl.
:- forall(member(G, [t1,t2,t3,t4,t5,t6,t7,t8]), ( catch(G, E, (write(G-E), nl)) -> true ; write(G-failed), nl )).
PL
want_loop="done"
want_sound="$(printf '%s\n' 't1_unbound' 't2(2)' 't3_unbound_after_fail' 't4_w_unboundu(1)' 't5(f(2))' 't6-again' 't7(2)' 't8_no')"
red=0; arms=0
arm() {
    local label="$1" want="$2" got
    arms=$((arms+1))
    got="$(cd "$D" && "${@:3}" 2>/dev/null | grep .)"
    if [ "$got" = "$want" ]; then echo "  $label GREEN: equal to swipl"
    else echo "  $label RED: differs from swipl"; diff <(printf '%s\n' "$want") <(printf '%s\n' "$got") | sed 's/^/    /' | head -8; red=$((red+1)); fi
}
build4() {
    ( cd "$D" && timeout -k 5 120 "$B/scrip" --compile --out="$1.s" "$1.pl" < /dev/null > /dev/null 2>&1 && [ -s "$1.s" ] \
      && gcc -m64 -no-pie "$1.s" -o "$1.bin" -L"$B/out" -lscrip_rt -lm -Wl,-rpath,"$B/out" > /dev/null 2>&1 )
}
arm "loop m3" "$want_loop" timeout -k 5 120 "$B/scrip" -d4096k -s4096k loop.pl < /dev/null
arm "sound m3" "$want_sound" timeout -k 5 120 "$B/scrip" sound.pl < /dev/null
for p in loop sound; do
    w="$want_sound"; [ "$p" = loop ] && w="$want_loop"
    if build4 "$p"; then
        if [ "$p" = loop ]; then arm "loop m4" "$w" timeout -k 5 120 ./loop.bin -d4096k -s4096k -- < /dev/null
        else arm "sound m4" "$w" timeout -k 5 120 ./sound.bin < /dev/null; fi
    else echo "  $p m4 RED: the program did not compile or link in mode 4"; red=$((red+1)); arms=$((arms+1)); fi
done
echo "PL_CAUGHT_THROW_TRAIL_BOARD arms=$arms red=$red (tree $(git -C "$B" rev-parse --short HEAD))"
[ "$red" = 0 ] && { echo "GATE OK [$G]: $arms arms equal to swipl"; exit 0; }
echo "GATE FAIL [$G]: $red of $arms arms differ from swipl"; exit 1
