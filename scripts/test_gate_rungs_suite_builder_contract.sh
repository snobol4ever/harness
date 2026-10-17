#!/bin/bash
# test_gate_rungs_suite_builder_contract.sh -- the DONE-WHEN of row master-suite-builder-honours-deferral-contract-and-scopes-absorption (ladder I, rank 1).
#
# ⭐ WHY THIS EXISTS (ceo RULING 2026-09-02 on hq_P's FINDING ff4b0aa2). util_build_rungs_suite.py is the ONLY tool that converts loose corpus files into a graded rungs, and it disagrees
# BY CONSTRUCTION with test_gate_suite_conversion_complete.sh, the gate that polices it: the gate ENFORCES the PENDING.md/KEEP.md deferral contract, and the builder contains ZERO references
# to either filename. ⛔ THE GATE POLICES WHAT THE BUILDER CANNOT SEE -- so there is no supported way to convert the files the gate demands without also absorbing files deliberately deferred
# to other seats' LIVE rows. This gate grades the four requirements the ruling named, one named FAIL line each, so a partial cure reads as a partial cure rather than as a red blob.
#
# ⛔⛔ IT RUNS ENTIRELY IN A SCRATCH TREE AND NEVER OPENS THE REAL RUNGS FOR WRITING -- that is not caution, it is the only way this gate can exist. The defect under test is that PROBING the
# builder WRITES to shared corpus (`--help` alone rebuilt the SNOBOL4 rungs: six files, 2335 insertions / 2344 deletions), so a gate that measured in place would corrupt the tree it grades,
# once per run, on every seat. The recipe is the script's OWN documented one (util_build_rungs_suite.py:31): cp -r corpus/tests/<lang> into a scratch dir, point S4E_HOME at its parent.
# ⭐ The last check re-asserts that the real corpus/tests is byte-clean, so a future refactor that breaks the sandbox is caught HERE rather than by the next seat's confusing dirty tree.
#
# ⛔ REFUSES rc=2 RATHER THAN GRADING A MOVING BASELINE: if corpus/tests is already dirty, "did the builder write?" has no answer, and a gate that cannot measure must not pass what it failed
# to read. ⛔ Do NOT relax a check to make this green -- every FAIL below is reproduced from a measurement, and each names the requirement it grades.
set -u
R="${S4E_HOME:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"   # D-17 PORTABLE-HOME: the SEAT ROOT is derived from THIS script, never a hardcoded seat (hq_C measured 2026-09-02: the old /home/claude_P default graded hq_P's checkout from hq_C's seat)

cd "$R/harness/scripts" 2>/dev/null || { echo "⛔ REFUSED (rc=2): no $R/harness/scripts -- cannot locate the builder"; exit 2; }
B=util_build_rungs_suite.py
[ -f "$B" ] || { echo "⛔ REFUSED (rc=2): $B not found -- nothing to grade"; exit 2; }
git -C "$R/corpus" diff --quiet -- tests/ 2>/dev/null || { echo "⛔ REFUSED (rc=2): corpus/tests is dirty -- a no-op cannot be proven against a moving baseline. Commit or stash first."; exit 2; }
T="$(mktemp -d)" || exit 2
trap 'rm -rf "$T"' EXIT
mkdir -p "$T/corpus/tests" && cp -r "$R/corpus/tests/icon" "$R/corpus/tests/snobol4" "$T/corpus/tests/" || { echo "⛔ REFUSED (rc=2): could not stage the scratch tree"; exit 2; }
snap() { find "$T/corpus/tests" -name 'ALL.*' -type f -exec md5sum {} \; | sort; }
fams() { cut -d, -f4 "$T/corpus/tests/icon/ALL.csv" 2>/dev/null | tail -n +2 | sort -u; }
SYNTH_ABS="zz_contract_gate_synthetic_absorbable"
reset_icon() {
  rm -rf "$T/corpus/tests/icon"; cp -r "$R/corpus/tests/icon" "$T/corpus/tests/icon"
  # ⛔ ARM D'S POPULATION MUST EXIST BY CONSTRUCTION (measured 2026-09-05, row three-master-builder-gates-
  # are-red-at-head): real tests/icon has already gone empty of organic loose absorbable pairs at least
  # twice before this (see arm D's own history above, both times read as "went stale" -- the SAME class of
  # false signal, a THIRD time, is what actually happened here: this whole gate went red the same way).
  # UNPROVEN is the correct verdict on an empty population -- but a check that can never be exercised because
  # its population keeps getting absorbed out from under it is not a gate, it is a coin flip on corpus churn.
  # A synthetic pair, planted fresh into the scratch tree on every reset, guarantees arm D always has exactly
  # one thing to scope --absorb-only against, independent of how much of the real corpus has been absorbed.
  printf 'procedure main()\n    write("contract gate synthetic witness");\nend\n' >"$T/corpus/tests/icon/${SYNTH_ABS}.icn"
  printf 'contract gate synthetic witness\n' >"$T/corpus/tests/icon/${SYNTH_ABS}.ref"
}
F=0
added=""   # bound up front: arm D's UNPROVEN branch (population empty) must not leave arm E's read of $added unbound under `set -u`
# --- A (req 4a) -- a real --help: it exits 0, documents the absorb-side selector, and writes NOTHING. Today the flag is unrecognized, silently ignored, and the run proceeds with defaults.
s="$(snap)"; o="$(S4E_HOME="$T" python3 "$B" --help 2>&1)"; rc=$?
{ [ $rc -eq 0 ] && printf '%s' "$o" | grep -q -- '--absorb-only'; } || { echo "FAIL A (req4): --help must exit 0 and document --absorb-only (got rc=$rc)"; F=1; }
[ "$s" = "$(snap)" ] || { echo "FAIL A (req4): --help MUTATED a rung suite -- for this script the universal 'ask it what it does' gesture is a WRITE TO SHARED CORPUS"; F=1; }
# --- B (req 4b) -- an unknown flag REFUSES rc=2 and writes nothing. sys.argv is parsed by hand (:519-580, no argparse), so today an unrecognized flag falls through to --lang snobol4.
s="$(snap)"; S4E_HOME="$T" python3 "$B" --lang icon --zzz-not-a-flag >/dev/null 2>&1; rc=$?
[ $rc -eq 2 ] || { echo "FAIL B (req4): an unknown flag must REFUSE rc=2, got rc=$rc -- silently ignored, so the run proceeded with defaults"; F=1; }
[ "$s" = "$(snap)" ] || { echo "FAIL B (req4): the unknown-flag run MUTATED a rung suite"; F=1; }
# --- C (req 3) -- VALIDATE BEFORE WRITE: a run that ends rc=2 is a no-op on shared state. Measured today: the rungs goes 534 -> 536 entries and THEN the run refuses, so a REFUSAL must be undone by hand.
# ⛔ WITNESS CHANGED FROM rung36_jcon_scan,rung36_jcon_scan2 TO rung36_jcon_cxprimes (taker, same session req1/2 landed).
# req1's own fix (PENDING.md deferral only blocks while its row is LIVE -- icon-scan-env-value-residue is DONE) plus a
# companion fix (discover_pairs now falls back to a sibling .expected when no .ref exists, which is exactly how
# rung36_jcon_scan[2].icn carry their reference) together make the ORIGINAL witness pair genuinely absorbable+deletable
# -- see arm D, which now legitimately absorbs them via --absorb-only. So --only rung36_jcon_scan,rung36_jcon_scan2 no
# longer refuses at all (rc=0, both files correctly deleted after a correct absorption): a stale premise, not a
# regression -- re-run BEFORE this pair's fix confirms the FAIL reproduces unchanged on that commit. rung36_jcon_cxprimes
# is deferred to icon-coexpression-support-design, which stays LIVE independent of this row, so it is a REFUSAL this
# arm can rely on staying reproducible rather than one that expires the next time someone fixes the thing it names.
reset_icon; s="$(snap)"; S4E_HOME="$T" python3 "$B" --lang icon --only rung36_jcon_cxprimes --delete-absorbed >/dev/null 2>&1; rc=$?
[ "$s" = "$(snap)" ] || { echo "FAIL C (req3): the rc=$rc refusal WROTE the rungs first -- a refusal that has already mutated shared state is not a refusal"; F=1; }
# --- D (req 2) -- --absorb-only scopes ABSORPTION, exactly. Today --only/--family scope only what --delete-absorbed DELETES (the script says so when it refuses), so nothing narrows what is absorbed.
# ⛔⭐⭐ THE WITNESS IS DISCOVERED AT RUNTIME, NEVER HARDCODED -- and that is the whole point of this rewrite (hq_T 2026-09-03, row reopened by ceo audit CEO-172).
# THIS ARM WENT STALE AND READ AS A BUILDER REGRESSION. It named rung36_jcon_scan,rung36_jcon_scan2 literally; corpus 2bb735c7 (2026-09-02 09:25) converted
# both into rung36_all entries 41/42, so they stopped being loose absorbable pairs, so the builder's rc=2 became the CORRECT answer -- and an arm asserting
# rc=0 then accused a correct tool of being broken. The reopen even named two builder commits to bisect; neither was implicated, and a bisect would have
# found nothing. ⛔ THIS IS THE SECOND TIME FOR THIS GATE: arm C above carries the same scar and was fixed the same way, by swapping in another hardcoded
# name. Swapping again would only reset the timer. ⭐ THE REAL DEFECT IS A GATE THAT HARDCODES WITNESS NAMES WHILE POLICING A TOOL WHOSE JOB IS TO CONVERT
# THOSE WITNESSES OUT OF EXISTENCE -- its own subject destroys its fixtures, so any literal name here has an expiry date nobody records.
# The cure asks the BUILDER what is absorbable rather than asserting it: an unscoped run absorbs the full absorbable set (the builder's own notion, not a
# reimplementation of it here -- a gate that recomputed "absorbable" would be agreeing with itself instead of policing), then a scoped run must absorb
# EXACTLY the one family we name out of that set. Immune to corpus churn by construction.
reset_icon; before="$(fams)"
S4E_HOME="$T" python3 "$B" --lang icon >/dev/null 2>&1
absorbable="$(comm -13 <(printf '%s\n' "$before") <(fams))"
# ⛔ ZERO absorbable pairs = THIS ARM CANNOT MEASURE. It must REFUSE, never pass: "the selector scoped correctly" is unprovable when there is nothing to scope.
if [ -z "$absorbable" ]; then
  echo "UNPROVEN D (req2): no loose absorbable pair exists in tests/icon, so --absorb-only cannot be exercised -- this arm REFUSES rather than passing on an empty population"; F=1
else
  pick="$(printf '%s\n' "$absorbable" | head -1)"
  reset_icon; before="$(fams)"
  S4E_HOME="$T" python3 "$B" --lang icon --absorb-only "$pick" >/dev/null 2>&1; rc=$?
  added="$(comm -13 <(printf '%s\n' "$before") <(fams) | tr '\n' ' ' | sed 's/ *$//')"
  [ $rc -eq 0 ] || { echo "FAIL D (req2): --absorb-only must be a supported absorb-side selector (got rc=$rc, asking for the discovered-absorbable family '$pick')"; F=1; }
  [ "$added" = "$pick" ] || { echo "FAIL D (req2): --absorb-only absorbed [$added] but was asked for [$pick] -- the selector does not scope ABSORPTION"; F=1; }
fi
# --- E (req 1) -- the builder READS the deferral contract, and never absorbs a deferred file or another row's live witness. The source check is the "READS" clause; the two greps are the behaviour.
{ grep -q 'PENDING\.md' "$B" && grep -q 'KEEP\.md' "$B"; } || { echo "FAIL E (req1): $B references neither PENDING.md nor KEEP.md -- the gate polices a deferral contract the builder cannot see"; F=1; }
printf '%s\n' "$added" | tr ' ' '\n' | grep -qx 'rung36_jcon_cxprimes' && { echo "FAIL E (req1): absorbed rung36_jcon_cxprimes -- PENDING.md defers it to the LIVE row icon-coexpression-support-design"; F=1; }
printf '%s\n' "$added" | tr ' ' '\n' | grep -qx 'coexpr_gc_stack_witness' && { echo "FAIL E (req1): absorbed coexpr_gc_stack_witness -- the live DONE-WHEN witness of row coexpr-stack-leaves-the-compacting-gc-heap; absorbing it reaches into ANOTHER ROW'S ACCEPTANCE TEST"; F=1; }
# --- the sandbox must not have leaked. A gate that grades "does it write?" by writing is its own defect.
git -C "$R/corpus" diff --quiet -- tests/ || { echo "FAIL: THE REAL corpus/tests WAS MODIFIED -- the scratch-tree sandbox leaked, and this gate corrupted the tree it grades"; F=1; }
[ $F -eq 0 ] && { echo "PASS: util_build_rungs_suite.py honours PENDING.md/KEEP.md, scopes absorption exactly (--absorb-only), validates before it writes, and refuses unknown flags rc=2"; exit 0; }
exit 1
