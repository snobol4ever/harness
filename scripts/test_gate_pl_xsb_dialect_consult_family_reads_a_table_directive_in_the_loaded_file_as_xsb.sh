#!/usr/bin/env bash
# test_gate_pl_xsb_dialect_consult_family_reads_a_table_directive_in_the_loaded_file_as_xsb.sh -- THE RUN-TIME LOADER OF THE XSB DIALECT READS :- table IN THE FILE IT LOADS (ceo CEO-2005, DESIGN-PLAN
# xsb-tabling-wfs step 1, ARCH-PROLOG-WFS-TABLING.md section 8 R1). XSB's consult/1, [File], load_dync/1, ensure_dync_loaded/1 and ensure_loaded/1 read a consulted file's directives as the compiler does: a
# ':- table path/2, unreach/1.' makes those predicates tabled, so the left-recursive path/2 of the sibling terminates and tnot(path(X,X)) answers. SCRIP's plain consult/1 ran the directive as a goal
# (existence_error(procedure, table/1)) and the untabled left recursion overflowed the stack; the XSB dialect now sends consult/1 down the load_files(_, [dialect(xsb)]) road ensure_loaded already took,
# and the prelude library xsb_builtins defines load_dync/1 and ensure_dync_loaded/1 on it. The expected text is the first four lines of the vendored XSB-cut ref corpus/tests/prolog/xsb_wfs/xw01_loader_table.ref.
# ARMS: (1) the five entry points and the list goal each print the four path(1,Y) answers (m3; the call and the list goal also in m4; the program is XSB's own text under the xsb package prelude)
#       (2) a consult of a missing file raises existence_error(source_sink, F) with context consult/1, as the plain road did; the arm prints it as XSB 5.0.0 writes the indicator, consult / 1 (the writer landing of 2026-10-28 made the old text consult/1 stale)
#       (3) the default dialect's consult/1 is the plain reader still: a file of facts consulted from a plain program loads and answers (the xsb clause is guarded by the dialect flag)
# RED BEFORE (measured 2026-10-28 on SCRIP c22bbf71e, the tree before the cure): consult(xw01_prog) and [xw01_prog] overflowed the stack after 'directive raised: existence_error(procedure,table/1)',
# load_dync/1 and ensure_dync_loaded/1 raised existence_error(procedure, ...); ensure_loaded/1 already answered. Arm (3) is the guard against the cure reaching the other dialects.
# rc 0 all arms; rc 1 an arm red; rc 2 could not measure (no binary, stale binary, no witness file).
set -u
GATE_NAME=test_gate_pl_xsb_dialect_consult_family_reads_a_table_directive_in_the_loaded_file_as_xsb
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="${S4E_HOME:-$(cd "$HERE/../.." && pwd)}"
SCRIP="$HERE/../../SCRIP/scrip"
RT="${RT_DIR:-$HERE/../../SCRIP/out}"
WIT="$HERE/../../corpus/tests/prolog/xsb_wfs"
PRELUDE="$HERE/../../corpus/packages/prolog/xsb_tests/ALL.prelude"
refuse() { echo "⛔ REFUSED(2) [$GATE_NAME]: $*" >&2; exit 2; }
[ -x "$SCRIP" ] || refuse "no scrip binary at $SCRIP -- run make first"
[ -f "$WIT/xw01_prog.P" ] && [ -f "$WIT/xw01_loader_table.ref" ] || refuse "no witness at $WIT (xw01_prog.P, xw01_loader_table.ref)"
[ -f "$PRELUDE" ] || refuse "no package prelude at $PRELUDE"
"$HERE/util_require_fresh.sh" --gate "$GATE_NAME" "$SCRIP" "$RT/libscrip_rt.so" || exit 2
MODES="${PL_RUNG_MODES:-m3,m4}"
TMPD="$(mktemp -d)"; trap 'rm -rf "$TMPD"' EXIT
red=0; total=0
PRE="$(grep -v '^#' "$PRELUDE" | grep -v '^$')"
cp "$WIT/xw01_prog.P" "$TMPD/xw01_prog.P"
printf 'f(1).\nf(2).\n' > "$TMPD/plainfacts.pl"
run_m3() { ( cd "$TMPD" && timeout -k 5 150 "$SCRIP" "$1" </dev/null 2>"$TMPD/err" ); }
run_m4() {
    local src="$1" s="$TMPD/w.s" b="$TMPD/w.bin"
    ( cd "$TMPD" && timeout -k 5 240 "$SCRIP" --compile --out="$s" "$src" </dev/null 2>"$TMPD/err" ) || { echo "  (m4: compile failed: $(head -c 160 "$TMPD/err"))"; return 97; }
    gcc -m64 -no-pie "$s" -o "$b" -L"$RT" -lscrip_rt -Wl,-rpath,"$RT" -lm 2>"$TMPD/err" || { echo "  (m4: link failed: $(head -c 160 "$TMPD/err"))"; return 98; }
    ( cd "$TMPD" && timeout -k 5 60 "$b" </dev/null 2>"$TMPD/err" )
}
arm() {
    local name="$1" src="$2" want_out="$3" only="${4:-m3,m4}" mode got
    for mode in m3 m4; do
        case "$MODES" in *"$mode"*) : ;; *) continue ;; esac
        case "$only" in *"$mode"*) : ;; *) continue ;; esac
        total=$((total+1))
        got="$("run_$mode" "$src" | sort)"
        if [ "$got" = "$want_out" ]; then echo "  ok  $name $mode"
        else echo "  RED $name $mode: out=[$got] want [$want_out] $(head -c 200 "$TMPD/err" 2>/dev/null)"; red=$((red+1)); fi
    done
}
WANT_PATHS="$(grep '^path' "$WIT/xw01_loader_table.ref" | sort)"
[ "$(printf '%s\n' "$WANT_PATHS" | wc -l)" -eq 4 ] || refuse "the ref does not carry the four path answers"
# a compile in mode 4 costs three times a mode-3 run (the load_files closure is parsed either way), so the two entry points that differ in how the compiler lowers them (the call and the list goal) run in
# both modes and the four that share the prelude road run in mode 3 only
for form in "consult(xw01_prog)|m3,m4" "[xw01_prog]|m3,m4" "consult([xw01_prog])|m3" "load_dync(xw01_prog)|m3" "ensure_dync_loaded(xw01_prog)|m3" "ensure_loaded(xw01_prog)|m3"; do
    modes="${form#*|}"; form="${form%|*}"
    key="$(printf '%s' "$form" | tr -c 'a-z0-9' '_')"
    { printf '%s\n' "$PRE"; printf 'test :- %s, ( path(1,Y), write(path(1,Y)), nl, fail ; true ).\n:- initialization(test).\n' "$form"; } > "$TMPD/$key.pl"
    arm "the_xsb_dialect_${key}_loads_the_tabled_sibling" "$TMPD/$key.pl" "$WANT_PATHS" "$modes"
done
{ printf '%s\n' "$PRE"; printf ':- initialization(catch(consult(nonexistent_zz), error(E, C), (write(E), write(%s), write(C), nl))).\n' "' in '"; } > "$TMPD/missing.pl"
arm a_missing_file_is_existence_error_source_sink_in_consult_1 "$TMPD/missing.pl" "existence_error(source_sink,nonexistent_zz) in consult / 1" m3
printf ':- initialization(main).\nmain :- consult(plainfacts), forall(f(X), (write(f(X)), nl)), halt.\n' > "$TMPD/plain.pl"
arm the_default_dialect_consult_is_the_plain_reader_still "$TMPD/plain.pl" "$(printf 'f(1)\nf(2)')"
echo "$GATE_NAME: arms=$total red=$red modes=$MODES"
[ "$red" -eq 0 ] || { echo "⛔ $GATE_NAME RED"; exit 1; }
echo "✅ $GATE_NAME GREEN"
