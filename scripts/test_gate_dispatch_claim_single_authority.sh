#!/usr/bin/env bash
# test_gate_dispatch_claim_single_authority.sh -- prove the claim/column single-authority cure, BOTH ARMS.
#
# Row: dispatch-claim-single-authority (hq_B 2026-08-28). The cure has three parts and this gate proves each
# one CAN SAY NO as well as yes -- the bar the baton set, and the same discipline the false-green-gate cluster
# is converting the rest of the suite to.
#
#   HOLE A  done with NO baton must REFUSE rc=2. It used to PRINT the law it was breaking ("closing on the seat
#           word alone, which LAW 1 forbids") and then fall through to the unconditional DONE write, exit 0.
#   (a)     done with a PASSING criterion must mirror the close into QUEUE.tsv's state column, so claim and
#           column cannot disagree across a session boundary. Until the cure, no verb ever wrote that column.
#   (b)     sweep must garbage-collect claims that are DONE with no live row, and must KEEP (reporting) a claim
#           with no live row and NO DONE latch -- that is a live lock whose row vanished, not residue.
#
# ⛔ Runs entirely in a SCRATCH postoffice (S4E_POST); it never reads or writes the real one.
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"; MSG="$HERE/s4e_msg.sh"
[ -f "$MSG" ] || { echo "⛔ GATE CANNOT RUN (rc=2): no s4e_msg.sh beside this gate at $MSG" >&2; exit 2; }
bash -n "$MSG" || { echo "⛔ GATE CANNOT RUN (rc=2): s4e_msg.sh does not parse" >&2; exit 2; }
SC="$(mktemp -d)"; trap 'rm -rf "$SC"' EXIT
mkdir -p "$SC/claims" "$SC/tasks" "$SC/hq_B/inbox" || { echo "⛔ GATE CANNOT RUN (rc=2): scratch postoffice not creatable" >&2; exit 2; }
printf '# rank\ttopic\towner\tstate\n' > "$SC/QUEUE.tsv"
run() { S4E_POST="$SC" S4E_SEAT=hq_B S4E_NO_BANNER=1 bash "$MSG" "$@" 2>&1; }
state() { awk -F'\t' -v t="$1" '$2==t{print $4}' "$SC/QUEUE.tsv"; }
fail=0
ck() { if [ "$2" = "$3" ]; then printf '  PASS  %s\n' "$1"; else printf '  ⛔FAIL %s\n        want=[%s] got=[%s]\n' "$1" "$3" "$2"; fail=$((fail+1)); fi; }

# ---------------------------------------------------------------- HOLE A ---
printf 'hq_B\n' > "$SC/claims/no-baton.claim"
printf '1\tno-baton\thq_B\tRUNNING\n' >> "$SC/QUEUE.tsv"
out="$(run done no-baton)"; rc=$?
ck "HOLE A: done with no baton REFUSES"            "$rc" "2"
ck "HOLE A: no DONE latch written"                 "$(grep -c '^DONE$' "$SC/claims/no-baton.claim")" "0"
ck "HOLE A: column NOT moved to DONE"              "$(state no-baton)" "RUNNING"

# --------------------------------------------------------- (a) POSITIVE ----
printf 'hq_B\n' > "$SC/claims/green-row.claim"
printf '1\tgreen-row\thq_B\tRUNNING\n' >> "$SC/QUEUE.tsv"
printf '# TASK green-row\nDONE-WHEN: test -f "%s/QUEUE.tsv"\n' "$SC" > "$SC/tasks/green-row.task.md"
out="$(run done green-row)"; rc=$?
ck "(a) verified close exits 0"                    "$rc" "0"
ck "(a) claim latched DONE"                        "$(grep -c '^DONE$' "$SC/claims/green-row.claim")" "1"
ck "(a) COLUMN MIRRORED to DONE"                   "$(state green-row)" "DONE"

# --------------------------------------------------------- (a) NEGATIVE ----
# The arm that matters: a criterion that FAILS must leave BOTH stores untouched.
printf 'hq_B\n' > "$SC/claims/red-row.claim"
printf '1\tred-row\thq_B\tRUNNING\n' >> "$SC/QUEUE.tsv"
printf '# TASK red-row\nDONE-WHEN: test -f "%s/definitely-absent-file"\n' "$SC" > "$SC/tasks/red-row.task.md"
out="$(run done red-row)"; rc=$?
ck "(a) NEG failing criterion does not exit 0"     "$([ "$rc" -ne 0 ] && echo nonzero || echo zero)" "nonzero"
ck "(a) NEG claim NOT latched"                     "$(grep -c '^DONE$' "$SC/claims/red-row.claim")" "0"
ck "(a) NEG column NOT moved"                      "$(state red-row)" "RUNNING"

# ------------------------------------------------------------- (b) SWEEP ---
printf 'hq_B\nDONE\n' > "$SC/claims/residue-gone.claim"      # DONE + no live row -> collect
printf 'hq_B\n'       > "$SC/claims/orphan-live.claim"       # no DONE + no live row -> KEEP and report
out="$(run sweep)"
ck "(b) residue claim garbage-collected"           "$([ -f "$SC/claims/residue-gone.claim" ] && echo present || echo gone)" "gone"
ck "(b) NEG live-lock orphan KEPT, not deleted"    "$([ -f "$SC/claims/orphan-live.claim" ] && echo present || echo gone)" "present"
ck "(b) NEG orphan is REPORTED"                    "$(printf '%s' "$out" | grep -c 'KEPT, NOT DELETED')" "1"
ck "(b) swept row's claim also collected"          "$([ -f "$SC/claims/green-row.claim" ] && echo present || echo gone)" "gone"

# ------------------------------------------------- regression: park path ---
printf '2\tpark-me\tunassigned\tFREE\n' >> "$SC/QUEUE.tsv"
run park park-me PARKED >/dev/null
ck "park still writes the column (shared helper)"  "$(state park-me)" "PARKED"

echo
if [ "$fail" -eq 0 ]; then echo "✅ GATE OK: dispatch-claim-single-authority — HOLE A refuses, (a) mirrors, (b) collects residue and keeps live locks. Both arms proven."; exit 0
else echo "⛔ GATE FAIL: $fail check(s) failed"; exit 1; fi
