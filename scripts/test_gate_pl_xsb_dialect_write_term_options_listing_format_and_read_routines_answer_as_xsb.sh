#!/usr/bin/env bash
# test_gate_pl_xsb_dialect_write_term_options_listing_format_and_read_routines_answer_as_xsb.sh -- THE XSB DIALECT'S WRITE_TERM OPTIONS, LISTING, FORMAT AND READ ROUTINES ANSWER AS XSB 5.0.0 DOES (hq_packages 2026-10-29, CEO-1927: XSB is the oracle of packages/prolog/xsb_tests;
# the prolog_tests row of the write, read, format and listing programs). Five witnesses in corpus/tests/prolog/xsb_writer, each ref XSB's own temp file (gentest protocol):
#   xwr02_write_term_options  ignore_ops writes lists as .(a,.(b,[])) and braces as {}(,(a,b)); portable(true) keeps lists and braces; integer_base(hex|octal|N), integer_prefix and radix write 0xff, 16'ff,
#                             8'377, 0o173, -0xff; a list of printable codes is written as a double-quoted string by write_term (not under ignore_ops); max_depth counts list elements and compound arguments as XSB does
#                             (n([1,2|...],f(g(...)))); with quoted(true) an operator functor is parenthesized ((+)(a,b)) but write_canonical's is not; an invalid option is domain_error(write_option, Option)
#   xwr03_listing             listing/0,1 prints a dynamic predicate's clauses (variables lettered, body on indented lines, a blank line after), a static one is permission_error(access, static_private_predicate, PI)
#   xwr04_float_options       write_term float_precision(N) and float_specifier(f|e|g) print with printf's precision; the default is 15 digits and a trailing .0
#   xwr05_format              lib/format.P: ~w ~q ~W write a +/2 term as its sides around a bare plus, column fill puts the remainder on the LAST ~t points, a non-list argument is the single argument, and a lone tilde,
#                             a text mixing characters and codes, a ~s argument mixing them and leftover arguments throw and print nothing
#   xwr06_read_and_term       '- 1' reads as the integer -1 ('- (1)' and '-(1)' stay compounds), read_canonical/2, file_open/3 mode 3 with file_read/3 (vv(Name, Var) in an open list) and str_cat/3, foo() as a
#                             compound of arity 0 for functor/3, univ and term_to_atom, set_xsb_param(float_display_format, [precision(N)])
# ARMS per witness: (1) ORACLE: the stored ref is exactly what live XSB 5.0.0 writes (an XSB that cannot run REFUSES rc 2; one that disagrees reds the gate: the ref is stale)
#       (2) m3 and (3) m4: SCRIP's stdout under the xsb package prelude equals the ref byte for byte (the first differing line is named); (4) once: CAN FAIL, a ref with one changed line reads RED
# RED BEFORE (measured 2026-10-29 on SCRIP f0567644e, the tree before the cure: the working-tree change reverted and rebuilt): all ten m3 and m4 arms red (61, 33, 7, 15 and 12 ref lines differ of 92, 34, 24, 26
# and 21: write_term printed '.'(a,'.'(b,[])), no listing/1 existed, float_precision was a domain_error, format wrote 'A' + 'B' and threw nothing, read_canonical/2 and file_open/3 did not exist).
# rc 0 all arms; rc 1 an arm red; rc 2 could not measure (no binary, stale binary, no XSB, no witness).
set -u
GATE_NAME=test_gate_pl_xsb_dialect_write_term_options_listing_format_and_read_routines_answer_as_xsb
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIP="$HERE/../../SCRIP/scrip"
RT="${RT_DIR:-$HERE/../../SCRIP/out}"
WIT="$HERE/../../corpus/tests/prolog/xsb_writer"
PRELUDE="$HERE/../../corpus/packages/prolog/xsb_tests/ALL.prelude"
refuse() { echo "⛔ REFUSED(2) [$GATE_NAME]: $*" >&2; exit 2; }
[ -x "$SCRIP" ] || refuse "no scrip binary at $SCRIP -- run make first"
WITNESSES="xwr02_write_term_options xwr03_listing xwr04_float_options xwr05_format xwr06_read_and_term"
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
    case "$MODES" in *m3*) ( cd "$d" && timeout -k 5 120 "$SCRIP" run.pl </dev/null > m3.out 2> m3.err ); verdict "$w: SCRIP m3 answers as XSB" "$d/m3.out" "$WIT/$w.ref" ;; esac
    case "$MODES" in *m4*)
        if ( cd "$d" && timeout -k 5 240 "$SCRIP" --compile --out=run.s run.pl </dev/null > /dev/null 2> m4.cerr ) && gcc -m64 -no-pie "$d/run.s" -o "$d/run.bin" -L"$RT" -lscrip_rt -Wl,-rpath,"$RT" -lm 2> "$d/m4.lerr"; then
            ( cd "$d" && timeout -k 5 120 "$d/run.bin" </dev/null > m4.out 2> m4.err ); verdict "$w: SCRIP m4 answers as XSB" "$d/m4.out" "$WIT/$w.ref"
        else total=$((total+1)); red=$((red+1)); echo "  RED $w: SCRIP m4 did not compile or link: $(head -c 200 "$d/m4.cerr" "$d/m4.lerr" 2>/dev/null)"; fi ;;
    esac
done
sed '1s/.*/not what XSB writes/' "$WIT/xwr02_write_term_options.ref" > "$TMPD/ref_corrupt"
total=$((total+1))
if cmp -s "$TMPD/xwr02_write_term_options/temp" "$TMPD/ref_corrupt"; then echo "  RED CAN FAIL: a corrupted ref read equal to XSB's output"; red=$((red+1)); else echo "  ok  CAN FAIL: a ref with one changed line reads red against XSB's output"; fi
echo "$GATE_NAME: arms=$total red=$red modes=$MODES"
[ "$red" -eq 0 ] || { echo "⛔ $GATE_NAME RED"; exit 1; }
echo "✅ $GATE_NAME GREEN"
