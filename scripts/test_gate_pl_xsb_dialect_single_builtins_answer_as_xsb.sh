#!/usr/bin/env bash
# test_gate_pl_xsb_dialect_single_builtins_answer_as_xsb.sh -- THE XSB DIALECT'S SINGLE BUILTINS ANSWER AS XSB 5.0.0 DOES (hq_packages 2026-10-29, the group 6 programs of the XsbTests non-tabling reds, CEO-2012).
# One witness per builtin family in corpus/tests/prolog/xsb_builtins (xbiNN_name.P with its xbiNN_name.ref and, when it needs files beside it, an xbiNN_name.d directory copied into the run directory, the ref XSB's own temp file by the gentest protocol); the gate runs every pair it finds, so a landing
# adds a witness and no gate.
#   xbi01_arithmetic  round, ceiling, floor and truncate pass an integer through (ISO and GNU raise type_error(float, 5)); round is floor(X + 0.5); the xor evaluable is ><; an expression that is not evaluable
#                     is type_error(evaluable, Term) with the term itself, not Name/Arity (the culprit of a top-level unary function is its argument, XSB's own quirk); a list is never evaluated, [a] included
#   xbi02_retract_nr_gc_dynamic  retract_nr/1 is retract/1 (the clause goes, a failing or undefined target fails, an unbound one is instantiation_error); gc_dynamic/1 answers an integer for an unbound argument and
#                     type_error(variable, N) for a bound one (the count itself is XSB's storage timing, never printed: CEO-1934, CEO-2012 (c))
#   xbi03_qualified_call_loads_the_module_file  the first call M:Goal of a module not yet loaded loads the file M.P beside the program (its ?- directive prints once), a later call loads nothing, a system
#                     module (basics) has no file beside (the companion module file is the witness's .d directory, copied beside it)
#   xbi04_file_io     file_write/2, file_flush/2, file_seek/4 (place 0, 1, 2), file_truncate/3 (leaves the position at the new end), print_file_contents/1, rm/1 and xsb_configuration(os_type, _) over the stream
#                     file_open/3 returns, every status 0 (io_tests io_basics)
# ARMS per witness: (1) ORACLE: the stored ref is exactly what live XSB 5.0.0 writes (an XSB that cannot run REFUSES rc 2; one that disagrees reds the gate: the ref is stale)
#       (2) m3 and (3) m4: SCRIP's stdout under the xsb package prelude equals the ref byte for byte (the first differing line is named); (4) once: CAN FAIL, a ref with one changed line reads RED
# rc 0 all arms; rc 1 an arm red; rc 2 could not measure (no binary, stale binary, no XSB, no witness).
set -u
GATE_NAME=test_gate_pl_xsb_dialect_single_builtins_answer_as_xsb
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIP="$HERE/../../SCRIP/scrip"
RT="${RT_DIR:-$HERE/../../SCRIP/out}"
WIT="$HERE/../../corpus/tests/prolog/xsb_builtins"
PRELUDE="$HERE/../../corpus/packages/prolog/xsb_tests/ALL.prelude"
refuse() { echo "⛔ REFUSED(2) [$GATE_NAME]: $*" >&2; exit 2; }
[ -x "$SCRIP" ] || refuse "no scrip binary at $SCRIP -- run make first"
WITNESSES="$(cd "$WIT" 2>/dev/null && for f in xbi*.P; do [ -f "$f" ] && [ -f "${f%.P}.ref" ] && echo "${f%.P}"; done)"
[ -n "$WITNESSES" ] || refuse "no witness pair (xbiNN_name.P and .ref) at $WIT"
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
FIRST=""
for w in $WITNESSES; do
    [ -n "$FIRST" ] || FIRST="$w"
    d="$TMPD/$w"; mkdir -p "$d"; cp "$WIT/$w.P" "$d/$w.P"
    [ -d "$WIT/$w.d" ] && cp -R "$WIT/$w.d/." "$d/"
    { printf '%s\n' "$PRE"; cat "$WIT/$w.P"; printf ':- initialization((test, halt)).\n'; } > "$d/run.pl"
    ( cd "$d" && rm -f temp && printf '[%s].\ntell(temp).\ntest.\ntold.\nhalt.\n' "$w" | timeout -k 5 120 "$XSB" --nobanner --quietload > xsb.log 2>&1 )
    [ -s "$d/temp" ] || refuse "XSB wrote no temp file for $w: $(head -c 300 "$d/xsb.log")"
    verdict "$w: the stored ref is what live XSB 5.0.0 writes" "$d/temp" "$WIT/$w.ref"
    case "$MODES" in *m3*) ( cd "$d" && timeout -k 5 120 "$SCRIP" run.pl </dev/null > m3.out 2> m3.err ); verdict "$w: SCRIP m3 answers as XSB" "$d/m3.out" "$WIT/$w.ref" ;; esac
    case "$MODES" in *m4*)
        if ( cd "$d" && timeout -k 5 240 "$SCRIP" --compile --out=run.s run.pl </dev/null > /dev/null 2> m4.cerr ) && gcc -m64 -no-pie "$d/run.s" -o "$d/run.bin" -L"$RT" -lscrip_rt -Wl,-rpath,"$RT" -lm 2> "$d/m4.lerr"; then
            ( cd "$d" && timeout -k 5 120 "$d/run.bin" </dev/null > m4.out 2> m4.err ); verdict "$w: SCRIP m4 answers as XSB" "$d/m4.out" "$WIT/$w.ref"
        else total=$((total+1)); red=$((red+1)); echo "  RED $w: SCRIP m4 did not compile or link: $(head -c 200 "$d/m4.cerr" "$d/m4.lerr" 2>/dev/null)"; fi ;;
    esac
done
sed '1s/.*/not what XSB writes/' "$WIT/$FIRST.ref" > "$TMPD/ref_corrupt"
total=$((total+1))
if cmp -s "$TMPD/$FIRST/temp" "$TMPD/ref_corrupt"; then echo "  RED CAN FAIL: a corrupted ref read equal to XSB's output"; red=$((red+1)); else echo "  ok  CAN FAIL: a ref with one changed line reads red"; fi
echo "$GATE_NAME: arms=$total red=$red modes=$MODES"
[ "$red" -eq 0 ] || { echo "⛔ $GATE_NAME RED"; exit 1; }
echo "✅ $GATE_NAME GREEN"
