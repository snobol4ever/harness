#!/usr/bin/env bash
export S4E_MINT_NO_CRITERION="gate fixture: the row under test exercises the bus, not work (CEO-1386)"
# test_gate_s4e_next_tiebreak_by_mint_time.sh -- proves next()'s PASS 3 tie-breaks equal-rank FREE rows
# by MINT TIME (newest first), not QUEUE.tsv file order, AND that rank still dominates the tiebreak
# (row next-tiebreak-by-mint-time-not-file-order, hq_C finding, ceo mint 2026-09-01T22:59:57Z).
# Runs entirely against a throwaway sandbox postoffice (S4E_POST override) -- never touches the live one.
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
S4E_MSG="$HERE/s4e_msg.sh"
[ -x "$S4E_MSG" ] || S4E_MSG="bash $HERE/s4e_msg.sh"
SBX="$(mktemp -d /tmp/s4e_tiebreak_gate_XXXXXX)"
trap 'rm -rf "$SBX"' EXIT
fail() { echo "GATE FAIL [s4e_next_tiebreak]: $1"; exit 1; }

mk_seat() { mkdir -p "$SBX/$1/inbox" "$SBX/$1/archive"; }
mk_task() { # $1=topic $2=mint-iso-ts (empty for none)
    if [ -n "$2" ]; then
        printf 'LINKS: minted via `mint` by ceo, %s\n' "$2" > "$SBX/tasks/$1.task.md"
    else
        printf 'no mint line at all\n' > "$SBX/tasks/$1.task.md"
    fi
}
reset_sbx() {
    rm -rf "$SBX"; mkdir -p "$SBX/claims" "$SBX/tasks"
    mk_seat gate_tester
}

# --- CASE 1: equal rank, newer mint time wins over older, over no-timestamp-at-all ---
reset_sbx
printf '1\told_row\tunassigned\tFREE\n1\tnew_row\tunassigned\tFREE\n1\tno_ts_row\tunassigned\tFREE\n' > "$SBX/QUEUE.tsv"
mk_task old_row   "2026-08-20T10:00:00Z"
mk_task new_row   "2026-09-01T22:59:57Z"
mk_task no_ts_row ""
out="$(S4E_POST="$SBX" S4E_SEAT=gate_tester $S4E_MSG next 2>&1)"
echo "$out" | grep -q "LOCKED new_row" || fail "CASE 1 (newer wins at equal rank): expected 'LOCKED new_row', got: $(echo "$out" | grep -E 'LOCKED|SKIP|EMPTY')"

# --- CASE 2: rank still dominates -- an OLDER row at a LOWER rank number beats a NEWER row at a higher rank ---
reset_sbx
printf '1\tnewer_but_rank1\tunassigned\tFREE\n0\tolder_but_rank0\tunassigned\tFREE\n' > "$SBX/QUEUE.tsv"
mk_task newer_but_rank1 "2026-09-01T23:59:59Z"
mk_task older_but_rank0 "2026-01-01T00:00:00Z"
out="$(S4E_POST="$SBX" S4E_SEAT=gate_tester $S4E_MSG next 2>&1)"
echo "$out" | grep -q "LOCKED older_but_rank0" || fail "CASE 2 (rank dominates tiebreak): expected 'LOCKED older_but_rank0', got: $(echo "$out" | grep -E 'LOCKED|SKIP|EMPTY')"

# --- CASE 3: reversing file order in QUEUE.tsv does not change the verdict (proves it's not file order) ---
reset_sbx
printf '1\tnew_row\tunassigned\tFREE\n1\told_row\tunassigned\tFREE\n' > "$SBX/QUEUE.tsv"
mk_task old_row "2026-08-20T10:00:00Z"
mk_task new_row "2026-09-01T22:59:57Z"
out="$(S4E_POST="$SBX" S4E_SEAT=gate_tester $S4E_MSG next 2>&1)"
echo "$out" | grep -q "LOCKED new_row" || fail "CASE 3 (file-order-reversed control): expected 'LOCKED new_row' regardless of file order, got: $(echo "$out" | grep -E 'LOCKED|SKIP|EMPTY')"

echo "GATE OK [s4e_next_tiebreak]: equal-rank ties break by mint time newest-first (case 1), rank still dominates the tiebreak (case 2), and file order is proven irrelevant (case 3)."
exit 0
