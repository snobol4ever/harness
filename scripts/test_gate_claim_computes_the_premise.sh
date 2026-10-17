#!/usr/bin/env bash
# test_gate_claim_computes_the_premise.sh -- `claim` and `next` RUN a row's PREMISE-WHEN and REFUSE the lock
# when it comes back red, the way `done` runs its DONE-WHEN and refuses to close.
# Row instruments-claim-computes-the-rows-premise-the-way-done-computes-its-done-when (coo 2026-09-20; ceo
# CEO-1002, on Lon's rule that when a seat fails to do a thing the system never asked them to do, the row is
# against the SYSTEM -- a ruling that converts a structural gap into an instruction is obeyed for a week).
# THE ASYMMETRY BEING CURED: the bus VERIFIED THE EXIT and TRUSTED THE ENTRY. SIX WHEEL-SPINS IN ONE DAY,
# 2026-09-20, every one a premise that was cheap to check and that nothing made anyone check: a 51-entry
# taxonomy withdrawn because the allocator never collects; a trail mark banked against an empty trail; a cure
# announced for a raw push a watchpoint then proved dead; effort inferred from `ps`; a row opened on a premise
# red in every SnoRungs run; an eight-program bisect with three claims false on this tree.
# ⛔ A RED PREMISE IS NOT A DEFECT. It is the row needing REWRITING before an hour goes into it -- so the
# refusal must not lock, must not serve, must name the premise, and must say which of those two things it is.
# TEN ARMS against a THROWAWAY postoffice under mktemp -- never the live one:
#   (1) STALE-REFUSES   a red PREMISE-WHEN refuses `claim`: NO claim file, column still FREE, nonzero rc.
#   (2) NAMES-IT        that refusal PRINTS the failing premise text and what the premise itself said. A
#                       refusal that does not name the premise sends the seat to debug their own tree.
#   (3) LIVE-ADMITS     a green PREMISE-WHEN locks exactly as before -- the gate must not cost a good row.
#   (4) ABSENT-ADMITS   a baton with NO PREMISE-WHEN still locks (⛔ 1100+ live batons predate the field; a
#                       gate that blocked them would stop the fleet) -- and says so, so nothing reads an
#                       unasked question as a verified answer.
#   (5) NOOP-NOT-VERIFIED  `PREMISE-WHEN: true` locks but must NOT report a verified premise. The vacuous
#                       criterion is the entry-side form of the false green this fleet keeps paying for.
#   (6) ASSIGNED-GATED  ⛔ THE PATH THAT MATTERS MOST. An ASSIGNED row never passes through `claim` (the HQ
#                       wrote the lock), so a cure wired only into `claim` leaves the fleet's COMMONEST
#                       dispatch unchecked. `next` must refuse to flip ASSIGNED->RUNNING on a red premise.
#   (7) NEXT-NOT-SILENT `next` over a FREE red-premise row prints the refusal and leaves the row FREE. The
#                       picker captures the inner claim's streams, so a refusal raised there can die unseen.
#   (8) OVERRIDE-LOUD   S4E_PREMISE_OVERRIDE takes the lock, says so, and writes the reason into the baton.
#                       An escape hatch that leaves no receipt is indistinguishable from the hole it replaces.
#   (9) WHOLE-FIELD     a multi-line PREMISE-WHEN is read WHOLE. The truncation class that ate DONE-WHENs
#                       (a heredoc opener alone exits 0 having run nothing) must not be re-imported here.
#  (10) NOT-SWALLOWED   a multi-line DONE-WHEN followed by PREMISE-WHEN must NOT absorb it -- otherwise the
#                       premise runs as part of the completion test and the two contracts merge silently.
# FAIL-ONCE: five mutants -- M1 unwires claim's gate (arm 1 red), M2 unwires the ASSIGNED path only (arm 6
# red, the half-wired shape), M3 blinds the gate to always-admit (arms 1/6/7 red), M4 drops PREMISE-WHEN from
# the extractor's terminator set (arm 10 red), M5 truncates the premise to one line (arm 9 red).
# EXIT 0 all arms hold and all five mutants go red; 1 otherwise; 2 REFUSED (fixture unbuildable).
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; MSG="$HERE/s4e_msg.sh"
[ -f "$MSG" ] || { echo "⛔ REFUSED: $MSG missing"; exit 2; }
W="$(mktemp -d)" || { echo "⛔ REFUSED: mktemp failed"; exit 2; }
# ⛔ $BASHPID, not $$: a bare EXIT trap fires inside forked children too, and bash keeps $$ at the original
# shell's pid in a subshell, so the obvious guard compares equal and deletes the fixture mid-run.
MAINPID=$$; trap '[ "$BASHPID" = "$MAINPID" ] && rm -rf "$W"' EXIT
PO="$W/po"; ME=ceo; HQ=ceo; SEAT=cto
# ⛔⭐ env -u: this gate is itself a DONE-WHEN, so it runs INSIDE a `done` that `next` may have invoked as its
# own probe. S4E_PID_LOCK, the dispatch opt-out AND the premise variables leak in from that parent and would
# silently change what the fixture measures -- an inherited S4E_PREMISE_OVERRIDE would disable the feature
# under test and the whole gate would report a green it never took. Scrubbed, always.
FIX() { env -u S4E_PID_LOCK -u S4E_NO_DISPATCH_PROBE -u S4E_PREMISE_OVERRIDE -u S4E_NO_PREMISE_CHECK \
        -u S4E_PREMISE_TIMEOUT S4E_HOME="$W" S4E_POST="$PO" S4E_SEAT="$ME" S4E_NO_BANNER=1 \
        S4E_NO_DISPATCH_PROBE=1 "$@"; }
# ⛔ S4E_NO_DISPATCH_PROBE=1 in the fixture: the DONE-WHEN probe is a DIFFERENT cure with its own gate, and
# letting it close fixture rows mid-arm would make this gate's verdict depend on that one's behaviour.
mkrow() {   # mkrow <rank> <topic> <done-when> [premise-when]
  printf '%s\t%s\t%s\tFREE\n' "$1" "$2" "$HQ" >> "$PO/QUEUE.tsv"
  { printf '# TASK %s\nGOAL: gate fixture.\nDONE-WHEN: %s\n' "$2" "$3"
    [ "${4:-}" = "-" ] || printf 'PREMISE-WHEN: %s\n' "${4:-}"
    printf 'LINKS: none\n## NEXT\ngo\n## LEDGER\n'; } > "$PO/tasks/$2.task.md"; }
mk_po() {
  rm -rf "$PO"; mkdir -p "$PO/tasks" "$PO/claims" "$PO/released" "$PO/$ME/inbox" "$PO/$SEAT/inbox" || return 2
  : > "$PO/BOARD.md"; : > "$PO/QUEUE.done.tsv"; printf 'QUARTET\n' > "$PO/MODE"; printf '5\n' > "$PO/PROTOCOL-VERSION"
  printf '%s\n' "$HQ" > "$PO/$ME/HQ"; printf '# gate fixture queue\n' > "$PO/QUEUE.tsv"
  # THE PREMISE OF EVERY FIXTURE ROW IS A FILE THAT DOES OR DOES NOT EXIST -- the cheapest possible shape,
  # and the same shape a real premise takes ("the thing this row is built on is still there").
  : > "$PO/PREMISE-HOLDS"
  mkrow 0 t-stale  'test -f "$S4E_HOME/po/NOPE"' 'test -f "$S4E_HOME/po/PREMISE-GONE-SINCE-MONDAY"'
  mkrow 1 t-live   'test -f "$S4E_HOME/po/NOPE"' 'test -f "$S4E_HOME/po/PREMISE-HOLDS"'
  mkrow 2 t-absent 'test -f "$S4E_HOME/po/NOPE"' -
  mkrow 3 t-noop   'test -f "$S4E_HOME/po/NOPE"' 'true'
  mkrow 4 t-asg    'test -f "$S4E_HOME/po/NOPE"' 'test -f "$S4E_HOME/po/PREMISE-GONE-SINCE-MONDAY"'
  mkrow 5 t-ovr    'test -f "$S4E_HOME/po/NOPE"' 'test -f "$S4E_HOME/po/PREMISE-GONE-SINCE-MONDAY"'
  # (9) THE TRUNCATION WITNESS: the heredoc OPENER alone exits 0 having run nothing, so a premise read one
  # line at a time reads GREEN. Read whole, the real check on the last line exits 1. Green-if-truncated.
  printf '%s\n' '# TASK t-multi' 'GOAL: gate fixture.' 'DONE-WHEN: test -f "$S4E_HOME/po/NOPE"' \
    "PREMISE-WHEN: cat > \"\$S4E_HOME/po/w.txt\" <<'EOF'" 'the premise body' 'EOF' \
    'test -f "$S4E_HOME/po/PREMISE-GONE-SINCE-MONDAY"' 'LINKS: none' '## NEXT' 'go' '## LEDGER' \
    > "$PO/tasks/t-multi.task.md"
  printf '%s\t%s\t%s\tFREE\n' 6 t-multi "$HQ" >> "$PO/QUEUE.tsv"
  # (10) THE SWALLOW WITNESS: a multi-line DONE-WHEN (heredoc, real check AFTER the delimiter) with a
  # PREMISE-WHEN under it. The premise is GREEN and leaves a MARKER, so the swallow is measured by side
  # effect and not by a shared exit code: after `done`, the marker must be absent -- the completion test
  # must not have run the premise. (The swallow also breaks `done` outright, because the swallowed text
  # begins with the literal label and bash reports command-not-found; the arm reads BOTH signals, since a
  # future extractor could strip the label and leave only the silent half.)
  printf '%s\n' '# TASK t-swallow' 'GOAL: gate fixture.' \
    "DONE-WHEN: cat > \"\$S4E_HOME/po/d.txt\" <<'EOF'" 'the donewhen body' 'EOF' \
    'test -f "$S4E_HOME/po/d.txt"' \
    'PREMISE-WHEN: touch "$S4E_HOME/po/premise-ran.marker"' 'LINKS: none' '## NEXT' 'go' '## LEDGER' \
    > "$PO/tasks/t-swallow.task.md"
  printf '%s\t%s\t%s\tFREE\n' 7 t-swallow "$HQ" >> "$PO/QUEUE.tsv"; }
col() { grep -P "^[0-9]+\t\Q$1\E\t" "$PO/QUEUE.tsv" 2>/dev/null | head -1 | cut -f4; }
arm() {   # arm <label> <script> -> 0 iff every contract holds on <script>
  local lbl="$1" s="$2" ok=1 out rc
  mk_po || return 2
  # ---- (1) STALE-REFUSES + (2) NAMES-IT ----------------------------------------------------------------
  out="$(FIX bash "$s" claim t-stale 2>&1)"; rc=$?
  [ "$rc" = 0 ] && { echo "  [$lbl] (1) claim SUCCEEDED on a row whose premise is red -- the whole defect"; ok=0; }
  [ -f "$PO/claims/t-stale.claim" ] && { echo "  [$lbl] (1) a claim file was written despite the refusal -- a refusal that still locks is not a refusal"; ok=0; }
  [ "$(col t-stale)" = FREE ] || { echo "  [$lbl] (1) the QUEUE column moved to '$(col t-stale)' on a refused claim"; ok=0; }
  grep -q 'PREMISE-GONE-SINCE-MONDAY' <<<"$out" || { echo "  [$lbl] (2) the refusal does not PRINT the failing premise -- the seat cannot tell it from their own tree breaking"; ok=0; }
  grep -qi 'rewrit' <<<"$out" || { echo "  [$lbl] (2) the refusal never says the row needs REWRITING -- a red premise read as a defect sends the seat to debug it"; ok=0; }
  # ---- (3) LIVE-ADMITS ---------------------------------------------------------------------------------
  out="$(FIX bash "$s" claim t-live 2>&1)"; rc=$?
  [ "$rc" = 0 ] || { echo "  [$lbl] (3) claim REFUSED a row whose premise is green (rc=$rc): $(grep -m1 '⛔' <<<"$out" | cut -c1-90)"; ok=0; }
  [ -f "$PO/claims/t-live.claim" ] || { echo "  [$lbl] (3) a green premise did not lock"; ok=0; }
  # ---- (4) ABSENT-ADMITS, loudly -----------------------------------------------------------------------
  out="$(FIX bash "$s" claim t-absent 2>&1)"; rc=$?
  [ "$rc" = 0 ] || { echo "  [$lbl] (4) claim REFUSED a baton with no PREMISE-WHEN -- that would stop 1100+ live rows"; ok=0; }
  [ -f "$PO/claims/t-absent.claim" ] || { echo "  [$lbl] (4) a baton with no premise did not lock"; ok=0; }
  grep -q 'PREMISE UNVERIFIED' <<<"$out" || { echo "  [$lbl] (4) an unchecked premise was SILENT -- silence reads as verified"; ok=0; }
  # ---- (5) NOOP-NOT-VERIFIED ---------------------------------------------------------------------------
  out="$(FIX bash "$s" claim t-noop 2>&1)"; rc=$?
  [ "$rc" = 0 ] || { echo "  [$lbl] (5) claim REFUSED a vacuous premise -- it certifies nothing, which is not the same as red"; ok=0; }
  grep -q 'exited 0' <<<"$out" && { echo "  [$lbl] (5) a premise of \`true\` was reported as a VERIFIED premise"; ok=0; }
  grep -q 'certifies nothing' <<<"$out" || { echo "  [$lbl] (5) a vacuous premise passed without being named as one"; ok=0; }
  # ---- (6) ASSIGNED-GATED: the path that never touches `claim` -----------------------------------------
  printf '%s\nASSIGNED-BY %s %s\n' "$ME" "$HQ" "$(date -u +%FT%TZ)" > "$PO/claims/t-asg.claim"
  out="$(FIX bash "$s" next 2>&1)"
  grep -qE 'ASSIGNED->RUNNING +t-asg' <<<"$out" && { echo "  [$lbl] (6) an ASSIGNED row with a RED premise was SERVED -- the commonest dispatch in the fleet, unchecked"; ok=0; }
  grep -q '^RUNNING$' "$PO/claims/t-asg.claim" && { echo "  [$lbl] (6) the assigned row was flipped to RUNNING on a red premise"; ok=0; }
  grep -q 'PREMISE-GONE-SINCE-MONDAY' <<<"$out" || { echo "  [$lbl] (6) next refused the assigned row without naming the premise"; ok=0; }
  rm -f "$PO/claims/t-asg.claim"
  # ---- (7) NEXT-NOT-SILENT on a FREE row ---------------------------------------------------------------
  rm -f "$PO/claims/t-live.claim" "$PO/claims/t-absent.claim" "$PO/claims/t-noop.claim"
  mk_po || return 2
  out="$(FIX bash "$s" next 2>&1)"
  grep -q 'PREMISE-GONE-SINCE-MONDAY' <<<"$out" || { echo "  [$lbl] (7) next walked past the rank-0 red-premise row in SILENCE -- the refusal died inside the captured claim"; ok=0; }
  grep -qE 'LOCKED +t-stale' <<<"$out" && { echo "  [$lbl] (7) next served the red-premise row anyway"; ok=0; }
  [ -f "$PO/claims/t-stale.claim" ] && { echo "  [$lbl] (7) next locked the red-premise row"; ok=0; }
  [ "$(col t-stale)" = FREE ] || { echo "  [$lbl] (7) the red-premise row left FREE? column reads '$(col t-stale)'"; ok=0; }
  # ---- (8) OVERRIDE-LOUD-AND-RECORDED ------------------------------------------------------------------
  out="$(env -u S4E_PID_LOCK -u S4E_NO_PREMISE_CHECK S4E_HOME="$W" S4E_POST="$PO" S4E_SEAT="$ME" \
        S4E_NO_BANNER=1 S4E_NO_DISPATCH_PROBE=1 S4E_PREMISE_OVERRIDE="the premise names a file the fixture renamed" \
        bash "$s" claim t-ovr 2>&1)"; rc=$?
  [ "$rc" = 0 ] || { echo "  [$lbl] (8) an explicit, reasoned override still could not take the row (rc=$rc)"; ok=0; }
  [ -f "$PO/claims/t-ovr.claim" ] || { echo "  [$lbl] (8) the override did not lock"; ok=0; }
  grep -q 'OVERRIDDEN' <<<"$out" || { echo "  [$lbl] (8) the override was SILENT"; ok=0; }
  grep -q 'PREMISE OVERRIDDEN' "$PO/tasks/t-ovr.task.md" || { echo "  [$lbl] (8) the override left no receipt in the baton -- an escape hatch with no record is the hole it replaces"; ok=0; }
  # ---- (9) WHOLE-FIELD: the truncation class must not be re-imported on the new label -------------------
  out="$(FIX bash "$s" claim t-multi 2>&1)"; rc=$?
  [ "$rc" = 0 ] && { echo "  [$lbl] (9) a MULTI-LINE premise was read one line at a time: the heredoc opener exited 0 having run nothing and the row locked on a premise that never ran"; ok=0; }
  [ -f "$PO/claims/t-multi.claim" ] && { echo "  [$lbl] (9) the truncated premise locked the row"; ok=0; }
  # ---- (10) NOT-SWALLOWED: the DONE-WHEN must stop at the new label ------------------------------------
  FIX bash "$s" claim t-swallow >/dev/null 2>&1 || { echo "  [$lbl] fixture: could not claim t-swallow"; return 2; }
  rm -f "$PO/premise-ran.marker"
  out="$(FIX bash "$s" done t-swallow 2>&1)"; rc=$?
  [ -f "$PO/premise-ran.marker" ] && { echo "  [$lbl] (10) \`done\` RAN THE PREMISE: a multi-line DONE-WHEN swallowed the PREMISE-WHEN under it, so the two contracts are one"; ok=0; }
  [ "$rc" = 0 ] || { echo "  [$lbl] (10) the multi-line DONE-WHEN did not close its row (done rc=$rc) -- if it swallowed the premise line the criterion no longer parses: $(grep -m1 -E '⛔|command not found' <<<"$out" | cut -c1-90)"; ok=0; }
  [ "$ok" = 1 ]; }
echo "claim/next compute a row's PREMISE-WHEN and refuse the lock on a red one (scratch postoffice under $W)"
cp "$HERE/lib_release_guard.sh" "$W/" 2>/dev/null || true
if arm PASS "$MSG"; then echo "  [PASS] stale refuses and names it · live admits · absent admits loudly · vacuous never reads as verified · ASSIGNED gated at serve · next not silent · override loud and recorded · whole field read · DONE-WHEN not swallowed"; pass=1
else pass=$?; [ "$pass" = 2 ] && { echo "⛔ REFUSED: fixture could not be built (rc=2)"; exit 2; }; pass=0; fi
# ⛔⭐⭐ A MUTANT IS A DIRECTORY, AND THE TARGET MAY BE A LIB. Two things changed on 2026-09-23 when the
# DONE-WHEN EXTRACTOR MOVED INTO lib_donewhen.sh (cto's ruling: one implementation, no second reader to drift).
# FIRST, a mutant written to $W/<n>.sh resolves `dirname "${BASH_SOURCE[0]}"` to $W and finds no lib beside it;
# the bus now REFUSES rc=2 without the extractor rather than warning, so EVERY mutant here would have gone red
# for a staging reason while printing "red as required" -- a fail-once that proves nothing, which is the exact
# false green this mechanism exists to disprove. SECOND, m4's anchor line moved with the extractor, so its
# target is the LIB and not the bus.
mut() {  # mut <name> <from> <to> [target-basename] -> stages $W/<name>/ with every lib + the bus, mutates one
  local n="$1" a="$2" b="$3" tgt="${4:-s4e_msg.sh}" src
  mkdir -p "$W/$n" || { echo "⛔ REFUSED: cannot stage the $n mutant directory"; exit 2; }
  cp "$HERE"/lib_*.sh "$MSG" "$W/$n/" || { echo "⛔ REFUSED: cannot stage the siblings the $n mutant sources"; exit 2; }
  src="$HERE/$tgt"; [ -f "$src" ] || { echo "⛔ REFUSED: $n names a target that does not exist: $tgt"; exit 2; }
  awk -v a="$a" -v b="$b" '$0==a{print b; k++; next} {print} END{exit !k}' "$src" > "$W/$n/$tgt" \
    || { echo "⛔ REFUSED: $n's anchor line is not where the mutant expects it (target $tgt) -- the mutation would be a no-op"; exit 2; }
  grep -qF "$b" "$W/$n/$tgt" || { echo "⛔ REFUSED: $n did not change $tgt"; exit 2; }
  bash -n "$W/$n/$tgt" 2>/dev/null || { echo "⛔ REFUSED: the $n mutant does not parse -- fixture, not verdict"; exit 2; }
  # ⛔ EXACTLY ONE FILE MAY DIFFER: a mutant that also perturbed a sibling would attribute its red to the wrong
  # change, and staging by copy makes that mistake silent rather than loud.
  for _f in "$W/$n"/*; do
    case "${_f##*/}" in "$tgt") continue;; esac
    cmp -s "$_f" "$HERE/${_f##*/}" || { echo "⛔ REFUSED: $n perturbed ${_f##*/} as well as $tgt"; exit 2; }
  done; }
# ⛔ EXACT-STRING awk, never regex sed: these lines are dense in $ | * ( ) and a mutation that silently matched
# nothing would hand back an unmutated copy, the arm would pass, and the gate would report a fail-once it never
# performed -- a false green inside the mechanism that exists to disprove one.
mut m1 '              s4e_premise_gate "$topic" claim || exit 1' '              :'
if arm M1-claim-unwired "$W/m1/s4e_msg.sh" >"$W/m1.log" 2>&1; then echo "  [FAIL-ONCE M1] ⛔ GREEN with claim's premise gate removed -- the gate cannot detect an unchecked claim"; m1=0
else echo "  [FAIL-ONCE M1] red as required, claim unwired: $(grep -m1 '(1)' "$W/m1.log" | sed 's/^ *//' | cut -c1-100)"; m1=1; fi
# ⛔ M2 UNWIRES ONLY THE ASSIGNED PATH -- the exact half-wired state a cure wired into `claim` alone ships in,
# and the one every sibling gate would pass straight through. If arm 6 cannot see this, the arm is decoration.
mut m2 '           s4e_premise_gate "$t" next || continue' '           :'
if arm M2-assigned-unwired "$W/m2/s4e_msg.sh" >"$W/m2.log" 2>&1; then echo "  [FAIL-ONCE M2] ⛔ GREEN with the ASSIGNED->RUNNING path unwired -- arm 6 cannot see a half-wired cure"; m2=0
else echo "  [FAIL-ONCE M2] red as required, assigned path unwired: $(grep -m1 '(6)' "$W/m2.log" | sed 's/^ *//' | cut -c1-100)"; m2=1; fi
# ⛔ M3 short-circuits the BODY rather than replacing the header: swapping the header would need a second
# function to absorb the orphaned body, and a mutant that will not PARSE goes red for a reason having nothing
# to do with the cure -- a fail-once that proves nothing.
mut m3 '    local t="$1" verb="${2:-claim}" b="$PO/tasks/$1.task.md" pw log rc to t0 el' '    return 0'
if arm M3-gate-blinded "$W/m3/s4e_msg.sh" >"$W/m3.log" 2>&1; then echo "  [FAIL-ONCE M3] ⛔ GREEN with the premise gate blinded to always-admit"; m3=0
else echo "  [FAIL-ONCE M3] red as required, gate blinded: $(grep -m1 -E '\(1\)|\(6\)|\(7\)' "$W/m3.log" | sed 's/^ *//' | cut -c1-100)"; m3=1; fi
# ⛔ M4 drops PREMISE-WHEN from the extractor's terminator set: the multi-line DONE-WHEN then swallows the
# premise line under it. Only arm 10 can see this, and it is the reason arm 10 exists.
mut m4 '            seen && /^(GOAL|LINKS|RANK|DONE-WHEN|DONE-WHEN-HISTORY|PREMISE-WHEN|PREMISE-WHEN-HISTORY|SCOPE|LEDGER|OWNER|BLOCKED-ON|FINDING|MINTED BY):/ { exit }' \
       '            seen && /^(GOAL|LINKS|RANK|DONE-WHEN|DONE-WHEN-HISTORY|SCOPE|LEDGER|OWNER|BLOCKED-ON|FINDING|MINTED BY):/ { exit }' \
       lib_donewhen.sh
if arm M4-terminator-dropped "$W/m4/s4e_msg.sh" >"$W/m4.log" 2>&1; then echo "  [FAIL-ONCE M4] ⛔ GREEN with PREMISE-WHEN dropped from the terminator set -- a DONE-WHEN may swallow the premise unseen"; m4=0
else echo "  [FAIL-ONCE M4] red as required, terminator dropped: $(grep -m1 '(10)' "$W/m4.log" | sed 's/^ *//' | cut -c1-100)"; m4=1; fi
# ⛔ M5 re-imports the truncation class on the new label only: the premise is read one physical line at a time.
mut m5 's4e_premise_text()  { s4e_field_criterion_text "$1" PREMISE-WHEN; }' \
       's4e_premise_text()  { sed -n "s/^PREMISE-WHEN:[[:space:]]*//p" "$1" | head -1; }' \
       lib_donewhen.sh
if arm M5-premise-truncated "$W/m5/s4e_msg.sh" >"$W/m5.log" 2>&1; then echo "  [FAIL-ONCE M5] ⛔ GREEN with the premise truncated to one line -- the heredoc false green is back and arm 9 is blind to it"; m5=0
else echo "  [FAIL-ONCE M5] red as required, premise truncated: $(grep -m1 '(9)' "$W/m5.log" | sed 's/^ *//' | cut -c1-100)"; m5=1; fi
if [ "$pass" = 1 ] && [ "$m1" = 1 ] && [ "$m2" = 1 ] && [ "$m3" = 1 ] && [ "$m4" = 1 ] && [ "$m5" = 1 ]; then
  echo "✅ GATE OK: claim and next compute the row's PREMISE-WHEN, refuse the lock on a measured red one and say the row needs rewriting, admit every premise they could not measure, and never read silence as verification."; exit 0; fi
echo "⛔ GATE FAILED (pass=$pass m1-red=$m1 m2-red=$m2 m3-red=$m3 m4-red=$m4 m5-red=$m5)"; exit 1
