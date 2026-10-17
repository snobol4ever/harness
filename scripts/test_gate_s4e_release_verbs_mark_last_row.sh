#!/usr/bin/env bash
# test_gate_s4e_release_verbs_mark_last_row.sh -- THE .last-row CONTRACT OF THE DISPATCHER'S CLOSING VERBS (row
# park-marks-last-row-only-when-clearing-own-claim, MASTER-PLAN ladder I rung I7; seat14 + seat07 measured, ceo minted rank 0,
# hq_B cured and gated 2026-09-01).
#
# THE CONTRACT: every verb that CLOSES a row this seat holds -- unclaim, done, park-of-my-own-claim -- writes $PO/$ME/.last-row as
# "<topic>\n<STATE> <stamp>", because the Stop banner's fallback reads that marker to attribute the session; and park on a row this
# seat does NOT hold (a PARKED-AROUND, claim preserved) leaves the marker alone, because that park closed nothing of mine.
# MEASURED FAILURE THIS GATE PINS: park never wrote the marker, so a session that ended by parking was attributed to the row last
# unclaimed or done'd -- days old, cumulative commit count (seat14: parked icon-n2 with zero commits, banner said 'RELEASED
# polyglot-scrip-demos-10-working, 1 commit(s)'). The cure enumerated one more verb; this gate is what stops the NEXT closing verb
# from reopening it silently -- add a verb that removes a claim file, add an arm here.
#
# ⛔ RUNS AGAINST A SCRATCH POSTOFFICE, NEVER THE LIVE ONE: s4e_msg.sh honours S4E_POST (the postoffice root) and S4E_SEAT (who I am),
# so every claim, park, done and marker below lands under mktemp and is deleted on exit. The live /home/resources/postoffice is not
# read or written by any arm.
# ⭐ TWO-PART PROOF (RULES.md THE INSTRUMENT LAWS -- fail once, pass once): after the pass arms, a COPY of s4e_msg.sh with park's
# s4e_mark_row line deleted is run through the park arm and MUST turn it red; a gate that cannot go red is the false-green trap.
# EXIT: 0 all arms hold and the fail-once arm went red · 1 a contract arm broke · 2 REFUSED (cannot build the scratch postoffice).
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; MSG="$HERE/s4e_msg.sh"
[ -f "$MSG" ] || { echo "⛔ REFUSED: $MSG missing"; exit 2; }
W="$(mktemp -d)" || { echo "⛔ REFUSED: mktemp failed"; exit 2; }; trap 'rm -rf "$W"' EXIT
PO="$W/po"; ME=hq_B; OTHER=seat05
mk_po() {   # a minimal postoffice: four rows, four batons, two mailboxes
  rm -rf "$PO"; mkdir -p "$PO/tasks" "$PO/claims" "$PO/$ME/inbox" "$PO/$OTHER/inbox" "$PO/released" || return 2
  : > "$PO/QUEUE.tsv"; : > "$PO/BOARD.md"; : > "$PO/QUEUE.done.tsv"
  for t in t-unclaim t-done t-park-own t-park-other; do printf '2\t%s\tunassigned\tFREE\n' "$t" >> "$PO/QUEUE.tsv"
    # a REAL predicate: `done` refuses a DONE-WHEN that is a shell no-op (true / : / exit 0) -- that guard is right, so the
    # fixture's predicate tests something that is true in the scratch postoffice and would not be elsewhere
    printf '# TASK %s\nGOAL: gate fixture.\nDONE-WHEN: test -f %s/tasks/%s.task.md\nLINKS: none\n## NEXT\n(none)\n## LEDGER\n' "$t" "$PO" "$t" > "$PO/tasks/$t.task.md"; done
}
run() { S4E_POST="$PO" S4E_SEAT="$ME" S4E_PARK_FORCE="${FORCE:-0}" bash "$1" "${@:2}" >"$W/out" 2>&1; }
marker() { [ -s "$PO/$ME/.last-row" ] && { printf '%s' "$(sed -n 1p "$PO/$ME/.last-row")"; printf '|%s' "$(sed -n 2p "$PO/$ME/.last-row" | cut -d' ' -f1)"; } || printf 'NONE'; }
arm() {   # arm <label> <script> -> runs the four verbs, prints the marker after each, returns 0 iff the contract holds
  local lbl="$1" s="$2" ok=1 m
  mk_po || return 2
  run "$s" claim t-unclaim   || { echo "  [$lbl] claim t-unclaim failed: $(tail -1 "$W/out")"; return 1; }
  run "$s" unclaim t-unclaim "gate"; m="$(marker)"; [ "$m" = "t-unclaim|RELEASED" ] || { echo "  [$lbl] after unclaim: marker=$m (want t-unclaim|RELEASED)"; ok=0; }
  run "$s" claim t-done      || { echo "  [$lbl] claim t-done failed"; return 1; }
  run "$s" done t-done;          m="$(marker)"; [ "$m" = "t-done|DONE" ]         || { echo "  [$lbl] after done: marker=$m (want t-done|DONE) :: $(grep -m1 -E 'REFUSED|FAIL' "$W/out" | cut -c1-100)"; ok=0; }
  run "$s" claim t-park-own  || { echo "  [$lbl] claim t-park-own failed"; return 1; }
  run "$s" park t-park-own PARKED; m="$(marker)"; [ "$m" = "t-park-own|PARKED" ] || { echo "  [$lbl] after park-own: marker=$m (want t-park-own|PARKED)"; ok=0; }
  printf '%s\n' "$OTHER" > "$PO/claims/t-park-other.claim"           # another seat holds it
  FORCE=1 run "$s" park t-park-other PARKED; m="$(marker)"; [ "$m" = "t-park-own|PARKED" ] || { echo "  [$lbl] after park-other (PARKED-AROUND): marker=$m (must stay t-park-own|PARKED)"; ok=0; }
  [ -f "$PO/claims/t-park-other.claim" ] || { echo "  [$lbl] park-other deleted the other seat's claim"; ok=0; }
  [ "$ok" = 1 ]
}
echo "s4e release verbs -> .last-row contract (scratch postoffice under $W)"
if arm PASS "$MSG"; then echo "  [PASS] unclaim/done/park-own each mark .last-row; park-other leaves it"; pass=1; else pass=0; fi
# fail-once: a copy without park's mark must go red on the park-own arm
sed '/^\s*s4e_mark_row "\$topic" PARKED\s*$/d' "$MSG" > "$W/msg_nomark.sh"
if grep -q 's4e_mark_row "$topic" PARKED' "$W/msg_nomark.sh"; then echo "⛔ REFUSED: could not remove park's mark line for the fail-once arm"; exit 2; fi
if arm FAIL-ONCE "$W/msg_nomark.sh" >/dev/null 2>&1; then echo "  [FAIL-ONCE] ⛔ the gate stayed GREEN with park's mark deleted -- it cannot detect the defect it exists for"; red=0; else echo "  [FAIL-ONCE] red with park's mark deleted, as it must be"; red=1; fi
if [ "$pass" = 1 ] && [ "$red" = 1 ]; then echo "✅ GATE OK: closing verbs mark .last-row, park-around does not, and the gate goes red when the mark is removed."; exit 0; fi
echo "⛔ GATE FAILED (pass=$pass fail-once-red=$red)"; exit 1
