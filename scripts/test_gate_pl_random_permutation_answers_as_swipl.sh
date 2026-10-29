#!/usr/bin/env bash
# test_gate_pl_random_permutation_answers_as_swipl.sh -- random_permutation/2 ANSWERS AS swipl's library(random) DOES (cfo 2026-10-14,
# row prolog-swi-core-test-dict-every-case-agrees-with-swipl-in-both-modes-ceo-1709: test_dict's create#1 builds dicts from a
# random_permutation/2 of its keys and raised existence_error).
#
# The base prelude (prolog_parse.c) types swipl 9.0.4's own definition: a list in either argument is keyed with random/1, keysorted and
# its values read off; both unbound is instantiation_error, a non-list type_error(list, X). The order of a permutation is the
# generator's, so the arms grade what swipl's answer is independent of: the elements and their multiplicity, the length, either
# direction, the empty list, and the two errors.
#
# THE ARMS: one program, seven lines, stdout cut against swipl in this run, mode 3 and mode 4. FAIL-ONCE, measured on the parent
# 847a4db05 rebuilt: 7 of 7 lines missing or different in both modes (random_permutation/2 does not exist); with the cure 7 of 7
# as swipl in both modes.
# rc=0 both modes agree with swipl · rc=1 a divergence · rc=2 REFUSAL (no swipl, no build).  ~3 s.
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
B="$HERE/../../SCRIP"
G=test_gate_pl_random_permutation_answers_as_swipl
refuse() { echo "⛔ REFUSED(2) [$G]: $*"; exit 2; }
. "$HERE/lib_oracle_flags.sh" || refuse "lib_oracle_flags.sh unloadable -- the one accessor of the oracle binaries"
SW="$(swipl_bin)"; [ -x "$SW" ] || refuse "no swipl at $SW -- the oracle (swipl_bin)"
[ -x "$B/scrip" ] || refuse "$B/scrip is not built"
[ -f "$B/out/libscrip_rt.so" ] || refuse "out/libscrip_rt.so is not built -- mode 4 cannot link"
"$HERE/util_require_fresh.sh" --gate "$G" || exit $?
D="$(mktemp -d)" || refuse "no scratch dir"
trap 'rm -rf "$D"' EXIT
cat > "$D/w.pl" <<'PL'
:- initialization(main).
t(N, G) :- catch((G -> R = yes ; R = no), error(E, _), R = err(E)), writeq(N-R), nl.
main :- t(same_elements, (numlist(1, 50, L), random_permutation(L, P), msort(P, L))),
  t(length, (random_permutation([a,b,c,d], P2), length(P2, 4))),
  t(reverse_direction, (random_permutation(Q, [x,y,z]), msort(Q, [x,y,z]))),
  t(empty, random_permutation([], [])),
  t(duplicates_kept, (random_permutation([a,a,b], P3), msort(P3, [a,a,b]))),
  t(both_unbound, random_permutation(_, _)),
  t(not_a_list, random_permutation(foo, _)).
PL
want="$(cd "$D" && timeout -k 5 20 "$SW" -q w.pl -t halt < /dev/null 2>/dev/null | grep .)"
[ "$(printf '%s\n' "$want" | grep -c .)" = 7 ] || refuse "swipl did not answer the seven lines: [$want]"
m4ok=1   # a program SCRIP refuses to compile is this gate's red, never a refusal
( cd "$D" && timeout -k 5 60 "$B/scrip" --compile --out=w.s w.pl < /dev/null > /dev/null 2>&1 && [ -s w.s ] \
  && gcc -m64 -no-pie w.s -o w.bin -L"$B/out" -lscrip_rt -lm -Wl,-rpath,"$B/out" > /dev/null 2>&1 ) || m4ok=0
red=0
arm() {
    local label="$1"; shift
    local got n
    got="$(cd "$D" && "$@" 2>/dev/null | grep .)"
    n="$(diff <(printf '%s\n' "$want") <(printf '%s\n' "$got") | grep -c '^<')"
    if [ "$got" = "$want" ]; then echo "  $label GREEN: 7 of 7 lines as swipl"
    else echo "  $label RED: $n of 7 swipl lines missing or different"; diff <(printf '%s\n' "$want") <(printf '%s\n' "$got") | sed 's/^/    /'; red=1; fi
}
arm m3 timeout -k 5 20 "$B/scrip" --run w.pl < /dev/null
if [ "$m4ok" = 1 ]; then arm m4 timeout -k 5 20 ./w.bin < /dev/null; else echo "  m4 RED: the program did not compile or link in mode 4"; red=1; fi
[ "$red" = 0 ] && echo "PASS $G"
exit "$red"
