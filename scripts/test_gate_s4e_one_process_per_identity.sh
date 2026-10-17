#!/usr/bin/env bash
# test_gate_s4e_one_process_per_identity.sh -- ONE PROCESS PER IDENTITY on the postoffice bus. Row
# bus-refuses-a-second-live-process-under-one-seat-identity (ceo ruling 2026-09-03, on hq_B's routing of seat11's
# measurement 16:40: /home/claude11 held TWO live claude processes at once -- an interactive session and a scheduled
# routine `claude --name Fleet #11 --model claude-sonnet-5 --effort max`, per .claude/scheduled_tasks.lock). LAW 6
# derives identity from the ROOT PATH, so both were seat11 to the bus: one $ME, one claim namespace, one inbox. The
# routine left SCRIP dirty mid-edit while the session closed a row, and a claim HIDES its row from the other picker
# -- so the race was silent from BOTH sides. Cure: s4e_msg.sh takes a (pid,starttime) lock at $PO/<seat>/.pid on
# every verb and REFUSES rc=2 naming BOTH pids when another LIVE process holds the identity. hq_B 2026-09-03.
# SIX ARMS against a THROWAWAY postoffice under mktemp -- never the live one:
#   (1) CONCURRENT  two GENUINELY concurrent verbs under one S4E_HOME (a background `done` whose DONE-WHEN sleeps,
#                   holding the lock, while `check` runs): the second REFUSES rc=2 and NAMES BOTH PIDS -- the
#                   incumbent pid matching the real background process -- while the incumbent still completes rc=0.
#   (2) RELEASE     a verb that exits normally leaves NO lock behind, and the next verb succeeds.
#   (3) STALE       a lock naming a DEAD pid self-clears; the verb runs.
#   (4) RECYCLED    ⛔ THE FALSE-REFUSAL ARM. A lock naming a LIVE pid whose STARTTIME differs is a recycled pid,
#                   NOT the holder -- it must self-clear. A pid-only lock refuses a seat that is alone in its root,
#                   i.e. the guard manufacturing the exact false signal it exists to remove.
#   (5) TORN        an empty/garbled lock file never wedges the bus.
#   (7) MARKER     an inherited S4E_PID_LOCK naming a live process that is NOT the lock holder must NOT wave a
#                   genuine second writer through -- the descendant marker is not a skeleton key.
#   (6) NESTED      ⛔ THE SELF-DEADLOCK ARM. s4e_msg.sh calls ITSELF eight times -- `ask` EXECS into `send` (same
#                   pid, same starttime, trap thrown away by exec), `board`/`done` spawn a `banner` child, `mint`
#                   installs its OWN EXIT trap and then clears it. Every one must succeed AND leave no lock behind.
# FAIL-ONCE (INSTRUMENT LAWS): two mutated copies, each removing one half of the cure --
#   M1 drops the s4e_pid_acquire call -> arm (1) red.  M2 makes liveness pid-only -> arm (4) red.
#   M3 trusts the descendant marker without checking it against the lock file -> arm (7) red.
# EXIT 0 all six arms hold on the live script AND both mutants go red; 1 otherwise; 2 REFUSED (fixture unbuildable).
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; MSG="$HERE/s4e_msg.sh"
[ -f "$MSG" ] || { echo "⛔ REFUSED: $MSG missing"; exit 2; }
[ -r /proc/self/stat ] || { echo "⛔ REFUSED: /proc is unreadable, so process identity cannot be measured at all"; exit 2; }
W="$(mktemp -d)" || { echo "⛔ REFUSED: mktemp failed"; exit 2; }
# ⛔⭐ THE CLEANUP TRAP IS GUARDED BY $BASHPID, AND WITHOUT THIS THE GATE DELETES ITS OWN FIXTURE MID-RUN.
# MEASURED while building this gate: a bare `trap 'rm -rf "$W"' EXIT` fired inside a FORKED CHILD. `sleep N &`
# followed immediately by `kill` can land the signal in the window between fork and exec, while the child is
# still bash carrying the parent's inherited EXIT trap -- so it ran the cleanup, $W vanished, and every
# subsequent arm failed for reasons having nothing to do with the cure. ⭐ $$ CANNOT DETECT THIS: bash keeps
# $$ at the ORIGINAL shell's pid inside subshells, so the child's guard would compare equal and fire anyway.
# $BASHPID is the real pid of the process evaluating it. Same lesson as the cure this gate grades: the cheap
# name is not the identity, and the wrong one fails in the direction of looking correct.
MAINPID=$$; trap '[ "$BASHPID" = "$MAINPID" ] && rm -rf "$W"' EXIT
PO="$W/po"; ME=hq_B; HQ=ceo
pstart() { local s; s="$(cat "/proc/$1/stat" 2>/dev/null)" || return 1; printf '%s' "${s##*') '}" | awk '{print $20}'; }
mk_po() {
  rm -rf "$PO"; mkdir -p "$PO/tasks" "$PO/claims" "$PO/released" "$PO/$ME/inbox" "$PO/$HQ/inbox" || return 2
  : > "$PO/BOARD.md"; : > "$PO/QUEUE.done.tsv"; printf 'QUARTET\n' > "$PO/MODE"; printf '%s\n' "$HQ" > "$PO/$ME/HQ"
  { printf '# gate fixture queue\n'; printf '0\tt-hold\tunassigned\tFREE\n'; printf '7\tt-spare\tunassigned\tFREE\n'; } > "$PO/QUEUE.tsv"
  # ⛔ The DONE-WHEN must SLEEP: that is what makes the incumbent verb hold the lock long enough for a SECOND verb
  # to run against it -- real concurrency, not a hand-written lock file. It contains '$' so `done`'s vacuity probe
  # skips it, and its first word is `sleep` so the decorated-no-op blocklist does not eat it.
  printf '# TASK t-hold\nGOAL: gate fixture.\nDONE-WHEN: sleep 6 && test -f "$S4E_HOME/po/QUEUE.tsv"\nLINKS: none\n## NEXT\ngo\n## LEDGER\n' > "$PO/tasks/t-hold.task.md"
  printf '# TASK t-spare\nGOAL: gate fixture.\nDONE-WHEN: test -f %s/QUEUE.tsv\nLINKS: none\n## NEXT\ngo\n## LEDGER\n' "$PO" > "$PO/tasks/t-spare.task.md"
}
# ⛔⭐ env -u S4E_PID_LOCK ON EVERY FIXTURE INVOCATION. This gate manufactures INDEPENDENT processes; the cure
# deliberately waves a DESCENDANT through (s4e_msg.sh calls itself eight times and would otherwise deadlock
# against its own banner child), and it recognises one by an EXPORTED marker. So if this gate is itself run
# from inside an s4e verb -- which is exactly what `done` does when it verifies this row's DONE-WHEN -- the
# marker leaks in and every "independent" fixture process is taken for a descendant.
# ⛔ MEASURED, AND IT IS THE WHOLE REASON THIS LINE EXISTS: the gate passed standalone and went RED under
# `done`, from an environment variable, on an unchanged tree. A verdict that depends on who invoked the
# grader is not a verdict -- the identical defect s4e_msg.sh already convicts in its own S4E_HOME comment.
FIX() { env -u S4E_PID_LOCK S4E_HOME="$W" S4E_POST="$PO" S4E_SEAT="$ME" "$@"; }
run() { FIX S4E_NO_BANNER=1 bash "$@" >"$W/out" 2>&1; }
nolock() { [ ! -f "$PO/$ME/.pid" ]; }
arm() {   # arm <label> <script> -> 0 iff all six contracts hold on <script>
  local lbl="$1" s="$2" ok=1 rc bgpid inc out
  mk_po || return 2
  run "$s" claim t-hold || { echo "  [$lbl] fixture: claim t-hold failed: $(tail -1 "$W/out")"; return 2; }
  # ---- (1) CONCURRENT: a real background `done` holds the identity while `check` runs against it -------------
  # ⛔ EXPLICIT `exec`, and NOT the FIX function, so $! names the process that actually holds the lock.
  # Backgrounding a shell FUNCTION forks a subshell that then forks again for `env`, so $! named a pid two
  # short of the real holder and the arm failed while the cure was working perfectly -- the fixture lying
  # about which process it launched. The lock file is cross-checked against $! below, so a future fork layer
  # cannot quietly reintroduce this.
  { exec env -u S4E_PID_LOCK S4E_HOME="$W" S4E_POST="$PO" S4E_SEAT="$ME" S4E_NO_BANNER=1 bash "$s" done t-hold; } >"$W/bg.out" 2>&1 & bgpid=$!
  local i=0; while [ $i -lt 40 ] && ! kill -0 "$bgpid" 2>/dev/null; do i=$((i+1)); sleep 0.1; done
  sleep 1.5
  local holder=""; [ -f "$PO/$ME/.pid" ] && read -r holder _ < "$PO/$ME/.pid"
  [ "${holder:-}" = "$bgpid" ] || echo "  [$lbl] (1) NOTE: lock file names pid ${holder:-none}, background job is $bgpid -- fixture drift, the assertion below grades the lock file"
  [ -n "${holder:-}" ] && bgpid="$holder"
  run "$s" check; rc=$?; out="$(cat "$W/out")"
  if [ "$rc" != 2 ]; then echo "  [$lbl] (1) a second CONCURRENT verb returned rc=$rc, want rc=2 REFUSED -- two live processes shared one identity"; ok=0
  else
    printf '%s' "$out" | grep -q 'REFUSED: ANOTHER LIVE PROCESS ALREADY HOLDS THE IDENTITY' || { echo "  [$lbl] (1) rc=2 but the refusal does not name the defect"; ok=0; }
    printf '%s' "$out" | grep -q "INCUMBENT  pid $bgpid" || { echo "  [$lbl] (1) refusal does not name the INCUMBENT pid $bgpid: $(printf '%s' "$out" | grep -m1 INCUMBENT)"; ok=0; }
    printf '%s' "$out" | grep -qE 'THIS ONE   pid [0-9]+' || { echo "  [$lbl] (1) refusal does not name the SECOND pid -- the ruling says name BOTH"; ok=0; }
  fi
  wait "$bgpid"; rc=$?
  [ "$rc" = 0 ] || { echo "  [$lbl] (1) the INCUMBENT verb did not complete (rc=$rc) -- the guard must refuse the newcomer, never break the holder: $(tail -1 "$W/bg.out")"; ok=0; }
  # ---- (2) RELEASE ------------------------------------------------------------------------------------------
  nolock || { echo "  [$lbl] (2) the lock survived a normal exit: $(cat "$PO/$ME/.pid")"; ok=0; rm -f "$PO/$ME/.pid"; }
  run "$s" check || { echo "  [$lbl] (2) the next verb after a released lock was refused: $(tail -1 "$W/out")"; ok=0; }
  # ---- (3) STALE: a DEAD pid self-clears --------------------------------------------------------------------
  # ⛔ A DEAD PID IS SOURCED FROM AN ALREADY-EXITED EXEC'D CHILD, never by killing a fresh background job:
  # that kill races the fork/exec window above. Verified actually dead, so a recycled pid cannot silently
  # turn this arm into a test of something else.
  local dead; dead="$(bash -c 'echo $$')"
  [ -n "$dead" ] && [ ! -d "/proc/$dead" ] || { echo "  [$lbl] fixture: could not obtain a reliably dead pid (got '$dead')"; return 2; }
  printf '%s 1 2026-09-03T00:00:00Z done\n' "$dead" > "$PO/$ME/.pid"
  run "$s" check || { echo "  [$lbl] (3) a lock naming a DEAD pid did not self-clear (rc=$?): $(grep -m1 REFUSED "$W/out")"; ok=0; }
  # ---- (4) RECYCLED: a LIVE pid with the WRONG starttime is NOT the holder -----------------------------------
  rm -f "$PO/$ME/.pid"; sleep 30 & local live=$!
  printf '%s 999999999 2026-09-03T00:00:00Z done\n' "$live" > "$PO/$ME/.pid"
  run "$s" check; rc=$?; kill "$live" 2>/dev/null; wait "$live" 2>/dev/null
  [ "$rc" = 0 ] || { echo "  [$lbl] (4) a RECYCLED pid (live pid, different starttime) was treated as the holder (rc=$rc) -- a pid-only lock refuses a seat that is ALONE in its root"; ok=0; }
  # ---- (5) TORN ---------------------------------------------------------------------------------------------
  rm -f "$PO/$ME/.pid"; : > "$PO/$ME/.pid"
  run "$s" check || { echo "  [$lbl] (5) an empty lock file wedged the bus: $(grep -m1 REFUSED "$W/out")"; ok=0; }
  # ---- (6) NESTED self-invocation: exec, banner child, mint's own EXIT trap ----------------------------------
  rm -f "$PO/$ME/.pid"
  FIX bash "$s" ask t-hold "nested exec probe" >"$W/out" 2>&1 \
    || { echo "  [$lbl] (6) ask (which EXECS into send) failed: $(tail -1 "$W/out")"; ok=0; }
  grep -q 'ANOTHER LIVE PROCESS' "$W/out" && { echo "  [$lbl] (6) ask DEADLOCKED against its own exec'd image"; ok=0; }
  nolock || { echo "  [$lbl] (6) exec leaked the lock (exec throws the release trap away with the old image)"; ok=0; rm -f "$PO/$ME/.pid"; }
  FIX bash "$s" board "nested banner probe" >"$W/out" 2>&1 \
    || { echo "  [$lbl] (6) board (which spawns a banner child) failed: $(tail -1 "$W/out")"; ok=0; }
  grep -q 'ANOTHER LIVE PROCESS' "$W/out" && { echo "  [$lbl] (6) board DEADLOCKED against its own banner child"; ok=0; }
  nolock || { echo "  [$lbl] (6) board leaked the lock"; ok=0; rm -f "$PO/$ME/.pid"; }
  run "$s" mint t-minted 4 "gate fixture goal minted to exercise mint's own EXIT trap" \
    || { echo "  [$lbl] (6) mint failed: $(tail -1 "$W/out")"; ok=0; }
  nolock || { echo "  [$lbl] (6) mint leaked the lock -- its own EXIT trap clobbered the release"; ok=0; rm -f "$PO/$ME/.pid"; }
  run "$s" next || { echo "  [$lbl] (6) next failed: $(tail -1 "$W/out")"; ok=0; }
  nolock || { echo "  [$lbl] (6) next leaked the lock"; ok=0; rm -f "$PO/$ME/.pid"; }
  # ---- (7) INHERITED MARKER: naming a live process is not enough -- it must BE the one in the lock file ------
  # ⛔ The descendant pass-through reads an EXPORTED variable, i.e. attacker-free but stale-prone input. Here a
  # verb arrives carrying a marker for a LIVE process that is NOT the lock holder, while a genuine second
  # writer holds the identity. It must still REFUSE. Without the file-agreement check, an inherited marker is
  # a skeleton key that silently disables the whole guard for every process below it.
  rm -f "$PO/$ME/.pid"; sleep 30 & local other=$!
  local ostart; ostart="$(pstart "$other")"
  printf '%s %s 2026-09-03T00:00:00Z done\n' "$other" "$ostart" > "$PO/$ME/.pid"
  sleep 30 & local bystander=$!; local bstart; bstart="$(pstart "$bystander")"
  FIX S4E_NO_BANNER=1 S4E_PID_LOCK="$ME:$bystander:$bstart" bash "$s" check >"$W/out" 2>&1; rc=$?
  kill "$other" "$bystander" 2>/dev/null; wait "$other" 2>/dev/null; wait "$bystander" 2>/dev/null
  [ "$rc" = 2 ] || { echo "  [$lbl] (7) an inherited S4E_PID_LOCK naming a live NON-holder waved the verb past a real second writer (rc=$rc) -- the marker is a skeleton key"; ok=0; }
  rm -f "$PO/$ME/.pid"
  [ "$ok" = 1 ]
}
echo "s4e one process per identity (scratch postoffice under $W)"
cp "$HERE/lib_release_guard.sh" "$W/" 2>/dev/null || true
if arm PASS "$MSG"; then echo "  [PASS] concurrent verb refused rc=2 naming both pids; lock released; stale/recycled/torn self-clear; no nested deadlock"; pass=1
else pass=$?; [ "$pass" = 2 ] && { echo "⛔ REFUSED: fixture could not be built (rc=2)"; exit 2; }; pass=0; fi
# ---- FAIL-ONCE M1: the acquire call is gone ------------------------------------------------------------------
# ⛔ EXACT-STRING awk, never a regex sed: the cured line is dense with `$`, `|`, `*` and `;;`, every one of which
# means something else to BRE. A mutation regex that silently matched nothing would hand back an UNMUTATED copy,
# the arm would pass, and the gate would report a fail-once it never performed -- a false green inside the very
# mechanism that exists to prove the gate is not falsely green. Both mutants are VERIFIED below before use.
M1_FROM='case "$cmd" in mailbox|"") ;; *) s4e_assert_box "$ME" identity; s4e_pid_acquire;; esac'
M1_TO='case "$cmd" in mailbox|"") ;; *) s4e_assert_box "$ME" identity;; esac'
awk -v a="$M1_FROM" -v b="$M1_TO" '$0==a{print b; n++; next} {print} END{exit !n}' "$MSG" > "$W/m1.sh" \
  || { echo "⛔ REFUSED: the acquire call site is not where M1 expects it -- the cure moved, so the mutation would be a no-op"; exit 2; }
grep -qF "$M1_TO" "$W/m1.sh" && ! grep -qF "$M1_FROM" "$W/m1.sh" \
  || { echo "⛔ REFUSED: M1 did not produce an uncured call site"; exit 2; }
if arm M1-no-acquire "$W/m1.sh" >"$W/m1.log" 2>&1; then echo "  [FAIL-ONCE M1] ⛔ GREEN with the acquire call removed -- the gate cannot detect an unguarded bus"; m1=0
else echo "  [FAIL-ONCE M1] red as required, no acquire: $(grep -m1 '(1) a second CONCURRENT' "$W/m1.log" | sed 's/^ *//' | cut -c1-104)"; m1=1; fi
# ---- FAIL-ONCE M2: liveness ignores the starttime (a pid-only lock) -------------------------------------------
M2_TO='s4e_pid_live() { [ -n "${1:-}" ] && [ -d "/proc/$1" ]; }'
# ⛔ s4e_pid_live spans TWO lines in the cure, so the mutant replaces the first and SKIPS THE SECOND
# POSITIONALLY -- never by matching the continuation's own text, which is denser in regex metacharacters than
# the line it replaces. Leaving that orphan behind would make the copy a SYNTAX ERROR, and a fixture that will
# not parse goes red for a reason having nothing to do with the cure: a fail-once that proves nothing.
awk -v b="$M2_TO" 'skip{skip=0; next} $0 ~ /^s4e_pid_live\(\) \{/ {print b; n++; skip=1; next} {print} END{exit !n}' "$MSG" > "$W/m2.sh" \
  || { echo "⛔ REFUSED: s4e_pid_live() is not where M2 expects it -- the mutation would be a no-op"; exit 2; }
grep -qF "$M2_TO" "$W/m2.sh" || { echo "⛔ REFUSED: M2 did not produce the pid-only mutant"; exit 2; }
grep -q 's4e_proc_start "\$1"' "$W/m2.sh" && { echo "⛔ REFUSED: M2 left the starttime comparison in place -- not a pid-only mutant"; exit 2; }
bash -n "$W/m2.sh" 2>/dev/null || { echo "⛔ REFUSED: the M2 mutant does not parse -- fixture, not verdict"; exit 2; }
if arm M2-pid-only "$W/m2.sh" >"$W/m2.log" 2>&1; then echo "  [FAIL-ONCE M2] ⛔ GREEN with liveness reduced to the bare pid -- the gate cannot detect the recycled-pid false refusal"; m2=0
else echo "  [FAIL-ONCE M2] red as required, pid-only liveness: $(grep -m1 '(4)' "$W/m2.log" | sed 's/^ *//' | cut -c1-104)"; m2=1; fi
# ---- FAIL-ONCE M3: the descendant marker is trusted without agreeing with the lock file ----------------------
M3_FROM='        if [ "${_p:-}" = "${_hp:-}" ] && [ "${_t:-}" = "${_ht:-}" ]; then'
M3_TO='        if true; then'
awk -v a="$M3_FROM" -v b="$M3_TO" '$0==a{print b; n++; next} {print} END{exit !n}' "$MSG" > "$W/m3.sh" \
  || { echo "⛔ REFUSED: the marker/file agreement check is not where M3 expects it -- the mutation would be a no-op"; exit 2; }
grep -qF "$M3_TO" "$W/m3.sh" || { echo "⛔ REFUSED: M3 did not produce the trust-the-marker mutant"; exit 2; }
bash -n "$W/m3.sh" 2>/dev/null || { echo "⛔ REFUSED: the M3 mutant does not parse -- fixture, not verdict"; exit 2; }
if arm M3-trust-marker "$W/m3.sh" >"$W/m3.log" 2>&1; then echo "  [FAIL-ONCE M3] ⛔ GREEN with the marker trusted blindly -- the gate cannot detect the skeleton-key hole"; m3=0
else echo "  [FAIL-ONCE M3] red as required, marker trusted blindly: $(grep -m1 '(7)' "$W/m3.log" | sed 's/^ *//' | cut -c1-104)"; m3=1; fi
if [ "$pass" = 1 ] && [ "$m1" = 1 ] && [ "$m2" = 1 ] && [ "$m3" = 1 ]; then
  echo "✅ GATE OK: the bus refuses a second live process under one seat identity, names both pids, and never refuses a seat that is alone in its root."; exit 0; fi
echo "⛔ GATE FAILED (pass=$pass m1-red=$m1 m2-red=$m2 m3-red=$m3)"; exit 1
