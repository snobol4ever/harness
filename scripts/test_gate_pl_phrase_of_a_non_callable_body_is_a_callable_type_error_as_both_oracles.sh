#!/usr/bin/env bash
# test_gate_pl_phrase_of_a_non_callable_body_is_a_callable_type_error_as_both_oracles.sh -- phrase/2 and phrase/3 of a body that is neither a
# variable, a list, a string nor callable (a number) raise type_error(callable, Body), as ISO 8.1.1.3, swipl 9.0.4 and gprolog 1.6.0 all do,
# m3 and m4, in the ISO default and under --dialect=gnu (cfo 2026-10-18; swi core/test_dcg phrase:iso_8_1_1_3_OPEN#2).
# THE DEFECT: the built-in prelude's '$dcg_body' (prolog_parse.c) sent every remaining body to its non-terminal clause, NT =.. L0 then G =.. L1,
# and =.. with a number as the functor raised type_error(atom, 27). A clause before it now refuses a non-callable body as callable.
# THE REFS ARE CUT FROM THE ORACLES, NEVER FROM SCRIP: the table was cut 2026-10-18 and every run re-cuts it from /usr/bin/swipl and from the
# pristine gplc build, and REFUSES rc=2 when either disagrees with it or is absent.
# FAIL-ONCE (CEO-1680): with the new '$dcg_body' clause removed on the same tree, the ISO-default program read FAIL in both modes (measured
# 2026-10-18, type_error(atom,...) on all three lines).
# Usage: bash ../harness/scripts/test_gate_pl_phrase_of_a_non_callable_body_is_a_callable_type_error_as_both_oracles.sh
set -uo pipefail
GATE_NAME=test_gate_pl_phrase_of_a_non_callable_body_is_a_callable_type_error_as_both_oracles
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
main :- forall(member(G, [phrase(27, [], []), phrase(27, []), phrase(1.5, [], [])]), (catch((call(G) -> R = yes ; R = no), error(E, _), R = E), writeq(R), nl)), halt.
PL
cat > "$d/want" <<'WANT'
type_error(callable,27)
type_error(callable,27)
type_error(callable,1.5)
WANT
(cd "$d" && timeout -k 5 30 "$SWIPL" -q w.pl </dev/null > s.oracle 2>/dev/null)
cmp -s "$d/want" "$d/s.oracle" || { echo "⛔ REFUSED(2) [$GATE_NAME]: the table is not what $SWIPL prints now"; diff "$d/want" "$d/s.oracle" | head -5; exit 2; }
(cd "$d" && PATH="$GPB:$PATH" timeout -k 5 60 gplc -o gb w.pl >/dev/null 2>&1 && timeout -k 5 30 ./gb </dev/null > g.oracle 2>/dev/null)
cmp -s "$d/want" "$d/g.oracle" || { echo "⛔ REFUSED(2) [$GATE_NAME]: the table is not what gprolog 1.6.0 prints now"; diff "$d/want" "$d/g.oracle" | head -5; exit 2; }
fails=0; graded=0
grade() {
    local tag="$1"; shift
    graded=$((graded + 1))
    (cd "$d" && timeout -k 5 30 "$SCRIP" "$@" w.pl </dev/null 2>/dev/null > "$d/$tag.m3"); local rc=$?
    if [ $rc -ne 0 ] || ! cmp -s "$d/want" "$d/$tag.m3"; then fails=$((fails + 1)); echo "  $tag m3 rc=$rc differs:"; diff "$d/want" "$d/$tag.m3" | head -6; fi
    graded=$((graded + 1))
    if (cd "$d" && timeout -k 5 60 "$SCRIP" "$@" --compile --out="$tag.s" w.pl </dev/null >/dev/null 2>&1 \
        && gcc -no-pie -o "$tag.bin" "$tag.s" -L"$OUT" -lscrip_rt -lm -Wl,-rpath,"$OUT" 2>/dev/null); then
        (cd "$d" && timeout -k 5 30 "./$tag.bin" </dev/null 2>/dev/null > "$d/$tag.m4"); rc=$?
        if [ $rc -ne 0 ] || ! cmp -s "$d/want" "$d/$tag.m4"; then fails=$((fails + 1)); echo "  $tag m4 rc=$rc differs:"; diff "$d/want" "$d/$tag.m4" | head -6; fi
    else fails=$((fails + 1)); echo "  $tag m4 did not compile or link"; fi
}
grade iso
grade gnu --dialect=gnu
echo "PLPHRASECALLABLE_BOARD programs=1 dialects=2 modes=2 graded=$graded PASS=$((graded - fails)) FAIL=$fails"
[ $fails -eq 0 ] || exit 1
exit 0
