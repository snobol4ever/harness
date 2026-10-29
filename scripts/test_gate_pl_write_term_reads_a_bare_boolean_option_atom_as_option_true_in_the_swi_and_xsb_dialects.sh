#!/usr/bin/env bash
# test_gate_pl_write_term_reads_a_bare_boolean_option_atom_as_option_true_in_the_swi_and_xsb_dialects.sh -- write_term(T, [quoted]) IS write_term(T, [quoted(true)]) WHERE THE ORACLE SAYS SO.
# swipl 9.0.4 and 10.1.5 read a bare atom naming a boolean write option (quoted, ignore_ops, numbervars, ...) as Option(true); XSB does too (its ref for
# prolog_tests_pip_write_term prints 'a b' for write_term('a b',[quoted]) and A for write_term('$VAR'(0),[numbervars])); the gprolog oracle (gprolog_bin) and ISO do NOT: they raise
# domain_error(write_option, quoted), and the default dialect keeps that answer. SCRIP raised it in every dialect (the SWI dialect lost all 11 lines of pip_write_term's
# first call to it). The two sites (by_name_dispatch.c pl_write_opts_check and unification.c rt_pl_write_term_cell) now accept the bare form in the SWI and XSB dialects only.
# The expected text for the SWI and default arms is RE-CHECKED on every run against live swipl and gprolog (an oracle that cannot answer REFUSES rc 2, one that disagrees
# reds the gate); the XSB arm is stored from the vendored XSB ref (corpus/packages/prolog/xsb_tests, prolog_tests_pip_write_term).
# RED BEFORE: on SCRIP 690d88013 the SWI arm and the XSB arm both raised domain_error(write_option, quoted) in m3 and m4 (4 arms red); the default arm was green.
set -u
GATE_NAME=test_gate_pl_write_term_reads_a_bare_boolean_option_atom_as_option_true_in_the_swi_and_xsb_dialects
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="${S4E_HOME:-$(cd "$HERE/../.." && pwd)}"
SCRIP="$HERE/../../SCRIP/scrip"
RT="${RT_DIR:-$HERE/../../SCRIP/out}"
SWIPL=/usr/bin/swipl
refuse() { echo "⛔ REFUSED(2) [$GATE_NAME]: $*" >&2; exit 2; }
. "$HERE/lib_oracle_flags.sh" || refuse "lib_oracle_flags.sh is missing"
GPROLOG="$(gprolog_bin)" || refuse "the gprolog oracle accessor refused"
[ -x "$SCRIP" ] || refuse "no scrip binary at $SCRIP -- run make first"
[ -x "$SWIPL" ] || refuse "no swipl oracle at $SWIPL"
[ -x "$GPROLOG" ] || refuse "no gprolog oracle at $GPROLOG"
"$HERE/util_require_fresh.sh" --gate "$GATE_NAME" "$SCRIP" "$RT/libscrip_rt.so" || exit 2
MODES="${PL_RUNG_MODES:-m3,m4}"
TMPD="$(mktemp -d)"; trap 'rm -rf "$TMPD"' EXIT
red=0; total=0
run_m3() { timeout -k 5 20 "$SCRIP" "$1" </dev/null 2>"$TMPD/err"; }
run_m4() {
    local src="$1" s="$TMPD/w.s" b="$TMPD/w.bin"
    timeout -k 5 60 "$SCRIP" --compile --out="$s" "$src" </dev/null 2>"$TMPD/err" || { echo "  (m4: compile failed: $(head -c 160 "$TMPD/err"))"; return 97; }
    gcc -m64 -no-pie "$s" -o "$b" -L"$RT" -lscrip_rt -Wl,-rpath,"$RT" -lm 2>"$TMPD/err" || { echo "  (m4: link failed: $(head -c 160 "$TMPD/err"))"; return 98; }
    timeout -k 5 20 "$b" </dev/null 2>"$TMPD/err"
}
run_swipl() { timeout -k 5 30 "$SWIPL" -q "$1" </dev/null 2>/dev/null; }
run_gprolog() { timeout -k 5 30 "$GPROLOG" --consult-file "$1" --query-goal halt </dev/null 2>/dev/null | grep -v -e '^compiling ' -e 'compiled, ' -e '^$' -e 'GNU Prolog' -e 'Copyright' -e '^Compiled ' -e '^By Daniel' -e 'Prolog top-Level' -e '^| ?-'; }
arm() {
    local name="$1" src="$2" want_out="$3" mode got
    for mode in m3 m4; do
        case "$MODES" in *"$mode"*) : ;; *) continue ;; esac
        total=$((total+1))
        got="$("run_$mode" "$src")"
        if [ "$got" = "$want_out" ]; then echo "  ok  $name $mode"
        else echo "  RED $name $mode: out=[$got] want [$want_out] $(head -c 200 "$TMPD/err" 2>/dev/null)"; red=$((red+1)); fi
    done
}
oracle() {
    local name="$1" which="$2" src="$3" want_out="$4" got
    total=$((total+1)); got="$("run_$which" "$src")"
    if [ "$got" = "$want_out" ]; then echo "  ok  $name oracle $which"
    else echo "  RED $name oracle $which disagrees with the expected text: out=[$got] want [$want_out]"; red=$((red+1)); fi
}
cat > "$TMPD/swi.pl" <<'EOP'
:- use_module(library(lists)).
:- initialization(main).
main :-
    write_term('a b', [quoted]), nl,
    write_term([a,b], [ignore_ops]), nl,
    write_term('$VAR'(0), [numbervars]), nl,
    write_term('$VAR'(27), [numbervars]), nl,
    write_term(f(a, 'B c', 1+2), [quoted, ignore_ops]), nl,
    write_term(f('A b', g(x)), [quoted(true), max_depth(3)]), nl,
    write_term('a b', [quoted(false)]), nl,
    halt.
EOP
cat > "$TMPD/plain.pl" <<'EOP'
:- initialization(main).
main :-
    catch(( write_term('a b', [quoted]), write(wrote) ), error(E, _), write(raised(E))), nl,
    write_term('a b', [quoted(true)]), nl,
    halt.
EOP
cat > "$TMPD/xsb.pl" <<'EOP'
:- op(1050, fy, import). :- op(1100, fx, export). :- op(1040, xfx, from). :- op(1100, fy, index). :- compiler_options([]). :- use_module(library(lists)).
:- initialization(main).
main :-
    write_term('a b', [quoted]), nl,
    write_term('$VAR'(0), [numbervars]), nl,
    halt.
EOP
WANT_SWI="$(printf '%s\n' "'a b'" '[a,b]' 'A' 'B1' "f(a,'B c',+(1,2))" "f('A b',g(x))" 'a b')"
WANT_PLAIN="$(printf '%s\n' 'raised(domain_error(write_option,quoted))' "'a b'")"
WANT_XSB="$(printf '%s\n' "'a b'" 'A')"
oracle swi swipl "$TMPD/swi.pl" "$WANT_SWI"
oracle default gprolog "$TMPD/plain.pl" "$WANT_PLAIN"
arm a_bare_boolean_option_is_option_true_in_the_swi_dialect "$TMPD/swi.pl" "$WANT_SWI"
arm a_bare_boolean_option_is_option_true_in_the_xsb_dialect "$TMPD/xsb.pl" "$WANT_XSB"
arm a_bare_boolean_option_stays_a_domain_error_in_the_default_dialect "$TMPD/plain.pl" "$WANT_PLAIN"
echo "$GATE_NAME: arms=$total red=$red modes=$MODES"
[ "$red" -eq 0 ] || { echo "⛔ $GATE_NAME RED"; exit 1; }
echo "✅ $GATE_NAME GREEN"
