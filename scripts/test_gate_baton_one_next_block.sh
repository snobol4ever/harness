#!/usr/bin/env bash
# test_gate_baton_one_next_block.sh -- every LIVE postoffice baton (a task file whose QUEUE.tsv row is
# not in a terminal state) carries exactly one `## NEXT` heading -- the ONE block `next`'s own printout
# tells every seat to read. Row: baton-one-next-block-gate. Ruling: ceo 2026-08-29, PROTOCOL.md step 4.
# Evidence: FINDING-2026-08-29-hq_B-baton-next-blocks-carry-two-opposite-conventions-and-icons-five-were-
# scrambled-so-the-top-block-was-false.md (9 of 417 files multi-NEXT, incl. tests-consolidate-icon
# scrambled 3-1-2-5-4 on a LIVE rank-1 row).
#
# ⛔ PATTERN CORRECTION (seat03, 2026-08-29): this row's own SCOPE text quotes the check as
# `grep -c '^## NEXT$'` (ANCHORED -- a heading line may carry nothing after the word NEXT). hq_B's own
# FINDING -- the evidentiary basis for the whole row -- measured with `grep -c '^## NEXT'` (UNANCHORED:
# any heading starting "## NEXT" counts, parenthetical or not), and hq_B's own cured reference example,
# tests-consolidate-icon.task.md, has a CURRENT heading reading `## NEXT (CURRENT -- 2026-08-29T...
# seat02, sixth renumbering)`. The anchored pattern does not match that line at all, so building the LAW
# against it would fail the blessed example on its own gate. Built against hq_B's actual (unanchored)
# pattern instead; the SCOPE text's trailing `$` reads as a transcription slip in ceo's brief, not a
# considered stricter spec -- corrected here rather than silently reconciled, per this project's own
# "provenance dies at the moment of transcription" caution.
#
# ⭐ RATCHET, NOT A HARD ==1 (ceo's own scope note, ledger 2026-08-29b): a live corpus this large has
# legacy non-conformance not caused by whoever runs this gate next; a hard bar on day one blocks every
# seat on somebody else's debt. The ceiling may only fall, driven down by the sweep (this row's scope
# item 3), never raised to accommodate a new offender.
#
# Usage: bash ../harness/scripts/test_gate_baton_one_next_block.sh [--selftest]
#   (no args)   scans the real postoffice, prints CHECKED/BAD, exits 0 (<=ratchet) or 1 (>ratchet, names
#               every offender) or 2 (cannot enumerate -- queue/tasks dir missing or zero live topics).
#   --selftest  proves the scan function both ways on synthetic fixtures (RULES.md INSTRUMENT LAWS #2:
#               a criterion must be shown able to say both YES and NO before it is trusted), then exits.
set -uo pipefail

# ===================================================================== SHARED SCANNER (real scan + selftest both call this) ===
count_next_headings() {
  # ⛔ NOT `grep -c ... || printf 0`: `grep -c` on ZERO matches still PRINTS "0" to stdout but exits 1
  # (its "no match" status), so a `||` fallback fires ANYWAY and appends a second "0" line -- caught by
  # this script's own --selftest (a criterion untested for its zero-case is exactly the class this
  # project's INSTRUMENT LAWS warn about). Exit status is deliberately discarded; only the printed count
  # is ever consulted by callers.
  grep -c '^## NEXT' "$1" 2>/dev/null
  return 0
}

live_topics() {  # $1 = QUEUE.tsv path
  awk -F'\t' 'NR>4 && $4 !~ /^(DONE|SUPERSEDED|RETIRED)/ {print $2}' "$1" | sort -u
}

run_scan() {  # $1 = QUEUE.tsv path, $2 = tasks dir -- prints "TOPIC: N" per offender then "CHECKED=x BAD=y"; rc 0/2 only (caller applies the ratchet)
  local q="$1" td="$2" topics topic f n checked=0 bad=0
  [ -f "$q" ] || { echo "⛔ REFUSING: queue file not found: $q" >&2; return 2; }
  [ -d "$td" ] || { echo "⛔ REFUSING: tasks dir not found: $td" >&2; return 2; }
  topics="$(live_topics "$q")"
  [ -n "$topics" ] || { echo "⛔ REFUSING: zero live topics enumerated from $q -- cannot measure" >&2; return 2; }
  while IFS= read -r topic; do
    [ -n "$topic" ] || continue
    checked=$((checked + 1))
    f="$td/$topic.task.md"
    if [ ! -f "$f" ]; then echo "$topic: MISSING (no task file)"; bad=$((bad + 1)); continue; fi
    n=$(count_next_headings "$f")
    [ "$n" -ne 1 ] && { echo "$topic: $n"; bad=$((bad + 1)); }
  done <<<"$topics"
  echo "CHECKED=$checked BAD=$bad"
  return 0
}

# ===================================================================================== § SELF-TEST ===
if [ "${1:-}" = "--selftest" ]; then
  st_rc=0
  check() { if [ "$2" = "$3" ]; then echo "  SELF-TEST OK: $1"; else echo "  SELF-TEST FAIL: $1 -- got [$2] expected [$3]"; st_rc=1; fi; }

  sandbox="$(mktemp -d)"; trap 'rm -rf "$sandbox"' EXIT
  mkdir -p "$sandbox/tasks"
  {
    echo "# header line 1 (ignored, NR>4 skips this)"
    echo "# header line 2"
    echo "# header line 3"
    echo "# rank	topic	owner	state"
    printf '0\tclean-one\tunassigned\tFREE\n'
    printf '0\tdoubled-two\tunassigned\tFREE\n'
    printf '0\tzero-three\tunassigned\tFREE\n'
    printf '0\tannotated-clean\tunassigned\tFREE\n'
    printf '0\tdone-and-doubled\tunassigned\tDONE\n'
    printf '0\tno-file-here\tunassigned\tFREE\n'
  } > "$sandbox/QUEUE.tsv"
  printf '# TASK clean-one\nGOAL: x\n## NEXT\nbody\n' > "$sandbox/tasks/clean-one.task.md"
  printf '# TASK doubled-two\nGOAL: x\n## NEXT\nfirst\n## NEXT\nsecond\n' > "$sandbox/tasks/doubled-two.task.md"
  printf '# TASK zero-three\nGOAL: x\nno heading at all here\n' > "$sandbox/tasks/zero-three.task.md"
  printf '# TASK annotated-clean\nGOAL: x\n## NEXT (CURRENT -- 2026-08-29 seat03, matches the UNANCHORED pattern)\nbody\n' > "$sandbox/tasks/annotated-clean.task.md"
  printf '# TASK done-and-doubled\nGOAL: x\n## NEXT\nfirst\n## NEXT\nsecond\n' > "$sandbox/tasks/done-and-doubled.task.md"
  # no-file-here: deliberately no task file -- live topic, missing baton

  out="$(run_scan "$sandbox/QUEUE.tsv" "$sandbox/tasks")"; rc=$?
  check "scan itself refuses only on structural failure, not on offenders" "$rc" "0"
  check "clean-one not flagged" "$(printf '%s\n' "$out" | grep -c '^clean-one:')" "0"
  check "doubled-two flagged with count 2" "$(printf '%s\n' "$out" | grep '^doubled-two:')" "doubled-two: 2"
  check "zero-three flagged with count 0" "$(printf '%s\n' "$out" | grep '^zero-three:')" "zero-three: 0"
  check "annotated-clean NOT flagged (unanchored pattern matches the parenthetical form)" "$(printf '%s\n' "$out" | grep -c '^annotated-clean:')" "0"
  check "done-and-doubled EXCLUDED (terminal state, not live)" "$(printf '%s\n' "$out" | grep -c '^done-and-doubled:')" "0"
  check "no-file-here flagged as MISSING, not silently skipped" "$(printf '%s\n' "$out" | grep -c '^no-file-here: MISSING')" "1"
  check "CHECKED counts only the 5 live topics (done-and-doubled excluded)" "$(printf '%s\n' "$out" | grep -o 'CHECKED=[0-9]*')" "CHECKED=5"
  check "BAD counts doubled-two + zero-three + no-file-here = 3" "$(printf '%s\n' "$out" | grep -o 'BAD=[0-9]*')" "BAD=3"

  # structural refusals: rc=2, both directions of "cannot enumerate"
  rm -f "$sandbox/QUEUE.tsv"
  run_scan "$sandbox/QUEUE.tsv" "$sandbox/tasks" >/dev/null 2>&1; check "missing QUEUE.tsv -> rc=2" "$?" "2"
  mkdir -p "$sandbox/QUEUE.tsv.d" && : # (placeholder so the next line's queue path exists as a plain empty file)
  printf '# a\n# b\n# c\n# rank\ttopic\towner\tstate\n' > "$sandbox/QUEUE.tsv"   # header only, zero live rows
  run_scan "$sandbox/QUEUE.tsv" "$sandbox/tasks" >/dev/null 2>&1; check "zero live topics -> rc=2" "$?" "2"

  # ratchet application itself, exercised in both directions (a criterion untested for YES is unproven -- INSTRUMENT LAWS #2)
  apply_ratchet() { local bad="$1" ceiling="$2"; [ "$bad" -le "$ceiling" ]; }
  apply_ratchet 3 4; check "bad=3 <= ceiling=4 -> pass (can say YES)" "$?" "0"
  apply_ratchet 5 4; check "bad=5 >  ceiling=4 -> fail (can say NO)" "$?" "1"

  if [ "$st_rc" -ne 0 ]; then echo "SELF-TEST FAIL: do not trust the real-tree scan below."; exit 1; fi
  echo "SELF-TEST: all checks passed."
  exit 0
fi

# ===================================================================================== REAL TREE SCAN ===
cd "$(dirname "$0")/../../SCRIP" || exit 2
PO="${S4E_POST:-/home/resources/postoffice}"
QUEUE="$PO/QUEUE.tsv"
TASKS="$PO/tasks"
# Ceiling measured live 2026-08-29 (seat03), same methodology as this script's own scan, over 183 live
# topics. Started at 4; polyglot-demo-empty-output-rc0 swept the same session (a pure heading rename --
# its own prose already named which of its 2 blocks was current, the heading just didn't say so
# machine-readably) brought it to 3: icon-n2-generator-activation-frames(2) snoflake-suite-scrip-only-
# gap(3) tests-consolidate-prolog(11 -- this row's own SCOPE explicitly defers it: "internally
# consistent but verbose -- convert it LAST and coordinate with its claim holder").
# Override only to WIDEN a gate run against a different/older postoffice snapshot, never to accommodate
# a genuinely new offender -- narrow the sweep instead.
# ⭐ CEILING LOWERED 3 -> 1 (hq_P 2026-08-29, row tests-consolidate-prolog). The header's own law is that it may
# only FALL, driven down by the sweep. Two of the three offenders are gone: `tests-consolidate-prolog` carried 12
# `## NEXT` headers (a pre-rule baton) and its 11 historical blocks are now demoted to `## SUPERSEDED-NEXT`, and
# `array-sum-valgrind-segv` cleared independently. ⛔ The remaining 1 is `picker-lane-restricted-rows-must-be-assigned`,
# which is MISSING a task file entirely -- a different defect (a queue row with no baton), not a NEXT-block one, and
# not repairable by demoting anything. Held at 1 rather than 0 so that row's absence does not block every seat.
RATCHET="${BATON_NEXT_RATCHET:-1}"

out="$(run_scan "$QUEUE" "$TASKS")"; scan_rc=$?
if [ "$scan_rc" -eq 2 ]; then
  printf '%s\n' "$out"
  echo "⛔ REFUSED (rc=2): cannot measure -- see reason above."
  exit 2
fi
printf '%s\n' "$out"
bad="$(printf '%s\n' "$out" | grep -o 'BAD=[0-9]*' | cut -d= -f2)"
if [ "$bad" -gt "$RATCHET" ]; then
  echo "GATE FAILED: $bad non-conforming live baton(s) > ratchet ceiling $RATCHET. Fix the newly-listed offender(s)"
  echo "above, or -- if the ceiling itself was measured wrong -- correct RATCHET in this script with the new count"
  echo "and reasoning. Do NOT raise it to paper over a fresh regression."
  exit 1
fi
echo "GATE OK: $bad non-conforming live baton(s) <= ratchet ceiling $RATCHET."
exit 0
