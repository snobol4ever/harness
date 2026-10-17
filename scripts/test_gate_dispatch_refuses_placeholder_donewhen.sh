#!/usr/bin/env bash
# test_gate_dispatch_refuses_placeholder_donewhen.sh -- next/assign REFUSE to dispatch a row whose
# DONE-WHEN is still the mint placeholder, rather than serving it "unverified" like any other
# could-not-measure criterion. Row mint-dispatch-refuses-a-placeholder-done-when, ceo ruling CEO-286
# 2026-09-05, adopting hq_T's measurement: s4e_dispatch_probe already answers rc=2 "could not measure"
# for a placeholder DONE-WHEN -- correctly -- but both next's dispatch gate and assign's dispatch probe
# then SERVED the row anyway, indistinguishable from a slow criterion or a missing compiler. A row
# opened onto an unmeasurable criterion can never be CLOSED by any amount of correct work (`done`
# executes the DONE-WHEN line whole; prose is not a command), so the refusal a seat gets when trying to
# close it is indistinguishable from the one a genuinely wrong CURE produces. Two rows were opened onto
# exactly this shape on 2026-09-05 alone (the err-msgs row hq_P had to re-mint, and CEO-285's rank-0
# oracle row).
#
# FOUR ARMS, hermetic under a scratch postoffice per mktemp -- never the live one:
#   (1) NEXT-REFUSES     a rank-0 row with a placeholder DONE-WHEN is REFUSED (named in the message,
#                         baton path given), NOT claimed, its QUEUE column stays FREE, and the SAME
#                         `next` invocation goes on to serve the next candidate instead of stopping dead.
#   (2) NEXT-CONTROL     a substantive DONE-WHEN that outruns the dispatch-probe budget (a real,
#                         environmental could-not-measure, not a placeholder) is still SERVED (claimed)
#                         with the pre-existing "COULD NOT MEASURE" warning -- proving this cure does not
#                         widen into refusing every rc-2-shaped row, only the placeholder text itself.
#   (3) ASSIGN-REFUSES   an HQ assigning a placeholder row to a seat is REFUSED rc=2, no claim written.
#   (4) PROMOTION-REFUSES  the OTHER path a row reaches a seat through -- dependency-inversion promotion
#                         of a blocked row's blocker -- is refused too when the BLOCKER's own DONE-WHEN
#                         is a placeholder. The first draft of the sibling next-runs-done-when-at-dispatch
#                         cure wired only the ordinary path and no sibling gate noticed; this arm exists
#                         so the same half-wired shape cannot happen here unnoticed either.
# FAIL-ONCE: three mutants, one per insertion site -- M1 removes the ordinary PASS-3 check (arm 1 red),
# M2 removes assign's check (arm 3 red), M3 removes the promotion check (arm 4 red). EXIT 0 iff all arms
# hold on the real tool AND all three mutants go red; 1 otherwise; 2 REFUSED (fixture unbuildable).
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; MSG="$HERE/s4e_msg.sh"
[ -f "$MSG" ] || { echo "⛔ REFUSED: $MSG missing"; exit 2; }
W="$(mktemp -d)" || { echo "⛔ REFUSED: mktemp failed"; exit 2; }
# ⛔ $BASHPID, not $$: a bare EXIT trap fires inside forked children too, and bash keeps $$ at the
# original shell's pid in a subshell, so the obvious guard compares equal and deletes the fixture
# mid-run (measured while building test_gate_s4e_one_process_per_identity.sh).
MAINPID=$$; trap '[ "$BASHPID" = "$MAINPID" ] && rm -rf "$W"' EXIT
PO="$W/po"; ME=hq_B; HQ=ceo; SEAT=seat01; BUDGET=4
# ⛔ THE FIXTURE MODE IS PROBED, NOT HARDCODED (COO-80, 2026-09-19, row
# instrument-the-nineteen-non-gc-blocking-arms). mk_po below wrote a literal mode, kept in step with the live
# fleet -- it read QUARTET, under which no HQ stands (CEO-911). This fixture's serving seat is hq_B, so every
# serve became a dispatch refusal and the placeholder mechanism this gate exists for was never exercised;
# worse, several arms READ AS PASSING on it, because "next did not serve the placeholder" is satisfied by a
# refusal that served nothing at all. ⛔ BOTH IDENTITIES ARE NAMED IN THE PROBE: this fixture drives an HQ
# (hq_B) and a FLEET seat (seat01), and the two are stood down by different arms of the same table, so a mode
# admitting only one still hollows the gate out.
. "$HERE/lib_gate.sh"
command -v gate_pick_dispatchable_mode >/dev/null 2>&1 || { echo "⛔ REFUSED: lib_gate.sh carries no gate_pick_dispatchable_mode -- the mode-probe rule is a sourced authority and a gate must never keep a private copy of it"; exit 2; }
PLACEHOLDER='⛔ MUST BE MADE RUNNABLE BEFORE done CAN EVER PASS — minted with no executable acceptance test; replace this line with a real command (see other tasks/*.task.md for the shape) before anyone can close this row.'
# ⛔⭐ env -u S4E_PID_LOCK AND S4E_NO_DISPATCH_PROBE: this gate is itself a DONE-WHEN, so it runs INSIDE a
# `done` that `next` may have invoked as its own dispatch probe. Both variables leak in from that parent
# and would silently change what the fixture measures -- scrubbed, always (same guard as the sibling gate).
FIX() { env -u S4E_PID_LOCK -u S4E_NO_DISPATCH_PROBE S4E_HOME="$W" S4E_POST="$PO" S4E_SEAT="$ME" \
        S4E_NO_BANNER=1 S4E_DISPATCH_PROBE_TIMEOUT="$BUDGET" "$@"; }
mkrow() { printf '%s\t%s\tunassigned\tFREE\n' "$1" "$2" >> "$PO/QUEUE.tsv"
          printf '# TASK %s\nGOAL: gate fixture.\nDONE-WHEN: %s\nLINKS: none\n## NEXT\ngo\n## LEDGER\n' "$2" "$3" > "$PO/tasks/$2.task.md"; }
col() { grep -P "^[0-9]+\t\Q$1\E\t" "$PO/QUEUE.tsv" 2>/dev/null | head -1 | cut -f4; }
mk_po() {
  rm -rf "$PO"; mkdir -p "$PO/tasks" "$PO/claims" "$PO/released" "$PO/$ME/inbox" "$PO/$HQ/inbox" "$PO/$SEAT/inbox" || return 2
  : > "$PO/BOARD.md"; : > "$PO/QUEUE.done.tsv"; printf '5\n' > "$PO/PROTOCOL-VERSION"
  if [ -z "${FIXTURE_MODE:-}" ]; then
      printf 'FLEET-16\n' > "$PO/MODE"
      FIXTURE_MODE="$(gate_pick_dispatchable_mode "$MSG" "$PO" "$ME,$SEAT" FLEET-16 FLEET-12 NONET DECTET)" || {
          echo "⛔ REFUSED: the picker refuses to dispatch $ME or $SEAT under every candidate mode (FLEET-16, FLEET-12, NONET, DECTET), so this fixture cannot get a placeholder row in front of the dispatch path at all. That is a finding about the stand-down table, not a reason to read a dispatch refusal as a placeholder refusal."; return 2; }
      echo "    fixture: MODE = $FIXTURE_MODE (probed -- the first candidate under which the picker dispatches both $ME and $SEAT)"
  fi
  printf '%s\n' "$FIXTURE_MODE" > "$PO/MODE"
  printf '%s\n' "$HQ" > "$PO/$ME/HQ"; printf '# gate fixture queue\n' > "$PO/QUEUE.tsv"
  mkrow 0 t-placeholder "$PLACEHOLDER"
  mkrow 1 t-slow 'sleep 30 && test -f "$S4E_HOME/po/QUEUE.tsv"'
  mkrow 2 t-green 'test -f "$S4E_HOME/po/QUEUE.tsv"'
  mkrow 9 t-asg-placeholder "$PLACEHOLDER"
}
arm() {   # arm <label> <script> -> 0 iff all four contracts hold on <script>
  local lbl="$1" s="$2" ok=1 out rc
  mk_po || return 2
  # ---- (1) NEXT-REFUSES: rank-0 t-placeholder is refused, unclaimed, stays FREE, and next moves on ----
  out="$(FIX bash "$s" next 2>&1)"; rc=$?
  grep -q 'REFUSING TO DISPATCH t-placeholder' <<<"$out" || { echo "  [$lbl] (1) no refusal message for t-placeholder: $(echo "$out" | head -3)"; ok=0; }
  grep -q "$PO/tasks/t-placeholder.task.md" <<<"$out" || { echo "  [$lbl] (1) refusal did not name the baton path"; ok=0; }
  grep -q 'LOCKED t-placeholder' <<<"$out" && { echo "  [$lbl] (1) t-placeholder was SERVED despite the refusal message -- the whole defect"; ok=0; }
  [ -f "$PO/claims/t-placeholder.claim" ] && { echo "  [$lbl] (1) a claim file was written for t-placeholder despite the refusal"; ok=0; }
  [ "$(col t-placeholder)" = FREE ] || { echo "  [$lbl] (1) t-placeholder column is '$(col t-placeholder)', want FREE (unclaimed, unchanged)"; ok=0; }
  grep -q 'LOCKED t-slow' <<<"$out" || { echo "  [$lbl] (1) after refusing t-placeholder, next did not go on to serve the next candidate (rank 1): $(echo "$out" | tail -5)"; ok=0; }
  [ "$rc" = 0 ] || { echo "  [$lbl] (1) next exited $rc after successfully serving a later row -- rc should be 0"; ok=0; }
  # ---- (2) NEXT-CONTROL: t-slow (just served above) is a REAL rc=2, and was served WITH a warning ------
  grep -q 'COULD NOT MEASURE t-slow' <<<"$out" || { echo "  [$lbl] (2) a genuine environmental rc=2 row was served without its usual warning -- this cure must not widen"; ok=0; }
  [ -f "$PO/claims/t-slow.claim" ] || { echo "  [$lbl] (2) t-slow was not actually claimed"; ok=0; }
  # ---- (3) ASSIGN-REFUSES: t-asg-placeholder, unclaimed, assigned to $SEAT ------------------------------
  out="$(env -u S4E_PID_LOCK -u S4E_NO_DISPATCH_PROBE S4E_HOME="$W" S4E_POST="$PO" S4E_SEAT="$HQ" S4E_NO_BANNER=1 \
        S4E_DISPATCH_PROBE_TIMEOUT="$BUDGET" bash "$s" assign "$SEAT" t-asg-placeholder 2>&1)"; rc=$?
  [ "$rc" = 2 ] || { echo "  [$lbl] (3) assign exited $rc on a placeholder DONE-WHEN, want 2: $(echo "$out" | head -3)"; ok=0; }
  grep -q 'PLACEHOLDER DONE-WHEN' <<<"$out" || { echo "  [$lbl] (3) assign's refusal did not name the placeholder shape: $(echo "$out" | head -3)"; ok=0; }
  [ -f "$PO/claims/t-asg-placeholder.claim" ] && { echo "  [$lbl] (3) assign wrote a claim despite refusing -- a refusal that still dispatches"; ok=0; }
  # ---- (4) PROMOTION-REFUSES: t-blocked is BLOCKED-ON t-promo-ph, whose OWN DONE-WHEN is a placeholder -
  mk_po || return 2
  # rank 0 candidate is BLOCKED-ON a placeholder blocker; a normal FREE row sits at rank 1 so the pass has
  # something left to serve once the promotion is (correctly) refused.
  printf '0\tt-blocked\tunassigned\tBLOCKED-ON:t-promo-ph\n' >> "$PO/QUEUE.tsv"
  printf '# TASK t-blocked\nGOAL: gate fixture.\nDONE-WHEN: test -f "$S4E_HOME/po/NO-SUCH-FILE"\nLINKS: none\n## NEXT\ngo\n## LEDGER\n' > "$PO/tasks/t-blocked.task.md"
  mkrow 5 t-promo-ph "$PLACEHOLDER"
  out="$(FIX bash "$s" next 2>&1)"
  grep -q 'LOCKED t-promo-ph' <<<"$out" && { echo "  [$lbl] (4) the placeholder blocker t-promo-ph was PROMOTED AND SERVED -- the promotion path is unwired"; ok=0; }
  [ -f "$PO/claims/t-promo-ph.claim" ] && { echo "  [$lbl] (4) a claim file was written for the placeholder blocker t-promo-ph"; ok=0; }
  grep -qE 'REFUSING TO (DISPATCH|PROMOTE) t-promo-ph' <<<"$out" || { echo "  [$lbl] (4) no refusal message for the placeholder blocker: $(echo "$out" | head -3)"; ok=0; }
  [ "$(col t-blocked)" = "BLOCKED-ON:t-promo-ph" ] || { echo "  [$lbl] (4) t-blocked's state moved to '$(col t-blocked)' -- a refused promotion must not silently un-block it"; ok=0; }
  [ "$ok" = 1 ]
}
echo "next/assign refuse a placeholder DONE-WHEN, on both the ordinary and the promotion serve path (scratch postoffice under $W)"
if arm PASS "$MSG"; then echo "  [PASS] next refuses + moves on · a real rc=2 still serves (control) · assign refuses rc=2, no claim · promotion of a placeholder blocker refuses too"; pass=1
else pass=$?; [ "$pass" = 2 ] && { echo "⛔ REFUSED: fixture could not be built (rc=2)"; exit 2; }; pass=0; fi
mut() {  # mut <name> <from> <to> -> writes $W/<name>.sh, verified actually changed and still parses
  local n="$1" a="$2" b="$3"
  awk -v a="$a" -v b="$b" '$0==a{print b; k++; next} {print} END{exit !k}' "$MSG" > "$W/$n.sh" \
    || { echo "⛔ REFUSED: $n's anchor line is not where the mutant expects it -- the mutation would be a no-op"; exit 2; }
  grep -qF "$b" "$W/$n.sh" || { echo "⛔ REFUSED: $n did not change the file"; exit 2; }
  bash -n "$W/$n.sh" 2>/dev/null || { echo "⛔ REFUSED: the $n mutant does not parse -- fixture, not verdict"; exit 2; }
}
# ⛔ EXACT-STRING awk, never regex sed: these lines are dense in $ | * ( ) and a mutation that silently
# matched nothing would hand back an unmutated copy, the arm would pass, and the gate would report a
# fail-once it never performed -- a false green inside the mechanism that exists to disprove one.
mut m1 '           if s4e_predispatch_placeholder_check "$topic"; then' '           if false; then'
if arm M1-ordinary-unwired "$W/m1.sh" >"$W/m1.log" 2>&1; then echo "  [FAIL-ONCE M1] ⛔ GREEN with next's ordinary-path check removed"; m1=0
else echo "  [FAIL-ONCE M1] red as required, ordinary path unwired: $(grep -m1 '(1)' "$W/m1.log" | sed 's/^ *//' | cut -c1-100)"; m1=1; fi
mut m2 '         if s4e_predispatch_placeholder_check "$topic"; then' '         if false; then'
if arm M2-assign-unwired "$W/m2.sh" >"$W/m2.log" 2>&1; then echo "  [FAIL-ONCE M2] ⛔ GREEN with assign's check removed"; m2=0
else echo "  [FAIL-ONCE M2] red as required, assign unwired: $(grep -m1 '(3)' "$W/m2.log" | sed 's/^ *//' | cut -c1-100)"; m2=1; fi
mut m3 '    s4e_predispatch_placeholder_check "$1" || return 0' '    return 0'
if arm M3-promotion-unwired "$W/m3.sh" >"$W/m3.log" 2>&1; then echo "  [FAIL-ONCE M3] ⛔ GREEN with the promotion-path check removed"; m3=0
else echo "  [FAIL-ONCE M3] red as required, promotion unwired: $(grep -m1 '(4)' "$W/m3.log" | sed 's/^ *//' | cut -c1-100)"; m3=1; fi
if [ "$pass" = 1 ] && [ "$m1" = 1 ] && [ "$m2" = 1 ] && [ "$m3" = 1 ]; then
  echo "✅ GATE OK: next and assign both refuse a placeholder DONE-WHEN with no claim written, on the ordinary and promotion serve paths, while a real rc=2 criterion still serves."; exit 0; fi
echo "⛔ GATE FAILED (pass=$pass m1-red=$m1 m2-red=$m2 m3-red=$m3)"; exit 1
