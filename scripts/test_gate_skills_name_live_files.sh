#!/usr/bin/env bash
# test_gate_skills_name_live_files.sh -- EVERY NAME A SKILL SPEAKS IS A LIVE NAME (DESIGN-PLAN skills-complete step 1, the cio 2026-11-07; Lon:
# "fully scrutinize the set of skill files, their granularity, their completeness and accuracy"). The body is util_skill_refs_census.py --check:
# every file, script, bus verb and flag named in .github/skills/*/{SKILL.md,reference.md} exists on the live tree, or is an allowed placeholder with
# its reason in harness/scripts/SKILL_REFS_ALLOW.tsv. rc 0 GREEN, 1 RED (the MISSING lines name each gap), 2 REFUSE (no skills dir or no bus).
# Fail-once: --self-test plants one missing file, one dead verb, one dead flag and one allowed placeholder and reads them (CEO-1680).
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
S4E="${S4E_HOME:-$(cd "$HERE/../.." && pwd)}"
python3 -I "$HERE/util_skill_refs_census.py" --self-test > /dev/null 2>&1 || { echo "REFUSE(2) [test_gate_skills_name_live_files]: the census's own self-test is red; the gate cannot measure"; exit 2; }
out="$(cd "$S4E" && S4E_HOME="$S4E" python3 -I "$HERE/util_skill_refs_census.py" --check 2>&1)"; rc=$?
line="$(printf '%s\n' "$out" | grep -m1 '^SKILL_REFS ')"
printf '%s\n' "$out" | grep '^MISSING ' | head -40 | sed 's/^/    /'
case "$rc" in
    0) echo "SKILL_REFS_BOARD $line (tree $(git -C "$S4E/.github" rev-parse --short=9 HEAD 2>/dev/null)) GATE OK [test_gate_skills_name_live_files]"; exit 0 ;;
    1) echo "SKILL_REFS_BOARD $line (tree $(git -C "$S4E/.github" rev-parse --short=9 HEAD 2>/dev/null)) GATE FAIL [test_gate_skills_name_live_files]: a skill names what the tree does not have"; exit 1 ;;
    *) echo "REFUSE(2) [test_gate_skills_name_live_files]: $(printf '%s\n' "$out" | tail -1)"; exit 2 ;;
esac
