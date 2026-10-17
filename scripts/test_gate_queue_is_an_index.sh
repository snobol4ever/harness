#!/usr/bin/env bash
# test_gate_queue_is_an_index.sh — V2-2 invariant, continuously enforced.
#
# ⛔ WHAT IT STOPS FROM REGROWING: v1's QUEUE.tsv carried the brief, the first step and the completion test
# inline — 5,965-byte prose blobs, 122KB total, 62% of rows dead. A queue that is also a brief store is a
# queue nobody sweeps, and a brief edited in place is a brief the holder never re-reads (that is how the
# s255 correction reached nobody). V2-2 makes QUEUE.tsv a pure dispatch INDEX — rank·topic·owner·state —
# with every brief, criterion, question and receipt in tasks/<topic>.task.md, the baton.
#
# THREE INVARIANTS: (1) every data row has exactly 4 fields; (2) every row has a baton; (3) no row carries
# prose — a field longer than the cap means someone put a brief back in the index.
#
# usage: bash ../harness/scripts/test_gate_queue_is_an_index.sh          exit 0 = index is clean, 1 = violated, 2 = unproven
set -u
PO="${S4E_POST:-/home/resources/postoffice}"
Q="$PO/QUEUE.tsv"; T="$PO/tasks"; CAP="${QUEUE_FIELD_CAP:-64}"
[ -f "$Q" ] || { echo "UNPROVEN: no $Q"; exit 2; }
[ -d "$T" ] || { echo "UNPROVEN: no $T — V2-2 not applied here"; exit 2; }
rows=0; bad4=0; nobaton=0; prose=0; worst=0
while IFS= read -r line; do
  case "$line" in \#*|'') continue;; esac
  rows=$((rows+1))
  n="$(printf '%s' "$line" | awk -F'\t' '{print NF}')"
  [ "$n" = 4 ] || { bad4=$((bad4+1)); printf '  ⛔ %s fields (want 4): %.60s\n' "$n" "$line"; continue; }
  topic="$(printf '%s' "$line" | cut -f2)"
  [ -f "$T/$topic.task.md" ] || { nobaton=$((nobaton+1)); printf '  ⛔ NO BATON: %s\n' "$topic"; }
  len="$(printf '%s' "$line" | awk -F'\t' '{m=0;for(i=1;i<=NF;i++) if(length($i)>m) m=length($i); print m}')"
  [ "$len" -gt "$worst" ] && worst="$len"
  [ "$len" -gt "$CAP" ] && { prose=$((prose+1)); printf '  ⛔ PROSE BACK IN THE INDEX (%s chars): %s\n' "$len" "$topic"; }
done < "$Q"
[ "$rows" -gt 0 ] || { echo "UNPROVEN: no data rows in $Q"; exit 2; }
printf 'QUEUE INDEX: %s rows · %s bytes · widest field %s (cap %s) · bad-arity %s · missing-baton %s · prose %s\n' \
  "$rows" "$(wc -c < "$Q")" "$worst" "$CAP" "$bad4" "$nobaton" "$prose"
if [ $((bad4+nobaton+prose)) -eq 0 ]; then echo "GATE PASS: QUEUE.tsv is an index and every row has a baton."; exit 0; fi
echo "GATE FAIL: the queue has drifted back toward being a brief store."; exit 1
