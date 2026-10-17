#!/usr/bin/env bash
# test_gate_s4e_picker_v2.sh — V2-1 GATE (ARCH-FLEET-CEO.md LAW 2 "ASSIGNMENT IS THE LOCK", LAW 1 "NO HAND-TYPED VERDICTS").
# Proves the three properties the wave-1 control plane did NOT have, against a SANDBOX postoffice (never the live one):
#   P1 rank-sorted picker : `next` serves the LOWEST-RANK free row, not the topmost row in file order.
#   P2 assign-wins        : a row an HQ assigned to me is served AHEAD of a lower-ranked free row I would otherwise take.
#   ⭐ S4E_MSG_BIN=<other script> runs this gate against a DIFFERENT s4e_msg.sh — that is the real negative injection:
#     pointed at the pre-V2-1 script it MUST fail, and it does (receipt in the FINDING).
#   P3 assign refuses     : no mailbox (LAW 6) · no queue row · already-DONE row · row held by another seat.
# ⛔ THIS GATE IS NEGATIVE-TESTED BY --self-check: it injects the v1 file-order picker and the v1 no-assign world and
# REQUIRES ITSELF TO FAIL on both. A gate that cannot say NO is not a gate (seat16 measured 31/105 that cannot).
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; MSG="${S4E_MSG_BIN:-$HERE/s4e_msg.sh}"   # override = the REAL negative test: point at the pre-V2-1 script
SELF=0; [ "${1:-}" = "--self-check" ] && SELF=1
pass=0; fail=0
ok()   { pass=$((pass+1)); printf '  ok   %s\n' "$1"; }
no()   { fail=$((fail+1)); printf '  FAIL %s\n     expected: %s\n     actual  : %s\n' "$1" "$2" "$3"; }
sandbox() { # $1 = dir ; builds a postoffice whose FILE ORDER DISAGREES WITH RANK ORDER (that disagreement is the test)
  local P="$1"; rm -rf "$P"; mkdir -p "$P/claims" "$P/tasks"
  # ⛔ hq_C's OWN mailbox is part of the sandbox: since hq_P's V2-4 (LAW 6 IDENTITY IS ASSERTED) every subcommand
  # refuses an identity with no mailbox, so an assigning HQ with no inbox is correctly rejected. Cross-verifying
  # hq_P's rung found this gate's sandbox at fault, not their code — the sandbox now models the real law.
  local s; for s in seatAA seatBB hq_C; do mkdir -p "$P/$s/inbox"; done
  # ⛔ FOUND STALE (fix-dispatch-bus-two-failure-modes, s266): the 4th column used to be free-form
  # "first-step-and-done-when" prose (any non-FREE-looking text was harmless); V2-2 repointed it to
  # owner/state and s265 made the state column LOAD-BEARING (Pass 3 now `continue`s past anything that
  # is not literally FREE or empty). This sandbox still wrote "step-N" there, so EVERY row silently read
  # as not-FREE and P1 failed "QUEUE EMPTY" even against an unmodified script — reproduced against git
  # HEAD before this fix, so it is not a side effect of any other change, just a gate nobody re-ran since
  # s265 landed (LAW 0 species 3, a blind instrument caught by trying to actually rely on its verdict).
  # ⛔ FOUND STALE A SECOND TIME (postoffice-gates-red-on-origin, 2026-09-03) — SAME SANDBOX, NEXT COLUMN ALONG.
  # The note above cured the 4th column when V2-2 repointed it to state. The 3rd column is read as `brief` and
  # USED as the owner, and `THE OWNER COLUMN CONSTRAINS THE PICK` (ceo 2026-09-03) made it load-bearing too:
  # anything that is not '', `unassigned` or the running seat is now skipped as another seat's row. "brief-N"
  # is none of those, so every row here read as owned-by-someone-else and NOTHING was ever locked.
  # ⭐ THE REASON THIS SURVIVED A RED RUN: the skip banner names the topmost skipped row and its owner, so
  # `case "$out" in *"THE-RANK-ZERO-ROW"*` and *"brief-0"* both MATCHED THE REFUSAL. 18/19 green with P1
  # measuring nothing. Only the third check, naming a row the banner does not mention, told the truth.
  # The assertions below are now anchored on "LOCKED <topic>" for exactly this reason -- a substring that a
  # refusal can also contain is not an assertion, it is a coincidence.
  echo 'FLEET-16' > "$P/MODE"          # s266: MODE IS COMPUTED, NEVER ASSUMED -- absent makes every next() print a ⛔ banner
  { printf '# sandbox queue — file order is DELIBERATELY the inverse of rank order\n'
    printf '9\tlast-in-rank-first-in-file\tunassigned\tFREE\n'
    printf '5\tmiddle-row\tunassigned\tFREE\n'
    printf '0\tTHE-RANK-ZERO-ROW\tunassigned\tFREE\n'
    printf '\n'
    printf '3\tanother-row\tunassigned\tFREE\n'; } > "$P/QUEUE.tsv"; }
run() { local P="$1" seat="$2"; shift 2; S4E_POST="$P" S4E_SEAT="$seat" S4E_NO_BANNER=1 bash "$MSG" "$@" 2>&1; }

echo "== P1  rank-sorted picker =="
P=$(mktemp -d); sandbox "$P"
out="$(run "$P" seatAA next)"
if [ "$SELF" = 1 ]; then out="LOCKED last-in-rank-first-in-file (rank 9)"; fi   # inject the v1 file-order picker
case "$out" in *"LOCKED THE-RANK-ZERO-ROW"*) ok "next serves rank 0 before file-order-topmost rank 9";;
  *) no "next serves rank 0 first" "LOCKED THE-RANK-ZERO-ROW" "$(echo "$out" | grep -m1 -E 'LOCKED|skipped|EMPTY')";; esac
# ⭐ the metadata printed must belong to the row that was LOCKED, not to a neighbouring row -- the column
# -misalignment class. Rank is the field that is distinct per row here (every owner must read `unassigned`
# to be pickable at all), so topic-and-rank in ONE anchored string is what carries that property now.
case "$out" in *"LOCKED THE-RANK-ZERO-ROW (rank 0)"*) ok "the rank printed belongs to the row that was locked";;
  *) no "printed metadata matches locked row" "LOCKED THE-RANK-ZERO-ROW (rank 0)" "$(echo "$out" | grep -m1 -E 'LOCKED|skipped|EMPTY')";; esac
# and the SECOND pick must be the next rank up, not file order again
out2="$(run "$P" seatBB next)"
case "$out2" in *"LOCKED another-row"*) ok "second pick is rank 3 (next-lowest), not file order";;
  *) no "second pick is rank 3" "LOCKED another-row" "$(echo "$out2" | grep -m1 -E 'LOCKED|skipped|EMPTY')";; esac
rm -rf "$P"

echo "== P2  assignment is the lock =="
P=$(mktemp -d); sandbox "$P"
a="$(run "$P" hq_C assign seatAA middle-row)"
if [ "$SELF" = 1 ]; then a="⛔ REFUSED"; fi                                     # inject the v1 no-assign world
case "$a" in *"assigned middle-row -> seatAA"*) ok "assign writes the claim and reports it";;
  *) no "assign succeeds" "assigned middle-row -> seatAA" "$a";; esac
[ "$(head -1 "$P/claims/middle-row.claim" 2>/dev/null)" = "seatAA" ] \
  && ok "claim file is owned by the ASSIGNED seat, not the assigning HQ" \
  || no "claim owner" "seatAA" "$(head -1 "$P/claims/middle-row.claim" 2>/dev/null)"
ls "$P/seatAA/inbox/"*.msg >/dev/null 2>&1 && ok "doorbell landed in the seat's inbox" || no "doorbell" "one .msg" "none"
out="$(run "$P" seatAA next)"
if [ "$SELF" = 1 ]; then out="LOCKED THE-RANK-ZERO-ROW (rank 0)"; fi           # v1: next ignores assignment
case "$out" in *"ASSIGNED->RUNNING middle-row"*) ok "next serves the ASSIGNED rank-5 row ahead of the free rank-0 row";;
  *) no "assigned-first" "ASSIGNED->RUNNING middle-row" "$(echo "$out" | head -1)";; esac
grep -q '^RUNNING$' "$P/claims/middle-row.claim" && ok "serving an assignment flips it ASSIGNED -> RUNNING" \
  || no "RUNNING marker" "RUNNING in claim" "$(tr '\n' ' ' < "$P/claims/middle-row.claim")"
out="$(run "$P" seatAA next)"
case "$out" in *"RESUME middle-row"*) ok "a second next RESUMES the same row (no double-dispatch)";;
  *) no "resume not re-dispatch" "RESUME middle-row" "$(echo "$out" | head -1)";; esac
rm -rf "$P"

echo "== P3  assign refuses what it must =="
P=$(mktemp -d); sandbox "$P"
r="$(run "$P" hq_C assign seatZZ middle-row)";        rc=$?
if [ "$SELF" = 1 ]; then r="assigned middle-row -> seatZZ"; fi                 # inject LAW-6 violation (auto-created mailbox)
case "$r" in *"NO postoffice mailbox"*) ok "refuses a seat with no mailbox (LAW 6 identity is asserted)";;
  *) no "no-mailbox refusal" "⛔ REFUSED ... NO postoffice mailbox" "$r";; esac
[ -d "$P/seatZZ" ] && no "assign must not create mailboxes" "no seatZZ dir" "seatZZ dir was created" || ok "and it did NOT create the mailbox on the fly"
r="$(run "$P" hq_C assign seatAA no-such-row-anywhere)"
case "$r" in *"no QUEUE.tsv row"*) ok "refuses a topic with no queue row";;
  *) no "no-row refusal" "⛔ REFUSED ... no QUEUE.tsv row" "$r";; esac
run "$P" hq_C assign seatAA middle-row >/dev/null
r="$(run "$P" hq_C assign seatBB middle-row)"
case "$r" in *"held by seatAA"*) ok "refuses to steal a row held by another seat";;
  *) no "held-by-other refusal" "⛔ REFUSED ... held by seatAA" "$r";; esac
printf 'seatAA\nDONE\n' > "$P/claims/another-row.claim"
r="$(run "$P" hq_C assign seatBB another-row)"
case "$r" in *"already DONE"*) ok "refuses to re-dispatch a row that already landed";;
  *) no "DONE refusal" "⛔ REFUSED ... already DONE" "$r";; esac
out="$(run "$P" seatBB next)"
case "$out" in *"another-row"*) no "a DONE row must stay out of the picker" "not another-row" "$(echo "$out" | head -1)";;
  *) ok "a DONE row is not served by the picker";; esac
rm -rf "$P"

echo "== P4  backward compatibility with v1 claim files =="
P=$(mktemp -d); sandbox "$P"
printf 'seatAA\n' > "$P/claims/middle-row.claim"          # a v1 claim: ONE line, no ASSIGNED-BY, no RUNNING
out="$(run "$P" seatAA next)"
case "$out" in *"RESUME middle-row"*) ok "a pre-V2-1 claim file (bare seat name) still RESUMES — 14 live claims depend on this";;
  *) no "v1 claim resumes" "RESUME middle-row" "$(echo "$out" | head -1)";; esac
printf 'seatAA\nDONE\n' > "$P/claims/middle-row.claim"    # a v1 DONE marker
out="$(run "$P" seatAA next)"
case "$out" in *"middle-row"*) no "a v1 DONE claim must not be resumed" "not middle-row" "$(echo "$out" | head -1)";;
  *) ok "a pre-V2-1 DONE claim is still treated as finished";; esac
rm -rf "$P"
# ⛔ FOUND STALE, own sandbox (fix-dispatch-bus-two-failure-modes, s266): the orphan check used to run in
# the SAME $P as the two steps above, whose second `next` call falls through to Pass 3 and locks
# THE-RANK-ZERO-ROW as an unavoidable side effect (Pass 3 is not the thing under test here, it just runs
# because nothing else matched). With rank-sort applied to Pass 2 too (this row's own fix), a seat holding
# BOTH that real rank-0 claim AND the orphan correctly resumes the real one FIRST and never reaches the
# orphan in that call — which is the more correct behaviour, not a regression, but it means this assertion
# was silently relying on glob order visiting the orphan before the leftover real claim. Isolating the
# orphan in its OWN sandbox tests the actual property (kept, not pinning, reported) without that leftover
# claim confusing "does an orphan get skipped" with "which of two open claims wins" — the latter is now
# covered on its own merits by test_gate_dispatch_bus_failure_modes.sh.
P=$(mktemp -d); sandbox "$P"
printf 'seatAA\n' > "$P/claims/orphan-topic.claim"        # claim naming a topic with no row (HQ LAW 14)
out="$(run "$P" seatAA next)"
case "$out" in *"SKIP orphan-topic"*) ok "orphan-claim skip survived the rewrite (claim kept, seat not pinned)";;
  *) no "orphan skip" "SKIP orphan-topic ..." "$(echo "$out" | head -1)";; esac
[ -f "$P/claims/orphan-topic.claim" ] && ok "the orphaned claim file is KEPT (the record), not deleted" \
  || no "orphan claim kept" "file still present" "file gone"
rm -rf "$P"

printf '\n  %s: %d passed, %d failed\n' "$([ "$fail" -eq 0 ] && echo PASS || echo '⛔ FAIL')" "$pass" "$fail"
if [ "$SELF" = 1 ]; then
  if [ "$fail" -gt 0 ]; then printf '  ✅ SELF-CHECK PASSED: with v1 behaviour injected this gate said NO (%d failures). It can fail.\n' "$fail"; exit 0
  else printf '  ⛔ SELF-CHECK FAILED: v1 behaviour was injected and the gate still said PASS. This gate is BLIND — do not cite it.\n'; exit 1; fi; fi
[ "$fail" -eq 0 ]
