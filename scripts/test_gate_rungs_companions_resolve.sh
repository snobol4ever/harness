#!/usr/bin/env bash
# ../harness/scripts/test_gate_rungs_companions_resolve.sh -- EVERY COMPANION A RUNGS ENTRY NAMES IS BESIDE THE RUNGS.
# AUTHORS: Lon Jones Cherryholmes · Claude Opus 5   DATE: 2026-09-05
#
# ⛔⭐⭐ WHAT THIS GATE ACTUALLY ENFORCES, AND A RETRACTED CLAIM IT USED TO CITE AS ITS REASON. An entry is graded in a
# FRESH temp dir with exactly the files the harness copies in, so a companion that resolves only by luck is a graded
# dependency nobody declared. This gate resolves every named companion against the rungs' DECLARED search path --
# beside the rungs, its config/, and what the harness puts on $SNO_LIB -- and fails when a companion exists in this
# corpus but on none of them.
# ⛔ THE ORIGINAL JUSTIFICATION IS WITHDRAWN BY ITS OWN AUTHOR (hq_T, 2026-09-05 ~14:15 CDT). This header used to say
# "25 snobol4 companions lived in corpus/include/, so 26 entries were graded against dependencies that were not there",
# citing FINDING-2026-09-05-hq_T-companions-live-outside-the-master-directory-so-26-of-31-entries-cannot-resolve-them.md.
# THAT FINDING CARRIES A RETRACTION BANNER: the harness sets SNO_LIB=<corpus>/include on every run
# (corpus_suite_harness.py:137 defines it, :434/:452/:495 pass it), which is exactly where those companions live, so
# they resolved the whole time. The closure TOOL was corrected to count $SNO_LIB; this prose was not, and went on
# telling the retracted story as fact for anyone who read the gate to understand why it exists.
# ⭐ THE STANDING RULE THIS COST US (same day, twice): retracting a finding banners THAT file and does nothing to the
# files citing it, so a dead claim keeps travelling inside its neighbours' headers and correction sections -- the places
# a reader trusts most. When you retract, grep the WHOLE tree, not just .github, and fix every citing sentence.
# ⭐ AND IT NEVER ANNOUNCED ITSELF, which is why this is a GATE and not a note. A missing include is not a special error:
# the entry fails like any other program and its diff reads as a semantic divergence in SCRIP. Two separate lanes reached
# "SCRIP is wrong" from this class in one day, and one of them was about to cure a compiler that was not broken.
#
# NO BUILD NEEDED (pure corpus census, ~0.4s): it never runs a program, only resolves names against declared dirs.
# rc=0 clean · rc=1 a companion exists on the declared path and is not beside the rungs · rc=2 REFUSAL (cannot measure).
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
S4E="${S4E_HOME:-$(cd "$HERE/../.." && pwd)}"
TOOL="$HERE/util_rungs_companion_closure.py"
CORPUS="$S4E/corpus"

refuse() { echo "⛔ GATE REFUSES: $*"; exit 2; }
[ -f "$TOOL" ]     || refuse "the closure tool is missing at $TOOL -- a gate whose instrument is absent has measured nothing"
[ -d "$CORPUS" ]   || refuse "no corpus at $CORPUS"

echo "== rungs companion closure -- every language with a rung suite, against its declared search path"
# ⛔ CAPTURE FIRST, THEN TEST. `tool | tee` would report tee's status and this gate would be green on every refusal
# (CLAUDE.md § the $?-after-a-pipeline trap, measured live on this box).
out="$(python3 "$TOOL" --lang all --corpus "$CORPUS" 2>&1)"; rc=$?
printf '%s\n' "$out"
case "$rc" in
  0) echo "✅ GATE PASS: every companion every rung suite entry names is reachable from that rung suite's own directory."; exit 0;;
  1) echo "⛔ GATE FAIL: at least one entry is graded WITHOUT a companion that exists in this corpus."
     echo "   Every entry naming one of the files above runs with that dependency ABSENT -- it compiles or fails like"
     echo "   any other program and the diff reads as a SCRIP defect. Do not debug the compiler on such an entry."
     echo "   CURE: python3 ../harness/scripts/util_rungs_companion_closure.py --lang <lang> --write   (then re-cut nothing --"
     echo "   the refs were cut when the companions WERE present; supplying them restores the graded program.)"
     exit 1;;
  *) echo "⛔ GATE REFUSES: the closure tool could not measure (rc=$rc) -- an ambiguous basename or a missing rungs."
     echo "   REFUSAL cause=closure-tool-rc-$rc signal=none"
     exit 2;;
esac
