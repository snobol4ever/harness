#!/usr/bin/env bash
# test_gate_pl_xsb_dialect_auto_table_and_suppl_table_table_the_predicates_xsb_tables.sh -- THE XSB COMPILER DIRECTIVES auto_table AND suppl_table TABLE THE PREDICATES XSB TABLES (hq_packages 2026-10-28,
# DESIGN-PLAN xsb-tabling-wfs step 4, ARCH-PROLOG-WFS-TABLING.md section 8 R4; CEO-1927: XSB 5.0.0 is the oracle of packages/prolog/xsb_tests).
# XSB's compiler (cmplib/tabdef.P, suppltab.P) runs these at compile time: auto_table tables (1) the predicate named by the goal argument of tnot/1, tfindall/3, tbagof/3, tsetof/3, (2) every directly
# recursive predicate that no :- mode declaration proves terminating (a '+' argument that is a variable of the head's structure), (3) then one predicate of every remaining loop of the call graph (the one
# in most loops, then an exported one, then of smaller arity, then the first); suppl_table(N) tables a predicate whose clause has an edb-dependency of N or more (and sums, or takes the maximum, if-then
# sums; a tabled or edb predicate counts 1). SCRIP's lower now computes the same sets and renames them as a :- table declaration does; before, both directives ran as goals (existence warning) and the
# untabled left recursion overflowed the stack.
# THE WITNESSES corpus/tests/prolog/xsb_auto_table/xat01_auto_table.P (the manual's example, a three-cycle, tnot) and xat02_suppl_table.P (ten clause shapes) print predicate_property(Head, tabled) for each
# predicate; each ref is XSB's own temp file (gentest protocol).
# ARMS: (1) ORACLE: each stored ref is exactly what live XSB 5.0.0 writes (an XSB that cannot run REFUSES rc 2; one that disagrees reds the gate: the ref is stale)
#       (2) m3 and (3) m4: SCRIP's stdout under the xsb package prelude equals each ref byte for byte (the first differing line is named)
#       (4) CAN FAIL: the same comparison against a ref with one line changed reads RED
# RED BEFORE (measured 2026-10-28 on SCRIP 96beddbdd + the writer landing, the tree before the cure): predicate_property never reported tabled, so 5 of 12 lines of xat01 and 6 of 10 of xat02 differed in both modes;
# and the step witnesses xw04/xw05 read RED (test_design_xsb_tabling_wfs_steps.sh --step 4: m3 0/2 m4 0/2 entries 0/4).
# rc 0 all arms; rc 1 an arm red; rc 2 could not measure (no binary, stale binary, no XSB, no witness).
set -u
GATE_NAME=test_gate_pl_xsb_dialect_auto_table_and_suppl_table_table_the_predicates_xsb_tables
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIP="$HERE/../../SCRIP/scrip"
RT="${RT_DIR:-$HERE/../../SCRIP/out}"
WIT="$HERE/../../corpus/tests/prolog/xsb_auto_table"
PRELUDE="$HERE/../../corpus/packages/prolog/xsb_tests/ALL.prelude"
refuse() { echo "⛔ REFUSED(2) [$GATE_NAME]: $*" >&2; exit 2; }
[ -x "$SCRIP" ] || refuse "no scrip binary at $SCRIP -- run make first"
WITNESSES="xat01_auto_table xat02_suppl_table"
for w in $WITNESSES; do [ -f "$WIT/$w.P" ] && [ -f "$WIT/$w.ref" ] || refuse "no witness at $WIT ($w.P, $w.ref)"; done
[ -f "$PRELUDE" ] || refuse "no package prelude at $PRELUDE"
. "$HERE/lib_oracle_flags.sh" || refuse "lib_oracle_flags.sh is missing"
XSB="$(xsb_bin)" || refuse "the XSB oracle accessor refused"
[ -x "$XSB" ] || refuse "XSB is not executable: $XSB"
"$HERE/util_require_fresh.sh" --gate "$GATE_NAME" "$SCRIP" "$RT/libscrip_rt.so" || exit 2
MODES="${PL_RUNG_MODES:-m3,m4}"
TMPD="$(mktemp -d)"; trap 'rm -rf "$TMPD"' EXIT
red=0; total=0
PRE="$(grep -v '^#' "$PRELUDE" | grep -v '^$')"
verdict() { # $1 name, $2 got file, $3 ref file
    total=$((total+1))
    if cmp -s "$2" "$3"; then echo "  ok  $1"
    else echo "  RED $1: $(diff "$3" "$2" | grep -c '^<') ref line(s) differ; first: $(diff "$3" "$2" | grep -m1 '^[<>]' | cut -c1-120)"; red=$((red+1)); fi
}
for w in $WITNESSES; do
    d="$TMPD/$w"; mkdir -p "$d"; cp "$WIT/$w.P" "$d/$w.P"
    { printf '%s\n' "$PRE"; cat "$WIT/$w.P"; printf ':- initialization((test, halt)).\n'; } > "$d/run.pl"
    ( cd "$d" && rm -f temp && printf '[%s].\ntell(temp).\ntest.\ntold.\nhalt.\n' "$w" | timeout -k 5 120 "$XSB" --nobanner --quietload > xsb.log 2>&1 )
    [ -s "$d/temp" ] || refuse "XSB wrote no temp file for $w: $(head -c 300 "$d/xsb.log")"
    verdict "$w: the stored ref is what live XSB 5.0.0 writes" "$d/temp" "$WIT/$w.ref"
    case "$MODES" in *m3*) ( cd "$d" && timeout -k 5 120 "$SCRIP" run.pl </dev/null > m3.out 2> m3.err ); verdict "$w: SCRIP m3 tables what XSB tables" "$d/m3.out" "$WIT/$w.ref" ;; esac
    case "$MODES" in *m4*)
        if ( cd "$d" && timeout -k 5 240 "$SCRIP" --compile -o run.s run.pl </dev/null > /dev/null 2> m4.cerr ) && gcc -m64 -no-pie "$d/run.s" -o "$d/run.bin" -L"$RT" -lscrip_rt -Wl,-rpath,"$RT" -lm 2> "$d/m4.lerr"; then
            ( cd "$d" && timeout -k 5 120 "$d/run.bin" </dev/null > m4.out 2> m4.err ); verdict "$w: SCRIP m4 tables what XSB tables" "$d/m4.out" "$WIT/$w.ref"
        else total=$((total+1)); red=$((red+1)); echo "  RED $w: SCRIP m4 did not compile or link: $(head -c 200 "$d/m4.cerr" "$d/m4.lerr" 2>/dev/null)"; fi ;;
    esac
done
sed '1s/.*/not what XSB writes/' "$WIT/xat01_auto_table.ref" > "$TMPD/ref_corrupt"
total=$((total+1))
if cmp -s "$TMPD/xat01_auto_table/temp" "$TMPD/ref_corrupt"; then echo "  RED CAN FAIL: a corrupted ref read equal to XSB's output"; red=$((red+1)); else echo "  ok  CAN FAIL: a ref with one changed line reads red against XSB's output"; fi
echo "$GATE_NAME: arms=$total red=$red modes=$MODES"
[ "$red" -eq 0 ] || { echo "⛔ $GATE_NAME RED"; exit 1; }
echo "✅ $GATE_NAME GREEN"
