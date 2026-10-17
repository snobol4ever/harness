#!/usr/bin/env bash
# test_gate_gprolog_output_filter_is_the_one_filter.sh -- ONE FILTER OVER gprolog's STANDARD OUTPUT, AND IT READS BOTH BANNERS (the coo
# 2026-10-10, ceo CEO-1599 on the oracle swap CEO-1598: Lon, in-chat to the ceo, verbatim: "Get the new oracle 1.6.0 and begin using it
# instead of the older one."). MEASURED: gprolog 1.6.0 prints its banner as three lines and then one EMPTY line, where 1.4.5 printed four
# lines and a compiling line; the five copies of the 1.4.5 filter (the GNU runner twice, lib_prolog_bench.sh's gnu_filter,
# test_bench_prolog_4way.sh, test_bench_prolog_modes.sh) kept that empty line, and every one of the 48 GNU driver outputs differed from its
# ref by it alone. They now call gprolog_output_filter (lib_oracle_flags.sh).
#   ARM 1  the fixed 1.6.0 witness through the filter is exactly the program's lines -- the banner and its empty line gone, an empty line
#          the program printed kept, the query echo and an "In file included from" preamble gone, a file:line warning kept
#   ARM 2  the same witness with --compile-diagnostics also drops the file:line warning and "compilation failed"
#   ARM 3  the fixed 1.4.5 witness through the filter is exactly the program's lines (both banners are read)
#   ARM 4  FAIL-ONCE, held as a negative control: the 1.4.5-keyed pattern the five copies carried, over the 1.6.0 witness, keeps the
#          banner's empty line -- so arm 1 can see the defect it guards
#   ARM 5  CENSUS: no script under ../harness/scripts/ but lib_oracle_flags.sh and this gate carries its own anchored copy of the banner pattern
#   ARM 6  LIVE: gprolog_bin (the oracle) consulting a two-line program prints, through the filter, exactly those two lines
# EXIT: 0 every arm holds · 1 an arm is red · 2 could not measure (the library or the oracle missing).
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
G=gprolog_output_filter_is_the_one_filter
. "$HERE/lib_oracle_flags.sh" 2>/dev/null && command -v gprolog_output_filter >/dev/null 2>&1 \
    || { echo "GATE UNPROVEN(2) [$G]: lib_oracle_flags.sh or its gprolog_output_filter is missing"; exit 2; }
checks=0; fails=0
ck() { checks=$((checks+1)); if [ "$1" = ok ]; then printf '  ok    %s\n' "$2"; else printf '  FAIL  %s\n' "$2"; fails=$((fails+1)); fi; }
W16=$'GNU Prolog 1.6.0 (64 bits)\nCompiled Sep 23 2026, 06:19:53 with gcc\nCopyright (C) 1999-2026 Daniel Diaz\n\nfirst\n\nthird\nIn file included from x.pl:1\nx.pl:3: warning: singleton variables [X] for p/1\ncompilation failed\n| ?- halt.'
W145=$'GNU Prolog 1.4.5 (64 bits)\nCompiled Feb 23 2020, 20:14:50 with gcc\nBy Daniel Diaz\nCopyright (C) 1999-2020 Daniel Diaz\ncompiling /x.pl for byte code...\n/x.pl compiled, 3 lines read - 1 bytes written, 5 ms\nfirst\n\nthird\n| ?- halt.'
want1=$'first\n\nthird\nx.pl:3: warning: singleton variables [X] for p/1\ncompilation failed'
want2=$'first\n\nthird'
got1="$(printf '%s\n' "$W16" | gprolog_output_filter)"
[ "$got1" = "$want1" ] && ck ok "ARM 1 the 1.6.0 witness reads the program's lines (5 of 11 kept)" || ck bad "ARM 1 the 1.6.0 witness read <$got1>"
got2="$(printf '%s\n' "$W16" | gprolog_output_filter --compile-diagnostics)"
[ "$got2" = "$want2" ] && ck ok "ARM 2 --compile-diagnostics also drops the file:line warning and compilation failed" || ck bad "ARM 2 read <$got2>"
got3="$(printf '%s\n' "$W145" | gprolog_output_filter)"
[ "$got3" = "$want2" ] && ck ok "ARM 3 the 1.4.5 witness reads the program's lines" || ck bad "ARM 3 the 1.4.5 witness read <$got3>"
old="$(printf '%s\n' "$W16" | grep -vE '^GNU Prolog|^Compiled |^By Daniel|^Copyright|^compiling |compiled, |^\| \?-|^error:|^warning:|cannot be redefined')"
[ "$old" != "$want1" ] && [ "$(printf '%s\n' "$old" | head -1)" = "" ] && ck ok "ARM 4 FAIL-ONCE: the 1.4.5-keyed pattern keeps the 1.6.0 banner's empty line" \
    || ck bad "ARM 4 the 1.4.5-keyed pattern no longer shows the defect -- the witness cannot see it"
copies="$(grep -l -F '^GNU Prolog|^Compiled |^By Daniel' "$HERE"/*.sh "$HERE"/*.py 2>/dev/null | grep -v -e '/lib_oracle_flags.sh$' -e "/test_gate_$G.sh\$" || true)"
users="$(grep -l -E 'gprolog_output_filter|gnu_filter' "$HERE"/*.sh 2>/dev/null | grep -v -e '/lib_oracle_flags.sh$' -e "/test_gate_$G.sh\$" | wc -l)"
[ -z "$copies" ] && ck ok "ARM 5 CENSUS: no other copy of the banner pattern (examined $(ls "$HERE"/*.sh "$HERE"/*.py | wc -l) scripts; $users call the one filter)" \
    || ck bad "ARM 5 CENSUS: a copy of the banner pattern outside the one filter: $(printf '%s' "$copies" | tr '\n' ' ')"
GP="$(gprolog_bin 2>/dev/null)" || { echo "GATE UNPROVEN(2) [$G]: gprolog_bin names no oracle -- arm 6 cannot run"; exit 2; }
T="$(mktemp -d)" || { echo "GATE UNPROVEN(2) [$G]: mktemp failed"; exit 2; }; trap 'rm -rf "$T"' EXIT
printf ':- initialization(main).\nmain :- write(alpha), nl, nl, write(omega), nl.\n' > "$T/p.pl"
got6="$(cd "$T" && timeout -k 5 30 "$GP" --consult-file "$T/p.pl" --query-goal halt < /dev/null 2>/dev/null | gprolog_output_filter)"
[ "$got6" = $'alpha\n\nomega' ] && ck ok "ARM 6 LIVE: the oracle's own consult, filtered, is the program's three lines" || ck bad "ARM 6 LIVE read <$got6>"
if [ "$fails" -eq 0 ]; then echo "GATE PASS(0) [$G]: $checks of $checks arms hold"; exit 0; fi
echo "GATE FAIL(1) [$G]: $fails of $checks arms red"; exit 1
