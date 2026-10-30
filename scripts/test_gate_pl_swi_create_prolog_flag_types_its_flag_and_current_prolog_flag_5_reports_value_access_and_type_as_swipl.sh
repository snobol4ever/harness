#!/usr/bin/env bash
# test_gate_pl_swi_create_prolog_flag_types_its_flag_and_current_prolog_flag_5_reports_value_access_and_type_as_swipl.sh -- A RUN-TIME PROLOG FLAG HAS A TYPE AND AN ACCESS (ceo CEO-1930, hq_icon on the SWI umbrella; swipl 9.0.4).
# swipl types every flag it creates -- create_prolog_flag/3's type(boolean|atom|integer|float|term), or the type of the first value set_prolog_flag gives a new name -- checks every later value
# against that type (type_error(bool|atom|integer|float, V); a boolean takes on/off/true/false and keeps true/false), refuses a read_only flag (permission_error(modify, flag, F)), and keeps an
# existing flag's type and access when create_prolog_flag meets it again (keep(true) leaves it alone). '$current_prolog_flag'(Name, Value, Scope, Access, Type) reports value, access (read|write) and
# type. SCRIP stored a created flag's value as the text of an atom (42 became '42'), ignored every option, and had no '$current_prolog_flag'/5, so core/test_prolog_flag invalid#1 (type_error(atom,42))
# and preset_bool#1 (a preset boolean kept by keep(true), read back as true+boolean) read red in both modes.
# THE WITNESS (SWI dialect, selected by the use_module line as the suite's files are): 84 labelled shapes, 171 lines of swipl's answer, 28 of the shapes refused (raised) -- a new flag of each type,
# declared and derived; the conversions (on -> true when declared boolean, 1 -> 1.0 when declared float, on kept as on when the type is derived); read_only and read_write; the refusals of the option
# list (the type, the access, the keep, the list itself, unbound arguments); a typed set of each type (accepted, refused, normalised); the implicit flag a set_prolog_flag of a new name makes; an existing
# flag met again (kept, replaced, refused by its own type, refused as read-only); and the type and access of six builtin flags -- each answered as `Label: ok|failed|raised(Formal)` and the flag's
# `[Value Access Type Scope]` after it.
# ARMS: the oracle answers the whole witness (its last line is present, an oracle that cannot REFUSES rc 2), then mode 3 and mode 4 each equal it line for line.
# RED BEFORE (measured 2026-10-30 on the tree before the cure, mode 3): the witness stops at its first '$current_prolog_flag'/5 call (existence_error), 2 lines of swipl's 171.
# NOT COVERED, KNOWN: an unbound Name to '$current_prolog_flag'/5 enumerates every flag in swipl and raises instantiation_error here; the builtin flags keep SCRIP's allow-list errors (domain_error) on a bad set.
# rc 0 every arm holds; 1 an arm is red; 2 cannot measure.
GATE_NAME=test_gate_pl_swi_create_prolog_flag_types_its_flag_and_current_prolog_flag_5_reports_value_access_and_type_as_swipl
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="${S4E_HOME:-$(cd "$HERE/../.." && pwd)}"
SCRIP="$ROOT/SCRIP/scrip"
RT="${RT_DIR:-$ROOT/SCRIP/out}"
SWIPL=/usr/bin/swipl
refuse() { echo "⛔ REFUSED(2) [$GATE_NAME]: $*" >&2; exit 2; }
[ -x "$SCRIP" ] || refuse "no scrip binary at $SCRIP -- run make first"
[ -x "$SWIPL" ] || refuse "no swipl oracle at $SWIPL"
"$HERE/util_require_fresh.sh" --gate "$GATE_NAME" "$SCRIP" "$RT/libscrip_rt.so" || exit 2
TMPD="$(mktemp -d)"; trap 'rm -rf "$TMPD"' EXIT
red=0; total=0
cat > "$TMPD/w.pl" <<'EOP'
:- use_module(library(lists)).
:- initialization(main).
st(N) :- ( '$current_prolog_flag'(N, V, S, A, T) -> ( var(S) -> Sc = open ; Sc = bound ), write(' ['), writeq(V), write(' '), write(A), write(' '), writeq(T), write(' '), write(Sc), write(']') ; write(' [no flag]') ).
t(L, G) :- write(L), write(':'), catch(( call(G) -> R = ok ; R = failed ), E, ( E = error(F, _) -> R = raised(F) ; R = threw(E) )), write(' '), writeq(R), nl.
c(L, N, V, O) :- t(L, create_prolog_flag(N, V, O)), ( atom(N) -> write('   '), write(N), st(N), nl ; true ).
s(L, N, V) :- t(L, set_prolog_flag(N, V)), write('   '), write(N), st(N), nl.
main :-
    c(new_int, f1, 42, []),
    c(new_atom, f2, abc, []),
    c(new_float, f3, 1.5, []),
    c(new_true, f4, true, []),
    c(new_term, f5, g(x), []),
    c(new_term_declared, f6, g(x), [type(term)]),
    c(new_int_as_float, f7, 1, [type(float)]),
    c(new_on_declared_boolean, f8, on, [type(boolean)]),
    c(new_on_derived, f9, on, []),
    c(new_off_declared, f10, off, [type(boolean)]),
    c(new_int_declared_term, f11, 1, [type(term)]),
    c(new_string, f12, "str", []),
    c(new_list, f13, [a,b], [type(term)]),
    c(new_nil, f14, [], []),
    c(new_read_only, f15, 5, [access(read_only)]),
    s(set_read_only, f15, 6),
    c(new_read_write, f16, 1, [access(read_write)]),
    c(bad_atom_int, f17, 42, [type(atom)]),
    c(bad_bool_atom, f18, abc, [type(boolean)]),
    c(bad_int_atom, f19, abc, [type(integer)]),
    c(bad_int_float, f20, 1.5, [type(integer)]),
    c(bad_atom_string, f21, "str", [type(atom)]),
    c(bad_type_name, f22, true, [type(foo)]),
    c(bad_type_oneof, f23, a, [type(oneof([a,b]))]),
    c(bad_access, f24, 1, [access(foo)]),
    c(bad_keep, f25, 1, [keep(maybe)]),
    c(unbound_name, _, 1, []),
    c(unbound_value, f26, _, []),
    c(unbound_options, f27, 1, _),
    c(unbound_type, f28, 1, [type(_)]),
    c(compound_name, g(x), 1, []),
    c(options_not_list, f29, 1, foo),
    c(unknown_option, f30, 1, [bogus(1)]),
    c(type_twice, f31, 1, [type(integer),type(atom)]),
    c(int_flag, g1, 1, [type(integer)]), s(int_flag_set_atom, g1, abc), s(int_flag_set_int, g1, 7), s(int_flag_set_float, g1, 1.5),
    c(atom_flag, g2, abc, [type(atom)]), s(atom_flag_set_int, g2, 3), s(atom_flag_set_atom, g2, def),
    c(bool_flag, g3, true, [type(boolean)]), s(bool_flag_set_off, g3, off), s(bool_flag_set_maybe, g3, maybe), s(bool_flag_set_true, g3, true),
    c(float_flag, g4, 1.0, [type(float)]), s(float_flag_set_float, g4, 2.5), s(float_flag_set_atom, g4, x),
    c(term_flag, g5, 1, [type(term)]), s(term_flag_set_term, g5, h(y)), s(term_flag_set_atom, g5, z),
    s(implicit_on, h1, on), s(implicit_int, h2, 42), s(implicit_atom, h3, foo), s(implicit_term, h4, f(x)),
    s(implicit_int_set_atom, h2, abc), s(implicit_int_set_int, h2, 43),
    s(implicit_bool_set_off, h1, off),
    s(pre_true, k1, true), c(keep_true_existing, k1, false, [type(boolean),keep(true)]),
    s(pre_true2, k2, true), c(keep_false_existing, k2, false, [type(boolean)]),
    c(recreate_atom, k3, a, [type(atom)]), c(recreate_keep, k3, b, [type(atom),keep(true)]), c(recreate_same, k3, c, [type(atom)]),
    c(recreate_other_type, k4, a, [type(atom)]), c(recreate_int, k4, 1, [type(integer)]),
    c(recreate_wrong_default_type, k5, a, [type(atom)]), c(recreate_default_int, k5, 5, []),
    c(recreate_int_as_float, k6, 1, [type(integer)]), c(recreate_float_over_int, k6, 2.5, [type(float)]),
    c(recreate_read_only, k7, 1, [access(read_only)]), c(recreate_over_read_only, k7, 2, []),
    c(recreate_read_only_keep, k7, 3, [keep(true)]),
    s(pre_atom, m1, aapje), c(keep_atom_to_int, m1, 42, [type(integer),keep(true)]),
    s(pre_int, m2, 42), c(keep_int_to_atom, m2, abc, [type(atom),keep(true)]),
    s(pre_bool, m3, true), c(keep_bool_to_term, m3, default, [type(term),keep(true)]),
    s(pre_int2, m4, 42), c(keep_int_to_float, m4, 0.1, [type(float),keep(true)]),
    t(meta_bounded, true), write('   bounded'), st(bounded), nl,
    write('   occurs_check'), st(occurs_check), nl,
    write('   unknown'), st(unknown), nl,
    write('   debug'), st(debug), nl,
    write('   iso'), st(iso), nl,
    write('   prefer_rationals'), st(prefer_rationals), nl,
    write('   no_such_flag_anywhere'), st(no_such_flag_anywhere), nl,
    t(meta_nonatom_name, '$current_prolog_flag'(3, _, _, _, _)),
    halt.
EOP
check() {
    local name="$1" got="$2"
    total=$((total+1))
    if [ "$got" = "$WANT" ]; then echo "  ok  $name"
    else echo "  RED $name: differs from swipl's answer:"; diff <(printf '%s\n' "$WANT") <(printf '%s\n' "$got") | head -8 | sed 's/^/      /'; red=$((red+1)); fi
}
WANT="$(timeout -k 5 30 "$SWIPL" -q "$TMPD/w.pl" </dev/null 2>&1)" || refuse "swipl could not run the witness"
[ "$(printf '%s\n' "$WANT" | tail -1)" = "meta_nonatom_name: raised(type_error(atom,3))" ] || refuse "swipl did not answer the witness to its last line"
total=$((total+1)); echo "  ok  swipl answers the whole witness ($(printf '%s\n' "$WANT" | wc -l) lines)"
got_m3="$(timeout -k 5 60 "$SCRIP" "$TMPD/w.pl" </dev/null 2>&1)"
check "mode 3 equals swipl" "$got_m3"
if timeout -k 5 60 "$SCRIP" --compile --out="$TMPD/w.s" "$TMPD/w.pl" </dev/null 2> "$TMPD/err" > /dev/null && gcc -m64 -no-pie "$TMPD/w.s" -o "$TMPD/w.bin" -L"$RT" -lscrip_rt -Wl,-rpath,"$RT" -lm 2> "$TMPD/err"; then
    got_m4="$(timeout -k 5 60 "$TMPD/w.bin" </dev/null 2>&1)"
else
    refuse "the mode-4 compile or link failed: $(head -c 200 "$TMPD/err")"
fi
check "mode 4 equals swipl" "$got_m4"
if [ "$red" = 0 ]; then echo "✅ GATE PASS [$GATE_NAME]: $total of $total arms hold"; exit 0; fi
echo "⛔ GATE FAIL [$GATE_NAME]: $red of $total arm(s) red"; exit 1
