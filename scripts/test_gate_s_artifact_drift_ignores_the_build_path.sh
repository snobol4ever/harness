#!/usr/bin/env bash
# test_gate_s_artifact_drift_ignores_the_build_path.sh
# (coo 2026-09-08, ceo's TWENTIETH INSTRUMENT-LAW BATCH; the gate shape the ceo ordered in the
#  same landing as the cure, taken from the coo's own FINDING of the same evening.)
#
# ⛔ THE DEFECT, WHICH BLOCKED EVERY SEAT'S HANDOFF FROM 2026-08-30 UNTIL IT WAS MEASURED.
# util_verify_s_artifacts_owed.sh checks for .s drift by rebuilding the artifacts IN A DISPOSABLE
# CLONE and asking whether the regen committed anything there. But an emitted .s carries its own
# SOURCE PATHNAME in its `.file` directive, so an artifact built at /tmp/verify_s_owed.XXXX/corpus/...
# can NEVER equal one built at /home/<seat>/corpus/... . All 23 prolog_bench artifacts differed for
# that reason and no other -- exactly two changed lines per file -- so the verifier reported 23 OWED
# on a tree that was current, and would have reported it forever. Regenerating cannot fix it, because
# regenerating is not what it is asking for.
#
# ⭐ THE LAW: an engine handed two spellings of one source produces two outputs that cannot be
# compared; a comparison whose two sides were produced at different PATHS is comparing the path.
# Corollary, and the reason this gate exists: any instrument that REBUILDS ELSEWHERE to check for
# drift must first prove it reports CLEAN on input known to be current.
#
# ⛔ WHY THIS GATES THE DISCRIMINATOR AND NOT THE WHOLE TREE. The obvious gate -- "clone the corpus
# elsewhere and assert the verifier says CLEAN" -- cannot be written honestly, because the tree
# legitimately carries REAL drift whenever codegen lands (43 real items the evening this was written,
# which the ceo has PARKED until SNOBOL4 is 100%). Such a gate would red for a true reason and be
# muted, and a muted check is worse than no check. So the population is the discriminator itself,
# `files_with_real_drift`, exercised on scratch git repos under mktemp: hermetic, needs no compiler,
# and asks exactly the question the defect got wrong.
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
V="$HERE/util_verify_s_artifacts_owed.sh"
[ -f "$V" ] || { echo "⛔ REFUSE(rc=2): $V missing -- cannot measure, which is never green"; exit 2; }
grep -q '^files_with_real_drift()' "$V" || { echo "⛔ REFUSE(rc=2): $V no longer defines files_with_real_drift -- this gate is grading a function that is gone, which must never read green"; exit 2; }
grep -q '^_s_norm_build_path()' "$V" || { echo "⛔ REFUSE(rc=2): $V no longer defines _s_norm_build_path -- the build-path rule this gate is named for is gone, and every arm below would report drift for a reason none of them names"; exit 2; }

# Source ONLY the helper, never the script: running the verifier here would rebuild the world.
W="$(mktemp -d)"; trap 'rm -rf "$W"' EXIT
# ⛔ BOTH halves of the discriminator, or this gate grades a function whose normaliser is undefined and
# every arm silently reports drift. _s_norm_build_path is where the build-path rule now LIVES.
sed -n '/^_s_norm_build_path()/,/^}/p;/^files_with_real_drift()/,/^}/p' "$V" > "$W/helper.sh"
. "$W/helper.sh"

R="$W/repo"; mkdir -p "$R"; git -C "$R" init -q 2>/dev/null
git -C "$R" config user.email a@b.c; git -C "$R" config user.name t
mk() { printf '\t.text\n\t.file\t1 "%s"\n\tmovq\t$%s, %%rax\n\tret\n' "$1" "$2" > "$R/a.s"; }

mk "/home/seat/corpus/bench/a.pl" 1
git -C "$R" add a.s >/dev/null 2>&1; git -C "$R" commit -qm base >/dev/null 2>&1
PRE="$(git -C "$R" rev-parse HEAD)"

RED=0; ARMS=0
arm() { # $1=label $2=expected(empty|a.s) $3=actual
    ARMS=$((ARMS+1))
    if [ "$3" = "$2" ]; then echo "  ✓ $1"
    else echo "  ⛔ $1 -- expected [$2], got [$3]"; RED=$((RED+1)); fi
}

echo "== test_gate_s_artifact_drift_ignores_the_build_path =="
echo "   population: the files_with_real_drift discriminator, 7 arms over scratch git repos under mktemp (no compiler, no rebuild)"

# ARM 1 — POSITION-ONLY: only the .file directive moved. NOT drift.
mk "/tmp/verify_s_owed.XXXX/corpus/bench/a.pl" 1
git -C "$R" commit -aqm pathonly >/dev/null 2>&1; POST="$(git -C "$R" rev-parse HEAD)"
arm "arm 1: a .file-only change is NOT reported as drift" "" "$(files_with_real_drift "$R" "$PRE" "$POST")"

# ARM 2 — DETECTOR PROOF: the RAW check the verifier used to do must still call arm 1's case drift.
# Without this, arm 1 would pass on a discriminator that reports nothing about anything.
raw="$(git -C "$R" diff --name-only "$PRE" "$POST")"
arm "arm 2: the raw name-only check DOES call it drift, so arm 1 is discriminating and not just silent" "a.s" "$raw"

# ARM 3 — REAL DRIFT IS STILL REPORTED IN FULL. The discount must be narrow or it is a hiding
# mechanism: an instruction changed, at the SAME path.
git -C "$R" checkout -q "$PRE" -- a.s; git -C "$R" commit -aqm back >/dev/null 2>&1
PRE2="$(git -C "$R" rev-parse HEAD)"
mk "/home/seat/corpus/bench/a.pl" 999
git -C "$R" commit -aqm realdrift >/dev/null 2>&1; POST2="$(git -C "$R" rev-parse HEAD)"
arm "arm 3: a real codegen change at the same path IS reported as drift" "a.s" "$(files_with_real_drift "$R" "$PRE2" "$POST2")"

# ARM 4 — THE MIXED CASE, and it is the one a lazy discount gets wrong: the path moved AND an
# instruction moved. A file must never be discounted because SOME of its change was positional.
mk "/tmp/verify_s_owed.YYYY/corpus/bench/a.pl" 777
git -C "$R" commit -aqm mixed >/dev/null 2>&1; POST3="$(git -C "$R" rev-parse HEAD)"
arm "arm 4: path moved AND an instruction moved is STILL drift (a partial discount would hide it)" "a.s" "$(files_with_real_drift "$R" "$POST2" "$POST3")"


# ⛔⭐⭐ ARMS 5-7 -- THE PATH IS NOT ONLY IN THE `.file` DIRECTIVE, AND THAT IS WHY THIS GATE EXISTED WHILE
# THE BUG SURVIVED (hq_T on hq_P's 2026-09-09 report). Arms 1-4 all move the path inside a `.file` line, so
# they passed against a discriminator that discounted `.file` AND NOTHING ELSE -- while this gate's own NAME
# claims the general property. THE NAME STATED THE PROPERTY, THE CODE IMPLEMENTED ONE INSTANCE, and the
# arms only ever exercised that instance. ⛔ MEASURED ON THE REAL CORPUS: 43 committed .s carry an absolute
# seat root, 43 times in `.file` and ~180 more times in PROGRAM DATA -- `.Lassign_α_361_1_s: .string
# "/home/claude_cto/corpus/benchmarks/icon/ipxref.icn"`. A .string is not a directive, so the owed check
# reported those artifacts OWED in every root but the one that regenerated last: a PERMANENT PING-PONG
# blocking whichever seat did not go last, on a check that is blocking since 2026-08-30.
mks() { printf '\t.text\n\t.file\t1 "%s/b/a.icn"\n.Lassign_x_1_s:\n\t.string\t"%s/b/a.icn"\n\tmovq\t$%s, %%%%rax\n\tret\n' "$1" "$1" "$2" > "$R/a.s"; }
mks "/home/claude_cto/corpus" 1
git -C "$R" commit -aqm strbase >/dev/null 2>&1; SPRE="$(git -C "$R" rev-parse HEAD)"
mks "/home/claude_P/corpus" 1
git -C "$R" commit -aqm strpath >/dev/null 2>&1; SP1="$(git -C "$R" rev-parse HEAD)"
arm "arm 5: a root path inside PROGRAM DATA (.string) is NOT drift -- the ping-pong case" "" "$(files_with_real_drift "$R" "$SPRE" "$SP1")"

# ⛔ THE DETECTOR PROOF FOR ARM 5, and it is the arm that proves the bug was real rather than argued: the
# OLD `.file`-only rule must STILL call arm 5's case drift. Without it, arm 5 passes over nothing.
_old_rule="$(git -C "$R" diff -U0 "$SPRE" "$SP1" -- a.s | grep -E '^[+-]' | grep -vE '^(\+\+\+|---)' \
            | grep -qvE '^[+-][[:space:]]*\.file[[:space:]]' && echo a.s)"
arm "arm 6: the OLD .file-only rule DOES call arm 5 drift, so arm 5 is discriminating and the bug was real" "a.s" "$_old_rule"

# ⛔⭐ ARM 7 -- THE FALSE NEGATIVE THE CURE MUST NOT TRADE FOR THE FALSE POSITIVE. Normalising both sides
# and comparing them invites a `sort`, and a sorted compare calls a pure REORDERING of instructions clean.
# A reordering is real drift. The sequences are compared AS SEQUENCES, and this arm is what holds that.
printf '\t.text\n\t.file\t1 "/home/claude_P/corpus/b/a.icn"\n.Lassign_x_1_s:\n\t.string\t"/home/claude_P/corpus/b/a.icn"\n\tret\n\tmovq\t$1, %%rax\n' > "$R/a.s"
git -C "$R" commit -aqm reorder >/dev/null 2>&1; SP2="$(git -C "$R" rev-parse HEAD)"
arm "arm 7: a pure REORDERING at an unchanged path is STILL drift (a sorted compare would hide it)" "a.s" "$(files_with_real_drift "$R" "$SP1" "$SP2")"

echo "-- population: $ARMS arms over 7 scratch commits, $RED red"
[ "$RED" -eq 0 ] || { echo "⛔ GATE RED: $RED of $ARMS arms"; exit 1; }
echo "✅ GATE OK: $ARMS/$ARMS arms -- .s drift is measured on content, never on the path it was built at"
