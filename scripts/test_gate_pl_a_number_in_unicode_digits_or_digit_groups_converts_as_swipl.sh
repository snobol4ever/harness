#!/usr/bin/env bash
# test_gate_pl_a_number_in_unicode_digits_or_digit_groups_converts_as_swipl.sh -- atom_number/2, number_codes/2 and number_string/2 read a number
# written in one block of Unicode decimal digits, and an integer written in digit groups, as swipl 9.0.4 does, m3 and m4 (cfo 2026-10-18; swi
# core/test_unicode's numbers unit, 2 -> 8 of 10 in both modes). THE CURE (by_name_dispatch.c pl_parse_number, the one text-to-number entry):
# text with a non-ASCII byte is mapped to ASCII digits when every digit comes from ONE Unicode decimal block (Arabic-Indic, Extended
# Arabic-Indic, Devanagari, fullwidth ...) and the rest is a sign, '.', 'e', 'r' or '_'; a mix of blocks, a mix with ASCII digits, a radix
# prefix or layout fails, as swipl. And an integer with '_' between digits (1_000_000) is that integer outside --dialect=gnu; gprolog 1.6.0 has
# no digit groups, so under --dialect=gnu '1_2' is still no number (graded below against gplc).
# NOT GRADED: writeq quoting of such an atom (swipl writes '٠١٢', SCRIP ٠١٢), and the source reader's reading of unquoted Unicode digits
# (test_unicode's two read cases), which belongs with the bootstrap parsers' lexer.
# THE REFS ARE CUT FROM THE ORACLES, NEVER FROM SCRIP: the tables below were cut 2026-10-18 from /usr/bin/swipl and the pristine gplc build,
# and every run re-cuts them and REFUSES rc=2 when an oracle and its table disagree or an oracle is absent.
# FAIL-ONCE (CEO-1680): with the by_name_dispatch.c change reverted on the same tree, m3 and m4 both read FAIL (measured 2026-10-18).
# Usage: bash ../harness/scripts/test_gate_pl_a_number_in_unicode_digits_or_digit_groups_converts_as_swipl.sh
set -uo pipefail
GATE_NAME=test_gate_pl_a_number_in_unicode_digits_or_digit_groups_converts_as_swipl
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIP="$HERE/../../SCRIP/scrip"
OUT="${RT_DIR:-$HERE/../../SCRIP/out}"
SWIPL=/usr/bin/swipl
GPB=/home/resources/gprolog-mon/pristine/gprolog-1.6.0/bin
[ -x "$SCRIP" ] || { echo "⛔ REFUSED(2) [$GATE_NAME]: no scrip binary at $SCRIP -- run make first"; exit 2; }
[ -x "$SWIPL" ] || { echo "⛔ REFUSED(2) [$GATE_NAME]: no oracle at $SWIPL"; exit 2; }
[ -x "$GPB/gplc" ] || { echo "⛔ REFUSED(2) [$GATE_NAME]: no gprolog 1.6.0 gplc at $GPB"; exit 2; }
"$HERE/util_require_fresh.sh" --gate "$GATE_NAME" "$SCRIP" "$OUT/libscrip_rt.so" || exit 2
d=$(mktemp -d) || exit 2
trap 'rm -rf "$d"' EXIT
cat > "$d/w.pl" <<'PL'
:- initialization(main).
t(A) :- ( catch(atom_number(A, N), _, fail) -> writeq(N) ; writeq(no) ), nl.
main :- forall(member(A, ['٠١٢٣٤٥٦٧٨٩', '١2', '1٢', '١٢.٣٤', '-١٢', '+١٢', '١٢e٣', '١٢.٥e-٣', '١r٣', '۱۲', '١۲', '१२', '٠x١', ' ١٢', '١_٢', '１２',
                          '1_2', '1_000_000', '-1_0', '1_2.5', '12_', '_12']), t(A)),
        number_codes(C, `٠١٢٣٤٥٦٧٨٩`), writeq(C), nl,
        number_string(S1, "-١٢.٣٤٥٦٧e٨٩"), writeq(S1), nl,
        number_string(S2, "-١٢.٣٤٥٦٧e-٨٩"), writeq(S2), nl,
        halt.
PL
cat > "$d/want" <<'WANT'
123456789
no
no
12.34
-12
12
12000.0
0.0125
1r3
12
no
12
no
no
12
12
12
1000000
-10
no
no
no
123456789
-1.234567e+90
-1.234567e-88
WANT
cat > "$d/g.pl" <<'PL'
:- initialization(main).
main :- ( catch(atom_number('1_2', N), _, fail) -> write(N) ; write(no) ), nl, halt.
PL
printf 'no\n' > "$d/g.want"
(cd "$d" && timeout -k 5 30 "$SWIPL" -q w.pl </dev/null > w.oracle 2>/dev/null)
cmp -s "$d/want" "$d/w.oracle" || { echo "⛔ REFUSED(2) [$GATE_NAME]: the table is not what $SWIPL prints now"; diff "$d/want" "$d/w.oracle" | head -5; exit 2; }
(cd "$d" && PATH="$GPB:$PATH" timeout -k 5 60 gplc -o gb g.pl >/dev/null 2>&1 && timeout -k 5 30 ./gb </dev/null > g.oracle 2>/dev/null)
cmp -s "$d/g.want" "$d/g.oracle" || { echo "⛔ REFUSED(2) [$GATE_NAME]: the GNU table is not what gprolog 1.6.0 prints now"; diff "$d/g.want" "$d/g.oracle" | head -5; exit 2; }
fails=0; graded=0
grade() {
    local tag="$1" prog="$2" want="$3"; shift 3
    graded=$((graded + 1))
    (cd "$d" && timeout -k 5 30 "$SCRIP" "$@" "$prog" </dev/null 2>/dev/null > "$d/$tag.m3"); local rc=$?
    if [ $rc -ne 0 ] || ! cmp -s "$d/$want" "$d/$tag.m3"; then fails=$((fails + 1)); echo "  $tag m3 rc=$rc differs:"; diff "$d/$want" "$d/$tag.m3" | head -8; fi
    graded=$((graded + 1))
    if (cd "$d" && timeout -k 5 60 "$SCRIP" "$@" --compile --out="$tag.s" "$prog" </dev/null >/dev/null 2>&1 \
        && gcc -no-pie -o "$tag.bin" "$tag.s" -L"$OUT" -lscrip_rt -lm -Wl,-rpath,"$OUT" 2>/dev/null); then
        (cd "$d" && timeout -k 5 30 "./$tag.bin" </dev/null 2>/dev/null > "$d/$tag.m4"); rc=$?
        if [ $rc -ne 0 ] || ! cmp -s "$d/$want" "$d/$tag.m4"; then fails=$((fails + 1)); echo "  $tag m4 rc=$rc differs:"; diff "$d/$want" "$d/$tag.m4" | head -8; fi
    else fails=$((fails + 1)); echo "  $tag m4 did not compile or link"; fi
}
grade swi w.pl want
grade gnu g.pl g.want --dialect=gnu
echo "PLUNICODENUMBER_BOARD programs=2 modes=2 graded=$graded PASS=$((graded - fails)) FAIL=$fails"
[ $fails -eq 0 ] || exit 1
exit 0
