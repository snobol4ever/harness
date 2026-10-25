#!/bin/bash
# test_gate_pl_clause_of_a_variable_head_in_a_plunit_unit_returns_its_body_goals_unqualified_as_swipl.sh -- clause/2 OF A RUN-TIME HEAD IN A UNIT HANDS BACK THE BODY AS WRITTEN (ceo CEO-1959, hq_packages; SWI core/test_moved_ubody.pl).
# SCRIP renames a predicate a module or a plunit unit defines to M:name (pl_module_flatten). A clause/2 goal with a LITERAL head is wrapped by the lowerer in $clause_unmangle, which gives the body back with every
# goal of the clause's own module unqualified; a clause/2 goal whose head is a VARIABLE bound at run time (Head = s3(_,_,_), clause(Head, Body)) is rewritten to $mctx_clause, whose body step only stripped a
# whole-body Module:Body wrapper -- so a unit predicate that called another unit predicate came back as 'plunit_moved_decompile:q'(A,B,C,D) where swipl answers q(A,B,C,D), and decom1-4, decomp7 of
# core/test_moved_ubody.pl read "true check failed". $mctx_unb now un-mangles every body goal relative to the module that owns the clause. The witness is the vendored file graded against its oracle-cut refs:
# 10 graded cases (2 more are EXCLUDED as swipl 9.0.4 decompiler defects, EXCLUDED_CASES.tsv), 9 pass in both modes, and the one that does not is decomp8#1 (swipl moves a leading Var = Term unification into the
# head -- s7(f(A)) :- q(A) -- which is a clause-store rewrite SCRIP does not do, the cto's mechanism). rc 0 exactly that; rc 1 any other case red; rc 2 cannot measure (no ./scrip, no suite runner, no board line).
HERE="$(cd "$(dirname "$0")" && pwd)"
cd "$HERE/../../SCRIP" 2>/dev/null || { echo "REFUSE(2): no SCRIP beside the harness"; exit 2; }
[ -x ./scrip ] && [ -f "$HERE/test_prolog_swi_suite.sh" ] || { echo "REFUSE(2): no ./scrip or no suite runner"; exit 2; }
T="$HERE/../../.scratch/mubd-$$"; mkdir -p "$T"; trap 'rm -rf "$T"' EXIT
S4E_PROGRESS_OFF=1 timeout -k 5 600 bash "$HERE/test_prolog_swi_suite.sh" --file core/test_moved_ubody.pl --modes m3,m4 --name-reds > "$T/o.txt" 2>&1; rc=$?
line="$(grep -m1 '^SWI_BOARD' "$T/o.txt")"
[ -n "$line" ] || { echo "REFUSE(2): the suite runner printed no SWI_BOARD line (rc=$rc)"; head -3 "$T/o.txt" | cut -c1-200; exit 2; }
echo "$line" | cut -c1-200
reds="$(grep '  RED ' "$T/o.txt" | sed 's/^ *RED core\/test_moved_ubody.pl://; s/:m[34]:.*//' | sort -u | tr '\n' ' ')"
g="$(echo "$line" | sed -n 's/.* graded=\([0-9]*\) .*/\1/p')"; p3="$(echo "$line" | sed -n 's/.* m3_pass=\([0-9]*\) .*/\1/p')"; p4="$(echo "$line" | sed -n 's/.* m4_pass=\([0-9]*\) .*/\1/p')"
if [ "$g" = 10 ] && [ "$p3" = 9 ] && [ "$p4" = 9 ] && [ "$reds" = "moved_decompile:decomp8#1 " ]; then echo "GATE OK -- core/test_moved_ubody.pl: 9 of 10 graded pass in both modes, the one red is decomp8#1 (the head-move rewrite)"; exit 0; fi
echo "GATE FAIL -- graded=$g m3_pass=$p3 m4_pass=$p4 reds=[$reds] (want 10 9 9 [moved_decompile:decomp8#1 ])"
grep '  RED ' "$T/o.txt" | cut -c1-180 | head -8
exit 1
