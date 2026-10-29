#!/usr/bin/env bash
# stale-binary preflight (row test-gate-scripts-that-grade-scrip-refuse-on-a-stale-binary-census-widened, hq_T 2026-09-05)
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
# test_gate_pl_consult_loads_the_named_file.sh -- consult/1 AND ITS BRACKET SHORTHAND LOAD THE NAMED FILE.
# Row prolog-inria-consult-and-bracket-file-directive-are-both-unimplemented (hq_C 2026-09-06).
# ISO 13211-1 sec 7.4.2/6.4 program-text loading.
#
# THE DEFECT THIS PINS, in two shapes with very different failure modes:
#   consult(t_foo)  raised existence_error(procedure,consult/1) -- loud, and at least honest.
#   :- [t_foo].     parsed, ran, exited 0, and DEFINED NOTHING. Silently accepted as a no-op. ⭐ That is the
#                   worse of the two by a distance: a no-op LOOKS ALIVE, and the program only dies later at the
#                   first call to a predicate the file was supposed to define, pointing at the wrong place.
# THE CURE: SCRIP compiles ahead of time, so consult means what an extra positional source file means -- the
# named file's clauses join THIS program at compile time. Multi-file loading therefore rides the same path
# test_gate_pl_multifile_initialization_runs_every_file already pins, instead of becoming a second unproven way
# to build a program. A runtime consult would need a runtime compiler; that is a different rung.
#
# WHAT IT PROVES, in six directions so a careless cure cannot pass it:
#   (a) consult/1 makes the named file's predicates callable, both modes.
#   (b) the BRACKET form is a REAL synonym, not a no-op -- the shape that used to lie.
#   (c) consult INSIDE A DIRECTIVE CONJUNCTION works (`:- consult(F), Goal.`) -- NOT the same code path as a
#       directive whose whole subject is the consult.
#   (h) A VARIABLE FILE NAME: `F = t_foo, [F]` in a clause body. This arm once pinned a limit (no run-time
#       loading, so the call had to RAISE consult/1); SCRIP 3eb9e62e0 made a list goal consult its files at run
#       time, directly and through call/1, so the limit is gone and the arm is RE-CUT to the oracle (cfo
#       2026-10-17, row prolog-gnu-semantics-leak-...-ceo-1810): swipl and gprolog 1.4.5 both print 2, and so
#       must SCRIP. This is the INRIA driver's spelling (inriasuite.pl:623-624, `[ProgFile]`).
#   (d) ⛔ CONTROL, AND THE ONE THAT KEEPS THE CURE HONEST: a list in a DATA position is NOT a consult.
#       `X = [a,b]` must still bind a list. A cure that scans every term for a list of atoms passes (a)-(c)
#       and silently tries to load files named a and b.
#   (e) CONTROL: a MISSING consulted file names itself on stderr and the program stays ALIVE, matching swipl,
#       which warns and continues. Neither a silent no-op nor a dead process.
#   (f) CONTROL: consulting the same file twice defines its predicates ONCE, not twice.
#   (g) The oracle is ASSERTED, never assumed: swipl runs every witness and the gate REFUSES if its answer moved.
# ⛔ Hermetic: every program is written under mktemp; nothing in corpus/ is read or written.
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)" || { echo "REFUSE(2): no SCRIP beside harness at $HERE/../../SCRIP (a port root) -- this gate measures SCRIP and cannot from here"; exit 2; }
SCRIP="${SCRIP:-$ROOT/scrip}"
refuse(){ echo "⛔ REFUSED-TO-GRADE: $*"; exit 2; }
[ -x "$SCRIP" ] || refuse "scrip not built at $SCRIP (a test that cannot measure REFUSES, never skips-as-success)"
SWIPL=/usr/bin/swipl; [ -x "$SWIPL" ] || refuse "no swipl at $SWIPL -- the oracle premise cannot be checked"
[ -f "$ROOT/out/libscrip_rt.so" ] || refuse "no $ROOT/out/libscrip_rt.so -- the m4 arm cannot link"
W="$(mktemp -d "${TMPDIR:-/tmp}/gate_plconsult.XXXXXX")" || refuse "mktemp failed"; trap 'rm -rf "$W"' EXIT
printf 't_foo(1,2).\n'                                                                                  > "$W/t_foo.pl"
printf ':- consult(t_foo).\n:- initialization(main).\nmain :- t_foo(1,X), write(X), nl.\n'               > "$W/direct.pl"
printf ':- [t_foo].\n:- initialization(main).\nmain :- t_foo(1,X), write(X), nl.\n'                      > "$W/bracket.pl"
printf ':- consult(t_foo), t_foo(1,Y), write(Y), nl.\n'                                                 > "$W/conj.pl"
printf ':- initialization(main).\nmain :- F = t_foo, [F], t_foo(1,X), write(X), nl.\n'                  > "$W/varfile.pl"
printf ':- initialization(main).\nmain :- X = [a,b], write(X), nl.\n'                                    > "$W/data.pl"
printf ':- consult(no_such_file_here).\n:- initialization(main).\nmain :- write(alive), nl.\n'           > "$W/missing.pl"
printf ':- [t_foo].\n:- [t_foo].\n:- initialization(main).\nmain :- findall(X, t_foo(1,X), L), write(L), nl.\n' > "$W/twice.pl"
fails=0; checks=0
ck(){ checks=$((checks+1)); if [ "$1" = ok ]; then printf '  ok    %s\n' "$2"; else printf '  FAIL  %s\n' "$2"; fails=$((fails+1)); fi; }
oracle(){ ( cd "$W" && timeout -k 5 30 "$SWIPL" -q -g true -t halt "$1.pl" </dev/null 2>/dev/null ); }
echo "=== gate: consult/1 and [File] load the named file ==="
echo "--- (g) the ORACLE premise, asserted before anything is graded ---"
for w in direct bracket conj varfile data missing twice; do
  eval "EXP_$w=\"\$(oracle $w)\""
done
[ "$EXP_direct" = "2" ]      || refuse "ORACLE PREMISE MOVED: swipl consult(t_foo) printed [$EXP_direct], expected 2"
[ "$EXP_bracket" = "2" ]     || refuse "ORACLE PREMISE MOVED: swipl [t_foo] printed [$EXP_bracket], expected 2"
[ "$EXP_varfile" = "2" ]     || refuse "ORACLE PREMISE MOVED: swipl F = t_foo, [F] printed [$EXP_varfile], expected 2"
[ "$EXP_data" = "[a,b]" ]    || refuse "ORACLE PREMISE MOVED: swipl X=[a,b] printed [$EXP_data]"
[ "$EXP_missing" = "alive" ] || refuse "ORACLE PREMISE MOVED: swipl on a missing consult printed [$EXP_missing], expected it to warn and CONTINUE"
[ "$EXP_twice" = "[2]" ]     || refuse "ORACLE PREMISE MOVED: swipl double-consult printed [$EXP_twice], expected [2]"
ck ok "oracle: direct=[$EXP_direct] bracket=[$EXP_bracket] conj=[$EXP_conj] data=[$EXP_data] missing=[$EXP_missing] twice=[$EXP_twice]"
for m in m3 m4; do
  echo "--- $m ---"
  run(){ if [ "$m" = m3 ]; then ( cd "$W" && timeout -k 5 60 "$SCRIP" "$1.pl" </dev/null 2>/dev/null ); else
           rm -f "$W/out.s" "$W/out.bin"
           ( cd "$W" && timeout -k 5 90 "$SCRIP" --compile --out=out.s "$1.pl" </dev/null >/dev/null 2>&1 ) || return 97
           timeout -k 5 90 gcc -no-pie -o "$W/out.bin" "$W/out.s" -L"$ROOT/out" -lscrip_rt -lm >/dev/null 2>&1 || return 98
           ( cd "$W" && LD_LIBRARY_PATH="$ROOT/out" timeout -k 5 60 ./out.bin </dev/null 2>/dev/null ); fi; }
  run_err(){ if [ "$m" = m3 ]; then ( cd "$W" && timeout -k 5 60 "$SCRIP" "$1.pl" </dev/null 2>&1 >/dev/null ); else
           rm -f "$W/e.s" "$W/e.bin"
           ( cd "$W" && timeout -k 5 90 "$SCRIP" --compile --out=e.s "$1.pl" </dev/null >/dev/null 2>&1 ) || return 97
           timeout -k 5 90 gcc -no-pie -o "$W/e.bin" "$W/e.s" -L"$ROOT/out" -lscrip_rt -lm >/dev/null 2>&1 || return 98
           ( cd "$W" && LD_LIBRARY_PATH="$ROOT/out" timeout -k 5 60 ./e.bin </dev/null 2>&1 >/dev/null ); fi; }
  o="$(run direct)";  [ "$o" = "$EXP_direct" ]  && ck ok "$m (a) consult/1 makes t_foo/2 callable -> [$o]" || ck no "$m (a) printed [$o], oracle says [$EXP_direct]"
  o="$(run bracket)"; [ "$o" = "$EXP_bracket" ] && ck ok "$m (b) [File] is a REAL synonym -> [$o]"         || ck no "$m (b) printed [$o], oracle says [$EXP_bracket] -- a silent no-op looks alive and dies later, elsewhere"
  o="$(run conj)";    [ "$o" = "$EXP_conj" ]    && ck ok "$m (c) consult inside a DIRECTIVE conjunction -> [$o]"  || ck no "$m (c) printed [$o], oracle says [$EXP_conj]"
  o="$(run varfile)"; [ "$o" = "$EXP_varfile" ] && ck ok "$m (h) [Var] in a clause body consults at run time -> [$o]" || ck no "$m (h) [Var] in a clause body printed [$o], oracle says [$EXP_varfile]"
  o="$(run data)";    [ "$o" = "$EXP_data" ]    && ck ok "$m (d) a list in DATA position is not a consult -> [$o]" || ck no "$m (d) printed [$o], oracle says [$EXP_data] -- the cure is scanning argument terms, not goals"
  o="$(run missing)"; [ "$o" = "$EXP_missing" ] && ck ok "$m (e) a missing consulted file leaves the program alive -> [$o]" || ck no "$m (e) printed [$o], oracle says [$EXP_missing]"
  o="$(run twice)";   [ "$o" = "$EXP_twice" ]   && ck ok "$m (f) consulting twice defines once -> [$o]"     || ck no "$m (f) printed [$o], oracle says [$EXP_twice] -- duplicate clauses"
done
echo "------------------------------------------------------------"
if [ "$fails" -eq 0 ]; then echo "✅ GATE GREEN: consult/1 and [File] load the named file, in goal position, without eating data lists (examined $checks checks)"; exit 0; fi
echo "⛔ GATE FAIL: $fails of $checks checks red"
echo "   CURE: prolog_compile splices consulted files into the program at compile time; a list is a consult ONLY in goal position"
exit 1
