#!/usr/bin/env bash
# s4e_probe_prelude_object.sh N | --list -- THE PROBES OF DESIGN prelude-object: THE PROLOG PRELUDE SHARED OBJECT READS AS THE SOURCE ROAD READS, AND
# ONLY THEN IS IT THE DEFAULT (the cio 2026-11-11, CIO-129; Lon 2026-11-09, COO-500, verbatim: "Make Prolog run much faster by using a shared object
# for all the prelude code." / "So you compile using mode 4 the *.pl into a shared object and make that code available to SCRIP executable.").
# MEASURED 2026-11-11 (the coo, row prolog-the-prelude-is-one-shared-object-...-coo-500): a one-line Prolog program runs 4,736,667,426 instructions
# on the source road and 148,373,545 with the object; trealla reads 313 of 329 with it against 319. The object road is therefore held off every
# root until each cause is cured, and each arm below RUNS it through util_prelude_object.sh (the object of the root's own runtime, built once,
# outside the root, handed to scrip by the path form of SCRIP_PL_PRELUDE_SO). An arm compares the OUTPUT of the object road with the oracle's
# (swipl through util_oracle.sh) and with the source road's (the switch at 0): the source road equal to the oracle is the arm's ground, and the
# arm REFUSES rc 2 when it is not (the witness would measure nothing).
#   1  THE OBJECT IS LOADED ONLY WHEN ASKED: with the switch unset scrip opens no prelude object (strace: no open of libscrip_prelude_prolog);
#      with the switch at 1 it tries the one beside its runtime; with a path it opens that path. (Red today: unset tries the one beside the
#      runtime, so an object left by an older local build is loaded beside a newer fetched runtime; MEASURED on the cio's root.)
#   2  CAUSE B, A PREDICATE THE OBJECT DEFINES IS DEFINED: trealla's tests_test0084 and dcg_reference print their answers on the object road
#      (red today: rc 2, builtin current_predicate is not on the ladder yet).
#   3  CAUSE C, THE PROGRAM'S DIALECT DECIDES WHAT EXISTS: under --dialect=swi unget_char/1 raises existence_error as swipl (red today: the
#      object was compiled under the default dialect and holds the wrapper lower skips for SWI, pl_swi_absent_leaf, lower_prolog.c).
#   4  CAUSE A, A SOFT CUT WHOSE CONDITION CALLS AN OBJECT PREDICATE: five programs (member leaving a choice point, member determinate,
#      append, select, nth0 as the condition of *->) print as swipl prints (red today: signal 11 or missing answers; the evidence folder is
#      /home/resources/progress/CTO-591-PRELUDE-OBJECT-SOFT-CUT-CRASH).
# rc 0 GREEN, 1 RED naming each program that differs, 2 REFUSE. Writes only under /tmp/s4e/<seat> and the object store.
set -u
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
root="${S4E_HOME:?REFUSE(2): S4E_HOME unset}"
refuse() { echo "REFUSE(2) [s4e_probe_prelude_object]: $*"; exit 2; }
arm="${1:-}"
[ "$arm" = "--list" ] && { sed -n '10,21p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; exit 0; }
case "$arm" in 1|2|3|4) ;; *) refuse "usage: s4e_probe_prelude_object.sh 1|2|3|4 | --list";; esac
scrip="$root/SCRIP/scrip"; [ -x "$scrip" ] || refuse "no binary at $scrip (make -j8 first)"
bash "$here/util_require_fresh.sh" --gate s4e_probe_prelude_object >/dev/null 2>&1 || { bash "$here/util_require_fresh.sh" --gate s4e_probe_prelude_object; exit 2; }
seat="${S4E_SEAT:-probe}"; mkdir -p "/tmp/s4e/$seat"; t="$(mktemp -d "/tmp/s4e/$seat/prelude_object_arm$arm.XXXXXX")" || refuse "no scratch"
trap 'rm -rf "$t"' EXIT
tree="$(git -C "$root/SCRIP" rev-parse --short=9 HEAD 2>/dev/null)"
run() { ( cd "$t" && SCRIP_PL_PRELUDE_SO="$1" timeout -k 5 "${S4E_PROBE_RUN_S:-60}" bash "$here/util_run_slot.sh" "$scrip" --dialect=swi --run "$2" < /dev/null 2>&1; rc=$?; [ "$rc" = 124 ] || [ "$rc" = 137 ] && echo "(no end within ${S4E_PROBE_RUN_S:-60} s: killed)"; true ); }
if [ "$arm" = 1 ]; then
    command -v strace >/dev/null || refuse "no strace on the box"
    printf ':- initialization(main).\nmain :- write(a), nl.\n' > "$t/w.pl"
    opens() { ( cd "$t" && env "$@" strace -f -e trace=openat,open "$scrip" --run "$t/w.pl" < /dev/null 2>&1 | grep -c 'libscrip_prelude_prolog' ); }
    unset_n="$(env -u SCRIP_PL_PRELUDE_SO bash -c "cd '$t' && strace -f -e trace=openat,open '$scrip' --run '$t/w.pl' < /dev/null 2>&1 | grep -c 'libscrip_prelude_prolog'")"
    one_n="$(opens SCRIP_PL_PRELUDE_SO=1)"; zero_n="$(opens SCRIP_PL_PRELUDE_SO=0)"; path_n="$(opens SCRIP_PL_PRELUDE_SO="$t/libscrip_prelude_prolog.so")"
    echo "PRELUDE_OBJECT_ARM1 opens_unset=$unset_n opens_at_0=$zero_n opens_at_1=$one_n opens_at_path=$path_n (tree $tree)"
    [ "$zero_n" = 0 ] || refuse "the switch at 0 opened a prelude object: the probe's ground is gone"
    [ "$unset_n" = 0 ] && [ "$one_n" -ge 1 ] && [ "$path_n" -ge 1 ] && { echo "GATE OK [s4e_probe_prelude_object 1]: the object is loaded only when asked"; exit 0; }
    echo "GATE FAIL [s4e_probe_prelude_object 1]: unset must open none ($unset_n), 1 must try the one beside the runtime ($one_n), a path must be tried ($path_n)"; exit 1
fi
so="$(bash "$here/util_prelude_object.sh")" || exit 2
[ -f "$so" ] || refuse "no object"
red=0; n=0
check() {
    local name="$1" prog="$2" want="$3" src obj
    n=$((n + 1))
    src="$(run 0 "$prog")"; obj="$(run "$so" "$prog")"
    [ "$src" = "$want" ] || refuse "$name: the source road does not print the oracle's answer on this tree, so the arm measures nothing (source road: $(printf '%s' "$src" | head -1 | cut -c1-100))"
    [ "$obj" = "$want" ] || { red=$((red + 1)); echo "  RED $name: the object road prints: $(printf '%s' "$obj" | head -1 | cut -c1-120)   the oracle and the source road print: $(printf '%s' "$want" | head -1 | cut -c1-80)"; }
}
oracle() { ( cd "$t" && bash "$here/util_oracle.sh" swipl --timeout 60 -- -q -t halt "$1" < /dev/null 2>&1 ); }
if [ "$arm" = 2 ]; then
    p="$root/corpus/packages/prolog/trealla_tests"
    for e in tests_test0084 dcg_reference; do
        [ -f "$p/$e.pl" ] && [ -f "$p/$e.out" ] || refuse "no $p/$e.pl with its answer (a sparse corpus worktree: run on a root)"
        cp "$p/$e.pl" "$t/$e.pl"; check "$e" "$t/$e.pl" "$(cat "$p/$e.out")"
    done
fi
if [ "$arm" = 3 ]; then
    printf ':- initialization(main).\nmain :- catch((unget_char(a), write(defined)), error(E, _), write(E)), nl.\n' > "$t/c1.pl"
    printf ':- initialization(main).\nmain :- catch((G = unget_code(_, 0'"'"'a), call(G), write(defined)), error(E, _), write(E)), nl.\n' > "$t/c2.pl"
    for w in c1 c2; do check "$w" "$t/$w.pl" "$(oracle "$t/$w.pl")"; done
fi
if [ "$arm" = 4 ]; then
    printf ':- initialization(main).\nmain :- between(1,2,N), ( member(N,[2,1,2]) *-> write(h1) ; write(h2) ), write(N), fail.\nmain :- nl.\n' > "$t/a1.pl"
    printf ':- initialization(main).\nmain :- between(1,2,N), ( member(X,[a]) *-> write(X) ; write(e) ), write(N), fail.\nmain :- nl.\n' > "$t/a2.pl"
    printf ':- initialization(main).\nmain :- between(1,2,N), ( append(X,_,[a,b]) *-> write(X) ; write(e) ), write(N), fail.\nmain :- nl.\n' > "$t/a3.pl"
    printf ':- initialization(main).\nmain :- between(1,2,N), ( select(X,[a,b],_) *-> write(X) ; write(e) ), write(N), fail.\nmain :- nl.\n' > "$t/a4.pl"
    printf ':- initialization(main).\nmain :- between(1,2,N), ( nth0(_,[a,b],X) *-> write(X) ; write(e) ), write(N), fail.\nmain :- nl.\n' > "$t/a5.pl"
    for w in a1 a2 a3 a4 a5; do check "$w" "$t/$w.pl" "$(oracle "$t/$w.pl")"; done
fi
echo "PRELUDE_OBJECT_ARM$arm programs=$n red=$red object=$(basename "$(dirname "$so")") (tree $tree)"
[ "$n" -gt 0 ] || refuse "no program ran"
[ "$red" = 0 ] && { echo "GATE OK [s4e_probe_prelude_object $arm]: the object road prints as the oracle and the source road print"; exit 0; }
echo "GATE FAIL [s4e_probe_prelude_object $arm]: $red of $n program(s) differ on the object road"; exit 1
