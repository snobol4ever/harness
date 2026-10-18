#!/usr/bin/env bash
# test_gate_monitor_run_runs_its_subject_in_a_scratch_mirror.sh -- monitor_run.sh runs its subject in a scratch mirror of the
# subject's own directory, never in the caller's cwd (coo 2026-09-25, on hq_pascal's measurement: fpc_tests' test_tisobuf2,
# test_tisobuf3 and test_tisoread, monitored from SCRIP/, left testfile, textfile and tisoread.tmp in SCRIP/, the tree read dirty
# and the PAT runner skipped its SCORE row).
# THE WITNESS reads a companion file beside it and writes a new file, both by relative name, and is monitored from a
# scratch "caller" directory. Four arms:
#   (a) --trace: the relative read resolves against the program's directory ("read: hello companion")
#   (b) --modes: a verdict is reached (AGREE, m3 against m4)
#   (c) no file the subject wrote lands in the caller's directory
#   (d) none lands in the program's directory either -- the mirror is scratch, and it dies with the run
# ⭐ FAIL-ONCE IS BUILT IN, EVERY RUN: the same arms grade monitor_run.sh at the parent of the commit that introduced the mirror
# (found with `git log -S` in this tree's history). It must red (a) and (c) and hold (b) and (d) -- the old script read the
# companion from the caller and wrote there.
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)" || { echo "REFUSE(2): no SCRIP beside harness at $HERE/../../SCRIP (a port root) -- this gate measures SCRIP and cannot from here"; exit 2; }
. "$HERE/lib_gate.sh" || { echo "REFUSED(2): cannot load lib_gate.sh"; exit 2; }; GATE_NAME=monitor_run_runs_its_subject_in_a_scratch_mirror
gate_require_fresh "$ROOT" src "$ROOT/scrip" || exit 2   # a stale binary is a refusal, never a verdict (test_gate_runners_refuse_on_a_stale_binary.sh census #2)
[ -x "$ROOT/scrip" ] || { echo "⛔ REFUSED(2): no $ROOT/scrip -- run make"; exit 2; }
T="$(mktemp -d)" || { echo "⛔ REFUSED(2): mktemp failed"; exit 2; }; trap 'rm -rf "$T"' EXIT
cc=$(git -C "$ROOT" log --format=%h -1 -S'SCRATCH MIRROR OF ITS OWN DIRECTORY' -- ../harness/scripts/monitor_run.sh)
[ -n "$cc" ] || { echo "⛔ REFUSED(2): the mirror's commit is not in this tree's history -- nothing to fail once against"; exit 2; }
git -C "$ROOT" show "$cc^:../harness/scripts/monitor_run.sh" > "$T/old_monitor_run.sh" || { echo "⛔ REFUSED(2): cannot read monitor_run.sh at $cc^"; exit 2; }
S4E_ROOT="$(cd "$ROOT/.." && pwd)"

grade() {   # grade <monitor_run.sh> <label> -- one "ARM <name> ok|RED" line per arm
  local m="$1" d="$T/$2"; mkdir -p "$d/prog" "$d/caller"
  printf 'hello companion\n' > "$d/prog/companion.txt"
  printf "\tINPUT(.C, 8, 'companion.txt')\n\tOUTPUT(.F, 7, 'made.txt')\n\tF = 'written'\n\tOUTPUT = 'read: ' C\nEND\n" > "$d/prog/w.sno"
  local tr md
  tr="$(cd "$d/caller" && S4E_HOME="$S4E_ROOT" timeout -k 5 120 bash "$m" "$d/prog/w.sno" --trace 2>&1)"
  md="$(cd "$d/caller" && S4E_HOME="$S4E_ROOT" timeout -k 5 300 bash "$m" "$d/prog/w.sno" --modes 2>&1)"
  printf '%s\n%s\n' "$tr" "$md" > "$T/$2.out"
  grep -q '^read: hello companion$' <<<"$tr" && echo "ARM a_relative_read ok" || echo "ARM a_relative_read RED"
  grep -q '^\[monitor_run\] AGREE' <<<"$md" && echo "ARM b_verdict ok" || echo "ARM b_verdict RED"
  [ -e "$d/caller/made.txt" ] && echo "ARM c_caller_clean RED" || echo "ARM c_caller_clean ok"
  [ -e "$d/prog/made.txt" ] && echo "ARM d_program_dir_clean RED" || echo "ARM d_program_dir_clean ok"
}
new=$(grade "$HERE/monitor_run.sh" new); old=$(grade "$T/old_monitor_run.sh" old)
fails=0
echo "=== gate: monitor_run.sh runs its subject in a scratch mirror of the subject's directory ==="
printf '%s\n' "$new" | sed 's/^/    /'
bad=$(printf '%s\n' "$new" | grep -c ' RED$')
[ "$bad" = 0 ] || { fails=$((fails+1)); echo "  FAIL: $bad arm(s) red on monitor_run.sh -- its output:"; sed 's/^/      /' "$T/new.out" | tail -12; }
want="a_relative_read c_caller_clean"
got=$(printf '%s\n' "$old" | awk '$3=="RED"{print $2}' | LC_ALL=C sort | tr '\n' ' ' | sed 's/ $//')
echo "  the old script ($cc^), the built-in fail-once: red on [$got]; must be exactly [$want]"
[ "$got" = "$want" ] || { fails=$((fails+1)); echo "  FAIL: the arms the old script reds are not the arms the cure changed"; sed 's/^/      /' "$T/old.out" | tail -8; }
if [ "$fails" = 0 ]; then echo "GATE PASS(0) [monitor_run_runs_its_subject_in_a_scratch_mirror]: 4 arms green, and the old script reds exactly the 2 the cure changed"; exit 0; fi
echo "⛔ GATE FAIL(1) [monitor_run_runs_its_subject_in_a_scratch_mirror]: $fails check(s) failed"; exit 1
