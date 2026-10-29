#!/usr/bin/env bash
# test_gate_pl_numbervars_4_scans_its_options_as_swipl.sh -- numbervars/4 SCANS ITS OPTION LIST AS swipl's scan_options DOES (cfo
# 2026-10-14, SWI core/test_scan_options.pl 3 -> 12 of 12).
#
# The base prelude's numbervars/4 was memberchk(singletons(true), Options) and numbervars/3: every other option, an implicit-true
# `singletons`, a dict of options and every malformed option list passed silently. It now scans the list as swipl does:
# singletons(Bool) (true/on/false/off, else type_error(bool, V); the bare atom singletons is singletons(true); the last occurrence wins),
# attvar(skip|bind|error) (else domain_error(numbervar_option, OptionList)), functor_name(Atom) (else type_error(atom, X)), any other
# name or name(Value) ignored, a non-option (f(a,b), 1.3) type_error(option, X), an unbound option or tail instantiation_error, a
# non-list tail type_error(list, T), and a dict is its Key:Value pairs. functor_name(F) numbers with F(N) instead of '$VAR'(N).
# NOT HERE: numbervars(T, S, b, []) with a non-integer End type-errors where swipl fails (numbervars/3's own check, unchanged).
#
# THE ARM: one program, 32 lines, stdout cut against swipl in this run, mode 3 and mode 4. FAIL-ONCE, measured on the parent fe497aebf
# rebuilt: 17 of 32 lines differ in both modes; with the cure 32 of 32 as swipl in both modes.
# rc=0 both modes agree with swipl · rc=1 a divergence · rc=2 REFUSAL (no swipl, no build).  ~3 s.
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
B="$HERE/../../SCRIP"
G=test_gate_pl_numbervars_4_scans_its_options_as_swipl
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
main :- t(sing, (numbervars(x(_,X,X), 0, E1, [singletons(true)]), writeq(E1), nl)),
 t(impl, (numbervars(x(_,X2,X2), 0, E2, [singletons]), writeq(E2), nl)),
 t(none, (numbervars(x(_,X3,X3), 0, E3, [unlikely(true)]), writeq(E3), nl)),
 t(bad42, numbervars(x(_,Y,Y), 0, _, [singletons(42)])),
 t(badopt, numbervars(x(_,Y1,Y1), 0, _, [f(a,b)])),
 t(badflt, numbervars(x(_,Y2,Y2), 0, _, [1.3])),
 t(inst1, numbervars(x(_,Y3,Y3), 0, _, [_])),
 t(inst2, numbervars(x(_,Y4,Y4), 0, _, [singletons(true)|_])),
 t(tail1, numbervars(x(_,Y5,Y5), 0, _, [singletons(true)|1])),
 t(dict, (numbervars(x(_,Z,Z), 0, E4, _{singletons:true}), writeq(E4), nl)),
 t(dict42, numbervars(x(_,Z1,Z1), 0, _, _{singletons:42})),
 t(dictno, (numbervars(x(_,Z2,Z2), 0, E5, _{unlikely:true}), writeq(E5), nl)),
 t(attvar_bad, numbervars(f(_), 0, _, [attvar(zzz)])),
 t(functor_name, (numbervars(f(A), 5, E7, [functor_name(v)]), writeq(f(A)-E7), nl)),
 t(functor_name_bad, numbervars(f(_), 5, _, [functor_name(1)])),
 t(bool_yes, numbervars(f(_), 0, _, [singletons(yes)])),
 t(bool_on, (numbervars(f(A7,A7,_), 0, E8, [singletons(on)]), print(f(A7)-E8), nl)),
 t(false, (numbervars(f(_,_), 0, E9, [singletons(false)]), print(E9), nl)),
 t(false_then_implicit, (numbervars(f(_,_), 0, E10, [singletons(false), singletons]), print(E10), nl)),
 t(true_then_false, (numbervars(f(_,_), 0, E11, [singletons(true), singletons(false)]), print(E11), nl)),
 t(not_a_list, numbervars(f(_), 0, _, foo)),
 t(start_bad, numbervars(f(_), a, _, [])).
PL
want="$(cd "$D" && timeout -k 5 20 "$SW" -q w.pl -t halt < /dev/null 2>/dev/null | grep .)"
[ "$(printf '%s\n' "$want" | grep -c .)" = 32 ] || refuse "swipl did not answer the thirty-two lines"
m4ok=1   # a program SCRIP refuses to compile is this gate's red, never a refusal
( cd "$D" && timeout -k 5 60 "$B/scrip" --compile --out=w.s w.pl < /dev/null > /dev/null 2>&1 && [ -s w.s ] \
  && gcc -m64 -no-pie w.s -o w.bin -L"$B/out" -lscrip_rt -lm -Wl,-rpath,"$B/out" > /dev/null 2>&1 ) || m4ok=0
red=0
arm() {
    local label="$1" got n; shift
    got="$(cd "$D" && "$@" 2>/dev/null | grep .)"
    n="$(diff <(printf '%s\n' "$want") <(printf '%s\n' "$got") | grep -c '^<')"
    if [ "$got" = "$want" ]; then echo "  $label GREEN: 32 of 32 lines as swipl"
    else echo "  $label RED: $n of 32 swipl lines missing or different"; diff <(printf '%s\n' "$want") <(printf '%s\n' "$got") | sed 's/^/    /'; red=1; fi
}
arm m3 timeout -k 5 30 "$B/scrip" --run w.pl < /dev/null
if [ "$m4ok" = 1 ]; then arm m4 timeout -k 5 30 ./w.bin < /dev/null; else echo "  m4 RED: the program did not compile or link in mode 4"; red=1; fi
[ "$red" = 0 ] && echo "PASS $G"
exit "$red"
