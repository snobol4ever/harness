#!/usr/bin/env bash
# test_gate_s4e_next_runs_done_when_at_dispatch.sh -- the picker RUNS a row's DONE-WHEN before serving it.
# Row next-and-assign-re-run-a-rows-done-when-before-serving-it (ceo ruling 2026-09-03 adopting seat09's
# suggestion). MEASURED by seat09 (FINDING-2026-09-03-seat09-pascal-relop-array-field-row-was-already-cured-
# five-days-before-dispatch.md): pascal-relop-into-array-and-field-lvalues-loses-value sat FREE for FIVE DAYS
# describing a bug a sibling row had already cured (ff1df778), and its DONE-WHEN grepped an exact "N pass /
# 0 fail" string that corpus growth had made permanently unpassable. The answer was in the baton the whole
# time and nothing ever asked it. Cure: s4e_msg.sh next (PASS 3) + assign, hq_B 2026-09-03.
# THE RULING'S THREE-WAY SPLIT: green closes the row DONE with an "already satisfied at dispatch" ledger line
# and serves the next; REFUSE (rc=2)/timeout serves the row WITH A WARNING; only RED serves it silently.
# SEVEN ARMS against a THROWAWAY postoffice under mktemp -- never the live one:
#   (1) GREEN-CLOSES  a satisfied row is NOT served: closed DONE (claim latch + column), baton gains the
#                     ledger line, and the picker goes on to serve the NEXT row.
#   (2) RED-SILENT    a genuinely failing row is served with ZERO probe chatter -- red is the only silent
#                     outcome because it is the only one that means there is real work here.
#   (3) SLOW-WARNS    a criterion that outruns the probe budget serves the row WITH a warning, never silently
#                     and never closed. A criterion too slow to PROBE is not a failing row.
#   (4) NOOP-NEVER-CLOSES  ⛔ THE SAFETY ARM. A DONE-WHEN of `true` certifies nothing. It must NOT be taken
#                     for green -- auto-closing on it would delete live rows on a criterion that examines
#                     nothing, which is strictly worse than the dead row this whole cure is about.
#   (5) ASSIGN-REFUSES  an HQ dispatching a satisfied row is refused and NO claim is written.
#   (6) CLOSE-SHAPE   ⛔ THE ANTI-DRIFT ARM. A dispatch-close must be byte-identical in shape to a hand
#                     `done` close (claim latch + column), because next delegates to `done` precisely so the
#                     close cannot exist twice. If someone reimplements it, this arm goes red.
#   (8) PROMOTION   the OTHER PASS 3 serve path -- dependency-inversion promotion of a blocked row's blocker
#                     -- is probed too. The first draft wired only one of the two and no sibling gate noticed.
#   (7) NOOP-AGREES   assign cannot delegate to `done` (that verb needs the runner's own claim), so it uses a
#                     MIRROR of done's vacuity blocklist. Two copies of one rule drift -- this arm asserts the
#                     two agree over a table of criteria instead of trusting a comment that says they do.
# FAIL-ONCE: four mutants -- M1 drops next's probe (arm 1 red), M2 stops assign refusing (arm 5 red),
# M3 blinds the vacuity mirror (arm 7 red), M4 unwires the promotion path only (arm 8 red). EXIT 0 all arms hold and all three mutants
# go red; 1 otherwise; 2 REFUSED (fixture unbuildable).
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; MSG="$HERE/s4e_msg.sh"
[ -f "$MSG" ] || { echo "⛔ REFUSED: $MSG missing"; exit 2; }
W="$(mktemp -d)" || { echo "⛔ REFUSED: mktemp failed"; exit 2; }
# ⛔ $BASHPID, not $$: a bare EXIT trap fires inside forked children too, and bash keeps $$ at the original
# shell's pid in a subshell, so the obvious guard compares equal and deletes the fixture mid-run (measured
# while building test_gate_s4e_one_process_per_identity.sh).
MAINPID=$$; trap '[ "$BASHPID" = "$MAINPID" ] && rm -rf "$W"' EXIT
PO="$W/po"; ME=hq_B; HQ=ceo; SEAT=seat01; BUDGET=4
# ⛔⭐ env -u S4E_PID_LOCK AND S4E_NO_DISPATCH_PROBE: this gate is itself a DONE-WHEN, so it runs INSIDE a
# `done` that `next` may have invoked as its own probe. Both variables leak in from that parent and would
# silently change what the fixture measures -- the identity lock would take every fixture process for a
# descendant, and an inherited opt-out would disable the very feature under test. Scrubbed, always.
FIX() { env -u S4E_PID_LOCK -u S4E_NO_DISPATCH_PROBE S4E_HOME="$W" S4E_POST="$PO" S4E_SEAT="$ME" \
        S4E_NO_BANNER=1 S4E_DISPATCH_PROBE_TIMEOUT="$BUDGET" "$@"; }
mkrow() { printf '%s\t%s\tunassigned\tFREE\n' "$1" "$2" >> "$PO/QUEUE.tsv"
          printf '# TASK %s\nGOAL: gate fixture.\nDONE-WHEN: %s\nLINKS: none\n## NEXT\ngo\n## LEDGER\n' "$2" "$3" > "$PO/tasks/$2.task.md"; }
mk_po() {
  rm -rf "$PO"; mkdir -p "$PO/tasks" "$PO/claims" "$PO/released" "$PO/$ME/inbox" "$PO/$HQ/inbox" "$PO/$SEAT/inbox" || return 2
  : > "$PO/BOARD.md"; : > "$PO/QUEUE.done.tsv"; printf 'QUARTET\n' > "$PO/MODE"; printf '5\n' > "$PO/PROTOCOL-VERSION"
  printf '%s\n' "$HQ" > "$PO/$ME/HQ"; printf '# gate fixture queue\n' > "$PO/QUEUE.tsv"
  mkrow 0 t-green 'test -f "$S4E_HOME/po/QUEUE.tsv"'
  mkrow 1 t-red   'test -f "$S4E_HOME/po/NO-SUCH-FILE"'
  mkrow 2 t-after 'test -f "$S4E_HOME/po/NO-SUCH-FILE"'
  mkrow 3 t-slow  'sleep 30 && test -f "$S4E_HOME/po/QUEUE.tsv"'
  mkrow 4 t-noop  'true'
  mkrow 5 t-hand  'test -f "$S4E_HOME/po/MODE"'
  mkrow 6 t-asg   'test -f "$S4E_HOME/po/MODE"'
}
col() { grep -P "^[0-9]+\t\Q$1\E\t" "$PO/QUEUE.tsv" 2>/dev/null | head -1 | cut -f4; }
park_off() { sed -i "s|^\\([0-9]*\\)\t$1\t\\([^\t]*\\)\t.*|\\1\t$1\t\\2\tPARKED|" "$PO/QUEUE.tsv"; rm -f "$PO/claims/$1.claim"; }
# ⛔ ONE fixture row is served per `next`; the arms below park each row off after grading it so the picker
# reaches the next one. Parking is the fixture's business, never the cure's.
arm() {   # arm <label> <script> -> 0 iff all seven contracts hold on <script>
  local lbl="$1" s="$2" ok=1 out rc
  mk_po || return 2
  # ---- (1) GREEN-CLOSES + (2) the picker moves on ------------------------------------------------------
  out="$(FIX bash "$s" next 2>&1)"
  grep -q 'ALREADY SATISFIED AT DISPATCH' <<<"$out" || { echo "  [$lbl] (1) a satisfied row was dispatched without the probe saying so"; ok=0; }
  grep -q 'LOCKED t-green' <<<"$out" && { echo "  [$lbl] (1) the satisfied row t-green was SERVED -- the whole defect"; ok=0; }
  [ "$(col t-green)" = DONE ] || { echo "  [$lbl] (1) t-green column is '$(col t-green)', want DONE"; ok=0; }
  grep -q '^DONE$' "$PO/claims/t-green.claim" 2>/dev/null || { echo "  [$lbl] (1) t-green claim carries no DONE latch"; ok=0; }
  grep -q 'ALREADY SATISFIED AT DISPATCH' "$PO/tasks/t-green.task.md" || { echo "  [$lbl] (1) no ledger line in the baton"; ok=0; }
  grep -q 'LOCKED t-red' <<<"$out" || { echo "  [$lbl] (1) after closing t-green the picker did not go on to serve the next row"; ok=0; }
  # ---- (2) RED-SILENT: t-red was just served -- it must have drawn no probe chatter --------------------
  grep -qE '⚠ DISPATCH PROBE|can never pass' <<<"$out" && { echo "  [$lbl] (2) a genuinely RED row was served with probe chatter -- red is the one silent outcome"; ok=0; }
  park_off t-red; park_off t-after
  # ---- (3) SLOW-WARNS ----------------------------------------------------------------------------------
  out="$(FIX bash "$s" next 2>&1)"
  grep -q 'LOCKED t-slow' <<<"$out" || { echo "  [$lbl] (3) a slow-criterion row was not served: $(grep -m1 -E 'LOCKED|EMPTY' <<<"$out")"; ok=0; }
  grep -q 'COULD NOT MEASURE' <<<"$out" || { echo "  [$lbl] (3) a criterion that outran the probe budget was served SILENTLY -- a picker must not hide what it could not measure"; ok=0; }
  [ "$(col t-slow)" = DONE ] && { echo "  [$lbl] (3) a row that could not be MEASURED was CLOSED -- the unsafe direction"; ok=0; }
  park_off t-slow
  # ---- (4) NOOP-NEVER-CLOSES ---------------------------------------------------------------------------
  out="$(FIX bash "$s" next 2>&1)"
  [ "$(col t-noop)" = DONE ] && { echo "  [$lbl] (4) a row whose DONE-WHEN is \`true\` was CLOSED at dispatch -- auto-closing on a criterion that examines nothing"; ok=0; }
  grep -q 'LOCKED t-noop' <<<"$out" || { echo "  [$lbl] (4) the vacuous-criterion row was not served: $(grep -m1 -E 'LOCKED|EMPTY' <<<"$out")"; ok=0; }
  grep -q 'can never pass' <<<"$out" || { echo "  [$lbl] (4) served a row with an uncloseable DONE-WHEN and said nothing about it"; ok=0; }
  park_off t-noop
  # ---- (6) CLOSE-SHAPE: a dispatch close matches a hand `done` close -----------------------------------
  FIX bash "$s" claim t-hand >/dev/null 2>&1 && FIX bash "$s" done t-hand >/dev/null 2>&1 \
    || { echo "  [$lbl] fixture: hand close of t-hand failed"; return 2; }
  local hcol hlatch; hcol="$(col t-hand)"; hlatch="$(grep -c '^DONE$' "$PO/claims/t-hand.claim" 2>/dev/null || echo 0)"
  [ "$hcol" = "$(col t-green)" ] || { echo "  [$lbl] (6) dispatch-close column '$(col t-green)' != hand-done column '$hcol' -- the close has been reimplemented"; ok=0; }
  [ "$hlatch" = "$(grep -c '^DONE$' "$PO/claims/t-green.claim" 2>/dev/null || echo 0)" ] || { echo "  [$lbl] (6) dispatch-close claim latch differs from a hand done close"; ok=0; }
  # ---- (5) ASSIGN-REFUSES ------------------------------------------------------------------------------
  out="$(env -u S4E_PID_LOCK -u S4E_NO_DISPATCH_PROBE S4E_HOME="$W" S4E_POST="$PO" S4E_SEAT="$HQ" S4E_NO_BANNER=1 \
        S4E_DISPATCH_PROBE_TIMEOUT="$BUDGET" bash "$s" assign "$SEAT" t-asg 2>&1)"; rc=$?
  [ "$rc" = 0 ] && { echo "  [$lbl] (5) assign DISPATCHED an already-satisfied row (rc=0)"; ok=0; }
  grep -q 'ALREADY SATISFIED' <<<"$out" || { echo "  [$lbl] (5) assign refused but not for being already satisfied: $(grep -m1 -E '⛔' <<<"$out" | cut -c1-90)"; ok=0; }
  [ -f "$PO/claims/t-asg.claim" ] && { echo "  [$lbl] (5) assign wrote a claim despite refusing -- a refusal that still dispatches"; ok=0; }
  # ---- (7) NOOP-AGREES: the assign-side mirror agrees with done's own blocklist ------------------------
  local crit dv pv n=0
  while IFS='|' read -r crit; do
    [ -n "$crit" ] || continue; n=$((n+1))
    rm -f "$PO/claims/t-ag.claim"; grep -v $'\tt-ag\t' "$PO/QUEUE.tsv" > "$PO/q.t" && mv "$PO/q.t" "$PO/QUEUE.tsv"
    mkrow 8 t-ag "$crit"
    FIX bash "$s" claim t-ag >/dev/null 2>&1
    if FIX bash "$s" done t-ag 2>&1 | grep -q 'no-op'; then dv=noop; else dv=usable; fi
    rm -f "$PO/claims/t-ag.claim"
    if env -u S4E_PID_LOCK -u S4E_NO_DISPATCH_PROBE S4E_HOME="$W" S4E_POST="$PO" S4E_SEAT="$HQ" S4E_NO_BANNER=1 \
       S4E_DISPATCH_PROBE_TIMEOUT="$BUDGET" bash "$s" assign "$SEAT" t-ag 2>&1 | grep -q 'certifies nothing'; then pv=noop; else pv=usable; fi
    rm -f "$PO/claims/t-ag.claim"
    [ "$dv" = "$pv" ] || { echo "  [$lbl] (7) done says '$dv' and the assign-side mirror says '$pv' for DONE-WHEN: $crit"; ok=0; }
  done <<'CRITS'
true
:
exit 0
echo done
true # nothing to verify
VAR=1 true
test -f /etc/hostname
CRITS
  [ "$n" -ge 6 ] || { echo "  [$lbl] fixture: the agreement table did not run ($n criteria)"; return 2; }
  # ---- (8) PROMOTION-PROBED -- RUNS LAST: its `next` walks the queue closing every satisfied row it meets,
  #          which would eat the fixtures arms 5 and 6 depend on. The OTHER serve path in PASS 3 -------------------------------------------
  # ⛔ PASS 3 hands a row to a seat from TWO places: the ordinary claim-and-serve, and the DEPENDENCY
  # INVERSION promotion that serves a blocked row's BLOCKER at the blocked row's rank. The first draft of the
  # cure wired only the ordinary one, and nothing caught it -- test_gate_s4e_unclaim_keeps_park.sh still
  # passed, because the row it asserts on arrives through the promotion path and sailed past the probe. This
  # arm exists so a half-wired cure can never read as a whole one again.
  printf '0\tt-blocked\tunassigned\tBLOCKED-ON:t-boss\n' >> "$PO/QUEUE.tsv"
  printf '# TASK t-blocked\nGOAL: gate fixture.\nDONE-WHEN: test -f "$S4E_HOME/po/NO-SUCH-FILE"\nLINKS: none\n## NEXT\ngo\n## LEDGER\n' > "$PO/tasks/t-blocked.task.md"
  mkrow 9 t-boss 'test -f "$S4E_HOME/po/MODE"'
  out="$(FIX bash "$s" next 2>&1)"
  grep -q 'LOCKED t-boss' <<<"$out" && { echo "  [$lbl] (8) a satisfied row served by DEPENDENCY INVERSION bypassed the probe -- the promotion path is unwired"; ok=0; }
  [ "$(col t-boss)" = DONE ] || { echo "  [$lbl] (8) the promoted blocker t-boss was not closed at dispatch (column '$(col t-boss)')"; ok=0; }
  park_off t-boss; park_off t-blocked

  [ "$ok" = 1 ]
}
echo "s4e next/assign run a row's DONE-WHEN at dispatch (scratch postoffice under $W)"
cp "$HERE/lib_release_guard.sh" "$W/" 2>/dev/null || true
if arm PASS "$MSG"; then echo "  [PASS] green closes + serves next · red silent · slow warns · \`true\` never closes · assign refuses · close shape matches \`done\` · vacuity mirror agrees"; pass=1
else pass=$?; [ "$pass" = 2 ] && { echo "⛔ REFUSED: fixture could not be built (rc=2)"; exit 2; }; pass=0; fi
mut() {  # mut <name> <from> <to> <log> -> writes $W/<name>.sh, verified actually changed
  local n="$1" a="$2" b="$3"
  awk -v a="$a" -v b="$b" '$0==a{print b; k++; next} {print} END{exit !k}' "$MSG" > "$W/$n.sh" \
    || { echo "⛔ REFUSED: $n's anchor line is not where the mutant expects it -- the mutation would be a no-op"; exit 2; }
  grep -qF "$b" "$W/$n.sh" || { echo "⛔ REFUSED: $n did not change the file"; exit 2; }
  bash -n "$W/$n.sh" 2>/dev/null || { echo "⛔ REFUSED: the $n mutant does not parse -- fixture, not verdict"; exit 2; }
}
# ⛔ EXACT-STRING awk, never regex sed: these lines are dense in $ | * ( ) and a mutation that silently matched
# nothing would hand back an unmutated copy, the arm would pass, and the gate would report a fail-once it never
# performed -- a false green inside the mechanism that exists to disprove one.
mut m1 '    _dp_out="$(S4E_NO_BANNER=1 S4E_DONE_TIMEOUT="$(s4e_dispatch_timeout)" "$0" done "$_dgt" 2>&1)"; _dp_rc=$?' \
       '    _dp_out=""; _dp_rc=1'
if arm M1-no-probe "$W/m1.sh" >"$W/m1.log" 2>&1; then echo "  [FAIL-ONCE M1] ⛔ GREEN with next's probe removed -- the gate cannot detect an unprobed picker"; m1=0
else echo "  [FAIL-ONCE M1] red as required, no probe: $(grep -m1 '(1)' "$W/m1.log" | sed 's/^ *//' | cut -c1-100)"; m1=1; fi
mut m2 '           if [ "$_dprc" = 0 ]; then' '           if false; then'
if arm M2-assign-dispatches "$W/m2.sh" >"$W/m2.log" 2>&1; then echo "  [FAIL-ONCE M2] ⛔ GREEN with assign's refusal removed"; m2=0
else echo "  [FAIL-ONCE M2] red as required, assign dispatches: $(grep -m1 '(5)' "$W/m2.log" | sed 's/^ *//' | cut -c1-100)"; m2=1; fi
# ⛔ M3 short-circuits the BODY rather than replacing the header: swapping the header would need a second
# function to absorb the orphaned body, and a mutant that will not PARSE goes red for a reason having nothing
# to do with the cure -- a fail-once that proves nothing.
mut m3 '    local dw="${1:-}" nc nrm first' '    return 1'
if arm M3-blind-mirror "$W/m3.sh" >"$W/m3.log" 2>&1; then echo "  [FAIL-ONCE M3] ⛔ GREEN with the vacuity mirror blinded -- the gate cannot detect drift from done's blocklist"; m3=0
else echo "  [FAIL-ONCE M3] red as required, mirror blinded: $(grep -m1 '(7)' "$W/m3.log" | sed 's/^ *//' | cut -c1-100)"; m3=1; fi
# ⛔ M4 UNWIRES ONLY THE PROMOTION PATH -- the exact half-wired state the first draft of this cure shipped in,
# and which every sibling gate passed straight through. If arm 8 cannot see this, the arm is decoration.
mut m4 '                 s4e_dispatch_gate "$promo" "$rank" || continue' '                 :'
if arm M4-promotion-unwired "$W/m4.sh" >"$W/m4.log" 2>&1; then echo "  [FAIL-ONCE M4] ⛔ GREEN with the promotion path unwired -- arm 8 cannot see a half-wired cure"; m4=0
else echo "  [FAIL-ONCE M4] red as required, promotion unwired: $(grep -m1 '(8)' "$W/m4.log" | sed 's/^ *//' | cut -c1-100)"; m4=1; fi
if [ "$pass" = 1 ] && [ "$m1" = 1 ] && [ "$m2" = 1 ] && [ "$m3" = 1 ] && [ "$m4" = 1 ]; then
  echo "✅ GATE OK: the picker runs a row's DONE-WHEN before serving it, closes only on a criterion that certifies something, and never hides what it could not measure."; exit 0; fi
echo "⛔ GATE FAILED (pass=$pass m1-red=$m1 m2-red=$m2 m3-red=$m3 m4-red=$m4)"; exit 1
