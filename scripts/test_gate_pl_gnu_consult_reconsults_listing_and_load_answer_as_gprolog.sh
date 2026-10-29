#!/usr/bin/env bash
# test_gate_pl_gnu_consult_reconsults_listing_and_load_answer_as_gprolog.sh -- OUTSIDE THE SWI DIALECT consult/1 RECONSULTS, NAMES ITS FILE AS gprolog DOES, AND listing/1 AND load/1 EXIST
# (cfo 2026-10-15, row prolog-gnu-builtins-the-drivers-find-128-predicates-gnu-defines-and-scrip-lacks: BipsPl/consult_driver and utils_driver).
#
# SCRIP's consult/1 appended every clause, so a second consult of a file doubled its predicates where gprolog redefines them; it tried the bare name
# before NAME.pl and reported the bare name; listing/1 and load/1 did not exist. Outside the SWI dialect the base prelude now follows BipsPl/consult.pl
# and file_c.c: consult/1 takes an atom or a list of atoms ('$check_atom_or_atom_list'; [] consults nothing), resolves a name with no suffix to the
# first of NAME.pl, NAME.pro, NAME.prolog that exists, else NAME.pl (Pl_Prolog_File_Name_2: the bare name is never tried), and reports that name when it
# is missing; the first clause a consult reads for a predicate wipes the predicate's old clauses, and the predicate is recorded with the file's absolute
# path. listing/1 checks its indicator as gprolog (type_error(atom), type_error(integer), domain_error(not_less_than_zero), type_error(predicate_indicator);
# an unknown predicate lists nothing) and prints, per file in order, "% file: PATH", then each predicate's clauses through portray_clause/1, an asserted
# predicate under user_input. load/1 checks an atom or atom list, names NAME.wbc for a name with no suffix and raises existence_error for a missing file;
# an existing byte-code file is refused with permission_error(load, byte_code, P), since SCRIP cannot run pl2wam output. The SWI dialect is unchanged.
#
# THE ARM: one program (it writes c1.pl and c2.pl into its scratch dir), the reference cut from gprolog 1.4.5 (2026-10-15) with the dir printed as DIR,
# mode 3 and mode 4.
# FAIL-ONCE, measured on the parent rebuilt (SCRIP e8c88a8b3): 28 of the 30 lines differ in both modes.
# rc=0 both modes agree with gprolog · rc=1 a divergence · rc=2 REFUSAL (no build).  ~5 s.
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
B="$HERE/../../SCRIP"
G=test_gate_pl_gnu_consult_reconsults_listing_and_load_answer_as_gprolog
refuse() { echo "⛔ REFUSED(2) [$G]: $*"; exit 2; }
[ -x "$B/scrip" ] || refuse "$B/scrip is not built"
[ -f "$B/out/libscrip_rt.so" ] || refuse "out/libscrip_rt.so is not built -- mode 4 cannot link"
"$HERE/util_require_fresh.sh" --gate "$G" || exit $?
D="$(mktemp -d)" || refuse "no scratch dir"
D="$(cd "$D" && pwd -P)"
trap 'rm -rf "$D"' EXIT
cat > "$D/g.pl" <<'PL'
:- initialization(main).
t(G) :- copy_term(G, C), catch(findall(C, C, L), E, true), ( var(E) -> R = L ; E = error(F, _) -> R = error(F) ; R = ball(E) ), \+ \+ ( numbervars(G-R, 0, _), writeq(G), write(' => '), writeq(R), nl ).
w(F, Ls) :- open(F, write, S), forall(member(L, Ls), (write(S, L), nl(S))), close(S).
main :- w('c1.pl', [':- dynamic(cq/1).', 'cq(1).', 'cq(X) :- X = two ; X = three.']), w('c2.pl', ['cs(N, M) :- M is N * N.']),
  t((consult(c1), consult('c1.pl'), cq(_))), t((consult([c1, 'c2.pl']), cs(3, _))), t(consult(c0)), t(consult([abc, 1])), t(consult([])),
  t(load(c0)), t(load('c0.wbc')), t(load(_)), t(load(3)),
  assertz(ld(1, foo)), listing(cq/1), listing(cs), listing(ld/2), t(listing(nosuch/1)), t(listing(3/1)), t(listing(foo/(-1))), t(listing(f(x))).
PL
want="$(cat <<'WANT'
consult(c1),consult('c1.pl'),cq(A) => [(consult(c1),consult('c1.pl'),cq(1)),(consult(c1),consult('c1.pl'),cq(two)),(consult(c1),consult('c1.pl'),cq(three))]
consult([c1,'c2.pl']),cs(3,A) => [(consult([c1,'c2.pl']),cs(3,9))]
consult(c0) => error(existence_error(source_sink,'c0.pl'))
consult([abc,1]) => error(type_error(atom,1))
consult([]) => [consult([])]
load(c0) => error(existence_error(source_sink,'c0.wbc'))
load('c0.wbc') => error(existence_error(source_sink,'c0.wbc'))
load(A) => error(instantiation_error)
load(3) => error(type_error(list,3))

% file: DIR/c1.pl

cq(1).
cq(A) :-
	(   A = two
	;   A = three
	).

% file: DIR/c2.pl

cs(A, B) :-
	B is A * A.

% file: user_input

ld(1, foo).
listing(nosuch/1) => [listing(nosuch/1)]
listing(3/1) => error(type_error(atom,3))
listing(foo/ -1) => error(domain_error(not_less_than_zero,-1))
listing(f(x)) => error(type_error(predicate_indicator,f(x)))
WANT
)"
red=0
arm() {
    local label="$1"; shift
    local got n t
    got="$(cd "$D" && rm -f c1.pl c2.pl && "$@" 2>/dev/null | sed "s#$D#DIR#g")"
    t="$(printf '%s\n' "$want" | wc -l)"
    n="$(diff <(printf '%s\n' "$want") <(printf '%s\n' "$got") | grep -c '^<')"
    if [ "$got" = "$want" ]; then echo "  $label GREEN: $t of $t lines as gprolog"
    else echo "  $label RED: $n of $t gprolog lines missing or different"; diff <(printf '%s\n' "$want") <(printf '%s\n' "$got") | sed 's/^/    /'; red=1; fi
}
arm m3 timeout -k 5 20 "$B/scrip" --run --dialect=gnu g.pl < /dev/null
if ( cd "$D" && timeout -k 5 60 "$B/scrip" --compile --dialect=gnu --out=g.s g.pl < /dev/null > /dev/null 2>&1 && [ -s g.s ] \
     && gcc -m64 -no-pie g.s -o g.bin -L"$B/out" -lscrip_rt -lm -Wl,-rpath,"$B/out" > /dev/null 2>&1 ); then
    arm m4 timeout -k 5 20 ./g.bin < /dev/null
else echo "  m4 RED: the program did not compile or link in mode 4"; red=1; fi
[ "$red" = 0 ] && echo "PASS $G"
exit "$red"
