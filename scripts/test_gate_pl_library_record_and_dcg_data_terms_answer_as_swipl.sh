#!/usr/bin/env bash
# test_gate_pl_library_record_and_dcg_data_terms_answer_as_swipl.sh -- library(record) DEFINES ITS ACCESSORS AS swipl's DOES, A
# DCG RULE KEEPS AN =/2 TERM THAT IS DATA, AND strip_module/3 AND prolog_load_context(module, M) ANSWER AS swipl (cfo 2026-10-14,
# row prolog-swi-library-test-record-every-case-agrees-with-swipl-in-both-modes-ceo-1664, CEO-1698).
#
# SWI's library/test_record.pl read 0/18 in both modes: library(record) was not vendored. It is now (src/parsers/prolog/prelude/
# record.pl, byte-identical to swipl 9.0.4's), with two generator tables (../harness/scripts/util_gen_prolog_prelude_libs.py): SOURCE_EDITS
# makes the directive :- record(R) assert the clauses compile_records/2 writes (SWI compiles them by system:term_expansion/2, a
# hook SCRIP never runs for a vendored library), and CROSS_HOOKS joins its error:has_type(record(M:Name), X) clause to
# library(error)'s '$error_has_type'/2, so a record-typed field is checked. Three cures it needed on the way: the DCG expander
# (prolog_parse.c tls) turned EVERY nested =/2 into a goal-only TT_UNIFY node, data included, so { C = (RF=[H|RF1]) } built a
# clause whose =/2 printed '?' -- now only a goal position converts; strip_module/3 and prolog_load_context(module, M) are base
# prelude predicates (one flat module: M is user). NOT HERE: prolog_load_context/2 at run time, where swipl fails because nothing
# is loading and SCRIP answers user; any key but module; the plunit_<unit> module swipl's begin_tests/1 opens (test_record's
# point#11).
#
# THE ARMS: one program, twenty-two properties, stdout cut against swipl in this run, mode 3 and mode 4. FAIL-ONCE, measured on
# the parent ba4e1a860 rebuilt: 21 of 22 lines differ in both modes; with the cure 22 of 22 as swipl.
# rc=0 both modes agree with swipl · rc=1 a divergence · rc=2 REFUSAL (no swipl, no build).  ~5 s.
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
B="$HERE/../../SCRIP"
G=test_gate_pl_library_record_and_dcg_data_terms_answer_as_swipl
refuse() { echo "⛔ REFUSED(2) [$G]: $*"; exit 2; }
. "$HERE/lib_oracle_flags.sh" || refuse "lib_oracle_flags.sh unloadable -- the one accessor of the oracle binaries"
SW="$(swipl_bin)"; [ -x "$SW" ] || refuse "no swipl at $SW -- the oracle (swipl_bin)"
[ -x "$B/scrip" ] || refuse "$B/scrip is not built"
[ -f "$B/out/libscrip_rt.so" ] || refuse "out/libscrip_rt.so is not built -- mode 4 cannot link"
"$HERE/util_require_fresh.sh" --gate "$G" || exit $?
D="$(mktemp -d)" || refuse "no scratch dir"
trap 'rm -rf "$D"' EXIT
cat > "$D/w.pl" <<'PL'
:- use_module(library(record)).
:- record foo(x:integer).
:- record bar(x:foo).
:- record zot(x).
:- record point(x:integer=0, y:integer=0).
:- prolog_load_context(module, M), writeq(load_module-M), nl.
:- initialization(main).
t(N, G) :- catch((G -> R = yes ; R = no), error(E, _), R = E), writeq(N-R), nl.
d1(C) --> { C = (RF=[H|RF1]), H = h, RF1 = [] }.
d2(C) --> { C = (a ; x, RF=[H|RF1], f(RF, H, RF1)) }.
d3(f(X=Y)) --> [X], { Y = 2 }.
main :- t(dcg_data_eq, (phrase(d1(C1), []), C1 = (_ = [h]))), t(dcg_data_eq_in_or, (phrase(d2(C2), []), C2 = (a ; x, R = [Hd|T], f(R0, H0, T0)), R == R0, Hd == H0, T == T0)),
    t(dcg_head_eq, (phrase(d3(T3), [1]), T3 == f(1=2))),
    t(make, (make_foo([x(10)], F), F == foo(10))), t(make_typed_record_field, (make_foo([x(10)], F2), make_bar([x(F2)], B), is_bar(B))),
    t(default, (default_foo(D), D = foo(V), var(V))), t(is_unbound_field, (default_foo(D2), is_foo(D2))), t(untyped, (make_zot([], Z), Z = zot(V2), var(V2), is_zot(Z))),
    t(access, (make_point([y(2), x(1)], P), point_x(P, X), point_y(P, Y), X-Y == 1-2)), t(defaults, (make_point([y(2)], P2), P2 == point(0,2))),
    t(type_error, make_point([x(1), y(foo)], _)), t(inst_error, make_point([x(1), y(_)], _)), t(unknown_field, make_point([x(1), z(3)], _)),
    t(rest, (make_point([z(123), y(0), y(10), x(1)], P3, Rest), P3-Rest == point(1,10)-[z(123)])),
    t(set, (set_x_of_point(5, point(1,2), P4), P4 == point(5,2))), t(setarg, (P5 = point(1,2), set_y_of_point(7, P5), P5 == point(1,7))),
    t(data, findall(N-Vv, point_data(N, point(3,4), Vv), [x-3, y-4])), t(current_record, (current_record(point, Mm:Tt), Mm:Tt == user:point(x:integer=0,y:integer=0))),
    t(strip_plain, (strip_module(foo, M1, P1), M1-P1 == user-foo)), t(strip_nested, (strip_module(a:b:c, M2, Pp2), M2-Pp2 == b-c)),
    t(strip_var_module, (strip_module(Q:f, M3, P6), M3 == user, P6 == Q:f)).
PL
want="$(cd "$D" && timeout -k 5 20 "$SW" -q w.pl -t halt < /dev/null 2>/dev/null | grep .)"
[ "$(printf '%s\n' "$want" | grep -c .)" = 22 ] || refuse "swipl did not answer the twenty-two properties: [$want]"
( cd "$D" && timeout -k 5 60 "$B/scrip" --compile --out=w.s w.pl < /dev/null > /dev/null 2>&1 ) || refuse "mode 4 compile failed"
( cd "$D" && gcc -m64 -no-pie w.s -o w.bin -L"$B/out" -lscrip_rt -lm -Wl,-rpath,"$B/out" > /dev/null 2>&1 ) || refuse "mode 4 link failed"
red=0
arm() {
    local label="$1"; shift
    local got n
    got="$(cd "$D" && "$@" 2>/dev/null | grep .)"
    n="$(diff <(printf '%s\n' "$want") <(printf '%s\n' "$got") | grep -c '^>')"
    if [ "$got" = "$want" ]; then echo "  $label GREEN: 22 of 22 lines as swipl"
    else echo "  $label RED: $n of 22 lines differ from swipl"; diff <(printf '%s\n' "$want") <(printf '%s\n' "$got") | sed 's/^/    /'; red=1; fi
}
arm m3 timeout -k 5 20 "$B/scrip" --run w.pl < /dev/null
arm m4 timeout -k 5 20 ./w.bin < /dev/null
[ "$red" = 0 ] && echo "PASS $G"
exit "$red"
