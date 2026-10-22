#!/usr/bin/env bash
# test_gate_pl_a_double_quoted_text_holding_code_0_keeps_its_length_in_all_four_double_quotes_modes.sh -- a "..." literal whose text holds code 0
# keeps its length under double_quotes = string, codes, chars and atom, in both modes (row prolog-swi-shim-forall-gate-test-utf8-86-of-94-under-its-
# floor-of-90-since-22f78bec7, hq_prolog 2026-10-22; the coo bisected the red to SCRIP 2c1f2d637, which carried the length of every ATOM and left the
# STRING literal on strlen: library/test_utf8 lost the eight instances whose text holds \u0000).
# WHAT IS GRADED: three literals ("\x00\", "a\x00\b", "\u0000azAZ09") read under each flag, printed as length-contents: string_length and
# string_codes (string), length and the code list (codes), length and the char list (chars), atom_length, the atom and atom_codes (atom).
# THE REFS ARE CUT FROM THE ORACLE, NEVER FROM SCRIP: the four expectation tables below were cut 2026-10-22 from /usr/bin/swipl by absolute path, and
# every run re-cuts all four from the live swipl and REFUSES rc=2 when the oracle and a table disagree or swipl is absent.
# FAIL-ONCE: on d84310ceb every program printed length 0 for the first literal and 1 for the second in m3 and m4 (the text stopped at its first code 0).
# Usage: bash ../harness/scripts/test_gate_pl_a_double_quoted_text_holding_code_0_keeps_its_length_in_all_four_double_quotes_modes.sh
set -uo pipefail
GATE_NAME=test_gate_pl_a_double_quoted_text_holding_code_0_keeps_its_length_in_all_four_double_quotes_modes
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIP="$HERE/../../SCRIP/scrip"
OUT="${RT_DIR:-$HERE/../../SCRIP/out}"
SWIPL=/usr/bin/swipl
[ -x "$SCRIP" ] || { echo "⛔ REFUSED(2) [$GATE_NAME]: no scrip binary at $SCRIP -- run make first"; exit 2; }
[ -x "$SWIPL" ] || { echo "⛔ REFUSED(2) [$GATE_NAME]: no oracle at $SWIPL"; exit 2; }
"$HERE/util_require_fresh.sh" --gate "$GATE_NAME" "$SCRIP" "$OUT/libscrip_rt.so" || exit 2
d=$(mktemp -d) || exit 2
trap 'rm -rf "$d"' EXIT
body_for() {
    case "$1" in
        string) echo 'forall(t(S), (string_length(S, L), string_codes(S, Cs), writeq(L-Cs), nl))' ;;
        codes|chars) echo 'forall(t(X), (length(X, L), writeq(L-X), nl))' ;;
        atom) echo 'forall(t(X), (atom_length(X, L), atom_codes(X, Cs), writeq(L-X-Cs), nl))' ;;
    esac
}
for w in string codes chars atom; do
    cat > "$d/$w.pl" <<PL
:- set_prolog_flag(double_quotes, $w).
t("\\x00\\").
t("a\\x00\\b").
t("\\u0000azAZ09").
:- initialization(main).
main :- $(body_for "$w"), halt.
PL
done
cat > "$d/string.want" <<'WANT'
1-[0]
3-[97,0,98]
7-[0,97,122,65,90,48,57]
WANT
cp "$d/string.want" "$d/codes.want"
cat > "$d/chars.want" <<'WANT'
1-['\x0\']
3-[a,'\x0\',b]
7-['\x0\',a,z,'A','Z','0','9']
WANT
cat > "$d/atom.want" <<'WANT'
1-'\x0\'-[0]
3-'a\x0\b'-[97,0,98]
7-'\x0\azAZ09'-[0,97,122,65,90,48,57]
WANT
fails=0; graded=0
for w in string codes chars atom; do
    "$SWIPL" -q -g main -t halt "$d/$w.pl" </dev/null > "$d/$w.oracle" 2>/dev/null
    cmp -s "$d/$w.want" "$d/$w.oracle" || { echo "⛔ REFUSED(2) [$GATE_NAME]: the $w expectation table is not what $SWIPL prints now"; diff "$d/$w.want" "$d/$w.oracle" | head -5; exit 2; }
    timeout -k 5 20 "$SCRIP" "$d/$w.pl" </dev/null 2>/dev/null > "$d/$w.m3"; rc=$?; graded=$((graded + 1))
    if [ $rc -ne 0 ] || ! cmp -s "$d/$w.want" "$d/$w.m3"; then fails=$((fails + 1)); echo "  $w m3 rc=$rc differs:"; diff "$d/$w.want" "$d/$w.m3" | head -10; fi
    graded=$((graded + 1))
    if timeout -k 5 60 "$SCRIP" --compile -o "$d/$w.s" "$d/$w.pl" </dev/null >/dev/null 2>&1 && as --64 -o "$d/$w.o" "$d/$w.s" 2>/dev/null \
        && gcc -no-pie -o "$d/$w.bin" "$d/$w.o" "$OUT/libscrip_rt.so" -lm -lstdc++ -Wl,-rpath,"$OUT" 2>/dev/null; then
        timeout -k 5 20 "$d/$w.bin" </dev/null 2>/dev/null > "$d/$w.m4"; rc=$?
        if [ $rc -ne 0 ] || ! cmp -s "$d/$w.want" "$d/$w.m4"; then fails=$((fails + 1)); echo "  $w m4 rc=$rc differs:"; diff "$d/$w.want" "$d/$w.m4" | head -10; fi
    else fails=$((fails + 1)); echo "  $w m4 did not compile or link"; fi
done
echo "PLDQNUL_BOARD programs=4 modes=2 graded=$graded PASS=$((graded - fails)) FAIL=$fails"
[ $fails -eq 0 ] || exit 1
exit 0
