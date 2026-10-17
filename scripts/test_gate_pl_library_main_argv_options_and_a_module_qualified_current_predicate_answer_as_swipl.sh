#!/usr/bin/env bash
# test_gate_pl_library_main_argv_options_and_a_module_qualified_current_predicate_answer_as_swipl.sh -- library(main) AND
# library(optparse) ARE VENDORED, argv_options/3,4 TAKE THEIR ARGV MODULE-QUALIFIED AS swipl's DO, AND
# current_predicate(M:Name/Arity) ANSWERS FOR A MODULE (cfo 2026-10-14, row
# prolog-swi-library-test-main-every-case-agrees-with-swipl-in-both-modes-ceo-1664).
#
# SWI's library/test_main.pl read 5/48: library(main) and library(optparse) were not vendored, so the file's
# :- use_module(library(main)) fell to a run-time use_module SCRIP refuses and no case ran. Now (src/parsers/prolog/prelude/
# main.pl and optparse.pl, byte-identical to swipl 9.0.4's, optparse reading since the reader takes a bar inside an argument,
# 95fb68844) with five SOURCE_EDITS in ../harness/scripts/util_gen_prolog_prelude_libs.py: --gspy takes its spy(PI) branch and
# cli_enable_development_system/0 drops its xpce branch (SCRIP loads no library at run time and has neither source), and
# argv_options/3, argv_options/4 and argv_usage/1 read a bare argument as user:X (SCRIP's module flattener qualifies a
# meta-argument only inside a module or a plunit unit). Two cures it needed: argv_options/3,4 and argv_usage/1 join the
# flattener's table of library meta-predicates (prolog_lower.c pl_mod_meta_builtins, spec ":"), so a call from a unit hands
# the library plunit_<unit>:Argv; and current_predicate/1 takes M:Name/Arity (lower_prolog.c routes a qualified indicator to
# the prelude's '$cp_mq'/2): a module's own predicate is its flattened name 'M:Name', and a user predicate is visible from
# every module, as swipl's default import makes it -- so in(M:opt_type(_,_,_)) finds the calling unit's own opt_type/3.
# NOT HERE: a predicate exactly one module defines also gets a bare alias from the flattener, which current_predicate(X:N/A)
# then sees from every other module X (swipl answers no) -- test_main's opt_type/3 is defined by several units and has none;
# current_prolog_flag(break_level, _) in library(main)'s main/0 raises domain_error where swipl fails (no graded program reaches it).
#
# THE ARMS: one program under the plunit shim, sixteen lines (eleven current_predicate properties, guided parsing in two units,
# unguided parsing in a unit and from user, one opt_parse/4), stdout cut against swipl with its own library(plunit),
# library(main) and library(optparse) in this run, mode 3 and mode 4. FAIL-ONCE, measured on
# the parent 95fb68844 rebuilt: 15 of 16 lines missing or different in both modes (current_predicate(M:N/A) raises
# type_error(predicate_indicator, ...), argv_options and opt_parse do not exist); with the cure 16 of 16 in both modes.
# rc=0 both modes agree with swipl · rc=1 a divergence · rc=2 REFUSAL (no swipl, no shim, no build).  ~6 s.
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
B="$HERE/../../SCRIP"
G=test_gate_pl_library_main_argv_options_and_a_module_qualified_current_predicate_answer_as_swipl
refuse() { echo "⛔ REFUSED(2) [$G]: $*"; exit 2; }
. "$HERE/lib_oracle_flags.sh" || refuse "lib_oracle_flags.sh unloadable -- the one accessor of the oracle binaries"
SW="$(swipl_bin)"; [ -x "$SW" ] || refuse "no swipl at $SW -- the oracle (swipl_bin)"
PLUNIT="${S4E_CORPUS:-$B/../corpus}/tests/prolog/plunit.pl"; [ -f "$PLUNIT" ] || refuse "no plunit shim at $PLUNIT"
[ -x "$B/scrip" ] || refuse "$B/scrip is not built"
[ -f "$B/out/libscrip_rt.so" ] || refuse "out/libscrip_rt.so is not built -- mode 4 cannot link"
"$HERE/util_require_fresh.sh" --gate "$G" || exit $?
D="$(mktemp -d)" || refuse "no scratch dir"
trap 'rm -rf "$D"' EXIT
cat > "$D/w.pl" <<'PL'
:- use_module(library(plunit)).
:- use_module(library(main)).
:- use_module(library(optparse)).
t(N, G) :- catch((G -> R = yes ; R = no), error(E, _), R = E), writeq(N-R), nl.
tv(N, G, V) :- catch((G -> R = V ; R = no), error(E, _), R = E), writeq(N-R), nl.
foo.
:- begin_tests(g).
opt_type(v, verbose, boolean).
opt_type(n, count, integer).
test(g) :- M = plunit_g, t(own, current_predicate(M:opt_type/3)), t(lit, current_predicate(plunit_g:opt_type/3)),
    t(user_visible, current_predicate(M:foo/0)), t(user_q, current_predicate(user:foo/0)), t(missing, current_predicate(M:nope/0)),
    t(other_unit, current_predicate(plunit_u:opt_type/3)), t(user_opt_type, current_predicate(user:opt_type/3)),
    t(arity_enum, findall(A, current_predicate(M:opt_type/A), [3])), t(not_atom, current_predicate(1:foo/0)), t(bad_pi, current_predicate(M:foo)),
    argv_options(['-v', '-n', '3', a], P, O), writeq(guided-(P-O)), nl.
:- end_tests(g).
:- begin_tests(h).
opt_type(x, y, boolean).
test(h) :- argv_options(['-x', c], P, O), writeq(guided_other_unit-(P-O)), nl.
:- end_tests(h).
:- begin_tests(u).
test(u) :- t(u_own, current_predicate(plunit_u:opt_type/3)), argv_options(['--name=arg', '--pi=3.14', a1], P, O), writeq(unguided-(P-O)), nl.
:- end_tests(u).
go :- run_tests, argv_options([b, '--no-x'], P, O), writeq(user_unguided-(P-O)), nl,
    tv(optparse, opt_parse([[opt(verbose), type(boolean), default(false), shortflags([v]), longflags([verbose])]], ['-v', f], Opts, Pos), Opts-Pos).
PL
printf ':- initialization(go).\n' > "$D/g.pl"
want="$(cd "$D" && timeout -k 5 20 "$SW" -q -g go -t halt w.pl < /dev/null 2>/dev/null | grep -E '^[a-z_]+-')"
[ "$(printf '%s\n' "$want" | grep -c .)" = 16 ] || refuse "swipl did not answer the sixteen lines: [$want]"
m4ok=1   # a program SCRIP refuses to compile is this gate's red, never a refusal
( cd "$D" && timeout -k 5 60 "$B/scrip" --compile -o w.s "$PLUNIT" w.pl g.pl < /dev/null > /dev/null 2>&1 && [ -s w.s ] \
  && gcc -m64 -no-pie w.s -o w.bin -L"$B/out" -lscrip_rt -lm -Wl,-rpath,"$B/out" > /dev/null 2>&1 ) || m4ok=0
red=0
arm() {
    local label="$1"; shift
    local got n
    got="$(cd "$D" && "$@" 2>/dev/null | grep -E '^[a-z_]+-')"
    n="$(diff <(printf '%s\n' "$want") <(printf '%s\n' "$got") | grep -c '^<')"
    if [ "$got" = "$want" ]; then echo "  $label GREEN: 16 of 16 lines as swipl"
    else echo "  $label RED: $n of 16 swipl lines missing or different"; diff <(printf '%s\n' "$want") <(printf '%s\n' "$got") | sed 's/^/    /'; red=1; fi
}
arm m3 timeout -k 5 20 "$B/scrip" --run "$PLUNIT" w.pl g.pl < /dev/null
if [ "$m4ok" = 1 ]; then arm m4 timeout -k 5 20 ./w.bin < /dev/null; else echo "  m4 RED: the program did not compile or link in mode 4"; red=1; fi
[ "$red" = 0 ] && echo "PASS $G"
exit "$red"
