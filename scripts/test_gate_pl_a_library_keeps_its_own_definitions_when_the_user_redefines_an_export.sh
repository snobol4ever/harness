#!/usr/bin/env bash
# test_gate_pl_a_library_keeps_its_own_definitions_when_the_user_redefines_an_export.sh -- A VENDORED LIBRARY RESOLVES ITS OWN CALLS IN ITS OWN MODULE (hq_snobol4, 2026-10-24; the cto's
# ruling (a) under CEO-1964, ARCH-PROLOG-DATABASE.md section 2): every export a spliced library defines also gets a private key, its module-qualified name (dcg_basics:digit/3), every call inside
# a spliced library's clauses to an export of a spliced library is renamed to the defining library's private key, the exported key is a LIBRARY-kind decls entry (kind 7), and the first
# load-time assert of a LIBRARY key takes it as the program's own, dynamic, re-pointing that key alone. So a user definition, at compile time or at load time (term_expansion), is reached by
# every user call and by no library call, as swipl resolves a library body in its module and the user's definition in user. CELLS: the own-export arm (dcg/basics digits//1 calling its
# digit//1 after the user redefines digit//1, at compile time and at load time), the cross-library arm (aggregate's sum and max over lists' sum_list/2 and max_list/2 after the user
# redefines both, both times), a load-time assert of a LIBRARY key (digit/3), and issues_test1142's shape (the user's term-expanded digits//1 and digit//1 both). Each clause of a cell sits on its own line (the loader defers a clause by its line, after the term_expansion line). Every cell runs in m3 and
# m4 against swipl (expectations CUT FROM THE ORACLE at run time); FAIL_ONCE=1 corrupts the first expectation. The parent of the cure reads red on five cells (four print the user's answer
# from library code or refuse the assert as static_procedure). rc 0 green, 1 red, 2 could not measure.
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
set -uo pipefail
G="$(basename "${BASH_SOURCE[0]}" .sh)"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)" || { echo "REFUSE(2): no SCRIP beside harness"; exit 2; }
SCRIP="${SCRIP_BIN:-$ROOT/scrip}"; RT_DIR="${RT_DIR:-$ROOT/out}"
. "$HERE/lib_oracle_flags.sh" || { echo "⛔ GATE REFUSE(2) [$G]: lib_oracle_flags.sh unloadable"; exit 2; }
SWI="$(swipl_bin)" || { echo "⛔ GATE REFUSE(2) [$G]: no swipl -- every expectation is cut from the oracle"; exit 2; }
[ -x "$SCRIP" ] && [ -f "$RT_DIR/libscrip_rt.so" ] || { echo "⛔ GATE REFUSE(2) [$G]: no scrip or runtime"; exit 2; }
T=$(mktemp -d) || exit 2; trap 'rm -rf "$T"' EXIT
PH='main :- ( phrase(digits(L), [49,50,51], R) -> atom_codes(A, L), atom_codes(B, R), write(A-B) ; write(no) ), nl, ( phrase(digit(C), [120]) -> write(C) ; write(nodigit) ), nl.'
AG='main :- aggregate_all(sum(X), member(X, [1,2,3]), S), write(S), nl, aggregate_all(max(Y), member(Y, [4,9,2]), M), write(M), nl, sum_list([1,2], U), write(U), nl.'
CELLS=(
"own_export_redefined_at_compile_time|:- use_module(library(dcg/basics)).@digit(D) --> [D], { D =:= 120 }.@$PH"
"own_export_redefined_at_load_time|:- use_module(library(dcg/basics)).@term_expansion(mk, (digit(D) --> [D], { D =:= 120 })).@mk.@$PH"
"cross_library_export_redefined_at_compile_time|:- use_module(library(aggregate)).@sum_list(_, 999).@max_list(_, 888).@$AG"
"cross_library_export_redefined_at_load_time|:- use_module(library(aggregate)).@term_expansion(mk, [sum_list(_, 999), max_list(_, 888)]).@mk.@$AG"
"a_load_time_clause_takes_a_library_key|term_expansion(mk, digit(1, a, b)).@mk.@main :- digit(X, Y, Z), write(X-Y-Z), nl."
"term_expanded_digits_and_digit_both|term_expansion(mk, [(digits([D|Ds]) --> digit(D), digits(Ds)), (digits([D]) --> digit(D)), (digit(D) --> [D], { memberchk(D, [zero,one]) })]).@mk.@main :- ( phrase(digits(L), [one,zero,one]) -> write(L) ; write(no) ), nl, ( phrase(digits(_), [one,nine]) -> write(yes) ; write(rejected) ), nl."
)
swi() { ( cd "$T" && timeout -k 5 30s "$SWI" -q -g halt -t halt "$1" </dev/null 2>/dev/null ); }
run3() { ( cd "$T" && LD_LIBRARY_PATH="$RT_DIR" timeout -k 5 30s "$SCRIP" "$1" </dev/null 2>/dev/null ); }
run4() { ( cd "$T" && SCRIP="$SCRIP" LIBRT="$RT_DIR/libscrip_rt.so" timeout -k 5 60s bash "$HERE/run_prolog_via_x86_backend.sh" "$T/$1" </dev/null 2>/dev/null ); }
RC=0; N=0; A3=0; A4=0; BAD=""; FIRST=1
for c in "${CELLS[@]}"; do n="${c%%|*}"; body="${c#*|}"; f="$n.pl"
  printf ':- initialization(main).\n%s\n' "${body//@/$'\n'}" > "$T/$f"
  want="$(swi "$f")"; [ -n "$want" ] || { echo "⛔ GATE REFUSE(2) [$G]: swipl printed nothing for cell $n"; exit 2; }
  [ -n "${FAIL_ONCE:-}" ] && [ "$FIRST" = 1 ] && want="$want corrupted by FAIL_ONCE"; FIRST=0
  N=$((N + 1)); g3="$(run3 "$f")"; g4="$(run4 "$f")"
  if [ "$g3" = "$want" ]; then A3=$((A3 + 1)); else RC=1; BAD="$BAD
      m3 $n: swipl [$(echo "$want" | tr '\n' ' ')] scrip [$(echo "$g3" | tr '\n' ' ' | cut -c1-80)]"; fi
  if [ "$g4" = "$want" ]; then A4=$((A4 + 1)); else RC=1; BAD="$BAD
      m4 $n: swipl [$(echo "$want" | tr '\n' ' ')] scrip [$(echo "$g4" | tr '\n' ' ' | cut -c1-80)]"; fi
done
echo "  blocking: m3 $A3 of $N cells agree with swipl; m4 $A4 of $N"
[ -n "$BAD" ] && printf '  ⛔ failing:%s\n' "$BAD" | head -30
if [ "$RC" = 0 ]; then echo "GATE PASS [$G]: $N cells in m3 and m4, a vendored library keeps its own definitions and a user definition takes the exported key alone"
else echo "GATE FAIL(1) [$G]: $((N - A3)) m3 and $((N - A4)) m4 cells disagree with swipl"; fi
echo "    tree: SCRIP=$(git -C "$ROOT" rev-parse --short HEAD 2>/dev/null)$(git -C "$ROOT" diff --quiet 2>/dev/null || echo -DIRTY) oracle: $SWI measured $(date -u +%Y-%m-%dT%H:%MZ)"
exit $RC
