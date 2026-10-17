#!/usr/bin/env bash
# test_gate_pl_select_dict_the_dict_operators_and_destructive_dict_assignment_answer_as_swipl.sh -- select_dict/3, :< AND >:<,
# b_set_dict/3 AND nb_set_dict/3, get_dict/5 AND A DICT'S KEY CHECK ANSWER AS swipl (cfo 2026-10-14, row
# prolog-swi-core-test-dict-every-case-agrees-with-swipl-in-both-modes-ceo-1709).
#
# SCRIP's library(dicts) (src/parsers/prolog/prelude/dicts.pl, SCRIP's own text) lacked select_dict/3, :</2, >:</2, b_set_dict/3 and
# nb_set_dict/3, and the reader had no :< or >:< operator (swipl declares both 700 xfx), so test_dict's clauses using them were
# parse errors. get_dict/5 took its new value fourth and its new dict fifth; swipl 9.0.4 answers the new dict fourth (measured:
# get_dict(k1, a{k1:v1}, V, D, v2) gives V = v1, D = a{k1:v2}). A list stands for a dict where swipl converts one implicitly
# ('$dict_conv'/2: get_dict/5, select_dict/3, :<, >:<, a Dict.key), and a key that is neither an atom nor a small integer raises
# type_error('dict-key', K) as swipl's dict_create does ('$dict_keys_ok'/1 in '$dict_build'/3). b_set_dict/3 is setarg/3 on the
# value's slot (undone on backtracking), nb_set_dict/3 nb_setarg/3, a missing key existence_error(key, K, Dict).
# NOT HERE: dict-method definitions (Tag.f() := V), random_permutation/2, threads (test_dict's dict_overflow cases: debt).
#
# THE ARMS: one program, fifteen lines, stdout cut against swipl in this run, mode 3 and mode 4. FAIL-ONCE, measured on the
# parent 66b626774 rebuilt: 15 of 15 lines missing in both modes (the :< and >:< clauses do not parse, so main/0 is never
# defined); with the cure 15 of 15 as swipl in both modes.
# rc=0 both modes agree with swipl · rc=1 a divergence · rc=2 REFUSAL (no swipl, no build).  ~4 s.
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
B="$HERE/../../SCRIP"
G=test_gate_pl_select_dict_the_dict_operators_and_destructive_dict_assignment_answer_as_swipl
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
kv(D, T-P) :- dict_pairs(D, T0, P), ( var(T0) -> T = var ; T = T0 ).
main :- t(get5, (get_dict(k1, a{k1:v1}, V, D, v2), V == v1, D == a{k1:v2})),
  t(get5_list, (get_dict(k1, [k1:v1], V2, D2, v2), V2 == v1, kv(D2, var-[k1-v2]))),
  t(get5_mismatch, get_dict(k1, a{k1:v1}, v2, _, v2)),
  t(select_tag_mismatch, select_dict(b{k1:v1}, a{k1:v1}, _)),
  t(select_var_tag, (select_dict(T{k1:Y}, a{k1:v1, k2:v2}, R2), T == a, Y == v1, kv(R2, var-[k2-v2]))),
  t(select_list, (select_dict([x(1)], [x(1),z(3)], R3), kv(R3, var-[z-3]))),
  t(sub, (T2{k1:Z} :< a{k1:v1, k2:v2}, T2 == a, Z == v1)),
  t(sub_missing, a{x:_} :< a{y:2}),
  t(join, (T3{k1:W, k2:W2} >:< a{k1:v1, k3:v3}, T3 == a, W == v1, var(W2))),
  t(join_clash, a{k1:v1} >:< a{k1:v2}),
  t(bset, (DD = a{k1:v1}, b_set_dict(k1, DD, v2), DD == a{k1:v2})),
  t(bset_undone, (DD2 = a{k1:v1}, (b_set_dict(k1, DD2, v2), fail ; true), DD2 == a{k1:v1})),
  t(nbset_kept, (DD3 = a{k1:v1}, (nb_set_dict(k1, DD3, v2), fail ; true), DD3 == a{k1:v2})),
  t(bset_missing, (DD4 = a{k1:v1}, b_set_dict(k9, DD4, v2))),
  t(dict_key, dict_pairs(_, a, ["k1"-v1])).
PL
want="$(cd "$D" && timeout -k 5 20 "$SW" -q w.pl -t halt < /dev/null 2>/dev/null | grep .)"
[ "$(printf '%s\n' "$want" | grep -c .)" = 15 ] || refuse "swipl did not answer the fifteen lines: [$want]"
m4ok=1   # a program SCRIP refuses to compile is this gate's red, never a refusal
( cd "$D" && timeout -k 5 60 "$B/scrip" --compile -o w.s w.pl < /dev/null > /dev/null 2>&1 && [ -s w.s ] \
  && gcc -m64 -no-pie w.s -o w.bin -L"$B/out" -lscrip_rt -lm -Wl,-rpath,"$B/out" > /dev/null 2>&1 ) || m4ok=0
red=0
arm() {
    local label="$1"; shift
    local got n
    got="$(cd "$D" && "$@" 2>/dev/null | grep .)"
    n="$(diff <(printf '%s\n' "$want") <(printf '%s\n' "$got") | grep -c '^<')"
    if [ "$got" = "$want" ]; then echo "  $label GREEN: 15 of 15 lines as swipl"
    else echo "  $label RED: $n of 15 swipl lines missing or different"; diff <(printf '%s\n' "$want") <(printf '%s\n' "$got") | sed 's/^/    /'; red=1; fi
}
arm m3 timeout -k 5 20 "$B/scrip" --run w.pl < /dev/null
if [ "$m4ok" = 1 ]; then arm m4 timeout -k 5 20 ./w.bin < /dev/null; else echo "  m4 RED: the program did not compile or link in mode 4"; red=1; fi
[ "$red" = 0 ] && echo "PASS $G"
exit "$red"
