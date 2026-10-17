#!/usr/bin/env bash
# test_gate_findings_live_in_the_findings_directory.sh -- EVERY TRACKED FINDING LIVES IN .github/findings/ AND NOWHERE ELSE
# (Lon 2026-09-18, in-chat, relayed by the cto: "every FINDING file lives in .github/findings/, NEVER in the .github root"; ceo CEO-859/862/866,
# RULES.md line 31). RENAMED FROM test_gate_no_finding_files.sh, WHICH ENFORCED THE OPPOSITE. That gate implemented CEO-760/796's prohibition;
# Lon retired the prohibition on 2026-09-18 and the gate went RED IN make preflight FOR EVERY SEAT the moment the first permitted FINDING landed
# (the cto's, .github e3b47af1) -- a fleet-wide landing block created by a law change, which is the cost of a gate that encodes a rule's POLARITY
# rather than its INVARIANT. It is repurposed rather than deleted for the same reason the digest gate's arm was flipped rather than dropped: the
# location rule needs policing too, and a deleted gate polices nothing. What it cannot check is the clause that matters most -- that a FINDING's
# measured claims are FOLDED into the citing baton or GOAL cursor in the same landing -- which is why that stays law and gets its own row.
# Cheap, no build: `git ls-files` in .github and SCRIP; population printed; rc=1 names each offender; rc=2 when a repo cannot be listed.
# FAIL_ONCE=1 plants a FINDING at the .github ROOT in a scratch clone and grades that clone, so the criterion is proven to red.
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../.." && pwd)"
# ⛔ SCRIP IS THIS GATE'S OWN REPO, .github S4E_HOME's ELSE THE SIBLING OF THIS CHECKOUT (coo 2026-10-08, CEO-1573): ROOT/SCRIP named
# the directory BESIDE a worktree, so a worktree of any other name refused ("not a git checkout").
GH="${S4E_HOME:-$ROOT}/.github"; SC="$(cd "$HERE/../../SCRIP" && pwd)"
if [ -n "${FAIL_ONCE:-}" ]; then
  W="$(mktemp -d)"; trap 'rm -rf "$W"' EXIT
  git clone -q "$GH" "$W/gh" 2>/dev/null || { echo "⛔ REFUSED-TO-GRADE: could not clone $GH for the planted arm"; exit 2; }
  printf '# planted at the root, which is the thing this gate forbids\n' > "$W/gh/FINDING-2099-01-01-fixture-planted.md"
  git -C "$W/gh" add FINDING-2099-01-01-fixture-planted.md
  GH="$W/gh"
fi
bad=""; n=0; found=0
for repo in "$GH" "$SC"; do
  [ -d "$repo/.git" ] || [ -f "$repo/.git" ] || { echo "⛔ REFUSED-TO-GRADE: $repo is not a git checkout"; exit 2; }
  files="$(git -C "$repo" ls-files 2>/dev/null)" || { echo "⛔ REFUSED-TO-GRADE: git ls-files failed in $repo"; exit 2; }
  n=$((n + $(printf '%s\n' "$files" | grep -c .)))
  hits="$(printf '%s\n' "$files" | grep -E '(^|/)FINDING-[^/]*\.md$' || true)"
  [ -z "$hits" ] && continue
  while IFS= read -r h; do
    [ -n "$h" ] || continue
    found=$((found + 1))
    case "$h" in findings/FINDING-*) ;; *) bad="$bad  $(basename "$repo")/$h"$'\n' ;; esac
  done <<< "$hits"
done
echo "population: $n tracked file(s) examined across .github and SCRIP; $found FINDING file(s) found"
if [ -n "$bad" ]; then
  printf '⛔ GATE RED [findings_live_in_the_findings_directory]: FINDING-*.md outside .github/findings/ (RULES.md line 31, Lon 2026-09-18):\n%s' "$bad"
  echo "  cure: git mv the file into .github/findings/ -- and if its measured claims are not yet in the citing baton or GOAL cursor, fold them there in the SAME landing, because Lon deletes findings periodically."
  exit 1
fi
echo "GATE PASS [findings_live_in_the_findings_directory]: all $found tracked FINDING file(s) are under .github/findings/ ($n files examined)"
