#!/usr/bin/env bash
# test_gate_pl_set_locale_publishes_its_properties_and_the_colon_directives_of_format_group_by_them_as_swipl.sh -- set_locale/1 on a locale made by
# locale_create/3 changes how format/3's ~:d and ~N:f group digits, and the old locale comes back, as swipl 9.0.4 does, m3 and m4 (hq_prolog
# 2026-11-04, swi core/test_locale group#85..92, 90 -> 98 of 98 in both modes). THE CURE (prolog_parse.c, the base prelude's set_locale/1): it
# publishes decimal_point, thousands_sep and grouping as the hidden flags $loc_dp, $loc_ts and $loc_grp that the C formatter reads through
# rt_pl_flag_text, and it called '$create_prolog_flag'/2 after 0a5305bac made that leaf /4 (Name, Value, Type, Access): every set_locale/1 raised
# existence_error('$create_prolog_flag'/2) and left '$cur_locale' set to the half-made locale.
# THE REF IS CUT FROM THE ORACLE, NEVER FROM SCRIP: the table below was cut 2026-11-04 from /usr/bin/swipl, and every run re-cuts it and REFUSES
# rc=2 when the oracle and the table disagree or the oracle is absent. Each answer is printed as its code list, so no output encoding is in play.
# FAIL-ONCE (CEO-1680): on the tree before the cure (origin dbff12a1d) m3 and m4 both read FAIL, every locale line an existence_error.
# Usage: bash ../harness/scripts/test_gate_pl_set_locale_publishes_its_properties_and_the_colon_directives_of_format_group_by_them_as_swipl.sh
set -uo pipefail
GATE_NAME=test_gate_pl_set_locale_publishes_its_properties_and_the_colon_directives_of_format_group_by_them_as_swipl
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIP="$HERE/../../SCRIP/scrip"
OUT="${RT_DIR:-$HERE/../../SCRIP/out}"
SWIPL=/usr/bin/swipl
[ -x "$SCRIP" ] || { echo "⛔ REFUSED(2) [$GATE_NAME]: no scrip binary at $SCRIP -- run make first"; exit 2; }
[ -x "$SWIPL" ] || { echo "⛔ REFUSED(2) [$GATE_NAME]: no oracle at $SWIPL"; exit 2; }
"$HERE/util_require_fresh.sh" --gate "$GATE_NAME" "$SCRIP" "$OUT/libscrip_rt.so" || exit 2
d=$(mktemp -d) || exit 2
trap 'rm -rf "$d"' EXIT
cat > "$d/w.pl" <<'PL'
:- initialization(main).
fwl(Out, Fmt, Args, Props) :- current_locale(Old), locale_create(Tmp, Old, Props), setup_call_cleanup(set_locale(Tmp), format(Out, Fmt, Args), set_locale(Old)).
t(Fmt, Args, Props) :- ( catch(fwl(atom(A), Fmt, Args, Props), E, (writeq(ex(E)), nl, fail)) -> atom_codes(A, Cs), writeq(Cs) ; writeq(failed) ), nl.
main :-
    t('~:d', [123456789], [grouping([2,2])]),
    t('~2:d', [123456789], [grouping([2,2])]),
    t('~:d', [123456789], [grouping([2,2,repeat(3)])]),
    t('~2:d', [123456789], [decimal_point(','), thousands_sep('.')]),
    t('~2:d', [123456789], [decimal_point(','), thousands_sep(' ')]),
    t('~2:d', [123456789], [decimal_point(','), thousands_sep('. ')]),
    t('~2:f', [1234567.89], [decimal_point(','), thousands_sep(' ')]),
    t('~2:f', [1234567.89], [decimal_point(','), thousands_sep('. ')]),
    t('~:d', [-1234567], [thousands_sep(' ')]),
    t('~:d', [1234567], [grouping([3]), thousands_sep(',')]),
    current_locale(L), writeq(L), nl,
    format(atom(A), '~:d', [1234567]), writeq(A), nl,
    format(atom(B), '~D', [1234567]), writeq(B), nl,
    halt.
PL
cat > "$d/want" <<'WANT'
[49,50,51,52,53,44,54,55,44,56,57]
[49,50,51,44,52,53,44,54,55,46,56,57]
[49,50,44,51,52,53,44,54,55,44,56,57]
[49,46,50,51,52,46,53,54,55,44,56,57]
[49,8201,50,51,52,8201,53,54,55,44,56,57]
[49,46,8201,50,51,52,46,8201,53,54,55,44,56,57]
[49,8201,50,51,52,8201,53,54,55,44,56,57]
[49,46,8201,50,51,52,46,8201,53,54,55,44,56,57]
[45,49,32,50,51,52,32,53,54,55]
[49,50,51,52,44,53,54,55]
default
'1,234,567'
'1,234,567'
WANT
(cd "$d" && timeout -k 5 30 "$SWIPL" -q w.pl </dev/null > w.oracle 2>/dev/null)
cmp -s "$d/want" "$d/w.oracle" || { echo "⛔ REFUSED(2) [$GATE_NAME]: the table is not what $SWIPL prints now"; diff "$d/want" "$d/w.oracle" | head -5; exit 2; }
fails=0; graded=1
(cd "$d" && timeout -k 5 30 "$SCRIP" w.pl </dev/null 2>/dev/null > "$d/w.m3"); rc=$?
if [ $rc -ne 0 ] || ! cmp -s "$d/want" "$d/w.m3"; then fails=$((fails + 1)); echo "  m3 rc=$rc differs:"; diff "$d/want" "$d/w.m3" | head -8; fi
graded=2
if (cd "$d" && timeout -k 5 60 "$SCRIP" --compile --out=w.s w.pl </dev/null >/dev/null 2>&1 \
    && gcc -no-pie -o w.bin w.s -L"$OUT" -lscrip_rt -lm -Wl,-rpath,"$OUT" 2>/dev/null); then
    (cd "$d" && timeout -k 5 30 ./w.bin </dev/null 2>/dev/null > "$d/w.m4"); rc=$?
    if [ $rc -ne 0 ] || ! cmp -s "$d/want" "$d/w.m4"; then fails=$((fails + 1)); echo "  m4 rc=$rc differs:"; diff "$d/want" "$d/w.m4" | head -8; fi
else fails=$((fails + 1)); echo "  m4 did not compile or link"; fi
echo "PLSETLOCALFORMAT_BOARD programs=1 modes=2 graded=$graded PASS=$((graded - fails)) FAIL=$fails"
[ $fails -eq 0 ] || { echo "GATE FAIL [$GATE_NAME]"; exit 1; }
echo "GATE OK [$GATE_NAME]"
exit 0
