#!/usr/bin/env bash
# test_gate_xsb_refs_are_cut_from_xsb_and_graded_ignoring_white_space.sh -- XSB IS THE ORACLE OF THE XSB PACKAGE, AS ITS OWN SCRIPTS RUN IT (ceo CEO-1927).
#
# Lon 2026-10-23 11:3x CDT, in-chat to the cfo, verbatim: "Since SWIPL does not have all XSB, we should begin to use XSB system as the third oracle."
# RULES.md § Oracles, FACT RULE XSB IS THE THIRD PROLOG ORACLE, FOR THE XSB PACKAGE: each program runs as XSB's own gentest.sh runs it
# ([NAME]. tell(temp). GOAL. told.), its answer sorted, compared ignoring white space, its ref cut from that run and checked against NAME_old.
# A mktemp package outside corpus/ (CEO-547) declares CONTRACT.tsv oracle=xsb-gentest, upstream=<a fixture test tree>, compare=ignore-all-space,
# and ORACLE_RUNS.tsv rows; util_build_package_suite.py builds it --twice with the real XSB (xsb_bin) and corpus_suite_harness.py grades it with
# the real SCRIP, mode 3, no progress row. ARMS:
#   1 the ref of ft_tests_t_sorted is XSB's temp SORTED (the program writes c, a, b): ALL.ref holds a, b, c
#   2 ALL.xsbold names t_sorted MATCH (its NAME_old is a b c) and t_stale DIFF (its NAME_old is stale; the ref is still XSB's, CEO-1927 (1))
#   3 t_silent writes nothing: EXCLUDED, FAKEABLE_NO_OBSERVABLE (CEO-1865) -- a silent engine would pass an empty ref
#   4 t_norun has no ORACLE_RUNS.tsv row: EXCLUDED, "run it nowhere" -- never cut from another oracle; 4b t_cr's answer carries a CR: not absorbed
#   5 every absorbed ALL.csv row's compare cell reads ignore-all-space
#   6 graded: t_ws (SCRIP prints p06:p, XSB p06 : p) PASSES -- diff -w; t_tok (SCRIP prints p06:q) FAILS -- a token is not white space
#   8 PHASE 2, STAGED (STAGED.tsv stage=upstream): t_sib loads helper by its upstream name -- PASSES with the run directory staged as its upstream
#     test directory (helper.pl written there, its appended driver cut off), FAILS without the column; 9 t_tmp's answer is the file temp it writes
#     (answer=temp-sorted): PASSES graded as temp's lines sorted, FAILS without the column (stdout is empty)
#   7 THE OVERFLOW ARM (CEO-1927 (5)): a plain prolog package (swipl) whose one program prints without end, built under S4E_OUTPUT_CAP_MB=1:
#     EXCLUDED as an OVERFLOW, never absorbed (rosetta-pascal's seven interactive programs were, at 268435457 bytes each, 2026-10-23)
# FAIL-ONCE: on the harness before this gate's landing the builder refuses the contract (rc 2) and absorbs the overflow -- arms 1-7 read red there.
set -u
GATE_NAME=test_gate_xsb_refs_are_cut_from_xsb_and_graded_ignoring_white_space
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
fail=0; ok() { echo "  ok   $*"; }; bad() { echo "  FAIL $*"; fail=1; }
XSB=$(bash -c ". '$HERE/lib_oracle_flags.sh' && xsb_bin") || { echo "⛔ REFUSED(2) [$GATE_NAME]: xsb_bin refused -- the oracle this gate grades by is absent"; exit 2; }
T=$(mktemp -d "${TMPDIR:-/tmp}/xsbgate.XXXXXX"); [ -n "${GATE_KEEP:-}" ] || trap 'rm -rf "$T"' EXIT; [ -n "${GATE_KEEP:-}" ] && echo "kept: $T"
U=$T/up; P=$T/pkg/xsb_fix; mkdir -p $U/ft_tests $P
cat > $U/ft_tests/t_sorted.P <<'EOF'
test :- write(c), nl, write(a), nl, write(b), nl.
EOF
printf 'a\nb\nc\n' > $U/ft_tests/t_sorted_old
cat > $U/ft_tests/t_stale.P <<'EOF'
test :- write(new), nl.
EOF
printf 'old\n' > $U/ft_tests/t_stale_old
cat > $U/ft_tests/t_silent.P <<'EOF'
test.
EOF
: > $U/ft_tests/t_silent_old
cat > $U/ft_tests/t_ws.P <<'EOF'
test :- write('p06 : p'), nl.
EOF
cp $U/ft_tests/t_ws.P $U/ft_tests/t_tok.P
printf 'test :- true.\n' > $U/ft_tests/t_norun.P
printf "test :- atom_codes(A, [0'a, 13, 0'b]), write(A), nl.\n" > $U/ft_tests/t_cr.P
printf ':- [helper].\ntest :- h(X), write(X), nl.\n' > $U/ft_tests/t_sib.P
printf 'h(5).\n' > $U/ft_tests/helper.P
printf 'test :- write(y), nl, write(x), nl.\n' > $U/ft_tests/t_tmp.P
printf 'name\tset\tsource\tlicense\n' > $P/SOURCES.tsv
for t in t_sorted t_stale t_silent t_ws t_tok t_norun t_cr t_sib helper t_tmp t_xcl; do printf 'ft_tests_%s\tft_tests\txsb/xsbtests/ft_tests/%s.P\tfixture\n' $t $t >> $P/SOURCES.tsv; done
# the vendored files SCRIP runs: each prints its own answer at initialization (t_ws and t_tok differ from XSB's in white space and in a token)
printf ':- initialization((write(c), nl, write(a), nl, write(b), nl)).\n' > $P/ft_tests_t_sorted.pl
printf ':- initialization((write(new), nl)).\n' > $P/ft_tests_t_stale.pl
printf ':- initialization(true).\n' > $P/ft_tests_t_silent.pl
printf ":- initialization((write('p06:p'), nl)).\n" > $P/ft_tests_t_ws.pl
printf ":- initialization((write('p06:q'), nl)).\n" > $P/ft_tests_t_tok.pl
printf ':- initialization(true).\n' > $P/ft_tests_t_norun.pl
printf ':- initialization(true).\n' > $P/ft_tests_t_cr.pl
# phase 2 (CEO-1927): t_sib loads its sibling by the UPSTREAM name; the vendored helper carries a driver the staging must cut off; t_tmp's answer is temp
printf ':- [helper].\n:- initialization((h(X), write(X), nl)).\n' > $P/ft_tests_t_sib.pl
printf 'h(5).\n\n%% DRIVER (appended by the vendoring, CEO-700): fixture\n:- initialization((write(driver_ran), nl)).\n' > $P/ft_tests_helper.pl
printf ':- initialization((tell(temp), write(y), nl, write(x), nl, told)).\n' > $P/ft_tests_t_tmp.pl
cp $U/ft_tests/t_sorted.P $U/ft_tests/t_xcl.P; printf ':- initialization((write(a), nl)).\n' > $P/ft_tests_t_xcl.pl
printf '# fixture\nft_tests_t_xcl.pl\tNO_ORACLE_ANSWER\tfixture: its answer carries the cpu time on some runs\n' > $P/EXCLUDED.tsv
printf '# fixture\nft_tests_t_sib.pl\tupstream\tstdout\tloads helper by its upstream name\nft_tests_t_tmp.pl\tupstream\ttemp-sorted\twrites its answer to temp\n' > $P/STAGED.tsv
printf 'oracle\txsb-gentest\tgate fixture (CEO-1927)\nupstream\t%s\tgate fixture\ncompare\tignore-all-space\tgate fixture (gentest.sh diff -w)\n' "$U" > $P/CONTRACT.tsv
{ echo "# fixture"; for t in t_sorted t_stale t_silent t_ws t_tok t_cr t_sib t_tmp t_xcl; do printf 'ft_tests_%s\tft_tests\tgentest\t%s\ttest.\t-e segfault_handler\\(warn\\).\tft_tests/test.sh\n' $t $t; done; } > $P/ORACLE_RUNS.tsv
cd "$HERE/../../SCRIP" || { echo "⛔ REFUSED(2) [$GATE_NAME]: no SCRIP beside the harness"; exit 2; }
TIMEOUT=60 python3 "$HERE/util_build_package_suite.py" "$P" --lang prolog --twice > $T/build.out 2>&1; brc=$?
grep -q 'binary older than the tree' $T/build.out && { echo "⛔ REFUSED(2) [$GATE_NAME]: the SCRIP binary is older than its tree -- make, then re-run (nothing measured)"; exit 2; }
[ "$brc" = 0 ] && ok "the builder built the xsb-gentest fixture (rc 0)" || { bad "the builder refused or failed (rc $brc): $(grep -m1 -E 'REFUS|Error|error' $T/build.out | cut -c1-200)"; }
ref_of() { awk -v n="$1" '/^%-+ [0-9]+ /{f=($NF==n); next} f' "$P/ALL.ref" 2>/dev/null | tr '\n' ' '; }
r=$(ref_of ft_tests_t_sorted); [ "$r" = "a b c " ] && ok "arm 1: t_sorted's ref is XSB's answer sorted: $r" || bad "arm 1: t_sorted's ref reads [$r], want [a b c ]"
grep -qP '^ft_tests_t_sorted\tMATCH$' $P/ALL.xsbold 2>/dev/null && grep -qP '^ft_tests_t_stale\tDIFF' $P/ALL.xsbold 2>/dev/null \
  && ok "arm 2: ALL.xsbold: t_sorted MATCH, t_stale DIFF" || bad "arm 2: ALL.xsbold lacks t_sorted MATCH / t_stale DIFF: $(tr '\n' ' ' < $P/ALL.xsbold 2>/dev/null | cut -c1-160)"
grep -q '^ft_tests_t_silent: .*FAKEABLE_NO_OBSERVABLE' $P/ALL.excluded.txt 2>/dev/null && ok "arm 3: t_silent excluded FAKEABLE_NO_OBSERVABLE" || bad "arm 3: t_silent not excluded as FAKEABLE_NO_OBSERVABLE"
grep -q '^ft_tests_t_cr: .*carriage returns' $P/ALL.excluded.txt 2>/dev/null && ! grep -q $'\r' $P/ALL.ref && ok "arm 4b: t_cr's answer carries a CR: not absorbed, no CR in ALL.ref" || bad "arm 4b: t_cr was absorbed or ALL.ref holds a CR"
grep -q '^ft_tests_t_xcl: EXCLUDED.tsv names it NO_ORACLE_ANSWER' $P/ALL.excluded.txt 2>/dev/null && ! grep -q '^[0-9]*,ft_tests_t_xcl,' $P/ALL.csv && ok "arm 4c: a program EXCLUDED.tsv names is not absorbed, though XSB answers it the same twice" || bad "arm 4c: t_xcl was absorbed despite its EXCLUDED.tsv row"
grep -q '^ft_tests_t_norun: .*run it nowhere' $P/ALL.excluded.txt 2>/dev/null && ok "arm 4: t_norun excluded, run nowhere" || bad "arm 4: t_norun not excluded as run nowhere"
n_cmp=$(python3 -c "import csv,sys; r=list(csv.DictReader(open('$P/ALL.csv'))); print(sum(1 for x in r if x.get('compare')=='ignore-all-space'), len(r))" 2>/dev/null)
[ "$n_cmp" = "6 6" ] && ok "arm 5: 6 of 6 absorbed rows read compare=ignore-all-space" || bad "arm 5: compare cells [$n_cmp], want 6 of 6"
n_stg=$(python3 -c "import csv; r={x['entry']:x for x in csv.DictReader(open('$P/ALL.csv'))}; print(r.get('ft_tests_t_sib',{}).get('stage'), r.get('ft_tests_t_tmp',{}).get('answer'), r.get('ft_tests_t_ws',{}).get('stage'))" 2>/dev/null)
[ "$n_stg" = "upstream temp-sorted " ] && ok "arm 5b: STAGED.tsv's two entries are absorbed with stage=upstream (t_tmp answer=temp-sorted); an unstaged entry's cells are empty" || bad "arm 5b: stage/answer cells read [$n_stg]"
S4E_PROGRESS_OFF=1 timeout 300 python3 "$HERE/corpus_suite_harness.py" run "$P/ALL.pl" "$P/ALL.ref" --lang prolog --modes m3 > $T/grade.out 2>&1
v_of() {  # the board lists every non-pass by name; an entry on a board that ran and not listed passed
  local f="${2:-$T/grade.out}" v; v=$(grep -E "^  [A-Z_]+ m3 $1:" "$f" | grep -oE 'FAIL|CRASH|HANG|UNPROVEN' | head -1)
  [ -n "$v" ] && { echo "$v"; return; }; grep -q '^SUITE_BOARD ' "$f" && echo PASS; }
[ "$(v_of ft_tests_t_ws)" = PASS ] && ok "arm 6: t_ws PASSES (p06:p against XSB's p06 : p, diff -w)" || bad "arm 6: t_ws reads [$(v_of ft_tests_t_ws)], want PASS"
[ "$(v_of ft_tests_t_tok)" = FAIL ] && ok "arm 6: t_tok FAILS (p06:q is not white space)" || bad "arm 6: t_tok reads [$(v_of ft_tests_t_tok)], want FAIL"
[ "$(v_of ft_tests_t_sib)" = PASS ] && ok "arm 8: t_sib PASSES staged upstream (helper found by its upstream name, its appended driver cut off)" || bad "arm 8: t_sib reads [$(v_of ft_tests_t_sib)], want PASS"
[ "$(v_of ft_tests_t_tmp)" = PASS ] && ok "arm 9: t_tmp PASSES with answer=temp-sorted (y, x written to temp; graded x, y)" || bad "arm 9: t_tmp reads [$(v_of ft_tests_t_tmp)], want PASS"
# the control: the same container with the compare column cut out of ALL.csv grades t_ws byte for byte, and must FAIL -- the column is what passes it
C=$T/pkg/ctl; mkdir -p $C; cp $P/* $C/
python3 -c "import csv,sys; r=list(csv.DictReader(open('$P/ALL.csv'))); f=[c for c in r[0].keys() if c!='compare']; w=csv.DictWriter(open('$C/ALL.csv','w',newline=''),f,extrasaction='ignore',lineterminator='\\n'); w.writeheader(); [w.writerow(x) for x in r]"
S4E_PROGRESS_OFF=1 timeout 300 python3 "$HERE/corpus_suite_harness.py" run "$C/ALL.pl" "$C/ALL.ref" --lang prolog --modes m3 > $T/ctl.out 2>&1
S2=$T/pkg/ctl2; mkdir -p $S2; cp $P/* $S2/
python3 -c "import csv,sys; r=list(csv.DictReader(open('$P/ALL.csv'))); f=[c for c in r[0].keys() if c not in ('stage','answer')]; w=csv.DictWriter(open('$S2/ALL.csv','w',newline=''),f,extrasaction='ignore',lineterminator='\\n'); w.writeheader(); [w.writerow(x) for x in r]"
S4E_PROGRESS_OFF=1 timeout 300 python3 "$HERE/corpus_suite_harness.py" run "$S2/ALL.pl" "$S2/ALL.ref" --lang prolog --modes m3 > $T/ctl2.out 2>&1
[ "$(v_of ft_tests_t_sib $T/ctl2.out)" = FAIL ] && [ "$(v_of ft_tests_t_tmp $T/ctl2.out)" = FAIL ] && ok "arm 8/9: control -- without the stage and answer columns t_sib and t_tmp FAIL (the columns are what pass them)" \
  || bad "arm 8/9: control -- without the columns t_sib reads [$(v_of ft_tests_t_sib $T/ctl2.out)], t_tmp [$(v_of ft_tests_t_tmp $T/ctl2.out)], want FAIL FAIL"
[ "$(v_of ft_tests_t_ws $T/ctl.out)" = FAIL ] && ok "arm 6: control -- without the compare column t_ws FAILS (the column is what passes it)" || bad "arm 6: control -- without the column t_ws reads [$(v_of ft_tests_t_ws $T/ctl.out)], want FAIL"
O=$T/pkg/ovf; mkdir -p $O
printf ':- initialization((repeat, write(xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx), nl, fail)).\n' > $O/forever.pl
printf ':- initialization((write(hi), nl, halt)).\n' > $O/once.pl
printf ":- initialization((write('[ModalShowX11Window] Cannot open display'), nl, halt)).\n" > $O/window.pl
S4E_OUTPUT_CAP_MB=1 TIMEOUT=60 python3 "$HERE/util_build_package_suite.py" "$O" --lang prolog --twice > $T/ovf.out 2>&1; orc=$?
if grep -q '^forever: .*bound' $O/ALL.excluded.txt 2>/dev/null && ! grep -q 'forever' $O/ALL.csv 2>/dev/null; then ok "arm 7: an OVERFLOW run is excluded, never absorbed (rc $orc)"
else bad "arm 7: forever.pl was not excluded as an OVERFLOW (rc $orc; ALL.ref $(stat -c %s $O/ALL.ref 2>/dev/null || echo -) bytes)"; fi
if grep -q '^window: .*could not open a display' $O/ALL.excluded.txt 2>/dev/null && ! grep -q 'window' $O/ALL.csv 2>/dev/null; then ok "arm 7b: an oracle's display refusal is no answer, never absorbed"
else bad "arm 7b: window.pl's 'Cannot open display' was absorbed as a ref"; fi
echo "population: 11 fixture programs under xsb-gentest, 3 under the plain prolog builder; the oracle $XSB"
if [ "$fail" != 0 ]; then echo "⛔ GATE FAIL [$GATE_NAME]"; tail -5 $T/build.out | sed 's/^/    build: /'; exit 1; fi
echo "✅ GATE PASS [$GATE_NAME]: XSB's answer is the ref, sorted and checked against NAME_old; an empty or unrun program is excluded; diff -w grades; an OVERFLOW is no answer"
exit 0
