#!/usr/bin/env bash
# test_gate_pl_variant_sha1_and_variant_hash_answer_as_swipl.sh -- variant_sha1/2 AND variant_hash/2 EXIST AND KEEP swipl's CONTRACT: a
# hash invariant over variable renaming, distinct for terms that are not variants, a 40-digit lower-case hex SHA-1 atom, and swipl's
# errors (cfo 2026-10-14, row prolog-swi-core-test-hash-every-case-agrees-with-swipl-in-both-modes-ceo-1664, CEO-1698).
#
# SWI's core/test_hash.pl read 10/20 in both modes: every variant_sha1 and variant_hash case raised existence_error. They are base
# prelude predicates now (src/parsers/prolog/prolog_parse.c): the term is copied without attributes (copy_term_nat/2), each variable
# bound to '$vh_var'(N) in term_variables/2 order (so variants give one key and a user's own '$VAR'(N) never collides with a
# variable), and the key is hashed -- variant_hash/2 by term_hash/2, variant_sha1/2 by a SHA-1 ('$sha1_hex'/2, written in Prolog over
# the key's write_canonical text in UTF-8; checked against python3 hashlib on "abc", the quick brown fox, a CJK string and 100 zero
# bytes). variant_sha1/2 raises as swipl 9.0.4 does: instantiation_error on an attributed variable, type_error(acyclic_term, T) on a
# cyclic term, type_error(free_of_attvar, T) on a term holding one; variant_hash/2 reads an attributed variable as a plain one.
# The hash VALUES are each system's own (swipl: "not stable across versions"); the arms grade the contract, never a value.
#
# THE ARMS: one program, nine properties, stdout cut against swipl in this run, mode 3 and mode 4. FAIL-ONCE, measured on the parent
# 6b1ecae5c rebuilt: 9 of 9 lines differ in both modes (existence_error for each); with the cure 9 of 9 as swipl.
# rc=0 both modes agree with swipl · rc=1 a divergence · rc=2 REFUSAL (no swipl, no build).  ~4 s.
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
B="$HERE/../../SCRIP"
G=test_gate_pl_variant_sha1_and_variant_hash_answer_as_swipl
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
t(N, G) :- catch((G -> R = yes ; R = no), error(E, _), (functor(E, F, A), R = F/A-E)), ( R = (type_error/2-type_error(K, _)) -> R2 = type_error(K) ; R2 = R ), writeq(N-R2), nl.
main :- t(hex40, (variant_sha1(this_is_an_atom, H), atom_length(H, 40), atom_codes(H, Cs), forall(member(C, Cs), (code_type(C, digit) ; (C >= 0'a, C =< 0'f))))),
    t(renaming, (variant_sha1(x(A), H1), variant_sha1(x(B), H2), H1 == H2)),
    t(not_variant, (variant_sha1(x(C, C), H3), variant_sha1(x(C, D), H4), H3 \== H4)),
    t(shared, (S = x(E), variant_sha1(x(S, S), H5), variant_sha1(x(x(E), x(E)), H6), H5 == H6)),
    t(float, (variant_sha1(1.0, H7), variant_sha1(2.0, H7))),
    t(cyclic, (Y = a(Y), variant_sha1(Y, _))),
    t(attvar, (dif(X, 3), variant_sha1(X, _))),
    t(holds_attvar, (dif(X2, 3), variant_sha1(x(a(X2)), _))),
    t(hash_attvar_plain, (freeze(Q, true), variant_hash(x(P, P), V1), variant_hash(x(Q, Q), V2), V1 == V2)), halt.
PL
want="$(cd "$D" && timeout -k 5 20 "$SW" -q w.pl < /dev/null 2>/dev/null)"
[ "$(printf '%s\n' "$want" | grep -c .)" = 9 ] || refuse "swipl did not answer the nine properties: [$want]"
( cd "$D" && timeout -k 5 60 "$B/scrip" --compile -o w.s w.pl < /dev/null > /dev/null 2>&1 ) || refuse "mode 4 compile failed"
( cd "$D" && gcc -m64 -no-pie w.s -o w.bin -L"$B/out" -lscrip_rt -lm -Wl,-rpath,"$B/out" > /dev/null 2>&1 ) || refuse "mode 4 link failed"
red=0
arm() {
    local label="$1"; shift
    local got n
    got="$(cd "$D" && "$@" 2>/dev/null)"
    n="$(diff <(printf '%s\n' "$want") <(printf '%s\n' "$got") | grep -c '^>')"
    if [ "$got" = "$want" ]; then echo "  $label GREEN: 9 of 9 lines as swipl"
    else echo "  $label RED: $n of 9 lines differ from swipl"; diff <(printf '%s\n' "$want") <(printf '%s\n' "$got") | sed 's/^/    /'; red=1; fi
}
arm m3 timeout -k 5 20 "$B/scrip" --run w.pl < /dev/null
arm m4 timeout -k 5 20 ./w.bin < /dev/null
[ "$red" = 0 ] && echo "PASS $G"
exit "$red"
