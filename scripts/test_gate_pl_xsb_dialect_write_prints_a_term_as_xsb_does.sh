#!/usr/bin/env bash
# test_gate_pl_xsb_dialect_write_prints_a_term_as_xsb_does.sh -- THE XSB DIALECT WRITES A TERM IN XSB'S OWN STYLE (hq_packages 2026-10-28, CEO-1927: XSB 5.0.0 is the oracle of packages/prolog/xsb_tests).
# XSB 5.0.0 writes every infix operator spaced (a + b, a = b, a : b, X is Y) except the comma and the semicolon (a,b and a;b); a term of priority above 1000 under write/1 and writeq/1
# is parenthesized ((a :- b), (a;b), (a --> b), (dynamic a)) where the comma term is not (a,b), and under writeln/1 and write_term(T, [priority(999)]) the comma term is too ((a,b));
# a prefix operator is followed by a space (- a, \+ a, - (1 + 2), - 1 for -(1) under write and - (1) under writeq); writeq wraps an operator atom that is a compound's argument
# (f((-)), f((:-),a)) and quotes '{}' and ';' as atoms; write_canonical writes functional form with lists as lists (+(a,b), [a|b], '{}'(+(a,b)), ';'(a,b)). SCRIP's SWI-style compact
# writer printed a+b, a:-b, a=b in the XSB dialect, which failed every XSB entry whose ref carries a spaced operator (238 of the 549 refs have one; table_tests_abol_test3 prints (f(1),a)).
# THE WITNESS corpus/tests/prolog/xsb_writer/xwr01_operators.P writes 95 terms through write, writeln, writeq and write_canonical; its ref is XSB's own temp file (gentest protocol).
# ARMS: (1) ORACLE: the stored ref is exactly what live XSB 5.0.0 writes (an XSB that cannot run REFUSES rc 2; one that disagrees reds the gate: the ref is stale)
#       (2) m3 and (3) m4: SCRIP's stdout under the xsb package prelude equals the ref byte for byte (the first differing line is named)
#       (4) CAN FAIL: the same comparison against a ref with one line changed reads RED
# RED BEFORE (measured 2026-10-28 on SCRIP 96beddbdd, the tree before the cure): 226 of the 380 labelled lines differed (m3 and m4 both red) (a+b for a + b, a:-b for (a :- b), a,b for (a,b) under writeln, f(-) for f((-)), '.'(a,[]) for [a]).
# rc 0 all arms; rc 1 an arm red; rc 2 could not measure (no binary, stale binary, no XSB, no witness).
set -u
GATE_NAME=test_gate_pl_xsb_dialect_write_prints_a_term_as_xsb_does
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIP="$HERE/../../SCRIP/scrip"
RT="${RT_DIR:-$HERE/../../SCRIP/out}"
WIT="$HERE/../../corpus/tests/prolog/xsb_writer"
PRELUDE="$HERE/../../corpus/packages/prolog/xsb_tests/ALL.prelude"
refuse() { echo "⛔ REFUSED(2) [$GATE_NAME]: $*" >&2; exit 2; }
[ -x "$SCRIP" ] || refuse "no scrip binary at $SCRIP -- run make first"
[ -f "$WIT/xwr01_operators.P" ] && [ -f "$WIT/xwr01_operators.ref" ] || refuse "no witness at $WIT (xwr01_operators.P, xwr01_operators.ref)"
[ -f "$PRELUDE" ] || refuse "no package prelude at $PRELUDE"
. "$HERE/lib_oracle_flags.sh" || refuse "lib_oracle_flags.sh is missing"
XSB="$(xsb_bin)" || refuse "the XSB oracle accessor refused"
[ -x "$XSB" ] || refuse "XSB is not executable: $XSB"
"$HERE/util_require_fresh.sh" --gate "$GATE_NAME" "$SCRIP" "$RT/libscrip_rt.so" || exit 2
MODES="${PL_RUNG_MODES:-m3,m4}"
TMPD="$(mktemp -d)"; trap 'rm -rf "$TMPD"' EXIT
red=0; total=0
REF="$WIT/xwr01_operators.ref"
PRE="$(grep -v '^#' "$PRELUDE" | grep -v '^$')"
{ printf '%s\n' "$PRE"; cat "$WIT/xwr01_operators.P"; printf ':- initialization((test, halt)).\n'; } > "$TMPD/run.pl"
verdict() { # $1 name, $2 got file, $3 ref file
    total=$((total+1))
    if cmp -s "$2" "$3"; then echo "  ok  $1"
    else local n; n="$(diff "$3" "$2" | grep -c '^<')"; echo "  RED $1: $n ref line(s) differ; first: $(diff "$3" "$2" | grep -m1 '^[<>]' | cut -c1-120)"; red=$((red+1)); fi
}
# (1) ORACLE
cp "$WIT/xwr01_operators.P" "$TMPD/xwr01_operators.P"
( cd "$TMPD" && rm -f temp && printf '[xwr01_operators].\ntell(temp).\ntest.\ntold.\nhalt.\n' | timeout -k 5 120 "$XSB" --nobanner --quietload > xsb.log 2>&1 )
[ -s "$TMPD/temp" ] || refuse "XSB wrote no temp file for the witness: $(head -c 300 "$TMPD/xsb.log")"
verdict "the stored ref is what live XSB 5.0.0 writes" "$TMPD/temp" "$REF"
# (2) m3 and (3) m4
case "$MODES" in *m3*) ( cd "$TMPD" && timeout -k 5 120 "$SCRIP" run.pl </dev/null > "$TMPD/m3.out" 2> "$TMPD/m3.err" ); verdict "SCRIP m3 writes the witness as XSB does" "$TMPD/m3.out" "$REF" ;; esac
case "$MODES" in *m4*)
    if ( cd "$TMPD" && timeout -k 5 240 "$SCRIP" --compile -o run.s run.pl </dev/null > /dev/null 2> m4.cerr ) && gcc -m64 -no-pie "$TMPD/run.s" -o "$TMPD/run.bin" -L"$RT" -lscrip_rt -Wl,-rpath,"$RT" -lm 2> "$TMPD/m4.lerr"; then
        ( cd "$TMPD" && timeout -k 5 120 "$TMPD/run.bin" </dev/null > "$TMPD/m4.out" 2> "$TMPD/m4.err" ); verdict "SCRIP m4 writes the witness as XSB does" "$TMPD/m4.out" "$REF"
    else total=$((total+1)); red=$((red+1)); echo "  RED SCRIP m4 did not compile or link: $(head -c 200 "$TMPD/m4.cerr" "$TMPD/m4.lerr" 2>/dev/null)"; fi ;;
esac
# (4) CAN FAIL: one changed line in the ref must read red
sed '3s/.*/wq: not what XSB writes/' "$REF" > "$TMPD/ref_corrupt"
total=$((total+1))
if cmp -s "$TMPD/temp" "$TMPD/ref_corrupt"; then echo "  RED CAN FAIL: a corrupted ref read equal to XSB's output"; red=$((red+1)); else echo "  ok  CAN FAIL: a ref with one changed line reads red against XSB's output"; fi
echo "$GATE_NAME: arms=$total red=$red modes=$MODES"
[ "$red" -eq 0 ] || { echo "⛔ $GATE_NAME RED"; exit 1; }
echo "✅ $GATE_NAME GREEN"
