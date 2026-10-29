#!/usr/bin/env bash
# test_gate_pl_exists_source_answers_a_library_the_prelude_holds_and_a_file_that_exists_as_swipl.sh -- exists_source/1 IS TRUE FOR A LIBRARY THE PRELUDE HOLDS AND FOR A FILE THAT EXISTS (hq_packages
# 2026-10-28, cto DESIGN-PLAN clpr-chr step 9, ARCH-PROLOG-CLPR-CHR.md R9; ceo CEO-2005). swipl 9.0.4 answers exists_source(library(clpr)) and exists_source(library(lists)) true, a library it does not
# have false, a file that exists (with or without its .pl) true, one that does not false, and a variable an instantiation_error. SCRIP evaluated the directive form at read time (:- if(exists_source(
# library(X))), the parser's own table) and had NO predicate: a body goal raised existence_error(procedure, exists_source/1). A goal naming a library literally is now decided by the lowerer from the same
# table (true when the prelude holds the library, fail when it does not), and the prelude's exists_source/1 answers a file spec and a variable. KNOWN LIMIT, named: a library name reached only through
# call/1 at run time reads false (the table is not visible to the runtime); the witness uses direct goals.
# The expected text is RE-CHECKED against live swipl on every run (an oracle that cannot answer REFUSES rc 2; one that disagrees reds the gate); the library names asked are ones both hold (clpr, lists) and one
# neither does.
# ARMS: (1) swipl's answer to the program equals the expected text  (2) SCRIP m3  (3) SCRIP m4 print it too
# RED BEFORE (measured 2026-10-28 on SCRIP 4c8cc45dd, the tree before the cure, rebuilt with the change reverted): SCRIP m3 and m4 printed nothing, the first goal raising
# existence_error(procedure, exists_source/1); the clpr-chr step 9 witness cr09_linprog read m3 0/1 m4 0/1 with the same existence_error.
set -u
GATE_NAME=test_gate_pl_exists_source_answers_a_library_the_prelude_holds_and_a_file_that_exists_as_swipl
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIP="$HERE/../../SCRIP/scrip"
RT="${RT_DIR:-$HERE/../../SCRIP/out}"
SWIPL=/usr/bin/swipl
refuse() { echo "⛔ REFUSED(2) [$GATE_NAME]: $*" >&2; exit 2; }
[ -x "$SCRIP" ] || refuse "no scrip binary at $SCRIP -- run make first"
[ -x "$SWIPL" ] || refuse "no swipl oracle at $SWIPL"
"$HERE/util_require_fresh.sh" --gate "$GATE_NAME" "$SCRIP" "$RT/libscrip_rt.so" || exit 2
MODES="${PL_RUNG_MODES:-m3,m4}"
TMPD="$(mktemp -d)"; trap 'rm -rf "$TMPD"' EXIT
red=0; total=0
cat > "$TMPD/ex.pl" <<'EOP'
:- initialization(main).
main :-
    ( exists_source(library(clpr)) -> writeln(clpr-yes) ; writeln(clpr-no) ),
    ( exists_source(library(lists)) -> writeln(lists-yes) ; writeln(lists-no) ),
    ( exists_source(library(no_such_library_zz)) -> writeln(nosuch-yes) ; writeln(nosuch-no) ),
    ( exists_source('ex.pl') -> writeln(self_with_ext-yes) ; writeln(self_with_ext-no) ),
    ( exists_source(ex) -> writeln(self_without_ext-yes) ; writeln(self_without_ext-no) ),
    ( exists_source(no_such_file_zz) -> writeln(missing-yes) ; writeln(missing-no) ),
    catch(( exists_source(_) -> writeln(unbound-yes) ; writeln(unbound-no) ), error(instantiation_error, _), writeln(unbound-instantiation_error)),
    halt.
EOP
WANT="$(printf '%s\n' 'clpr-yes' 'lists-yes' 'nosuch-no' 'self_with_ext-yes' 'self_without_ext-yes' 'missing-no' 'unbound-instantiation_error')"
got="$(cd "$TMPD" && timeout -k 5 60 "$SWIPL" -q ex.pl </dev/null 2>/dev/null)"
total=$((total+1)); if [ "$got" = "$WANT" ]; then echo "  ok  swipl 9.0.4 prints the expected text"; else echo "  RED the oracle swipl disagrees with the expected text: [$got]"; red=$((red+1)); fi
case "$MODES" in *m3*) total=$((total+1)); got="$(cd "$TMPD" && timeout -k 5 60 "$SCRIP" ex.pl </dev/null 2>/dev/null)"; if [ "$got" = "$WANT" ]; then echo "  ok  SCRIP m3"; else echo "  RED SCRIP m3: [$got]"; red=$((red+1)); fi ;; esac
case "$MODES" in *m4*)
    total=$((total+1))
    if ( cd "$TMPD" && timeout -k 5 120 "$SCRIP" --compile -o ex.s ex.pl </dev/null >/dev/null 2>"$TMPD/cerr" ) && gcc -m64 -no-pie "$TMPD/ex.s" -o "$TMPD/ex.bin" -L"$RT" -lscrip_rt -Wl,-rpath,"$RT" -lm 2>"$TMPD/lerr"; then
        got="$(cd "$TMPD" && timeout -k 5 60 "$TMPD/ex.bin" </dev/null 2>/dev/null)"; if [ "$got" = "$WANT" ]; then echo "  ok  SCRIP m4"; else echo "  RED SCRIP m4: [$got]"; red=$((red+1)); fi
    else echo "  RED SCRIP m4 did not compile or link: $(head -c 200 "$TMPD/cerr" "$TMPD/lerr" 2>/dev/null)"; red=$((red+1)); fi ;;
esac
echo "$GATE_NAME: arms=$total red=$red modes=$MODES"
[ "$red" -eq 0 ] || { echo "⛔ $GATE_NAME RED"; exit 1; }
echo "✅ $GATE_NAME GREEN"
