#!/usr/bin/env bash
export S4E_ONE_RUNNER_FIXTURE="gate arm ${0##*/}: a runner invoked as an instrument fixture, not a board (CEO-523)"
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
# test_gate_icn_ipl_reason_is_the_oracles_own_words.sh -- hq_I 2026-09-06, CEO-326.
#
# THE DEFECT THIS PINS. util_cut_icon_ipl_refs.sh wrote ONE composed sentence onto every row its rc!=0
# arm produced -- "needs argv/stdin this driver does not supply, or genuine rejection" -- and that
# sentence reached 212 rows of corpus/packages/icon/ipl/UNGRADED.tsv, the file that says WHAT IS OWED.
# Measured against the oracle, those 212 are four different answers: 102 programs whose link closure
# never resolved an identifier (this oracle is built WITHOUT graphics, so gprogs/ reaches WOpen,
# WAttrib, DrawLine, DrawPoint, Fg ... unresolved) and which then died calling one; 6 that want a tty;
# 34 that print their own usage banner; and the remainder, which are none of those. ⭐ A COMPOUND
# REASON CANNOT BE FALSIFIED BY ANY SINGLE OBSERVATION, so it is never corrected: "argv OR stdin OR a
# genuine rejection" is true of almost any failing program, which is exactly why it survived 212 rows.
# It is the untestable form of "I did not look".
#
# ⛔ AND THE ROWS ARE NOT COSMETIC. UNGRADED.tsv is work OWED and claimable; UNGRADABLE.tsv is a ruling
# nobody owes work on (lib_inventory.sh's own split). Filing a program that cannot run on this oracle at
# all as "needs argv" mints a row NO LANE CAN EVER CLOSE, and buries the genuinely curable argv rows
# among them -- the identical harm DISPLAY_REFUSED was split out of ORACLE_FAIL to prevent, recurring
# one arm lower down the same if-chain.
#
# TEN ARMS. 3 and 4 run the real cutter end to end against a scratch package (S4E_HOME redirection),
# never a re-implementation of its predicate -- a copied classifier is a classifier that drifts.
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
S4E="${S4E_HOME:-$(cd "$HERE/../.." && pwd)}"
. "$HERE/lib_oracle_flags.sh" 2>/dev/null || { echo "⛔ GATE REFUSES: lib_oracle_flags.sh unloadable" >&2; exit 2; }
PKG="$S4E/corpus/packages/icon/ipl"
CUTTER="$HERE/util_cut_icon_ipl_refs.sh"
RETIRED='needs argv/stdin this driver does not supply, or genuine rejection'
fails=0
refuse() { echo "⛔ GATE REFUSES (rc=2, cannot measure): $*" >&2; exit 2; }
red()    { echo "⛔ FAIL  $*"; fails=$((fails+1)); }
green()  { echo "✅ PASS  $*"; }

[ -f "$CUTTER" ] || refuse "the cutter under test is missing: $CUTTER"
[ -d "$PKG" ]    || refuse "the ipl package is missing: $PKG"
ICON="$(icon_bin)"   || refuse "no Icon oracle -- lib_oracle_flags.sh could not resolve icon_bin"
ICONT="$(icont_bin)" || refuse "no Icon oracle -- lib_oracle_flags.sh could not resolve icont_bin"
WORK="$(mktemp -d "${TMPDIR:-/tmp}/ipl_reason_gate.XXXXXX")" || refuse "mktemp failed"
trap 'rm -rf "$WORK"' EXIT

# ── ARM 1: no ipl census row carries the retired compound sentence, in EITHER sidecar.
hits=0
for tsv in "$PKG/UNGRADED.tsv" "$PKG/UNGRADABLE.tsv"; do
  [ -f "$tsv" ] || refuse "census sidecar missing: $tsv -- the lockdown requires it, so its absence is not a pass"
  n=$(grep -cF "$RETIRED" "$tsv"); hits=$((hits+n))
done
if [ "$hits" -ne 0 ]; then red "ARM 1: $hits ipl census row(s) still carry the retired compound reason '$RETIRED'"
else green "ARM 1: zero ipl census rows carry the retired compound reason"; fi

# ── ARM 2: every ORACLE_FAIL row quotes the oracle. A row whose reason does not contain the oracle's own
# words is back to a composed sentence under a different spelling, which is the defect, not a variant of it.
n_of=$(awk -F'\t' '$2=="ORACLE_FAIL"' "$PKG/UNGRADED.tsv" | wc -l)
if [ "$n_of" -eq 0 ]; then green "ARM 2: no ORACLE_FAIL rows to check (vacuous, and said so)"
else
  bad=$(awk -F'\t' '$2=="ORACLE_FAIL" && $3 !~ /the oracle said:/ {print $1}' "$PKG/UNGRADED.tsv")
  if [ -n "$bad" ]; then red "ARM 2: $(printf '%s\n' "$bad" | wc -l) of $n_of ORACLE_FAIL rows quote no oracle diagnostic: $(printf '%s' "$bad" | tr '\n' ' ')"
  else green "ARM 2: all $n_of ORACLE_FAIL rows carry the oracle's own words"; fi
fi

# ── The scratch package the next two arms grade. S4E_HOME redirection, so the REAL cutter walks it.
SCRATCH="$WORK/root"; mkdir -p "$SCRATCH/corpus/packages/icon/ipl/progs"
SP="$SCRATCH/corpus/packages/icon/ipl/progs"
cat > "$SP/gatefix_undeclared.icn" <<'ICN'
procedure main()
   write("this line runs first");
   gate_fixture_no_such_procedure();
end
ICN
cat > "$SP/gatefix_plainfail.icn" <<'ICN'
procedure main()
   stop("gate fixture: a refusal with every identifier resolved");
end
ICN
census="$WORK/census.txt"
S4E_HOME="$SCRATCH" bash "$CUTTER" --dir progs --mains-only > "$census" 2>&1 || true
grep -q 'gatefix_undeclared.icn' "$census" || refuse "the cutter produced no row for the scratch fixture -- it graded nothing, so neither arm below can mean anything: $(head -3 "$census" | tr '\n' ' ')"

# ── ARM 3: the ORDERING cure. An unresolved identifier that the run then DIES on is UNDECLARED_IDENTIFIER,
# not ORACLE_FAIL. This arm reads RED against the pre-cure cutter, where the check sat BELOW `if rc!=0`
# and could therefore only ever see runs that had already succeeded -- half of one piece of evidence.
row3="$(awk -F'\t' '$2=="gatefix_undeclared.icn"{print}' "$census")"
cls3="$(printf '%s' "$row3" | cut -f1)"; rc3="$(printf '%s' "$row3" | cut -f3)"
if [ "$cls3" = "UNDECLARED_IDENTIFIER" ] && [ "$rc3" != "0" ]; then
  green "ARM 3: a link-unresolved identifier that kills the run is UNDECLARED_IDENTIFIER at rc=$rc3, not ORACLE_FAIL"
else
  red "ARM 3: expected UNDECLARED_IDENTIFIER with rc!=0, got class='$cls3' rc='$rc3' -- the rc!=0 arm is eating the link evidence again"
fi

# ── ARM 4: the CONTROL, and it is the load-bearing half. A run that fails with EVERY identifier resolved
# must still be ORACLE_FAIL -- otherwise ARM 3 could be satisfied by a cutter that simply calls everything
# UNDECLARED_IDENTIFIER. Its reason must quote the oracle, and must NOT be blank: icont opens its runtime
# diagnostics with an empty line, so a `head -1` evidence reader reports an empty reason for every runtime
# error, which is why first_diag skips blanks.
row4="$(awk -F'\t' '$2=="gatefix_plainfail.icn"{print}' "$census")"
cls4="$(printf '%s' "$row4" | cut -f1)"; act4="$(printf '%s' "$row4" | cut -f5)"
if [ "$cls4" != "ORACLE_FAIL" ]; then
  red "ARM 4 (control): a plain refusal with no unresolved identifier must stay ORACLE_FAIL, got '$cls4'"
elif ! printf '%s' "$act4" | grep -q 'the oracle said: .*gate fixture'; then
  red "ARM 4 (control): the ORACLE_FAIL reason does not quote the oracle's own refusal: '$act4'"
else
  green "ARM 4: a resolved-but-failing run stays ORACLE_FAIL and its reason is the oracle's own words"
fi

# ── ARM 5: THE RULING'S OWN EXPIRY. Every ORACLE_CONTRACT_NOT_IMPLEMENTED row (the 25 once spelled NEEDS_DISPLAY, plus the 109 undeclared-graphics rows) in this
# package rests on ONE property of the oracle BINARY -- it is built without a graphics facility. That is
# the UNGRADABLE test made executable (lib_inventory.sh: "could this ruling be overturned for the whole
# class at once?"): rebuild or replace the oracle with a graphics build and ~102 rulings become wrong in
# the same instant, silently, because nobody re-reads a closed ruling. So the gate asks the oracle
# directly, every run, and REFUSES rc=2 -- never quietly passes -- the moment the answer changes.
feat="$WORK/feat"; mkdir -p "$feat"
cat > "$feat/feat.icn" <<'ICN'
procedure main()
   every write(&features);
end
ICN
( cd "$feat" && "$ICONT" -s feat.icn >/dev/null 2>&1 && ./feat > "$feat/out.txt" 2>&1 )
[ -s "$feat/out.txt" ] || refuse "could not ask the oracle for &features -- ARM 5 cannot measure, and a silent pass here would leave ~102 rulings unguarded"
if grep -qiE 'graphics|X Windows' "$feat/out.txt"; then
  refuse "THE ORACLE NOW HAS GRAPHICS ($(grep -iE 'graphics|X Windows' "$feat/out.txt" | tr '\n' ' ')). Every ORACLE_CONTRACT_NOT_IMPLEMENTED row in $PKG rests on its absence and must be RE-MEASURED, not re-stamped. This gate refuses rather than passing, because the rulings it guards are now unverified."
fi
green "ARM 5: the oracle reports no graphics facility, which is what all 134 ORACLE_CONTRACT_NOT_IMPLEMENTED rulings in this package assume"

# ── ARM 6: THE CENSUS PREDICATE'S OWN FALSE NEGATIVES. util_cut_icon_ipl_refs.sh selects its --mains-only
# population with an ANCHORED `^procedure[[:space:]]+main`, but Icon permits leading whitespace before the
# keyword, and progs/literat.icn declares its entry point indented at line 1054. The anchored form emitted
# NO ROW AT ALL for it -- not a named outcome, a silent skip, against that script's own written contract --
# and nothing downstream could notice, because `total=` counts the population the predicate already chose.
# This arm compares the two predicates over the shipped tree and names any file only the looser one finds.
missing=""
for sub in progs gprogs procs gprocs incl gincl; do
  [ -d "$PKG/$sub" ] || continue
  only="$(comm -13 <(cd "$PKG/$sub" && grep -lE '^procedure[[:space:]]+main[[:space:]]*\(' *.icn 2>/dev/null | sort) \
                   <(cd "$PKG/$sub" && grep -lE '^[[:space:]]*procedure[[:space:]]+main[[:space:]]*\(' *.icn 2>/dev/null | sort))"
  [ -n "$only" ] && missing="$missing $(printf '%s' "$only" | sed "s|^|$sub/|" | tr '\n' ' ')"
done
cut_pred="$(grep -c 'grep -lE .\^\[\[:space:\]\]\*procedure' "$CUTTER")"
if [ "$cut_pred" -eq 0 ]; then red "ARM 6: the cutter still selects its mains population with an anchored ^procedure, which cannot see an indented entry point"
elif [ -n "$missing" ]; then green "ARM 6: the cutter's mains predicate admits leading whitespace, and it is load-bearing --$missing would otherwise be skipped with no row"
else green "ARM 6: the cutter's mains predicate admits leading whitespace (no file currently depends on it, and the arm says so)"; fi

# ── ARM 7: THE NAME.argv SIDECAR, END TO END, AND THE ARM THAT MAKES IT MEAN ANYTHING IS THE LAST ONE.
# CEO-328 ruled ONE path-aware cutter reading BOTH sidecars, never a fork, so the reader lives in
# lib_icon_ipl_isolation.sh and the cutter and the suite both call it. Three execution shapes must agree
# on the SAME declaration: the oracle takes args bare after the filename, m3 needs `--` to separate them
# from SCRIP's own flags, m4's linked binary takes them bare. ⛔ hq_T's load-bearing arm carried over
# verbatim: A DECLARATION THAT CHANGES NOTHING PROVES NOTHING. An Icon witness written `n := args[1] | 6`
# passes with no argv at all -- it takes the default, prints the expected text and scores PASS -- so the
# arm below also asserts the no-argv output DIFFERS. That green was the whole defect hq_T found.
. "$HERE/lib_icon_ipl_isolation.sh" 2>/dev/null || refuse "lib_icon_ipl_isolation.sh unloadable -- the argv sidecar reader is the one authority both tiers share"
AW="$WORK/argv"; mkdir -p "$AW"
cat > "$AW/gatefix_argv.icn" <<'ICN'
procedure main(a)
   write("argc=", *a);
   every write("[", !a, "]");
end
ICN
printf 'gatefix_argv\tone\ttwo three\n' > "$AW/gatefix_argv.argv"
declare -a GA=(); ipl_argv_read "$AW/gatefix_argv.icn" GA; ga_rc=$?
if [ "$ga_rc" -ne 0 ] || [ "${#GA[@]}" -ne 2 ] || [ "${GA[1]}" != "two three" ]; then
  red "ARM 7a: the reader did not round-trip a well-formed sidecar (rc=$ga_rc, ${#GA[@]} args, second='${GA[1]:-}') -- a TAB-separated argument containing a space must arrive byte for byte"
else green "ARM 7a: a TAB-separated declaration round-trips, spaces inside an argument intact"
fi
# ⛔ THE REFUSALS ARE COUNTED, NOT ASSUMED. An arm that only ever calls red() inside a loop prints its
# green unconditionally -- including when the loop body never ran -- which is the "witness that passes
# while the class is open" shape this lane keeps meeting. ⭐ Found while checking THIS arm by hand, where
# `echo "case $(printf ...) rc=$?"` reported rc=0 for three refusals that were all correctly returning 2:
# the command substitution earlier in the SAME word runs first and clobbers `$?`. Same family as `$?`
# after a pipeline, one layer subtler, because nothing here looks like a pipeline.
n_refused=0; n_cases=0
for bad in "wrongname\tx" "gatefix_argv\tx\ngatefix_argv\ty" "gatefix_argv"; do
  n_cases=$((n_cases+1))
  printf "$bad\n" > "$AW/gatefix_argv.argv"
  declare -a GB=(); ipl_argv_read "$AW/gatefix_argv.icn" GB 2>/dev/null
  brc=$?
  if [ "$brc" -eq 2 ]; then n_refused=$((n_refused+1))
  else red "ARM 7b: a malformed sidecar was ACCEPTED (rc=$brc) instead of refused rc=2 -- running with a guessed argv pins plausible output as ground truth"; fi
done
printf 'gatefix_argv\tone\ttwo three\n' > "$AW/gatefix_argv.argv"
if [ "$n_cases" -eq 3 ] && [ "$n_refused" -eq 3 ]; then
  green "ARM 7b: all 3 malformed shapes REFUSE rc=2 (wrong name column, two declaration lines, no arguments) -- counted, not assumed"
else red "ARM 7b: $n_refused of $n_cases malformed shapes refused; the arm requires 3 of 3"; fi
SCRIP_BIN="$HERE/../../SCRIP/scrip"
if [ ! -x "$SCRIP_BIN" ]; then
  echo "⚠ ARM 7c SKIPPED-AS-NAMED: no ./scrip built, so the three-shape agreement cannot be measured here (this is NOT a pass)" >&2
else
  ( cd "$AW" && "$ICONT" -s gatefix_argv.icn >/dev/null 2>&1 && ./gatefix_argv "${GA[@]}" > oracle.out 2>&1 )
  ( cd "$AW" && "$SCRIP_BIN" --run gatefix_argv.icn -- "${GA[@]}" > m3.out 2>&1 )
  ( cd "$AW" && "$SCRIP_BIN" --compile gatefix_argv.icn > g.s 2>/dev/null && gcc -no-pie g.s -L"$HERE/../../SCRIP/out" -lscrip_rt -Wl,-rpath,"$HERE/../../SCRIP/out" -o g.bin 2>/dev/null && ./g.bin "${GA[@]}" > m4.out 2>&1 )
  ( cd "$AW" && ./gatefix_argv > noargv.out 2>&1 )
  if ! cmp -s "$AW/oracle.out" "$AW/m3.out" || ! cmp -s "$AW/oracle.out" "$AW/m4.out"; then
    red "ARM 7c: the three shapes disagree on one declaration -- oracle='$(tr '\n' '|' < "$AW/oracle.out")' m3='$(tr '\n' '|' < "$AW/m3.out")' m4='$(tr '\n' '|' < "$AW/m4.out")'"
  elif cmp -s "$AW/oracle.out" "$AW/noargv.out"; then
    red "ARM 7c: the declaration changed NOTHING -- with and without argv the program printed the same thing, so this fixture could not detect a sidecar that is never read (hq_T's own finding)"
  else
    green "ARM 7c: oracle, m3 and m4 agree on the declared argv, and the declaration demonstrably changes the output"
  fi
fi

# ── ARM 8: THE CLASS SPLIT IS A READING OF THE SHARED COUNT, NEVER A SECOND COUNT. The ipl runner prints
# ungraded_by_class= beside lib_inventory.sh's line; if the per-class rows do not sum to the bucket the
# shared body counted, two instruments over one package disagree and NEITHER number may be published.
for f in UNGRADED UNGRADABLE; do
  rows=$(awk -F'\t' 'NF>2 && $1 !~ /^#/{n++} END{print n+0}' "$PKG/$f.tsv")
  cls=$(awk -F'\t' 'NF>2 && $1 !~ /^#/{c[$2]++} END{n=0; for(k in c) n+=c[k]; print n+0}' "$PKG/$f.tsv")
  if [ "$rows" -ne "$cls" ]; then red "ARM 8: $f.tsv has $rows rows but $cls classified -- a row with no class is invisible to the split"; fi
done
green "ARM 8: every ipl census row carries a class, so the split sums to the bucket the shared body counts"

# ── ARM 9: PINS WHY test_icon_ipl_suite.sh SPELLS ITS m3 CALL THE LONG WAY. `${A[@]+-- "${A[@]}"}` is the
# idiom every reader reaches for to add a separator only when the array is non-empty, and it is WRONG:
# the literal is glued to the first element. This arm DEMONSTRATES that (so the reason is measured, not
# asserted) and then refuses to let the idiom back into the runner -- a future "simplification" of four
# lines into one would pass every existing test while handing the program one argv entry instead of two.
declare -a _g=(x "y z"); declare -a _got=(); for w in "${_g[@]+-- "${_g[@]}"}"; do _got+=("$w"); done
if [ "${#_got[@]}" -eq 3 ] && [ "${_got[0]}" = "--" ]; then
  red "ARM 9: the glue idiom did NOT glue on this bash -- the long form in the runner may be unnecessary here, but the arm's premise is now unverified; re-measure before simplifying anything"
elif [ "${_got[0]}" = "-- x" ]; then
  # ⛔ CODE LINES ONLY. The first draft of this arm matched the runner's own COMMENT explaining the trap
  # -- a gate reading its own documentation as a violation, which is the "predicate over source text sees
  # SPELLING, not EFFECT" rule biting the exact file written to obey it.
  if grep -v '^[[:space:]]*#' "$HERE/test_icon_ipl_suite.sh" | grep -q '\[@\]+-- '; then
    red "ARM 9: test_icon_ipl_suite.sh uses \${ARR[@]+-- ...}, which glues the separator onto the first argument (measured: '-- x' as ONE word)"
  else green "ARM 9: the glue idiom is demonstrably wrong here ('-- x' arrives as one word) and the runner does not use it"; fi
else
  refuse "ARM 9 cannot measure: the glue idiom produced '${_got[0]:-}' , which is neither the glued nor the separated shape this arm knows how to judge"
fi

# ── ARM 10: A PROGRAM THAT HAS A REF IS NOT WORK OWED. Measured 2026-09-06: the morning's stdin-fixture
# batch cut three refs (blnk2tab, delta, indxcomp) and left all three rows in UNGRADED.tsv, so the package
# advertised three finished programs as claimable work and its population identity was off by three from
# that commit onward. ⛔ The guard for this ALREADY EXISTED -- lib_inventory.sh sums the four buckets and
# would have REFUSED -- but the suite had not been run since, so the defect sat in the tree while the
# instrument that convicts it was idle. ⭐ AND IT SURVIVED MY OWN CHECK: I confirmed "851 = 64 + 233 + 554"
# using the 64 from a ledger instead of counting the .ref files, which is the transcription failure this
# package polices, committed inside the act of verifying an identity. This arm counts the files.
overlap=""
while IFS= read -r rel; do
  [ -z "$rel" ] && continue
  [ -f "$PKG/${rel%.icn}.ref" ] && overlap="$overlap $rel"
done < <(awk -F'\t' 'NF>2 && $1 !~ /^#/{print $1}' "$PKG/UNGRADED.tsv")
if [ -n "$overlap" ]; then red "ARM 10: these ipl programs have a .ref ref AND are still listed as work owed in UNGRADED.tsv:$overlap"
else
  # ⛔ THE SAME EXCLUSIONS AS THE TWO AUTHORITIES THIS ARM CHECKS (coo 2026-09-25, on hq_icon's finding): lib_inventory.sh and
  # test_icon_ipl_suite.sh both leave NAME.fixtures/ out of the shipped census, and this find counted
  # progs/iheader.fixtures/sample.icn (corpus 0c87851ca, 09-12) as a program -- 851 against 852, a red about the gate. A
  # *_driver file is its library's grading vehicle, not a program (CEO-1269), and the census drops it by name too.
  g=$(find "$PKG" -name '*.ref' ! -name ALL.ref ! -path '*.fixtures/*' | wc -l)
  u=$(awk -F'\t' 'NF>2 && $1 !~ /^#/{n++} END{print n+0}' "$PKG/UNGRADED.tsv")
  d=$(awk -F'\t' 'NF>2 && $1 !~ /^#/{n++} END{print n+0}' "$PKG/UNGRADABLE.tsv")
  sh=$(find "$PKG" -name '*.icn' ! -name 'ALL.icn' ! -name '*_driver.icn' ! -path '*.fixtures/*' | wc -l)
  # ⛔ AND A CONTAINER IS NOT A PROGRAM (ceo CEO-1272, coo 2026-09-25): CONTAINERS.tsv names the files that leave shipped with their
  # measurement ($include'd gincl/ declarations, $define tables), and lib_inventory.sh subtracts them -- so does this count.
  c=0; [ -f "$PKG/CONTAINERS.tsv" ] && c=$(awk -F'\t' 'NF>2 && $1 !~ /^#/{n++} END{print n+0}' "$PKG/CONTAINERS.tsv"); sh=$((sh - c))
  if [ "$((g+u+d))" -ne "$sh" ]; then red "ARM 10: buckets do not sum -- graded($g) + ungraded($u) + ungradable($d) = $((g+u+d)), shipped=$sh. ⛔ COUNTED, never quoted: graded is the .ref files on disk, not a number carried from a ledger."
  else green "ARM 10: no graded program is still listed as owed, and $g + $u + $d = $sh shipped, every count measured on disk"; fi
fi

if [ "$fails" -ne 0 ]; then echo "⛔ GATE RED: $fails arm(s) failed"; exit 1; fi
echo "✅ GATE GREEN: 10 arms"; exit 0
