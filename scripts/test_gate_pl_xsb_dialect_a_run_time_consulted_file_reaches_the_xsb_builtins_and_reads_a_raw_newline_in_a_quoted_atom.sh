#!/usr/bin/env bash
# test_gate_pl_xsb_dialect_a_run_time_consulted_file_reaches_the_xsb_builtins_and_reads_a_raw_newline_in_a_quoted_atom.sh -- A FILE THE PROGRAM CONSULTS AT RUN TIME CALLS XSB'S BUILTINS AND READS XSB'S
# QUOTED ATOMS (hq_packages 2026-10-29, ceo + cfo: sub_tests_decker, DESIGN-PLAN xsb-tabling-wfs step 10; CEO-1927: XSB 5.0.0 is the oracle of packages/prolog/xsb_tests). Two defects, one witness.
# (1) The compiler links a library predicate when the program text names it; a clause of the file the program consults at run time (sub_tests_Driver.pl's decker :- ..., load_dync(Data/decker_facts))
#     is not program text, so load_dync/1, term_depth/2, term_size/2, import/1 and the rest of xsb_builtins, xsb_dialect and xsb_ordsets were pruned and the call raised existence_error(procedure,
#     load_dync/1). A program of the XSB dialect that names a consult-family goal now keeps every export of those three libraries, as it already kept lists, apply and ordsets.
# (2) XSB reads a raw newline inside a quoted atom as a character (decker_facts.P holds 'Department of Social Science Informatics (S.W.I)<newline> Faculty of Psychology ...'); SCRIP's reader took the
#     layout as a syntax error (cannot_start_term) unless the text carried the SWI marker, and a data file carries none, so load_dync stopped at line 161 of 1141. Under the XSB dialect at run time the
#     reader now allows it.
# THE WITNESS corpus/tests/prolog/xsb_loader: xld01_loaded_file.P (the program: the XSB marker compiler_options/1 and test/0, which consults xld01_loader), xld01_loader.P (names load_dync, term_depth,
#     term_size, import and ord_setproduct, the program text names none of them) and xld01_data.P (three facts, the middle atom spans two lines); xld01_loaded_file.ref is XSB's own temp file (gentest protocol).
# ARMS: (1) ORACLE: the stored ref is exactly what live XSB 5.0.0 writes (an XSB that cannot run REFUSES rc 2; one that disagrees reds the gate: the ref is stale)
#       (2) m3 and (3) m4: SCRIP's stdout under the xsb package prelude equals the ref byte for byte (the first differing line is named)
#       (4) CAN FAIL: the same comparison against a ref with one line changed reads RED
# RED BEFORE (measured 2026-10-29 on SCRIP b364f719e with the two changes to prolog_parse.c reverted and rebuilt): m3 printed nothing and the error was existence_error(procedure, load_dync/1); with only
#     the first change in place it printed nothing and the error was syntax_error(cannot_start_term) from consult/1 at the data file's second fact.
# rc 0 all arms; rc 1 an arm red; rc 2 could not measure (no binary, stale binary, no XSB, no witness).
set -u
GATE_NAME=test_gate_pl_xsb_dialect_a_run_time_consulted_file_reaches_the_xsb_builtins_and_reads_a_raw_newline_in_a_quoted_atom
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIP="$HERE/../../SCRIP/scrip"
RT="${RT_DIR:-$HERE/../../SCRIP/out}"
WIT="$HERE/../../corpus/tests/prolog/xsb_loader"
PRELUDE="$HERE/../../corpus/packages/prolog/xsb_tests/ALL.prelude"
refuse() { echo "⛔ REFUSED(2) [$GATE_NAME]: $*" >&2; exit 2; }
[ -x "$SCRIP" ] || refuse "no scrip binary at $SCRIP -- run make first"
for f in xld01_loaded_file.P xld01_loaded_file.ref xld01_loader.P xld01_data.P; do [ -f "$WIT/$f" ] || refuse "no witness file $WIT/$f"; done
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
d="$TMPD/w"; mkdir -p "$d"; cp "$WIT"/xld01_*.P "$d/"
{ printf '%s\n' "$PRE"; cat "$WIT/xld01_loaded_file.P"; printf ':- initialization((test, halt)).\n'; } > "$d/run.pl"
mkdir -p "$TMPD/x"; cp "$WIT"/xld01_*.P "$TMPD/x/"
( cd "$TMPD/x" && rm -f temp && printf '[xld01_loaded_file].\ntell(temp).\ntest.\ntold.\nhalt.\n' | timeout -k 5 120 "$XSB" --nobanner --quietload > xsb.log 2>&1 )
[ -s "$TMPD/x/temp" ] || refuse "XSB wrote no temp file: $(head -c 300 "$TMPD/x/xsb.log")"
verdict "the stored ref is what live XSB 5.0.0 writes" "$TMPD/x/temp" "$WIT/xld01_loaded_file.ref"
case "$MODES" in *m3*) ( cd "$d" && timeout -k 5 300 "$SCRIP" run.pl </dev/null > m3.out 2> m3.err ); verdict "SCRIP m3: the consulted file calls XSB's builtins and reads its quoted atom" "$d/m3.out" "$WIT/xld01_loaded_file.ref" ;; esac
case "$MODES" in *m4*)
    if ( cd "$d" && timeout -k 5 300 "$SCRIP" --compile -o run.s run.pl </dev/null > /dev/null 2> m4.cerr ) && gcc -m64 -no-pie "$d/run.s" -o "$d/run.bin" -L"$RT" -lscrip_rt -Wl,-rpath,"$RT" -lm 2> "$d/m4.lerr"; then
        ( cd "$d" && timeout -k 5 300 "$d/run.bin" </dev/null > m4.out 2> m4.err ); verdict "SCRIP m4: the consulted file calls XSB's builtins and reads its quoted atom" "$d/m4.out" "$WIT/xld01_loaded_file.ref"
    else total=$((total+1)); red=$((red+1)); echo "  RED SCRIP m4 did not compile or link: $(head -c 200 "$d/m4.cerr" "$d/m4.lerr" 2>/dev/null)"; fi ;;
esac
sed '1s/.*/not what XSB writes/' "$WIT/xld01_loaded_file.ref" > "$TMPD/ref_corrupt"
total=$((total+1))
if cmp -s "$TMPD/x/temp" "$TMPD/ref_corrupt"; then echo "  RED CAN FAIL: a corrupted ref read equal to XSB's output"; red=$((red+1)); else echo "  ok  CAN FAIL: a ref with one changed line reads red against XSB's output"; fi
echo "$GATE_NAME: arms=$total red=$red modes=$MODES"
[ "$red" -eq 0 ] || { echo "⛔ $GATE_NAME RED"; exit 1; }
echo "✅ $GATE_NAME GREEN"
