#!/usr/bin/env bash
# test_gate_s4e_park_additive_blocker.sh -- a re-park ADDS a blocker to the state column instead of REPLACING
# the one already there, and `park` REFUSES a BLOCKED-ON:/PARKED-AWAITING: topic that names no real row.
# Row s4e-park-adds-a-blocker-and-refuses-an-unresolvable-topic (hq_P s285, FINDING-2026-09-02-hq_P-pascal-
# bubble-m3-segv-was-cured-by-the-zd-normalize-inrun-arm-and-the-row-stayed-parked-a-day-behind-a-rewritten-
# blocker.md; ceo ACCEPTED 2026-09-02 ~17:40 CDT). MEASURED: seat11's correct park (BLOCKED-ON:calling-
# convention-depth-tracked, the row that actually cured it) was overwritten TWICE by later re-parks recording
# a different hypothesis; when the true blocker landed DONE nothing was left naming it, so the row could not
# self-clear and eight seats released it unworked.
# TWO ARMS against a THROWAWAY postoffice under mktemp -- never the live one -- each run against the live
# s4e_msg.sh and (arm A only -- arm B's refuse-check pre-dates this row, hq_B mint) against a mutated copy
# with the additive-merge cure removed (FAIL-ONCE, INSTRUMENT LAWS fifth batch):
#   (A) park X BLOCKED-ON:B1, then park X BLOCKED-ON:B2 -> column reads BLOCKED-ON:B1+B2 (merged, not
#       overwritten); mark B1 DONE; `next` reconsiders X -> self-heals and locks/serves it (no longer stuck
#       BLOCKED-ON anything -- the state column left the BLOCKED-ON:/PARKED-AWAITING: family entirely).
#   (B) park Y BLOCKED-ON:<topic absent from QUEUE.tsv and QUEUE.done.tsv> -> REFUSED rc=2, column unchanged.
# EXIT 0 both arms hold on the live script AND arm (A) goes red on the mutated copy; 1 otherwise; 2 REFUSED.
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; MSG="$HERE/s4e_msg.sh"
[ -f "$MSG" ] || { echo "⛔ REFUSED: $MSG missing"; exit 2; }
W="$(mktemp -d)" || { echo "⛔ REFUSED: mktemp failed"; exit 2; }; trap 'rm -rf "$W"' EXIT
PO="$W/po"; SEAT=hq_C; THIRD=seat04
mk_po() {
  rm -rf "$PO"; mkdir -p "$PO/tasks" "$PO/claims" "$PO/released" "$PO/$SEAT/inbox" "$PO/$THIRD/inbox" || return 2
  : > "$PO/BOARD.md"; : > "$PO/QUEUE.done.tsv"; printf "TRIO\n" > "$PO/MODE"
  { printf '# gate fixture queue\n'; printf '0\tt-target\tunassigned\tFREE\n'; printf '5\tt-b1\tunassigned\tFREE\n'; printf '5\tt-b2\tunassigned\tFREE\n'; printf '0\tt-target-b\tunassigned\tFREE\n'; } > "$PO/QUEUE.tsv"
  local t; for t in t-target t-b1 t-b2 t-target-b; do
  # ⛔ THE FIXTURE CRITERION MUST BE **RED**, and it used to be `test -f <the baton itself>` -- always
  # true. Since 2026-09-03 the picker RUNS a row's DONE-WHEN before serving it (row next-and-assign-
  # re-run-a-rows-done-when-before-serving-it), so a fixture row whose criterion already passes is
  # closed at dispatch instead of served, and this gate could never see the routing it exists to test.
  # ⭐ The old fixture was ALWAYS semantically wrong -- a FREE row means "work not done" -- and nothing
  # noticed because nothing ever ran it. $PO/landed/<topic> is never created, so the row reads as real work.
    printf '# TASK %s\nGOAL: gate fixture.\nDONE-WHEN: test -f %s/landed/%s\nLINKS: none\n## NEXT\n(none)\n## LEDGER\n' "$t" "$PO" "$t" > "$PO/tasks/$t.task.md"; done
}
run() { local seat="$1"; shift; S4E_POST="$PO" S4E_SEAT="$seat" S4E_NO_BANNER=1 bash "$@" >"$W/out" 2>&1; }
col() { grep -P "^[0-9]+\t\Q$1\E\t" "$PO/QUEUE.tsv" | head -1 | cut -f4; }
arm_a() {   # arm_a <script> -> 0 iff additive-merge + self-heal holds on <script>
  local s="$1" ok=1 c
  mk_po || return 2
  run $SEAT "$s" park t-target BLOCKED-ON:t-b1 || { echo "  [A] first park refused: $(tail -1 "$W/out")"; return 2; }
  c="$(col t-target)"; [ "$c" = "BLOCKED-ON:t-b1" ] || { echo "  [A] fixture: after first park column=$c (want BLOCKED-ON:t-b1)"; return 2; }
  run $SEAT "$s" park t-target BLOCKED-ON:t-b2 || { echo "  [A] second park refused: $(tail -1 "$W/out")"; return 2; }
  c="$(col t-target)"
  [ "$c" = "BLOCKED-ON:t-b1+t-b2" ] || { echo "  [A] re-park OVERWROTE instead of ADDING: column=$c (want BLOCKED-ON:t-b1+t-b2, the merged set)"; ok=0; }
  printf 'seat-owner\nRUNNING\nDONE\n' > "$PO/claims/t-b1.claim"   # t-b1 lands DONE; t-b2 stays open
  run $THIRD "$s" next
  c="$(col t-target)"
  case "$c" in BLOCKED-ON:*|PARKED-AWAITING:*) echo "  [A] t-target still reads $c after its recorded blocker t-b1 went DONE -- self-heal did not see t-b1 (lost behind t-b2?)"; ok=0;; esac
  grep -q 'LOCKED t-target\b' "$W/out" || { echo "  [A] next did not self-heal+serve t-target once t-b1 (one of its TWO recorded blockers) went DONE: $(grep -m1 -E 'LOCKED|EMPTY|REFUS|⛔' "$W/out" | cut -c1-120)"; ok=0; }
  [ "$ok" = 1 ]
}
arm_b() {   # arm_b <script> -> 0 iff parking on an unresolvable topic REFUSES rc=2 and leaves the column alone
  local s="$1" ok=1 c rc
  mk_po || return 2
  run $SEAT "$s" park t-target-b BLOCKED-ON:topic-that-is-not-a-real-row-anywhere; rc=$?
  c="$(col t-target-b)"
  [ "$rc" = 2 ] || { echo "  [B] park on an unresolvable topic exited $rc (want 2): $(tail -3 "$W/out" | tr '\n' ' ')"; ok=0; }
  [ "$c" = "FREE" ] || { echo "  [B] column changed to $c despite the refusal (want FREE, unchanged)"; ok=0; }
  grep -qi 'REFUSED' "$W/out" || { echo "  [B] no REFUSED text in output: $(tail -3 "$W/out" | tr '\n' ' ')"; ok=0; }
  [ "$ok" = 1 ]
}
echo "s4e park: additive blocker merge + refuse-unresolvable-topic (scratch postoffice under $W)"
a_ok=1; b_ok=1
if arm_a "$MSG"; then echo "  [PASS A] BLOCKED-ON:t-b1 + BLOCKED-ON:t-b2 merge to BLOCKED-ON:t-b1+t-b2; t-b1 DONE alone self-heals and serves the row"; else a_ok=$?; [ "$a_ok" = 2 ] && { echo "⛔ REFUSED: arm A fixture could not be built (rc=2)"; exit 2; }; a_ok=0; fi
if arm_b "$MSG"; then echo "  [PASS B] park on a topic absent from QUEUE.tsv/QUEUE.done.tsv REFUSES rc=2, column left FREE"; else b_ok=$?; [ "$b_ok" = 2 ] && { echo "⛔ REFUSED: arm B fixture could not be built (rc=2)"; exit 2; }; b_ok=0; fi
# ⛔ THE MUTANT IS STAGED WITH ITS SIBLING LIBS. Since the DONE-WHEN extractor moved into lib_donewhen.sh
# (cto's ruling, 2026-09-23) the bus REFUSES rc=2 when that lib is not beside it, so a mutant dropped into a
# bare $W refuses EVERY verb -- and this gate's fail-once then prints "red as required" over a refusal that
# has nothing to do with the additive-merge cure. A fail-once red for a staging reason proves nothing.
mkdir -p "$W/nocure" && cp "$HERE"/lib_*.sh "$W/nocure/" || { echo "⛔ REFUSED(2): cannot stage the mutant's sibling libs"; exit 2; }
sed 's/if \[ "\$_dup" = 0 \]; then st="BLOCKED-ON:\${_old}+\${_new}"; else st="BLOCKED-ON:\${_old}"; fi/st="BLOCKED-ON:\${_new}"/' "$MSG" > "$W/nocure/s4e_msg.sh"
grep -q 'st="BLOCKED-ON:\${_new}"' "$W/nocure/s4e_msg.sh" || { echo "⛔ REFUSED: could not remove the additive-merge cure for the fail-once arm (the merge line moved?)"; exit 2; }
if arm_a "$W/nocure/s4e_msg.sh" >"$W/failonce" 2>&1; then echo "  [FAIL-ONCE] ⛔ arm A stayed GREEN with the additive-merge cure removed -- it cannot detect the defect it exists for"; red=0; else echo "  [FAIL-ONCE] red as required with the additive-merge cure removed: $(grep -m1 '\[A\]' "$W/failonce" | sed 's/^ *//' | cut -c1-120)"; red=1; fi
if [ "$a_ok" = 1 ] && [ "$b_ok" = 1 ] && [ "$red" = 1 ]; then echo "✅ GATE OK: park adds a blocker instead of replacing one, self-clears on any recorded blocker resolving, refuses an unresolvable topic, and goes red when the additive-merge cure is removed."; exit 0; fi
echo "⛔ GATE FAILED (arm-A=$a_ok arm-B=$b_ok fail-once-red=$red)"; exit 1
