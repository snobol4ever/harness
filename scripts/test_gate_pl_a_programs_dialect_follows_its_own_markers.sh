#!/usr/bin/env bash
# test_gate_pl_a_programs_dialect_follows_its_own_markers.sh
#
# THE ROW: prolog-a-swi-dialect-program-reads-a-double-quoted-text-as-a-string-object-as-swipl-does-the-gnu-dialect-as-codes-ceo-1599
# (hq_prolog), on the ceo's ruling CEO-1632 and CEO-1605; the design is .github/ARCH-PROLOG-DIALECTS.md.
# THE RULE: a program is SWI when its own tree carries a construct the GNU oracle refuses or does not read -- a :- module/2 or
# :- use_module/1,2 directive, an SSU rule -- else GNU/ISO, the default. prolog_lower.c's pl_dq_lower_program finds the marker in a
# file's own clauses (the prelude never decides), records g_stage2.pl_dialect_swi, and places :- set_prolog_flag(double_quotes,
# string) at the head of that file unless the program set the flag itself, so the compile-time default, the files after it and the
# run-time flag all read string; display/1 under SWI lowers to the prelude's '$display_swi'/1, library(edinburgh)'s
# write_term(T, [quoted(true), ignore_ops(true)]).
#
# THE ARM: two programs in both modes -- swi.pl (use_module(library(lists))) against SWI-Prolog 9.0.4, gnu.pl (no marker) against
# GNU Prolog 1.6.0 -- each with its own oracle's ref. rc=0 clean · rc=1 a divergence · rc=2 REFUSAL.
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
B="$HERE/../../SCRIP"
refuse() { echo "⛔ REFUSES rc=2: $*"; exit 2; }
[ -x "$B/scrip" ] || refuse "$B/scrip is not built -- cannot measure"
[ -f "$B/out/libscrip_rt.so" ] || refuse "out/libscrip_rt.so is not built -- mode 4 cannot link"
"$HERE/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
D="$(mktemp -d)" || refuse "no scratch dir"
trap 'rm -rf "$D"' EXIT
cat > "$D/swi.pl" <<'PL'
:- use_module(library(lists)).
:- initialization(main).
main :- X = "ab", ( string(X) -> write(string) ; is_list(X) -> write(codes) ; write(other) ), nl,
  current_prolog_flag(double_quotes, F), write(F), nl,
  display(f('A b', 1+2, -(x))), nl,
  string_concat(X, "c", Y), write(Y), nl, halt.
PL
cat > "$D/swi.ref" <<'REF'
string
string
f('A b',+(1,2),-(x))
abc
REF
cat > "$D/gnu.pl" <<'PL'
:- initialization(main).
main :- X = "ab", ( is_list(X) -> write(codes) ; write(other) ), nl,
  current_prolog_flag(double_quotes, F), write(F), nl,
  display(f('A b', 1+2, -(x))), nl, halt.
PL
cat > "$D/gnu.ref" <<'REF'
codes
codes
f(A b,+(1,2),-(x))
REF
red=0
for p in swi gnu; do
    ( cd "$D" && timeout -k 5 60 "$B/scrip" $p.pl < /dev/null > $p.m3 2>&1 )
    ( cd "$D" && timeout -k 5 60 "$B/scrip" --compile -o $p.s $p.pl < /dev/null > /dev/null 2>&1 && gcc -no-pie $p.s -L"$B/out" -lscrip_rt -lm -lpthread -Wl,-rpath,"$B/out" -o $p.bin 2>/dev/null ) || refuse "$p.pl: mode 4 did not build"
    ( cd "$D" && timeout -k 5 60 ./$p.bin < /dev/null > $p.m4 2>&1 )
    for m in m3 m4; do
        if cmp -s "$D/$p.ref" "$D/$p.$m"; then echo "  ok   $p $m: answers as its dialect's oracle"
        else echo "  FAIL $p $m:"; diff "$D/$p.ref" "$D/$p.$m" | head -8; red=$((red + 1)); fi
    done
done
if [ $red -eq 0 ]; then echo "GATE PASS(0): each program's dialect follows its own markers, both modes"; exit 0; fi
echo "GATE FAIL(1): $red of 4 program-modes diverge"; exit 1
