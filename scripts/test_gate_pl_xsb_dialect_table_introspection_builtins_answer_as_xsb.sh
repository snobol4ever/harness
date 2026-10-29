#!/usr/bin/env bash
# test_gate_pl_xsb_dialect_table_introspection_builtins_answer_as_xsb.sh -- THE XSB TABLE INTROSPECTION BUILTINS ANSWER AS XSB 5.0.0 DOES (hq_packages 2026-10-28, DESIGN-PLAN xsb-tabling-wfs step 5,
# ARCH-PROLOG-WFS-TABLING.md section 8 R12; CEO-1927: XSB 5.0.0 is the oracle of packages/prolog/xsb_tests). SCRIP's tabling library had get_calls/3, get_call/3 and get_returns_and_dls/3 but
# not XSB syslib/tables.P's table_state/4, truth_value/2, variant_get_residual/2, get_calls_for_table/2, abolish_table_subgoal/1,2, abolish_nonincremental_tables/0,1 and delete_return/2,3: a program
# naming one raised existence_error and the driver swallowed it (table_tests_get_resid, prolog_tests_std1 printed nothing). library(xsb_tables) now defines them over the table tries.
# THE WITNESS corpus/tests/prolog/xsb_tables/xtb01_introspection.P asks table_state/4 of an untabled, a tabled-without-table, a variant-table and a non-variant call (XSB: (undefined,undefined,undefined),
# (variant,no_entry,undefined), (variant,producer,complete), (variant,no_entry,undefined)), truth_value/2 of tabled, plain and undefined-valued goals, variant_get_residual/2 of an unconditional and a
# conditional answer, and get_calls_for_table/2 of a tabled and a plain predicate (a permission_error); its ref is XSB's own temp file (gentest protocol).
# ARMS: (1) ORACLE: the stored ref is exactly what live XSB 5.0.0 writes (an XSB that cannot run REFUSES rc 2; one that disagrees reds the gate: the ref is stale)
#       (2) m3 and (3) m4: SCRIP's stdout under the xsb package prelude equals the ref byte for byte (the first differing line is named)
#       (4) CAN FAIL: the same comparison against a ref with one line changed reads RED
# RED BEFORE (measured 2026-10-28 on SCRIP 5f1224122, the tree before the cure): table_state/4, truth_value/2, variant_get_residual/2 and get_calls_for_table/2 raised existence_error, so the witness printed
# err(existence_error(procedure, ...)) lines and test_design_xsb_tabling_wfs_steps.sh --step 5 read entries=0/3.
# rc 0 all arms; rc 1 an arm red; rc 2 could not measure (no binary, stale binary, no XSB, no witness).
set -u
GATE_NAME=test_gate_pl_xsb_dialect_table_introspection_builtins_answer_as_xsb
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIP="$HERE/../../SCRIP/scrip"
RT="${RT_DIR:-$HERE/../../SCRIP/out}"
WIT="$HERE/../../corpus/tests/prolog/xsb_tables"
PRELUDE="$HERE/../../corpus/packages/prolog/xsb_tests/ALL.prelude"
refuse() { echo "⛔ REFUSED(2) [$GATE_NAME]: $*" >&2; exit 2; }
[ -x "$SCRIP" ] || refuse "no scrip binary at $SCRIP -- run make first"
WITNESSES="xtb01_introspection"
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
    case "$MODES" in *m3*) ( cd "$d" && timeout -k 5 120 "$SCRIP" run.pl </dev/null > m3.out 2> m3.err ); verdict "$w: SCRIP m3 answers what XSB answers" "$d/m3.out" "$WIT/$w.ref" ;; esac
    case "$MODES" in *m4*)
        if ( cd "$d" && timeout -k 5 240 "$SCRIP" --compile --out=run.s run.pl </dev/null > /dev/null 2> m4.cerr ) && gcc -m64 -no-pie "$d/run.s" -o "$d/run.bin" -L"$RT" -lscrip_rt -Wl,-rpath,"$RT" -lm 2> "$d/m4.lerr"; then
            ( cd "$d" && timeout -k 5 120 "$d/run.bin" </dev/null > m4.out 2> m4.err ); verdict "$w: SCRIP m4 answers what XSB answers" "$d/m4.out" "$WIT/$w.ref"
        else total=$((total+1)); red=$((red+1)); echo "  RED $w: SCRIP m4 did not compile or link: $(head -c 200 "$d/m4.cerr" "$d/m4.lerr" 2>/dev/null)"; fi ;;
    esac
done
sed '1s/.*/not what XSB writes/' "$WIT/xtb01_introspection.ref" > "$TMPD/ref_corrupt"
total=$((total+1))
if cmp -s "$TMPD/xtb01_introspection/temp" "$TMPD/ref_corrupt"; then echo "  RED CAN FAIL: a corrupted ref read equal to XSB's output"; red=$((red+1)); else echo "  ok  CAN FAIL: a ref with one changed line reads red against XSB's output"; fi
echo "$GATE_NAME: arms=$total red=$red modes=$MODES"
[ "$red" -eq 0 ] || { echo "⛔ $GATE_NAME RED"; exit 1; }
echo "✅ $GATE_NAME GREEN"
