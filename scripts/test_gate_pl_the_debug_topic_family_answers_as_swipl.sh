#!/usr/bin/env bash
# test_gate_pl_the_debug_topic_family_answers_as_swipl.sh
#
# THE ROW: prolog-debug-3-and-the-debug-topic-family-are-absent-21-swi-test-files-call-debug-3 (hq_prolog, rank 1; 21 SWI
# test files call debug/3, among them every tabling_exN case's before/between/after hooks and xsb_test.pl). library(debug)
# in the Prolog prelude: debug(Topic, Format, Args) prints "% " + the formatted text on user_error when an enabled topic
# unifies with Topic, else succeeds silently; debug/1 enables a topic (u(_) covers u(x)), nodebug/1 disables the topic
# that is its variant, debugging/1 tests; nodebug/0 is the debugger's switch and leaves topics alone, as in swipl. The
# enabled set is one cell of the global store.
#
# THE ARM: 8 stdout lines plus the one stderr line an enabled topic prints, the ref cut from SWI-Prolog 9.0.4, in both
# modes. rc=0 clean · rc=1 a divergence · rc=2 REFUSAL.
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
t(G) :- catch((G -> write(yes) ; write(no)), error(E, _), write(E)), nl.
main :-
  debug(t, 'hi ~w', [1]), write(a), nl,
  t(debugging(t)),
  debug(t), t(debugging(t)),
  debug(t, 'shown ~w', [2]),
  debug(u(_)), t(debugging(u(x))),
  nodebug(t), t(debugging(t)),
  nodebug, t(debugging(u(x))),
  t(debug(t, 'x', [])),
  t(assertion(true)),
  halt.
PL
cat > "$D/g.ref" <<'REF'
a
no
yes
yes
no
yes
yes
yes
REF
( cd "$D" && timeout -k 5 30 "$B/scrip" g.pl < /dev/null > g.m3 2> g.m3e )
( cd "$D" && timeout -k 5 60 "$B/scrip" --compile --out=g.s g.pl < /dev/null > /dev/null 2>&1 && gcc -no-pie g.s -L"$B/out" -lscrip_rt -lm -lpthread -Wl,-rpath,"$B/out" -o g.bin 2>/dev/null ) || refuse "g.pl: mode 4 did not build"
( cd "$D" && timeout -k 5 30 ./g.bin < /dev/null > g.m4 2> g.m4e )
red=0
for m in m3 m4; do
    if cmp -s "$D/g.ref" "$D/g.$m" && grep -qx '% shown 2' "$D/g.${m}e" && ! grep -q 'hi 1' "$D/g.${m}e"; then echo "  ok   $m: 8 of 8 lines answer as swipl, the enabled topic prints on user_error and the disabled one does not"
    else echo "  FAIL $m: diverges from swipl:"; diff "$D/g.ref" "$D/g.$m" | head -12; echo "  stderr: $(head -3 "$D/g.${m}e" | tr '\n' '|')"; red=$((red + 1)); fi
done
if [ $red -eq 0 ]; then echo "GATE PASS(0): the debug topic family answers as swipl in both modes"; exit 0; fi
echo "GATE FAIL(1): $red of 2 mode(s) diverge"; exit 1
