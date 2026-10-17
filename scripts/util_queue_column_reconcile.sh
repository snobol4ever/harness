#!/usr/bin/env bash
# util_queue_column_reconcile.sh — reconcile QUEUE.tsv's STATE column (col4) against claims/<topic>.claim,
# which is the authority. Audit by default; --fix repairs the one direction that is safe to repair.
#
# ⭐ WHY THIS EXISTS (hq_B 2026-08-29, on hq_P's queue-wide audit; row queue-column-unwritten-by-acquiring-verbs).
# s4e_msg.sh's acquiring verbs (claim / next / assign) wrote the claim file and NOT the state column, while the
# releasing verbs (park / done / unclaim) wrote the column — so the column learned about endings and never about
# beginnings. Measured before the cure: of 16 rows holding a live claim, 15 read FREE. The script fix stops NEW
# drift; this reconciles the rows that drifted before it landed.
#
# ⛔⭐ THE TWO DIRECTIONS ARE NOT THE SAME SEVERITY, AND CONFLATING THEM IS THE MISTAKE THIS SCRIPT EXISTS TO STOP.
#   A: live claim, column reads FREE      -> ILLEGIBLE, correctly dispatched. The picker skips any row with a claim
#      file regardless of the column, so nothing is double-served. Cosmetic-but-load-bearing: a human reading the
#      queue sees free work that is not free. SAFE TO REPAIR — mirroring the claim changes no dispatch outcome.
#   B: column names an owner, NO claim file -> UNSERVABLE BY A SEAT. PASS 3 serves only FREE|'' so the column
#      hides it, and PASSES 1/2 iterate claim FILES so nothing resumes it. ⛔ NOT auto-repaired: returning it to
#      FREE is a DISPATCH act on someone else's row, and the column may be the only surviving record of intent.
#
# ⛔⭐ AND B IS NOT ONE POPULATION — hq_P's correction, 2026-08-29, reported against their own row. The first
# version of this script called every B row unservable, which reads as a defect. For one of the two populations
# it is the FEATURE:
#   B-RESERVED: an HQ-ONLY row (e.g. defect-c-zop-flat-regime-depth-compensate, CEO-19). The picker does NOT
#      filter on the owner column and only the STATE column is load-bearing (s265), so a row left FREE would be
#      served to whichever seat called `next` — and that seat's own baton tells it not to attempt the work.
#      ASSIGNED-with-no-claim IS THE DOCUMENTED MECHANISM for reserving a row to an HQ. Nothing is wrong.
#   B-STRANDED: a seat's lock vanished and the row is genuinely marooned. This one is the defect.
# ⭐ THE DISCRIMINATOR (hq_P's, and it needs no human): a RESERVATION never had a claim, so it has no release
# receipt under released/; a STRANDED row generally does. It is a heuristic, not a proof — so this script LABELS
# and never acts, and says which population it thinks each row is in and on what evidence.
set -u
PO="${S4E_POST:-/home/resources/postoffice}"; Q="$PO/QUEUE.tsv"; FIX=0
[ "${1:-}" = "--fix" ] && FIX=1
[ -f "$Q" ] || { echo "⛔ no QUEUE.tsv at $Q" >&2; exit 2; }
a_rows=""; a_n=0; b_n=0; b_res=0; b_str=0; b_restr=0
while IFS=$'\t' read -r rank topic owner state rest; do
  case "${rank:-}" in ''|\#*) continue;; esac
  [ -n "${topic:-}" ] || continue
  c="$PO/claims/$topic.claim"
  if [ -f "$c" ] && ! grep -q '^DONE$' "$c"; then
    case "${state:-}" in
      FREE|'') held="$(head -1 "$c")"
        if grep -q '^ASSIGNED-BY ' "$c"; then want="ASSIGNED:$held"; else want="CLAIMED:$held"; fi
        a_n=$((a_n+1)); a_rows="$a_rows$topic	$want
"
        printf '  A rank %-3s %-62s FREE -> %s\n' "$rank" "$topic" "$want";;
    esac
  elif [ ! -f "$c" ]; then
    case "${state:-}" in
      RESTRICTED:*)
        # ⭐ THE DURABLE RESERVATION (hq_P, SCRIP d1deda52, on ceo's ruling). A RESTRICTED:<x> row has no claim
        # file BY DESIGN and that is not a defect: the picker serves it to <x> and skips it for everyone else,
        # and unlike the ASSIGNED-as-reservation spelling it SURVIVES `unclaim` by construction -- restoring the
        # restriction instead of freeing the row. So it is reported, never counted as a problem.
        b_n=$((b_n+1)); b_restr=$((b_restr+1))
        printf '  ✅ B-RESTRICTED rank %-3s %-50s col=%-16s owner=%-6s  durable reservation — survives unclaim; nothing to do\n' "$rank" "$topic" "$state" "${owner:-<empty>}";;
      ASSIGNED*|LOCKED*|RUNNING*|CLAIMED*)
        b_n=$((b_n+1))
        if [ -f "$PO/released/$topic.release" ]; then
          b_str=$((b_str+1))
          printf '  ⛔ B-STRANDED rank %-3s %-52s col=%-16s owner=%-6s  no claim, but a release receipt exists — a lock went missing\n' "$rank" "$topic" "$state" "${owner:-<empty>}"
        else
          b_res=$((b_res+1))
          printf '  ⭐ B-RESERVED rank %-3s %-52s col=%-16s owner=%-6s  no claim and no release receipt — reads as a deliberate HQ reservation\n' "$rank" "$topic" "$state" "${owner:-<empty>}"
        fi;;
    esac
  fi
done < "$Q"
printf '\nQUEUE COLUMN RECONCILE: A(illegible, repairable)=%s   B(unservable, owner must decide)=%s\n' "$a_n" "$b_n"
if [ "$b_n" -gt 0 ]; then
  printf '   of which: B-RESTRICTED=%s (durable, nothing to do)   B-RESERVED=%s (deliberate but FRAGILE)   B-STRANDED=%s (likely a lost lock)\n' "$b_restr" "$b_res" "$b_str"
  printf '⛔ NO SEAT CAN BE SERVED EITHER KIND, but they want OPPOSITE treatment and this script will not guess:\n'
  printf '   B-RESERVED is how an HQ-only row is held (the picker ignores the owner column; only state is\n'
  printf '     load-bearing), so "unservable by a seat" is the POINT. Do not park these to FREE to tidy them.\n'
  # ⛔⭐ B-RESERVED IS NOT A STABLE STATE, AND THIS CENSUS IS A SNAPSHOT OF ONE (hq_P, 2026-08-29, reporting
  # a reservation they destroyed themselves an hour after explaining the mechanism to me in writing).
  # `unclaim` drives the state column to FREE UNCONDITIONALLY, even over ASSIGNED:<hq> -- ceo's 2026-08-28
  # ruling, and right for the DISPATCH meaning of ASSIGNED, which really is spent when a lock is released.
  # But ASSIGNED:<hq> also carries a RESTRICTION meaning that belongs to the ROW and is not spent by letting
  # go of a lock. So a correct `unclaim` silently converts B-RESERVED into A, the picker serves the row
  # within minutes, and a seat starts work its own baton forbids. That is what happened; seat16 caught it
  # and restored it with `park <topic> ASSIGNED:hq_P`.
  # ⭐ THE LESSON FOR ANY STATE CENSUS, and it is the converse of this script's own: A CENSUS THAT FINDS A
  # CONFORMING ROW HAS NOT FOUND A SAFE ONE. That row was conforming at every instant -- ASSIGNED, then
  # legitimately FREE, then ASSIGNED again. No instrument reading STATES would flag the hour in between,
  # because the defect lived in a TRANSITION. (The durable cure -- a distinct RESTRICTED:<x> spelling rather
  # than special-casing ASSIGNED:<hq> inside unclaim -- is hq_P's recommendation and ceo's ruling to make.)
  printf '     ⚠ B-RESERVED IS FRAGILE: `unclaim` drives the column to FREE even over ASSIGNED:<hq>, so a\n'
  printf '       reservation in that spelling is destroyed by any correct release and is preserved only by\n'
  printf '       `park`. This census is a SNAPSHOT — such a row can be FREE and under way within minutes.\n'
  # ⭐ THE WARNING NOW NAMES THE CURE, NOT JUST THE HAZARD (hq_P's ask, after RESTRICTED:<x> landed in
  # d1deda52). The fragility line above is still true but it is true of a SHRINKING set: a reservation
  # spelled RESTRICTED:<x> survives unclaim by construction, which was the entire point of minting it. An
  # instrument that warns about a hazard while a durable alternative exists, and does not name it, is
  # leaving the reader to rediscover the fix -- so this points at the spelling instead.
  printf '     ✅ THE DURABLE SPELLING IS `park <topic> RESTRICTED:<owner>` — it survives unclaim by\n'
  printf '       construction. If a B-RESERVED row above is a deliberate hold, RE-SPELL IT RESTRICTED and it\n'
  printf '       stops being a snapshot. Prefer that over ASSIGNED:<hq>-as-reservation for any new hold.\n'
  printf '   B-STRANDED is a genuine marooning: `park <topic> FREE` returns it to the picker, or\n'
  printf '     `assign <seat> <topic>` locks it properly.\n'
  printf '   ⭐ The split is a HEURISTIC (presence of a released/ receipt), not a proof. Ask the owner before\n'
  printf '     acting on either — a dispatch act on another HQ'"'"'s row is theirs to make.\n'
fi
[ "$FIX" = 1 ] || { printf '\n(audit only — pass --fix to repair the A rows)\n'; exit 0; }
[ "$a_n" -gt 0 ] || { echo "nothing to repair"; exit 0; }
# ⛔ SAME LOCK AS mint AND s4e_set_row_state. QUEUE.tsv is one file and up to 16 seats claim into it at every
# prompt; a read-all/write-back without this is a torn queue. One lock, ONE awk pass over all A rows — not 15
# separate rewrites, each of which would be its own race window.
lock="$PO/.mint.lock"; got=0
for _i in $(seq 1 50); do mkdir "$lock" 2>/dev/null && { got=1; break; }; sleep 0.1; done
[ "$got" = 1 ] || { echo "⛔ could not acquire $lock after 5s — another mint/claim is stuck. Investigate; do not rm -rf blindly." >&2; exit 3; }
trap 'rmdir "$lock" 2>/dev/null' EXIT
map="$(mktemp)"; printf '%s' "$a_rows" > "$map"
tmp="$(mktemp)"
awk -F'\t' -v OFS='\t' -v m="$map" 'BEGIN{while((getline l < m)>0){split(l,p,"\t"); if(p[1]!="") w[p[1]]=p[2]}}
  /^[0-9]+\t/ && NF>3 && ($2 in w) {$4=w[$2]} {print}' "$Q" > "$tmp" && cat "$tmp" > "$Q"
rc=$?; rm -f "$tmp" "$map"
[ "$rc" = 0 ] && printf '✅ repaired %s A row(s) — the column now mirrors the claim.\n' "$a_n" || { echo "⛔ rewrite failed"; exit 1; }
