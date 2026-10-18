#!/usr/bin/env bash
# test_gate_pl_writeq_brackets_a_declaration_atom_as_swipl_in_the_iso_default_and_as_gprolog_in_the_gnu_dialect.sh -- writeq of the declaration atoms
# (public, dynamic, discontiguous, initialization, module, multifile, meta_predicate, table, not) as operands, m3 and m4 (cfo 2026-10-18, row
# prolog-writeq-brackets-the-swi-declaration-atoms-its-own-current-op-does-not-list-public-dynamic-table-not).
# TWO ORACLES, ONE PER DIALECT (CEO-1536: the ISO default is graded by swipl, and SWI wins a conflict; --dialect=gnu is gprolog's):
# (1) THE ISO DEFAULT, against swipl 9.0.4 on terms BUILT with =.. (swipl cannot read the unbracketed form -- these are its operators): swipl brackets
#     eight of the nine, and writes module and not bare. prolog_atom.c op_cols_fill seeded module as fx 1150 for the writer, so SCRIP wrote
#     ((module),4) and - (module); swipl 9.0.4 has no module operator. The seed is gone.
# (2) THE GNU DIALECT, against gprolog 1.6.0 on the row's own witness (unbracketed, which gprolog reads): none of the nine is a GNU operator, and
#     the writer hides its seeded columns under --dialect=gnu (SCRIP 6a58680d6).
# THE REFS ARE CUT FROM THE ORACLES, NEVER FROM SCRIP: both tables were cut 2026-10-18 (swipl from /usr/bin/swipl, gprolog from the pristine
# gplc build), and every run re-cuts both and REFUSES rc=2 when an oracle and its table disagree or an oracle is absent.
# FAIL-ONCE (CEO-1680): with the module seed restored on the same tree, (1) read FAIL in both modes on its module line (measured 2026-10-18).
# Usage: bash ../harness/scripts/test_gate_pl_writeq_brackets_a_declaration_atom_as_swipl_in_the_iso_default_and_as_gprolog_in_the_gnu_dialect.sh
set -uo pipefail
GATE_NAME=test_gate_pl_writeq_brackets_a_declaration_atom_as_swipl_in_the_iso_default_and_as_gprolog_in_the_gnu_dialect
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
cat > "$d/iso.pl" <<'PL'
:- initialization(main).
main :- forall(member(A, [public, dynamic, discontiguous, initialization, module, multifile, meta_predicate, table, not]),
               ((X =.. [',', A, 4], Y =.. [-, A], writeq(X-Y)), nl)), halt.
PL
cat > "$d/iso.want" <<'WANT'
((public),4)- - (public)
((dynamic),4)- - (dynamic)
((discontiguous),4)- - (discontiguous)
((initialization),4)- - (initialization)
(module,4)- -module
((multifile),4)- - (multifile)
((meta_predicate),4)- - (meta_predicate)
((table),4)- - (table)
(not,4)- -not
WANT
cat > "$d/gnu.pl" <<'PL'
:- initialization(main).
main :- writeq([(public,4),(dynamic,1),(discontiguous,2),(initialization,3),(module,5),(multifile,6),(meta_predicate,7),(table,8),(not,9),- (table),- (dynamic)]), nl,
        ( current_op(P, T, public) -> writeq(P-T) ; write(no_op) ), nl, halt.
PL
cat > "$d/gnu.want" <<'WANT'
[(public,4),(dynamic,1),(discontiguous,2),(initialization,3),(module,5),(multifile,6),(meta_predicate,7),(table,8),(not,9),-table,-dynamic]
no_op
WANT
(cd "$d" && timeout -k 5 30 "$SWIPL" -q iso.pl </dev/null > iso.oracle 2>/dev/null)
cmp -s "$d/iso.want" "$d/iso.oracle" || { echo "⛔ REFUSED(2) [$GATE_NAME]: the ISO table is not what $SWIPL prints now"; diff "$d/iso.want" "$d/iso.oracle" | head -5; exit 2; }
(cd "$d" && PATH="$GPB:$PATH" timeout -k 5 60 gplc -o g gnu.pl >/dev/null 2>&1 && timeout -k 5 30 ./g </dev/null > gnu.oracle 2>/dev/null)
cmp -s "$d/gnu.want" "$d/gnu.oracle" || { echo "⛔ REFUSED(2) [$GATE_NAME]: the GNU table is not what gprolog 1.6.0 prints now"; diff "$d/gnu.want" "$d/gnu.oracle" | head -5; exit 2; }
fails=0; graded=0
grade() {
    local tag="$1" prog="$2" want="$3"; shift 3
    graded=$((graded + 1))
    (cd "$d" && timeout -k 5 30 "$SCRIP" "$@" "$prog" </dev/null 2>/dev/null > "$d/$tag.m3"); local rc=$?
    if [ $rc -ne 0 ] || ! cmp -s "$d/$want" "$d/$tag.m3"; then fails=$((fails + 1)); echo "  $tag m3 rc=$rc differs:"; diff "$d/$want" "$d/$tag.m3" | head -6; fi
    graded=$((graded + 1))
    if (cd "$d" && timeout -k 5 60 "$SCRIP" "$@" --compile -o "$tag.s" "$prog" </dev/null >/dev/null 2>&1 \
        && gcc -no-pie -o "$tag.bin" "$tag.s" -L"$OUT" -lscrip_rt -lm -Wl,-rpath,"$OUT" 2>/dev/null); then
        (cd "$d" && timeout -k 5 30 "./$tag.bin" </dev/null 2>/dev/null > "$d/$tag.m4"); rc=$?
        if [ $rc -ne 0 ] || ! cmp -s "$d/$want" "$d/$tag.m4"; then fails=$((fails + 1)); echo "  $tag m4 rc=$rc differs:"; diff "$d/$want" "$d/$tag.m4" | head -6; fi
    else fails=$((fails + 1)); echo "  $tag m4 did not compile or link"; fi
}
grade iso iso.pl iso.want
grade gnu gnu.pl gnu.want --dialect=gnu
echo "PLWRITEQDECLATOMS_BOARD programs=2 modes=2 graded=$graded PASS=$((graded - fails)) FAIL=$fails"
[ $fails -eq 0 ] || exit 1
exit 0
