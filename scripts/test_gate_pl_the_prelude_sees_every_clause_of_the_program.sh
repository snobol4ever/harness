#!/usr/bin/env bash
# test_gate_pl_the_prelude_sees_every_clause_of_the_program.sh -- the Prolog prelude (PL_PRELUDE_SRC in
# src/parsers/prolog/prolog_parse.c: member/2, append/3, reverse/2, last/2, ...) is injected for every predicate the
# PROGRAM references and the program does not define itself, whatever file of the program the reference or the
# definition sits in and however many clauses precede it (cto 2026-09-27, CTO-188, found by the pl2wam demo row).
#
# WHAT THIS PINS -- TWO DEFECTS OF prolog_inject_prelude, ONE CURE. (1) It decided "referenced" by a word scan of the
# TOP file's text only, so a prelude predicate called only from a file spliced in by :- include(F) was never
# injected: GNU's pl2wam (all.pl includes ten modules) died on existence_error(procedure, member/2). (2) It recorded
# the program's own definitions in user_defined[512][96] -- one row per CLAUSE, not per predicate -- so past clause
# 512 a user's own definition was invisible and the prelude's was appended after it: a program that defines
# reverse/2 after 600 facts answered [mine([a,b]),[b,a]] to findall(R, reverse([a,b], R), L), a second, foreign
# solution. wanted[256] and the per-clause calls[64] were the same fixed-cap shape (RULES.md NO FIXED LIMIT A PROGRAM
# CAN REACH). The cure walks every parsed clause tree (includes are spliced into the program before injection) into
# growable vectors, and keeps the old text scan as a union so nothing injected before is lost.
#
# THE REF IS CUT FROM swipl (a user definition of a library predicate wins there and nothing is appended), and the
# gate re-cuts it when swipl is on the box. GNU Prolog is not the oracle for arm (b): reverse/2 is a GNU built-in and
# GNU refuses the redefinition.
#
# RED BEFORE THE CURE (SCRIP 964982d54 with prolog_parse.c reverted): arm (a) existence_error(procedure,member/2),
# rc=2; arm (b) [mine([a,b]),[b,a]]. GREEN AFTER: both arms byte-identical to the ref in m3 and m4.
#
# Usage: bash ../harness/scripts/test_gate_pl_the_prelude_sees_every_clause_of_the_program.sh
set -uo pipefail
GATE_NAME=test_gate_pl_the_prelude_sees_every_clause_of_the_program
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIP="$HERE/../../SCRIP/scrip"
RT="${RT_DIR:-$HERE/../../SCRIP/out}"
. "$HERE/lib_gate.sh"
gate_parse_args "$@"
[ -x "$SCRIP" ] || { echo "⛔ REFUSED(2) [$GATE_NAME]: no scrip binary at $SCRIP -- run make first"; exit 2; }
"$HERE/util_require_fresh.sh" --gate "$GATE_NAME" "$SCRIP" "$RT/libscrip_rt.so" || exit 2
command -v gcc >/dev/null || { echo "⛔ REFUSED(2) [$GATE_NAME]: no gcc -- the mode-4 arm cannot be linked"; exit 2; }
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
mkdir -p "$T/a" "$T/b"
printf 'q1 :- member(X, [a,b]), write(X), nl, fail.\nq1.\n' > "$T/a/inc.pl"
{ printf ':- initialization(main).\n:- include(inc).\n'
  for i in $(seq 1 600); do printf 'filler(%d).\n' "$i"; done
  printf 'reverse(X, mine(X)).\n'
  printf 'main :- q1, findall(R, reverse([a,b], R), L), write(L), nl, ( last([x,y,z], E) -> write(E) ; write(none) ), nl, halt.\n'; } > "$T/a/w.pl"
sed 's/^:- include(inc)\.$//' "$T/a/w.pl" > "$T/b/w.pl"; cat "$T/a/inc.pl" >> "$T/b/w.pl"
printf 'a\nb\n[mine([a,b])]\nz\n' > "$T/ref"
if command -v swipl >/dev/null; then
    for arm in a b; do ( cd "$T/$arm" && timeout -k 5 30 swipl -q w.pl < /dev/null 2>/dev/null > sw.out )
        cmp -s "$T/$arm/sw.out" "$T/ref" || { echo "⛔ REFUSED(2) [$GATE_NAME]: swipl no longer prints the carried ref on arm ($arm) -- re-cut it from the oracle"; exit 2; }; done
fi
fail=0
for arm in a b; do
    case $arm in a) what="a prelude predicate called only from an included file is injected" ;; b) what="a user's reverse/2 defined after 600 clauses wins and nothing is appended" ;; esac
    ( cd "$T/$arm" && timeout -k 5 20 "$SCRIP" w.pl < /dev/null > m3.out 2>&1 ); rc3=$?
    if cmp -s "$T/$arm/m3.out" "$T/ref"; then echo "  ok   ($arm m3) $what"; else echo "  FAIL ($arm m3) rc=$rc3: $(tr '\n' ' ' < "$T/$arm/m3.out" | cut -c1-160)"; fail=1; fi
    if ( cd "$T/$arm" && "$SCRIP" --compile -o w.s w.pl < /dev/null > /dev/null 2>&1 && gcc -o w w.s -L"$RT" -lscrip_rt -Wl,-rpath,"$RT" -lm 2>/dev/null ); then
        ( cd "$T/$arm" && timeout -k 5 20 ./w < /dev/null > m4.out 2>&1 ); rc4=$?
        if cmp -s "$T/$arm/m4.out" "$T/ref"; then echo "  ok   ($arm m4) $what"; else echo "  FAIL ($arm m4) rc=$rc4: $(tr '\n' ' ' < "$T/$arm/m4.out" | cut -c1-160)"; fail=1; fi
    else echo "  FAIL ($arm m4) the witness did not compile or link in mode 4"; fail=1; fi
done
[ "$fail" = 0 ] && { echo "✅ GATE PASS [$GATE_NAME]: 2 arms x 2 modes answer as swipl does"; exit 0; }
echo "⛔ GATE RED [$GATE_NAME]"; exit 1
