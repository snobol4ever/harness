#!/usr/bin/env bash
# test_gate_s4e_donewhen_refuses_when_compiler_absent.sh -- a DONE-WHEN that DRIVES THE COMPILER is REFUSED (rc=2),
# never graded RED (rc=1), on a tree where ./scrip is not built. hq_P -> hq_B 2026-09-04, measured on
# pascal-m4-site1-forloop-backedge-64byte-excess: the criterion's compile step reads
#     timeout -k 5 300s SCRIP/scrip --compile ... || { echo "compile failed"; exit 1; }
# so a MISSING binary reported rc=1 -- "real work here", served SILENTLY by the dispatch probe -- instead of rc=2
# -- "could not measure", served WITH a warning. The ceo root's scrip was built 21 minutes AFTER the assign.
# V2-5's three exit codes apply to criteria, not only to gates; and the cure is ONE guard in s4e_msg.sh
# (s4e_donewhen_needs_compiler, at both runner sites) rather than a sweep of the 88 batons that carry the shape.
# THREE ARMS against a THROWAWAY postoffice under mktemp -- never the live one:
#   (1) DISPATCH-WARNS  `next` serves a compiler-driving row WITH the could-not-measure warning naming the binary,
#                       and does NOT close it.
#   (2) DONE-REFUSES    `done` on that row exits 2, names the binary, leaves claim and column untouched.
#   (3) SCOPE           a criterion that never names the compiler is untouched: `done` on a plain red row still
#                       exits 1 -- the guard must not turn every red into a refusal.
# FAIL-ONCE: mutant M1 strips the guard from a copy of s4e_msg.sh -- arms 1 and 2 must go red on it.
# EXIT 0 all arms hold on the real script and the mutant goes red; 1 otherwise; 2 REFUSED (fixture unbuildable).
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; MSG="$HERE/s4e_msg.sh"
[ -f "$MSG" ] || { echo "⛔ REFUSED: $MSG missing"; exit 2; }
W="$(mktemp -d)" || { echo "⛔ REFUSED: mktemp failed"; exit 2; }
MAINPID=$$; trap '[ "$BASHPID" = "$MAINPID" ] && rm -rf "$W"' EXIT
PO="$W/po"; ME=hq_B; HQ=ceo; BUDGET=4
# ⛔ THE FIXTURE MODE IS PROBED, NOT HARDCODED (COO-80, 2026-09-19, row
# instrument-the-nineteen-non-gc-blocking-arms). mk_po below wrote a literal mode into the scratch MODE, and
# that string was kept in step with the live fleet -- it read QUARTET. QUARTET stands EVERY HQ down
# (CEO-911), and this gate's seat is hq_B, so every serve in it became a dispatch refusal and six arms went
# red over a mechanism -- a missing compiler must REFUSE rather than grade -- that was never exercised at
# all. The mode is incidental to that subject; keeping a literal in step with the fleet is exactly the
# maintenance that fails silently. The rule is a sourced authority in lib_gate.sh: candidates are probed with
# an empty queue, claiming nothing, and the first that admits the seat is used.
. "$HERE/lib_gate.sh"
command -v gate_pick_dispatchable_mode >/dev/null 2>&1 || { echo "⛔ REFUSED: lib_gate.sh carries no gate_pick_dispatchable_mode -- the mode-probe rule is a sourced authority and a gate must never keep a private copy of it"; exit 2; }
FIX() { env -u S4E_PID_LOCK -u S4E_NO_DISPATCH_PROBE S4E_HOME="$W" S4E_POST="$PO" S4E_SEAT="$ME" \
        S4E_NO_BANNER=1 S4E_DISPATCH_PROBE_TIMEOUT="$BUDGET" "$@"; }
mkrow() { printf '%s\t%s\tunassigned\tFREE\n' "$1" "$2" >> "$PO/QUEUE.tsv"
          printf '# TASK %s\nGOAL: gate fixture.\nDONE-WHEN: %s\nLINKS: none\n## NEXT\ngo\n## LEDGER\n' "$2" "$3" > "$PO/tasks/$2.task.md"; }
mk_po() {
  rm -rf "$PO" "$W/SCRIP"; mkdir -p "$PO/tasks" "$PO/claims" "$PO/released" "$PO/$ME/inbox" "$PO/$HQ/inbox" "$W/harness/scripts" || return 2
  : > "$PO/BOARD.md"; : > "$PO/QUEUE.done.tsv"; printf '5\n' > "$PO/PROTOCOL-VERSION"
  if [ -z "${FIXTURE_MODE:-}" ]; then
      printf 'DECTET\n' > "$PO/MODE"
      FIXTURE_MODE="$(gate_pick_dispatchable_mode "$MSG" "$PO" "$ME" DECTET NONET FLEET-16)" || {
          echo "⛔ REFUSED: the picker refuses to dispatch $ME under every candidate mode (DECTET, NONET, FLEET-16), so this fixture cannot get a row served and cannot grade what a missing compiler does to it. That is a finding about the stand-down table, not a reason to read a dispatch refusal as a compiler refusal."; return 2; }
      echo "    fixture: MODE = $FIXTURE_MODE (probed -- the first candidate under which the picker dispatches $ME)"
  fi
  printf '%s\n' "$FIXTURE_MODE" > "$PO/MODE"
  printf '%s\n' "$HQ" > "$PO/$ME/HQ"; printf '# gate fixture queue\n' > "$PO/QUEUE.tsv"
  # hq_P's exact shape: the compile step reports a missing binary as rc=1. $W/SCRIP exists; $W/SCRIP/scrip does not.
  mkrow 0 t-cc    'cd "$S4E_HOME/SCRIP" && timeout -k 5 30s ./scrip --compile nothing.pas </dev/null >/dev/null 2>&1 || { echo "bubble m4 compile failed"; exit 1; }'
  mkrow 1 t-plain 'test -f "$S4E_HOME/po/NO-SUCH-FILE"'
}
col() { grep -P "^[0-9]+\t\Q$1\E\t" "$PO/QUEUE.tsv" 2>/dev/null | head -1 | cut -f4; }
arm() {   # arm <label> <script> -> 0 iff all three contracts hold on <script>
  local lbl="$1" s="$2" ok=1 out rc
  mk_po || return 2
  # ---- (1) DISPATCH-WARNS -------------------------------------------------------------------------------
  out="$(FIX bash "$s" next 2>&1)"
  grep -q 'LOCKED t-cc' <<<"$out" || { echo "  [$lbl] (1) the compiler-driving row was not served: $(grep -m1 -E 'LOCKED|EMPTY|⛔' <<<"$out" | cut -c1-100)"; ok=0; }
  grep -q 'COULD NOT MEASURE' <<<"$out" || { echo "  [$lbl] (1) served SILENTLY: a missing compiler read as a red row, not as could-not-measure"; ok=0; }
  grep -q 'not built' <<<"$out" || { echo "  [$lbl] (1) the warning does not name the missing binary"; ok=0; }
  [ "$(col t-cc)" = DONE ] && { echo "  [$lbl] (1) a row that could not be MEASURED was CLOSED"; ok=0; }
  # ---- (2) DONE-REFUSES ---------------------------------------------------------------------------------
  out="$(FIX bash "$s" done t-cc 2>&1)"; rc=$?
  [ "$rc" = 2 ] || { echo "  [$lbl] (2) done exited $rc, want 2 (REFUSE) -- a missing compiler graded as a verdict"; ok=0; }
  grep -q 'not built' <<<"$out" || { echo "  [$lbl] (2) the refusal does not name the missing binary"; ok=0; }
  [ "$(head -1 "$PO/claims/t-cc.claim" 2>/dev/null)" = "$ME" ] || { echo "  [$lbl] (2) the claim was disturbed by a refusal"; ok=0; }
  [ "$(col t-cc)" = DONE ] && { echo "  [$lbl] (2) done CLOSED a row it could not measure"; ok=0; }
  # ---- (3) SCOPE: a criterion that never names the compiler is graded, not refused -----------------------
  rm -f "$PO/claims/t-cc.claim"
  FIX bash "$s" claim t-plain >/dev/null 2>&1 || { echo "  [$lbl] fixture: claim t-plain failed"; return 2; }
  out="$(FIX bash "$s" done t-plain 2>&1)"; rc=$?
  [ "$rc" = 1 ] || { echo "  [$lbl] (3) a plain red row's done exited $rc, want 1 -- the guard fired on a criterion that never names the compiler"; ok=0; }
  [ "$ok" = 1 ]
}
echo "=== s4e DONE-WHEN REFUSES WHEN THE COMPILER IS ABSENT ==="
fail=0
if arm real "$MSG"; then echo "  ✅ real script: all three arms hold"; else rc=$?; [ "$rc" = 2 ] && { echo "⛔ REFUSED: fixture unbuildable"; exit 2; }; echo "  ⛔ real script: an arm is red"; fail=1; fi
# ---- FAIL-ONCE: strip the guard (both sites carry the marker) and the cure must be seen to matter ---------
M1="$W/s4e_m1.sh"; grep -v 'S4E-GUARD-COMPILER-ABSENT' "$MSG" > "$M1"
[ "$(grep -c 'S4E-GUARD-COMPILER-ABSENT' "$MSG")" -ge 2 ] || { echo "⛔ REFUSED: the guard marker is not at both runner sites in $MSG -- the mutant would be a no-op"; exit 2; }
if arm M1 "$M1" >/dev/null 2>&1; then echo "  ⛔ mutant M1 (guard stripped) still passes -- the gate cannot see the cure"; fail=1; else echo "  ✅ mutant M1 (guard stripped) goes red -- fail-once holds"; fi
[ "$fail" = 0 ] && { echo "PASS: a DONE-WHEN that drives an unbuilt compiler is REFUSED, never graded."; exit 0; }
echo "FAIL"; exit 1
