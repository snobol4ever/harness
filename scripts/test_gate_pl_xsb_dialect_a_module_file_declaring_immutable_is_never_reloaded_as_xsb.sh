#!/usr/bin/env bash
# test_gate_pl_xsb_dialect_a_module_file_declaring_immutable_is_never_reloaded_as_xsb.sh -- A MODULE FILE THAT DECLARES :- immutable. IS NEVER RELOADED, AND AN IMMUTABLE FILE NEVER REPLACES A LOADED MODULE (hq_packages 2026-10-29, CEO-1927: XSB 5.0.0 is the oracle of
# packages/prolog/xsb_tests; the prolog_tests programs test_immutable and test_immutable2). XSB names a module by its file: [xld02_m] loaded again after the file changed replaces a regular module, but a module
# loaded from a file with :- immutable. stays, a later load of the same module name is ignored whatever the new file holds, and an immutable file loaded over a regular module is ignored. SCRIP's XSB loader
# ('$lf_install') re-installed every load and raised existence_error(procedure, immutable/0) for the directive; it records the module name (the file's base name) with its immutability now and skips the install.
# THE WITNESS corpus/tests/prolog/xsb_loader/xld02_immutable.P with five module files xld02_a to xld02_e copied over xld02_m.P / xld02_n.P by shell/1 as XSB's own tests do; xld02_immutable.ref is XSB's temp file.
# ARMS: (1) ORACLE: the stored ref is exactly what live XSB 5.0.0 writes (an XSB that cannot run REFUSES rc 2; one that disagrees reds the gate: the ref is stale)
#       (2) m3 and (3) m4: SCRIP's stdout under the xsb package prelude equals the ref byte for byte; (4) CAN FAIL: the same comparison against a ref with one line changed reads RED
# RED BEFORE (measured 2026-10-29, the one-file change to prolog_parse.c reverted and rebuilt): m3 and m4 both red, the reloads printed second(b), third(b) and sixth(e) lines the ref does not hold, and the
# directive raised existence_error(procedure, immutable/0).
# rc 0 all arms; rc 1 an arm red; rc 2 could not measure (no binary, stale binary, no XSB, no witness).
set -u
GATE_NAME=test_gate_pl_xsb_dialect_a_module_file_declaring_immutable_is_never_reloaded_as_xsb
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIP="$HERE/../../SCRIP/scrip"
RT="${RT_DIR:-$HERE/../../SCRIP/out}"
WIT="$HERE/../../corpus/tests/prolog/xsb_loader"
PRELUDE="$HERE/../../corpus/packages/prolog/xsb_tests/ALL.prelude"
refuse() { echo "⛔ REFUSED(2) [$GATE_NAME]: $*" >&2; exit 2; }
[ -x "$SCRIP" ] || refuse "no scrip binary at $SCRIP -- run make first"
for f in xld02_immutable.P xld02_immutable.ref xld02_a.P xld02_b.P xld02_c.P xld02_d.P xld02_e.P; do [ -f "$WIT/$f" ] || refuse "no witness file $WIT/$f"; done
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
d="$TMPD/w"; mkdir -p "$d"; cp "$WIT"/xld02_*.P "$d/"
{ printf '%s\n' "$PRE"; cat "$WIT/xld02_immutable.P"; printf ':- initialization((test, halt)).\n'; } > "$d/run.pl"
mkdir -p "$TMPD/x"; cp "$WIT"/xld02_*.P "$TMPD/x/"
( cd "$TMPD/x" && rm -f temp && printf '[xld02_immutable].\ntell(temp).\ntest.\ntold.\nhalt.\n' | timeout -k 5 120 "$XSB" --nobanner --quietload > xsb.log 2>&1 )
[ -s "$TMPD/x/temp" ] || refuse "XSB wrote no temp file: $(head -c 300 "$TMPD/x/xsb.log")"
verdict "the stored ref is what live XSB 5.0.0 writes" "$TMPD/x/temp" "$WIT/xld02_immutable.ref"
case "$MODES" in *m3*) ( cd "$d" && timeout -k 5 300 "$SCRIP" run.pl </dev/null > m3.out 2> m3.err ); verdict "SCRIP m3: an immutable module is not reloaded" "$d/m3.out" "$WIT/xld02_immutable.ref" ;; esac
case "$MODES" in *m4*)
    if ( cd "$d" && timeout -k 5 300 "$SCRIP" --compile --out=run.s run.pl </dev/null > /dev/null 2> m4.cerr ) && gcc -m64 -no-pie "$d/run.s" -o "$d/run.bin" -L"$RT" -lscrip_rt -Wl,-rpath,"$RT" -lm 2> "$d/m4.lerr"; then
        ( cd "$d" && timeout -k 5 300 "$d/run.bin" </dev/null > m4.out 2> m4.err ); verdict "SCRIP m4: an immutable module is not reloaded" "$d/m4.out" "$WIT/xld02_immutable.ref"
    else total=$((total+1)); red=$((red+1)); echo "  RED SCRIP m4 did not compile or link: $(head -c 200 "$d/m4.cerr" "$d/m4.lerr" 2>/dev/null)"; fi ;;
esac
sed '1s/.*/not what XSB writes/' "$WIT/xld02_immutable.ref" > "$TMPD/ref_corrupt"
total=$((total+1))
if cmp -s "$TMPD/x/temp" "$TMPD/ref_corrupt"; then echo "  RED CAN FAIL: a corrupted ref read equal to XSB's output"; red=$((red+1)); else echo "  ok  CAN FAIL: a ref with one changed line reads red against XSB's output"; fi
echo "$GATE_NAME: arms=$total red=$red modes=$MODES"
[ "$red" -eq 0 ] || { echo "⛔ $GATE_NAME RED"; exit 1; }
echo "✅ $GATE_NAME GREEN"
