#!/usr/bin/env bash
export S4E_ONE_RUNNER_FIXTURE="gate arm ${0##*/}: a runner invoked as an instrument fixture, not a board (CEO-523)"
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
# test_gate_gc_a_prolog_box_result_survives_the_cap_raise_tail_under_gc_stress.sh -- A PROLOG BOX'S RESULT SURVIVES THE CAP RAISE
# TAIL IN BOTH MEDIA (cfo 2026-10-22, CEO-1895). SCRIP eac5ddd84 put the heap cap's raise entry (rt_pl_cap_raise, an rtx entry of
# clobber mask 0: it keeps rax:rdx unless it raises) inside every Prolog poll gate. In the binary medium (mode 3) the call was
# emitted by x86_call_ro as movabs rax, <entry>; call rax, so whenever the gate's body ran the box result in rax was the entry's
# address: the site's DT_FAIL test read garbage and the program exited at the root's gamma with rc 0 and no output. The text
# medium (mode 4) calls through the GOT and kept rax, and a gate body runs only when a collection is pending, so nothing but GC
# stress showed it. MEASURED: findall(X, between(1, 3, X), L) under SCRIP_GC_STRESS=1 printed nothing in mode 3 at eac5ddd84 and on
# every origin commit after it, and [1,2,3] at eac5ddd84^ and on the cure, which calls the entry through the rtcc road the poll
# itself takes (r11 saved to the rtcc block, call r11, r11 reloaded: every register and the flags kept).
# TWO ARMS, each in both modes, each against a ref cut from swipl -q: (1) a findall result printed under SCRIP_GC_STRESS=1 and 7;
# (2) a cap raise caught under SCRIP_GC_STRESS=7 at -d2m, so the raise road and the no-raise road both pass through the tail
# (stress 1 there costs 34 s a mode against 4 s; swipl's own stack_limit of 4 MB gives the same lines in 0.03 s).
# EXIT 0 all arms; 1 a red (named); 2 REFUSED.
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)" || { echo "REFUSE(2): no SCRIP beside harness at $HERE/../../SCRIP (a port root) -- this gate measures SCRIP and cannot from here"; exit 2; }
. "$HERE/lib_oracle_flags.sh"
SW="$(swipl_bin)" || { echo "REFUSED(2): swipl oracle missing"; exit 2; }
[ -x "$ROOT/scrip" ] || { echo "REFUSED(2): $ROOT/scrip not built"; exit 2; }
W="$(mktemp -d)"; trap 'rm -rf "$W"' EXIT
cat > "$W/fa.pl" <<'PL'
:- initialization(main).
main :- findall(X, between(1, 3, X), L), write(L), nl, findall(Y-Z, (member(Y, [a, b]), Z = Y), P), write(P), nl, halt.
PL
cat > "$W/cap.pl" <<'PL'
:- initialization(main).
:- set_prolog_flag(stack_limit, 4194304).
mk(0, L, L) :- !.
mk(N, A, L) :- N1 is N - 1, mk(N1, [N|A], L).
main :- catch(mk(5000000, [], _), error(E, _), (write(caught(E)), nl)), findall(X, between(1, 3, X), L), write(L), nl, write(after), nl, halt.
PL
red=0
for p in fa cap; do
    ( cd "$W" && timeout -k 5 120 "$SW" -q "$p.pl" < /dev/null > "$W/$p.ref" 2> /dev/null ) || true
    [ -s "$W/$p.ref" ] || { echo "REFUSED(2): swipl printed nothing for $p.pl"; exit 2; }
    ( cd "$W" && "$ROOT/scrip" --compile --out="$p.s" "$p.pl" < /dev/null > /dev/null 2>&1 && gcc "$p.s" -L"$ROOT/out" -lscrip_rt -lm -lpthread -Wl,-rpath,"$ROOT/out" -o "$p.bin" 2> /dev/null ) || { echo "RED: $p.pl did not compile and link"; red=1; continue; }
done
[ "$red" -eq 0 ] || { echo "GATE FAILED: see the RED lines above"; exit 1; }
run() { local p="$1" m="$2" st="$3" d="$4"; if [ "$m" = m3 ]; then ( cd "$W" && SCRIP_GC_STRESS="$st" timeout -k 5 120 "$ROOT/scrip" $d -s4096k "$p.pl" < /dev/null 2> /dev/null ); else ( cd "$W" && SCRIP_GC_STRESS="$st" timeout -k 5 120 "./$p.bin" $d -s4096k < /dev/null 2> /dev/null ); fi; }
for c in "fa 1 -d2048k" "fa 7 -d2048k" "cap 7 -d2048k"; do
    set -- $c
    for m in m3 m4; do
        o="$(run "$1" "$m" "$2" "$3")"
        [ "$o" = "$(cat "$W/$1.ref")" ] && echo "ok  $m $1 SCRIP_GC_STRESS=$2 $3 = swipl" || { echo "RED $m $1 SCRIP_GC_STRESS=$2 $3: got [$(printf '%s' "$o" | tr '\n' '|')] want [$(tr '\n' '|' < "$W/$1.ref")]"; red=1; }
    done
done
[ "$red" -eq 0 ] && { echo "GATE OK: a Prolog box result survives the cap raise tail under GC stress, and a caught cap raise reads as swipl's, in both modes"; exit 0; }
echo "GATE FAILED: see the RED lines above"; exit 1
