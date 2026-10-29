#!/usr/bin/env bash
# test_gate_pl_wildcard_match_answers_as_swipl.sh
#
# THE ROW: prolog-swi-term-string-3-garbage-collect-0-and-wildcard-match-2-are-absent-78-swi-cases (cfo). wildcard_match/2,3
# lives in the Prolog prelude (src/parsers/prolog/prolog_parse.c), a copy of swipl's src/os/pl-glob.c: ? and *, a class
# [...] with ranges and backslash escapes and no negation, {a,b,} alternation with backtracking, a backslash escaping the
# next character and a trailing one standing for itself, case_sensitive(false) lowering the pattern's plain characters and
# the subject (never a class member), a syntax error for an unclosed [ or {, and type_error(character_code, C) for a code
# past 0x10FFFF.
#
# THE ARM: the 29 cases of swipl's own files/test_glob.pl (glob_match), each with the verdict swipl gives, in both modes.
# rc=0 clean · rc=1 a divergence · rc=2 REFUSAL.
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
B="$HERE/../../SCRIP"
refuse() { echo "⛔ REFUSES rc=2: $*"; exit 2; }
[ -x "$B/scrip" ] || refuse "$B/scrip is not built -- cannot measure"
[ -f "$B/out/libscrip_rt.so" ] || refuse "out/libscrip_rt.so is not built -- mode 4 cannot link"
"$HERE/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
D="$(mktemp -d)" || refuse "no scratch dir"
trap 'rm -rf "$D"' EXIT
cat > "$D/g.pl" <<'PL'
:- initialization(main).
c(N, G, Want) :- catch((G -> R = true ; R = fail), error(E, _), R = err(E)), ( ok(Want, R) -> V = pass ; V = diverge ), write(N-V-R), nl.
ok(true, true). ok(fail, fail). ok(err(syn), err(syntax_error(_))). ok(err(code), err(type_error(character_code, 1114112))).
main :-
  c(1, wildcard_match('', ''), true),
  c(2, wildcard_match('', 'a'), fail),
  c(3, wildcard_match('a', ''), fail),
  c(4, wildcard_match('a?', 'aX'), true),
  c(5, wildcard_match('a[xyz]', 'ax'), true),
  c(6, wildcard_match('a[xy\\]]', 'a]'), true),
  c(7, wildcard_match('a\\', 'a\\'), true),
  c(8, wildcard_match('a\\a', 'aa'), true),
  c(9, wildcard_match('a\\[a', 'a[a'), true),
  c(10, wildcard_match('a[x-z]b', 'ayb'), true),
  c(11, wildcard_match('a[x-]b', 'axb'), true),
  c(12, wildcard_match('a[-x]b', 'axb'), true),
  c(13, wildcard_match('a{[-x],c}b', 'acb'), true),
  c(14, wildcard_match('a{[-x],c,}b', 'ab'), true),
  c(15, wildcard_match('a{[x-z],c,}b', 'ayb'), true),
  c(16, wildcard_match([65], 'A'), true),
  c(17, wildcard_match('a[Ѐ-ѐ]b', 'aХb'), true),
  c(18, wildcard_match(a, 'A', [case_sensitive(false)]), true),
  c(19, wildcard_match(a, 'A', [case_sensitive(true)]), fail),
  c(20, wildcard_match('A', a, [case_sensitive(false)]), true),
  c(21, wildcard_match('A', a, [case_sensitive(true)]), fail),
  c(22, wildcard_match(a, 'A'), fail),
  c(23, wildcard_match([0x110000], 'A'), err(code)),
  c(24, wildcard_match('se{xx', 'A'), err(syn)),
  c(25, wildcard_match('se{xx\\', 'A'), err(syn)),
  c(26, wildcard_match('se{xxр', 'A'), err(syn)),
  c(27, wildcard_match('se{xx[z', 'A'), err(syn)),
  c(28, wildcard_match('se[xy', 'A'), err(syn)),
  c(29, wildcard_match('se[xy\\', 'A'), err(syn)),
  halt.
PL
( cd "$D" && timeout -k 5 30 "$B/scrip" g.pl < /dev/null > g.m3 2>/dev/null )
( cd "$D" && timeout -k 5 60 "$B/scrip" --compile --out=g.s g.pl < /dev/null > /dev/null 2>&1 && gcc -no-pie g.s -L"$B/out" -lscrip_rt -lm -lpthread -Wl,-rpath,"$B/out" -o g.bin 2>/dev/null ) || refuse "g.pl: mode 4 did not build"
( cd "$D" && timeout -k 5 30 ./g.bin < /dev/null > g.m4 2>/dev/null )
red=0
for m in m3 m4; do
    p=$(grep -c -- '-pass-' "$D/g.$m"); d=$(grep -c -- '-diverge-' "$D/g.$m")
    if [ "$p" -eq 29 ] && [ "$d" -eq 0 ]; then echo "  ok   $m: 29 of 29 cases give swipl's verdict"
    else echo "  FAIL $m: $p of 29 give swipl's verdict; diverging: $(grep -- '-diverge-' "$D/g.$m" | tr '\n' ' ')"; red=$((red + 1)); fi
done
if [ $red -eq 0 ]; then echo "GATE PASS(0): wildcard_match/2,3 answers swipl's glob_match cases in both modes"; exit 0; fi
echo "GATE FAIL(1): $red of 2 mode(s) diverge"; exit 1
