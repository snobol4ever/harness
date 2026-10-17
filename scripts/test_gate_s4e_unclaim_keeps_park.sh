#!/usr/bin/env bash
# test_gate_s4e_unclaim_keeps_park.sh -- `unclaim` drives QUEUE.tsv's state column to FREE ONLY over a CLAIM-SHAPED column
# (CLAIMED:<seat>, ASSIGNED, ASSIGNED:<seat>, FREE, empty); a park written AROUND the claim (SUPERSEDED*, BLOCKED-ON:*,
# PARKED-AWAITING:*, PARKED*, RETIRED, GRANT-NEEDED*, RESTRICTED:*) survives the release, the receipt names it, and `next`
# does not serve the row. Row unclaim-clobbers-a-park-written-around-the-claim-so-next-serves-a-superseded-row (ceo MEASURED
# 2026-09-02 ~14:55: hq_B's unclaim of the superseded rung-2.0 row erased ceo's forced park, ceo's own `next` locked the
# resurrected rank-0 row, and a second unclaim lost the park again). Cure: s4e_msg.sh unclaim, hq_B 2026-09-02.
# TWO ARMS against a THROWAWAY postoffice under mktemp -- never the live one -- each run against the live s4e_msg.sh and
# against a mutated copy with the cure removed (FAIL-ONCE, INSTRUMENT LAWS fifth batch):
#   (A) claim -> unclaim over CLAIMED:<seat>  -> column FREE (the 2026-08-28 dispatch ruling, untouched)
#   (B) claim as hq_B -> ceo force-parks around it (SUPERSEDED:..., BLOCKED-ON:<row>, PARKED, GRANT-NEEDED:...) -> hq_B unclaims
#       -> column UNCHANGED, claim file gone, receipt names the kept state, and `next` as a third seat never locks the row.
# EXIT 0 both arms hold on the live script AND arm (B) goes red on the mutated copy; 1 otherwise; 2 REFUSED (fixture cannot be built).
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; MSG="$HERE/s4e_msg.sh"
[ -f "$MSG" ] || { echo "⛔ REFUSED: $MSG missing"; exit 2; }
W="$(mktemp -d)" || { echo "⛔ REFUSED: mktemp failed"; exit 2; }; trap 'rm -rf "$W"' EXIT
PO="$W/po"; ME=hq_B; PARKER=ceo; THIRD=hq_P
# ⛔ THE FIXTURE MODE IS PROBED, NOT HARDCODED (COO-80, 2026-09-19, row
# instrument-the-nineteen-non-gc-blocking-arms). mk_po below wrote `TRIO` into the scratch MODE. TRIO stands
# EVERY HQ down (CEO-910, 2026-09-19), and both seats this gate drives -- hq_B and hq_P -- are HQs, so every
# `next` in it became a dispatch refusal. ⛔ THAT DID NOT SHOW UP AS A HONEST RED: arm (A) asks that `next`
# did NOT lock the released row, and a REFUSAL satisfies that by doing nothing at all, so the arm was passing
# over an empty measurement while the gate as a whole failed for a reason that had nothing to do with parks.
# The mode was incidental to this gate's subject -- that a park written around a claim survives unclaim -- and
# became load-bearing without anyone choosing it. The rule is a sourced authority in lib_gate.sh: candidates
# are probed against the picker with an empty queue, claiming nothing, and the first that admits the seat is
# used, so the next stand-down moves this fixture along instead of hollowing it out.
. "$HERE/lib_gate.sh"
command -v gate_pick_dispatchable_mode >/dev/null 2>&1 || { echo "⛔ REFUSED: lib_gate.sh carries no gate_pick_dispatchable_mode -- the mode-probe rule is a sourced authority and a gate must never keep a private copy of it"; exit 2; }
mk_po() {
  rm -rf "$PO"; mkdir -p "$PO/tasks" "$PO/claims" "$PO/released" "$PO/$ME/inbox" "$PO/$PARKER/inbox" "$PO/$THIRD/inbox" || return 2
  : > "$PO/BOARD.md"; : > "$PO/QUEUE.done.tsv"
  if [ -z "${FIXTURE_MODE:-}" ]; then
      printf 'DECTET\n' > "$PO/MODE"
      FIXTURE_MODE="$(gate_pick_dispatchable_mode "$MSG" "$PO" "$THIRD" DECTET NONET FLEET-16)" || {
          echo "⛔ REFUSED: the picker refuses to dispatch $THIRD under every candidate mode (DECTET, NONET, FLEET-16), so this fixture cannot ask a third seat whether a parked row is served. That is a finding about the stand-down table, not a reason to grade a refusal as a pass."; return 2; }
      echo "    fixture: MODE = $FIXTURE_MODE (probed -- the first candidate under which the picker dispatches $THIRD)"
  fi
  printf '%s\n' "$FIXTURE_MODE" > "$PO/MODE"
  { printf '# gate fixture queue\n'; printf '2\tt-claim-shaped\tunassigned\tFREE\n'; printf '5\tt-blocker\tunassigned\tFREE\n'
    local i=0 t; for t in $PARKS; do i=$((i+1)); printf '0\tt-parked-%d\tunassigned\tFREE\n' "$i"; done; } > "$PO/QUEUE.tsv"
  local t; for t in t-claim-shaped t-blocker t-parked-1 t-parked-2 t-parked-3 t-parked-4; do
  # ⛔ THE FIXTURE CRITERION MUST BE **RED**, and it used to be `test -f <the baton itself>` -- always
  # true. Since 2026-09-03 the picker RUNS a row's DONE-WHEN before serving it (row next-and-assign-
  # re-run-a-rows-done-when-before-serving-it), so a fixture row whose criterion already passes is
  # closed at dispatch instead of served, and this gate could never see the routing it exists to test.
  # ⭐ The old fixture was ALWAYS semantically wrong -- a FREE row means "work not done" -- and nothing
  # noticed because nothing ever ran it. $PO/landed/<topic> is never created, so the row reads as real work.
    printf '# TASK %s\nGOAL: gate fixture.\nDONE-WHEN: test -f %s/landed/%s\nLINKS: none\n## NEXT\n(none)\n## LEDGER\n' "$t" "$PO" "$t" > "$PO/tasks/$t.task.md"; done
}
PARKS="SUPERSEDED:folded-into-t-blocker BLOCKED-ON:t-blocker PARKED GRANT-NEEDED:lon"
run() { local seat="$1" force="$2"; shift 2; S4E_POST="$PO" S4E_SEAT="$seat" S4E_PARK_FORCE="$force" S4E_NO_BANNER=1 bash "$@" >"$W/out" 2>&1; }
col() { grep -P "^[0-9]+\t\Q$1\E\t" "$PO/QUEUE.tsv" | head -1 | cut -f4; }
arm() {   # arm <label> <script> -> 0 iff the contract holds on <script>
  local lbl="$1" s="$2" ok=1 i=0 st c
  mk_po || return 2
  run $ME 0 "$s" claim t-claim-shaped || { echo "  [$lbl] claim t-claim-shaped failed: $(tail -1 "$W/out")"; return 2; }
  c="$(col t-claim-shaped)"; [ "$c" = "CLAIMED:$ME" ] || { echo "  [$lbl] fixture: after claim column=$c (want CLAIMED:$ME)"; return 2; }
  run $ME 0 "$s" unclaim t-claim-shaped gate; c="$(col t-claim-shaped)"
  [ "$c" = FREE ] || { echo "  [$lbl] (A) unclaim over CLAIMED: column=$c (want FREE -- the 2026-08-28 ruling)"; ok=0; }
  for st in $PARKS; do i=$((i+1))
    run $ME 0 "$s" claim "t-parked-$i" || { echo "  [$lbl] claim t-parked-$i failed: $(tail -1 "$W/out")"; return 2; }
    run $PARKER 1 "$s" park "t-parked-$i" "$st" || { echo "  [$lbl] fixture: ceo force-park $st refused: $(grep -m1 REFUSED "$W/out" | cut -c1-120)"; return 2; }
    c="$(col "t-parked-$i")"; [ "$c" = "$st" ] || { echo "  [$lbl] fixture: after park-around column=$c (want $st)"; return 2; }
    [ -f "$PO/claims/t-parked-$i.claim" ] || { echo "  [$lbl] fixture: park-around removed the claim"; return 2; }
    run $ME 0 "$s" unclaim "t-parked-$i" gate; c="$(col "t-parked-$i")"
    [ "$c" = "$st" ] || { echo "  [$lbl] (B) unclaim under park-around: column=$c (want $st kept)"; ok=0; }
    [ ! -f "$PO/claims/t-parked-$i.claim" ] || { echo "  [$lbl] (B) unclaim left the claim file"; ok=0; }
    grep -q "KEPT as '$st'" "$W/out" || { echo "  [$lbl] (B) receipt does not name the kept state $st"; ok=0; }
    grep -q "column kept as $st" "$PO/tasks/t-parked-$i.task.md" || { echo "  [$lbl] (B) ledger line does not name the kept state $st"; ok=0; }
  done
  run $THIRD 0 "$s" next; if grep -q 'LOCKED t-parked-' "$W/out" || ls "$PO/claims/" | grep -q '^t-parked-'; then echo "  [$lbl] (B) next served a parked-around row: $(grep -m1 LOCKED "$W/out")"; ok=0; fi
  grep -qE 'LOCKED t-(claim-shaped|blocker)' "$W/out" || { echo "  [$lbl] (A) next served neither the released claim-shaped row nor its blocker (PASS 3 serves a BLOCKED-ON row's blocker first, by design): $(grep -m1 -E 'LOCKED|EMPTY|REFUS|⛔' "$W/out" | cut -c1-120)"; ok=0; }
  [ "$ok" = 1 ]
}
echo "s4e unclaim keeps a park written around the claim (scratch postoffice under $W)"
if arm PASS "$MSG"; then echo "  [PASS] (A) CLAIMED -> FREE; (B) SUPERSEDED/BLOCKED-ON/PARKED/GRANT-NEEDED kept, receipt+ledger name it, next skips them"; pass=1; else pass=$?; [ "$pass" = 2 ] && { echo "⛔ REFUSED: fixture could not be built (rc=2)"; exit 2; }; pass=0; fi
sed 's/^\(\s*\*) _kept="\$_cur";\).*$/\1 _kept=""; s4e_set_row_state "$topic" "FREE" || true;;/' "$MSG" > "$W/msg_nocure.sh"
grep -q '_kept=""; s4e_set_row_state "$topic" "FREE" || true;;' "$W/msg_nocure.sh" || { echo "⛔ REFUSED: could not remove the cure for the fail-once arm (the kept arm moved?)"; exit 2; }
if arm FAIL-ONCE "$W/msg_nocure.sh" >"$W/failonce" 2>&1; then echo "  [FAIL-ONCE] ⛔ the gate stayed GREEN with the cure removed -- it cannot detect the defect it exists for"; red=0; else echo "  [FAIL-ONCE] red as required with the cure removed: $(grep -m1 '(B)' "$W/failonce" | sed 's/^ *//' | cut -c1-110)"; red=1; fi
if [ "$pass" = 1 ] && [ "$red" = 1 ]; then echo "✅ GATE OK: unclaim frees only a claim-shaped column, keeps a park written around the claim, and goes red when the cure is removed."; exit 0; fi
echo "⛔ GATE FAILED (pass=$pass fail-once-red=$red)"; exit 1
