#!/usr/bin/env bash
export S4E_ONE_RUNNER_FIXTURE="gate arm ${0##*/}: the Arizona and Jcon runners invoked on scratch packages as instrument fixtures, not boards (CEO-1272, CEO-523)"
# test_gate_icon_runners_grade_the_preprocess_only_contract.sh -- THE tpp CONTRACT, HELD BY BOTH ICON RUNNERS (hq_icon, SCRIP 999a62f58:
# icont's ipp.c ported whole, scrip -E prints what icont -E prints; coo 2026-09-25, the naming hq_icon accepted 21:0x). Upstream grades
# tpp by preprocessing, never by running it: `icont -E tpp.icn tpp9.icn`, stderr then stdout, byte for byte, exit 1 by design.
# PREPROCESS.tsv names each contract (program<TAB>argv<TAB>rc) and STEM.E.ref beside the program holds icont -E's stderr then stdout.
# Every argv file is a program graded by the one run; the fragment it $includes is a CONTAINER (CONTAINERS.tsv, CEO-1272).
# ARMS, on a scratch package whose ref is cut live from icont -E (pp.icn $includes frag.icn and raises a deliberate $error, rc 1;
# pp2.icn is the contract's second argv): (1) arizona grades both argv programs PASS in both modes, the fragment out of shipped;
# (2) jcon does the same for a one-file contract; (3) one byte changed in the ref reads FAIL in both runners, never PASS; (4) a
# contract with no .E.ref refuses rc 2; (5) an argv program that also carries its own .ref refuses rc 2 (two vehicles).
# ⛔ FAILED ONCE (measured at the landing): on the runners before the contract, arm 1 reads shipped=2 graded=0 and arm 2 graded=0.
# EXIT 0 every arm holds; 1 an arm is red; 2 REFUSED (icont missing or the fixture could not be cut -- nothing measured).
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)"
. "$HERE/lib_oracle_flags.sh" 2>/dev/null || { echo "⛔ REFUSED(2): lib_oracle_flags.sh unloadable"; exit 2; }
ICONT="$(icont_bin 2>/dev/null)"; [ -n "$ICONT" ] && [ -x "$ICONT" ] || { echo "⛔ REFUSED(2): icont missing -- the contract's ref cannot be cut"; exit 2; }
SCRATCH="${S4E_SCRATCH:-$(cd "$ROOT/.." && pwd)/.scratch}"; mkdir -p "$SCRATCH" || { echo "⛔ REFUSED(2): cannot create $SCRATCH"; exit 2; }
T="$(mktemp -d "$SCRATCH/gate_ppc_XXXXXX")" || { echo "⛔ REFUSED(2): mktemp failed"; exit 2; }; trap 'rm -rf "$T"' EXIT
export S4E_SCORE_NO_WRITE="gate fixture ${0##*/}: a scratch package, never a board"
fails=0; checks=0
ck() { checks=$((checks+1)); if [ "$1" = ok ]; then printf '  ok    %s\n' "$2"; else printf '  FAIL  %s\n' "$2"; fails=$((fails+1)); fi; }
bf() { local f="$1" b="$2" l kv; shift 2; l="$(grep -m1 "^$b " "$f")" || return 1; for kv in "$@"; do grep -qE "(^| )$kv( |\$)" <<<"$l" || return 1; done; }
hdr='# fixture\n# name<TAB>CLASS<TAB>reason\n'
F="$T/src"; mkdir -p "$F"
printf '$define GREETING "hi"\n$include "frag.icn"\nprocedure main()\n   write(GREETING)\nend\n$error deliberate\n' > "$F/pp.icn"
printf '# a fragment\nglobal g\n' > "$F/frag.icn"
printf '$ifdef GREETING\nx\n$endif\nprocedure q()\nend\n' > "$F/pp2.icn"
( cd "$F" && "$ICONT" -E pp.icn pp2.icn > io2.out 2> io2.err; echo $? > rc2; "$ICONT" -E pp.icn > io1.out 2> io1.err; echo $? > rc1 ) </dev/null
cat "$F/io2.err" "$F/io2.out" > "$F/pp.E.ref2"; cat "$F/io1.err" "$F/io1.out" > "$F/pp.E.ref1"; RC2="$(cat "$F/rc2")"; RC1="$(cat "$F/rc1")"
grep -q 'explicit \$error' "$F/pp.E.ref2" && grep -q '#line 0 "frag.icn"' "$F/pp.E.ref2" && [ "$RC2" = 1 ] || { echo "⛔ REFUSED(2): icont -E did not preprocess the fixture as expected (rc=$RC2)"; exit 2; }
mk_ariz() {  # <dir> <ref> -- an arizona_tests package under <dir>/corpus/packages/icon with the two-file contract
  local P="$1/corpus/packages/icon/arizona_tests"; mkdir -p "$P/general" "$P/special"
  cp "$F/pp.icn" "$F/pp2.icn" "$F/frag.icn" "$P/general/"; cp "$2" "$P/general/pp.E.ref"
  printf "$hdr" > "$P/UNGRADED.tsv"; printf "$hdr" > "$P/UNGRADABLE.tsv"
  printf 'general/pp.icn\tpp.icn pp2.icn\t%s\n' "$RC2" > "$P/PREPROCESS.tsv"
  printf 'general/frag.icn\tINCLUDED_BY\tgeneral/pp.icn -- its $include splices it (gate fixture)\n' > "$P/CONTAINERS.tsv"
}
mk_jcon() {  # <dir> <ref> -- a flat jcon package with the one-file contract
  mkdir -p "$1"; cp "$F/pp.icn" "$F/frag.icn" "$1/"; cp "$2" "$1/pp.E.ref"
  printf "$hdr" > "$1/UNGRADED.tsv"; printf "$hdr" > "$1/UNGRADABLE.tsv"
  printf 'pp.icn\tpp.icn\t%s\n' "$RC1" > "$1/PREPROCESS.tsv"
  printf 'frag.icn\tINCLUDED_BY\tpp.icn -- its $include splices it (gate fixture)\n' > "$1/CONTAINERS.tsv"
}
ariz() { S4E_HOME="$1" S4E_PROGRESS_DB="$1.tsv" timeout -k 5 600 bash "$HERE/test_icon_arizona_suite.sh" > "$1.out" 2>&1; }
jcon() { S4E_PROGRESS_DB="$1.tsv" timeout -k 5 600 bash "$HERE/test_icon_jcon_suite.sh" --corpus "$1" > "$1.out" 2>&1; }

mk_ariz "$T/a1" "$F/pp.E.ref2"; ariz "$T/a1"
grep -q 'binary older than the tree\|GATE UNPROVEN(2)' "$T/a1.out" && { echo "⛔ REFUSED(2): the runner could not measure (stale or unbuilt binary): $(grep -m1 'UNPROVEN\|older' "$T/a1.out" | cut -c1-160) -- make, then re-run"; exit 2; }
bf "$T/a1.out" ARIZONA_SUITE_BOARD shipped=2 graded=2 gap=0 m3_pass=2 m4_pass=2 && grep -q 'verdict=PASS' "$T/a1.out" && bf "$T/a1.out" PACKAGE_INVENTORY shipped=2 containers=1 \
  && ck ok "(1) arizona: scrip -E pp.icn pp2.icn equals icont -E byte for byte at rc $RC2 -- both argv programs PASS in both modes, the fragment out of shipped" \
  || ck no "(1) arizona: $(grep -m1 '^ARIZONA_SUITE_BOARD' "$T/a1.out" | cut -c1-120) :: $(grep -m1 'PREPROCESS_CONTRACT\|REFUSE' "$T/a1.out" | cut -c1-140)"
mk_jcon "$T/j1" "$F/pp.E.ref1"; jcon "$T/j1"
bf "$T/j1.out" JCON_SUITE_BOARD shipped=1 graded=1 gap=0 m3_pass=1 m4_pass=1 && [ "$(grep -c 'PREPROCESS_CONTRACT.*verdict=PASS' "$T/j1.out")" = 2 ] \
  && ck ok "(2) jcon: scrip -E pp.icn equals icont -E at rc $RC1 -- PASS in both modes, each mode's pass running the contract itself" \
  || ck no "(2) jcon: $(grep -m1 '^JCON_SUITE_BOARD' "$T/j1.out" | cut -c1-120) :: $(grep -m1 'PREPROCESS_CONTRACT\|REFUSE' "$T/j1.out" | cut -c1-140)"
{ cat "$F/pp.E.ref2"; printf 'X'; } > "$F/bad2"; { cat "$F/pp.E.ref1"; printf 'X'; } > "$F/bad1"   # one byte more, so neither can read equal
mk_ariz "$T/a3" "$F/bad2"; ariz "$T/a3"; mk_jcon "$T/j3" "$F/bad1"; jcon "$T/j3"
bf "$T/a3.out" ARIZONA_SUITE_BOARD m3_pass=0 m4_pass=0 && grep -q 'verdict=FAIL' "$T/a3.out" && bf "$T/j3.out" JCON_SUITE_BOARD m3_pass=0 m4_pass=0 \
  && ck ok "(3) one changed byte in the ref reads FAIL in both runners and both modes -- the compare is byte for byte" \
  || ck no "(3) a wrong ref: $(grep -m1 '^ARIZONA_SUITE_BOARD' "$T/a3.out" | cut -c1-90) :: $(grep -m1 '^JCON_SUITE_BOARD' "$T/j3.out" | cut -c1-90)"
mk_ariz "$T/a4" "$F/pp.E.ref2"; rm "$T/a4/corpus/packages/icon/arizona_tests/general/pp.E.ref"; ariz "$T/a4"; r4a=$?
mk_jcon "$T/j4" "$F/pp.E.ref1"; rm "$T/j4/pp.E.ref"; jcon "$T/j4"; r4j=$?
[ "$r4a" = 2 ] && grep -q 'is not beside it' "$T/a4.out" && [ "$r4j" = 2 ] && grep -q 'is not beside it' "$T/j4.out" \
  && ck ok "(4) a contract with no .E.ref refuses rc 2 in both runners -- a contract with no oracle cut" || ck no "(4) no .E.ref: arizona rc=$r4a jcon rc=$r4j"
mk_ariz "$T/a5" "$F/pp.E.ref2"; printf 'x\n' > "$T/a5/corpus/packages/icon/arizona_tests/general/pp2.ref"; ariz "$T/a5"; r5a=$?
mk_jcon "$T/j5" "$F/pp.E.ref1"; printf 'x\n' > "$T/j5/pp.ref"; jcon "$T/j5"; r5j=$?
[ "$r5a" = 2 ] && grep -q 'two grading vehicles' "$T/a5.out" && [ "$r5j" = 2 ] && grep -q 'two grading vehicles' "$T/j5.out" \
  && ck ok "(5) an argv program carrying its own .ref refuses rc 2 in both runners -- two vehicles for one program" || ck no "(5) own .ref: arizona rc=$r5a jcon rc=$r5j"
echo "population: $checks arm(s) over 2 runners -- a two-file and a one-file contract, refs cut live from icont -E (rc $RC2 and $RC1), one byte-mutated ref, two refusal shapes"
if [ "$fails" = 0 ]; then echo "GATE PASS(0) [icon_runners_grade_the_preprocess_only_contract]: $checks of $checks arms hold"; exit 0; fi
echo "⛔ GATE FAIL(1) [icon_runners_grade_the_preprocess_only_contract]: $fails of $checks arms red"; exit 1
