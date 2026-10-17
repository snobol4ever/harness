#!/usr/bin/env bash
# test_gate_s4e_next_rank_cap_for_seats.sh -- proves next() refuses rank-6-and-above rows for SEATS and
# still serves them to HQs, the ceo and the cto (row seat-picker-refuses-rows-of-rank-six-and-above-for-seats,
# rank 0; Lon 2026-09-06 11:20 via ceo, MASTER-PLAN sec THE FLEET-12 PLAN: "A SEAT NEVER TAKES A ROW OF
# RANK >= 6: park it back to FREE with a one-line note and pick again").
#
# ⛔ THE NEGATIVE ARMS ARE THE POINT, NOT THE POSITIVE ONE. A cap that also refused HQs would idle every
# rank 6-9 row in the queue -- design, shared engine, ABI, frames, bignum, coexpr -- and would do it
# QUIETLY, because an idled row looks exactly like a row nobody has got to yet. The CTO seat exists
# specifically to work rank >= 6, so a cap that caught it would disable the one identity the plan created
# for that band. So: one arm that it refuses, and three that it does not.
# ⭐ AND rank 5 IS TESTED BESIDE rank 6 DELIBERATELY -- an off-by-one here does not crash, it silently
# removes the top of the seat-takeable band, and the seats would simply see fewer rows.
#
# Runs entirely against a throwaway sandbox postoffice (S4E_POST override) -- never touches the live one.
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
S4E_MSG="$HERE/s4e_msg.sh"
GATE="s4e_next_rank_cap_for_seats"
SBX="$(mktemp -d /tmp/s4e_rankcap_gate_XXXXXX)"
trap 'rm -rf "$SBX"' EXIT
viol=0; arms=0
fail() { echo "  ⛔ $1"; viol=$((viol+1)); }

[ -f "$S4E_MSG" ] || { echo "GATE UNPROVEN(2) [$GATE]: $S4E_MSG not on disk -- cannot measure"; exit 2; }

reset_sbx() {
    rm -rf "$SBX"; mkdir -p "$SBX/claims" "$SBX/tasks" "$SBX/released"
    for s in seat01 hq_T ceo cto; do mkdir -p "$SBX/$s/inbox" "$SBX/$s/archive"; done
    printf 'FLEET-12\n' > "$SBX/MODE"
    printf 'hq_T\n' > "$SBX/seat01/HQ"
    : > "$SBX/BOARD.md"; : > "$SBX/QUEUE.tsv"
}
# ⛔ THE FIXTURE DONE-WHEN MUST FAIL, AND THAT IS A MEASURED REQUIREMENT, NOT A STYLE CHOICE. My first
# fixtures used `true` and then `test -f /etc/hostname`: the first is refused as a shell no-op that
# certifies nothing, and the second EXITS 0, so the picker closed the row as ALREADY SATISFIED AT DISPATCH
# and never reached the cap at all. Both made the negative arms pass while proving nothing. A DONE-WHEN
# that fails is the only one that leaves the row servable long enough to be capped or served.
mk_row() { # $1=rank $2=topic
    printf '%s\t%s\tunassigned\tFREE\n' "$1" "$2" >> "$SBX/QUEUE.tsv"
    printf '# TASK %s\nGOAL: sandbox fixture\nDONE-WHEN: test -f /nonexistent-rankcap-fixture-marker\n' "$2" \
        > "$SBX/tasks/$2.task.md"
}
pick_as() { S4E_POST="$SBX" S4E_SEAT="$1" bash "$S4E_MSG" next 2>&1 || true; }
# ⛔ THE REFUSAL IS A ONE-LINE SUMMARY, NOT A PER-ROW LINE (same ruling as the owned-skip report:
# per-row refusals bury the serve they precede). So the arms match the SUMMARY text.
CAP='at rank 6+ (HQ-ONLY tier'

# ⭐ ONE ROW PER CASE, ALWAYS. My first draft put a rank-6 and a rank-5 row in one queue and asserted the
# seat got the rank-5 one -- which it did, by SORT ORDER, without the cap ever firing. The arm passed
# vacuously. With a single row there is nothing else the picker can serve, so the verdict is the cap's.

# ---- ARM 1: a seat is REFUSED a rank-6 row (positively asserted) ----
reset_sbx; mk_row 6 rank_six_row
arms=$((arms+1)); OUT="$(pick_as seat01)"
printf '%s' "$OUT" | grep -q "$CAP" || fail "ARM 1: seat01 was NOT refused the rank-6 row -- the cap did not fire"
printf '%s' "$OUT" | grep -q 'LOCKED rank_six_row' && fail "ARM 1b: seat01 was SERVED the rank-6 row despite the refusal text"

# ---- ARM 2: a seat IS served rank 5 -- the cap must not eat the top of the seat band ----
reset_sbx; mk_row 5 rank_five_row
arms=$((arms+1)); OUT="$(pick_as seat01)"
printf '%s' "$OUT" | grep -q 'LOCKED rank_five_row' || fail "ARM 2: seat01 was not served the rank-FIVE row -- off by one, the seat band has lost its top"

# ---- ARM 3: an HQ IS served the same rank-6 row ----
reset_sbx; mk_row 6 rank_six_row
arms=$((arms+1)); OUT="$(pick_as hq_T)"
printf '%s' "$OUT" | grep -q "$CAP" && fail "ARM 3: hq_T was refused a rank-6 row -- this must be an AUTHORITY test, not a blanket one; it would idle every rank 6-9 row"
printf '%s' "$OUT" | grep -q 'LOCKED rank_six_row' || fail "ARM 3b: hq_T was not served the rank-6 row at all -- the cap is not the only way to fail this, so assert the serve"

# ---- ARM 4: the cto IS served rank 9 -- the identity the band exists for ----
reset_sbx; mk_row 9 rank_nine_row
arms=$((arms+1)); OUT="$(pick_as cto)"
printf '%s' "$OUT" | grep -q "$CAP" && fail "ARM 4: cto was refused a rank-9 row -- the CTO seat exists to work exactly this band"
printf '%s' "$OUT" | grep -q 'LOCKED rank_nine_row' || fail "ARM 4b: cto was not served the rank-9 row"

# ---- ARM 5: the ceo is never refused ----
reset_sbx; mk_row 8 rank_eight_row
arms=$((arms+1))
printf '%s' "$(pick_as ceo)" | grep -q "$CAP" && fail "ARM 5: the ceo was refused a rank-8 row -- the ceo is never restricted"

# ---- ARM 6: the refusal NAMES the override rather than dead-ending ----
reset_sbx; mk_row 7 rank_seven_row
arms=$((arms+1)); OUT="$(pick_as seat01)"
if printf '%s' "$OUT" | grep -q "$CAP"; then
    printf '%s' "$OUT" | grep -q 'claim <topic>' \
      || fail "ARM 6: the refusal does not name the deliberate override -- a seat told only NO re-runs next and gets the same NO"
else
    fail "ARM 6: seat01 was not refused a rank-7 row at all"
fi

# ---- ARM 7: it PRINTS HOW MANY IT SKIPPED, one line, not one per row (the GOAL's own clause) ----
reset_sbx; mk_row 6 rank_six_a; mk_row 7 rank_six_b; mk_row 8 rank_six_c
arms=$((arms+1)); OUT="$(pick_as seat01)"
printf '%s' "$OUT" | grep -qE 'skipped 3 free row\(s\) at rank 6\+' \
  || fail "ARM 7: no one-line count of the rank-capped skips (GOAL: 'and prints how many it skipped')"
[ "$(printf '%s' "$OUT" | grep -c 'HQ-ONLY tier')" -le 1 ] \
  || fail "ARM 7b: the cap printed one line PER ROW -- that buries the serve it precedes, the same ruling the owned-skip report already made"

# ---- ARM 8: an explicit direction OUTRANKS the cap (GOAL: 'assign still outranks') ----
reset_sbx
printf '6\trestricted_to_me\tunassigned\tRESTRICTED:seat01\n' >> "$SBX/QUEUE.tsv"
printf '# TASK restricted_to_me\nGOAL: fixture\nDONE-WHEN: test -f /nonexistent-rankcap-fixture-marker\n' > "$SBX/tasks/restricted_to_me.task.md"
arms=$((arms+1)); OUT="$(pick_as seat01)"
printf '%s' "$OUT" | grep -q 'LOCKED restricted_to_me' \
  || fail "ARM 8: a rank-6 row RESTRICTED to this seat by name was withheld -- an authority pointed it here on purpose, and assign outranks the cap"

if [ "$viol" -ne 0 ]; then
    echo "⛔ GATE FAIL [$GATE]: $viol of $arms arms broken"
    exit 1
fi
echo "GATE PASS(0) [$GATE]: $arms arms -- seats capped at rank 5, HQs/ceo/cto uncapped and SERVED, skips counted in ONE line, explicit direction outranks, override named"
exit 0
