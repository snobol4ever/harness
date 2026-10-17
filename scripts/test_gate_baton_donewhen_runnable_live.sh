#!/bin/bash
# test_gate_baton_donewhen_runnable_live.sh -- the DONE-WHEN of row live-batons-all-carry-a-computable-donewhen (ladder I, rank 1).
#
# ⭐ WHY A SECOND GATE AND NOT A FLAG ON THE FIRST (ceo ruling 2026-09-02, on hq_P's measurement). test_gate_baton_donewhen_runnable.sh answers "can this DONE-WHEN reach a verdict?" over EVERY
# baton on disk, and other rows already grade against that number. This gate asks the narrower question the ruling scopes: "can every LIVE row's DONE-WHEN reach a verdict?" ⛔ It COMPOSES the first
# gate rather than reimplementing its parser -- one authority for "is this DONE-WHEN runnable", never a second copy that can drift from it. Modifying the first gate's output to add a filter would
# have moved a number other rows are pinned to; that is why this is a wrapper.
#
# ⛔⭐ LIVENESS IS THE WHOLE POINT, AND IT IS WHAT MAKES 74 THE WRONG NUMBER TO CHASE. Of the 74 uncloseable batons measured 2026-09-02, only 49 sit on rows that can still be worked. The other 25
# are two DIFFERENT problems wearing the same symptom, and the ruling gives each its own rider: 11 sit on rows already marked DONE -- so those closures were never graded, and they are AUDIT material,
# not a backlog -- and 14 are ORPHAN BATONS with no QUEUE.tsv row at all, which is a claim nobody can make. ⛔ Curing all 74 uniformly would "fix" 25 rows by writing criteria nobody will ever run.
#
# THE GATE: LIVE uncloseable == 0. The other two populations are PRINTED, never graded here -- they are the riders' material, and a gate that failed on them would block this row on work the ruling
# deliberately routed elsewhere. ⛔ REFUSES rc=2 rather than guessing if either input is missing: an instrument that cannot measure must not pass what it failed to read.
set -u
R="${S4E_HOME:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"   # D-17 PORTABLE-HOME: the SEAT ROOT is derived from THIS script, never a hardcoded seat (hq_C measured 2026-09-02: the old /home/claude_P default graded hq_P's checkout from hq_C's seat)

PO=/home/resources/postoffice
Q="$PO/QUEUE.tsv"
G="$R/harness/scripts/test_gate_baton_donewhen_runnable.sh"
[ -f "$G" ] || { echo "⛔ REFUSED (rc=2): $G not found -- this gate composes it and cannot answer alone"; exit 2; }
[ -f "$Q" ] || { echo "⛔ REFUSED (rc=2): $Q not found -- liveness is unknowable without the queue"; exit 2; }
out="$(cd "$R/SCRIP" && bash "$G" 2>&1)"
tot="$(printf '%s\n' "$out" | grep -oE 'UNCLOSEABLE=[0-9]+' | head -1 | cut -d= -f2)"
case "$tot" in ''|*[!0-9]*) echo "⛔ REFUSED (rc=2): could not parse an UNCLOSEABLE=<n> total out of $G -- its output shape changed, so this wrapper is grading nothing"; exit 2 ;; esac
topics="$(printf '%s\n' "$out" | sed -n 's/^  ⛔ \([^:]*\):.*/\1/p' | sort -u)"
n_listed="$(printf '%s\n' "$topics" | grep -c . )"
[ "$n_listed" -eq "$tot" ] || { echo "⛔ REFUSED (rc=2): $G reports UNCLOSEABLE=$tot but names $n_listed topics -- the wrapper cannot classify what it cannot see"; exit 2; }
live=0; closed=0; orphan=0; live_list=""; closed_list=""; orphan_list=""
for t in $topics; do
    st="$(awk -F'\t' -v T="$t" '$2==T{print $4; exit}' "$Q")"
    if   [ -z "$st" ];      then orphan=$((orphan+1)); orphan_list="$orphan_list $t"
    elif [ "$st" = DONE ];  then closed=$((closed+1)); closed_list="$closed_list $t"
    else                         live=$((live+1));     live_list="$live_list $t"; fi
done
echo "uncloseable batons: $tot total -- LIVE=$live (graded here) · already-DONE=$closed (rider 1, audit) · ORPHAN=$orphan (rider 2, retire or row)"
[ "$closed" -gt 0 ] && { echo "-- rider 1, closed on a criterion that could never run (AUDIT; a red retroactive criterion REOPENS the row):"; for t in $closed_list; do echo "     $t"; done; }
[ "$orphan" -gt 0 ] && { echo "-- rider 2, orphan batons with no QUEUE.tsv row (retire to tasks/archive/ or give a row, named one by one on the baton):"; for t in $orphan_list; do echo "     $t"; done; }
if [ "$live" -ne 0 ]; then
    echo "-- LIVE rows that can never be closed (this gate's population):"; for t in $live_list; do echo "     $t"; done
    echo "GATE FAIL(1) [baton_donewhen_runnable_live]: $live LIVE row(s) carry a DONE-WHEN that can never exit 0 -- each needs a computable criterion or a SUPERSEDE with a reason"
    exit 1
fi
echo "PASS: every LIVE row carries a DONE-WHEN that can reach a verdict (0 of $tot uncloseable batons sit on a live row)"
