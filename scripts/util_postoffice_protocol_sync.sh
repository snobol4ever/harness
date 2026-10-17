#!/usr/bin/env bash
# util_postoffice_protocol_sync.sh — install the ORPHAN-SKIP law into the bus's PROTOCOL.md (row msg-next-orphan-skip, seat4 s191).
# ⛔ WHY THIS IS A SCRIPT AND NOT A HAND EDIT: /home/resources/postoffice IS NOT A GIT REPO. PROTOCOL.md is the
#    fleet's law and it exists in exactly ONE unversioned copy on one box — no history, no diff, no recovery. The
#    bus's own rule 5 says "NEVER a message instead of the pushed record"; its own LAW has no pushed record. Keeping
#    the text HERE, in SCRIP, makes it survive, reviewable and re-appliable by any seat. Run it after a bus rebuild.
# IDEMPOTENT: no-op if the section is already present. Prints a diff-shaped summary. Never touches claims or QUEUE.tsv.
set -u
PO="${S4E_POST:-/home/resources/postoffice}"; F="$PO/PROTOCOL.md"; MARK="### ORPHAN-SKIP"
[ -f "$F" ] || { echo "⛔ no $F"; exit 2; }
grep -q "^$MARK" "$F" && { echo "already present — no-op ($F)"; exit 0; }
ANCHOR='                                    # hold the same topic — the lock is ln-atomic.'
grep -qF "$ANCHOR" "$F" || { echo "⛔ anchor line not found in $F — PROTOCOL.md has been rewritten; re-derive the insert point by hand rather than guessing."; exit 1; }
T="$(mktemp)"; awk -v anchor="$ANCHOR" '{print} $0==anchor{
print "";
print "### ORPHAN-SKIP — a renamed row can no longer brick its holder (seat4, s191, row msg-next-orphan-skip)";
print "`next` resumes your unfinished claim BEFORE it scans QUEUE.tsv. So when a topic is RENAMED or RETIRED out";
print "from under a seat, that seat used to be pinned FOREVER to a row that no longer exists — and it printed";
print "`RESUME <topic>` with NO brief and NO reason, because the lookup that prints the brief silently matched";
print "nothing (measured on seat5 at s189: `arbno-nullalt-false-accept` renamed to `arbno-tail-false-accept` five";
print "minutes after the lock; it stranded real uncommitted codegen work). `next` now SKIPS an unfinished claim";
print "whose topic has NO QUEUE.tsv row, prints ONE line naming the dead topic and pointing at the question box,";
print "and FALLS THROUGH to live work:";
print "  SKIP <topic> — your unfinished claim names a topic with NO QUEUE.tsv row (renamed or retired out from";
print "  under you). Claim KEPT as the record; falling through to live work.";
print "⛔ THE CLAIM IS NEVER DELETED — rule 2 stands; a claim is the done-marker and the record. The skip is about";
print "   where next SENDS you, never about erasing what you HELD.";
print "⛔ ORPHAN-SKIP DISARMS ITSELF WHEN THE QUEUE IS DEAD. A missing or row-less QUEUE.tsv would make EVERY claim";
print "   look orphaned and unpin the WHOLE FLEET at once. An unreadable queue is an infrastructure failure, not a";
print "   rename, so next PINS and says so rather than unpinning. Same disarm in util_postoffice_sweep.sh.";
print "⭐ HQ LAW 14 (rename and unpin are ONE action) still stands — this is the MECHANICAL half, and it is better";
print "   because it does not depend on HQ remembering. Both halves, not either.";
print "⛔ A DONE CLAIM STILL HIDES ITS ROW FROM next (`[ -f claims/<topic>.claim ] && continue`), so a finished row";
print "   left in QUEUE.tsv is INERT to the picker but MISLEADING to every human who reads the file. Prune DONE rows";
print "   (HQ-59) or the rank column stops meaning anything: measured s191-08-20, 45 of 68 rows were already DONE —";
print "   EVERY rank-0 row among them — while next was handing out rank 22. Census: util_postoffice_sweep.sh.";
}' "$F" > "$T" && cat "$T" > "$F" && rm -f "$T"
echo "installed $MARK into $F ($(wc -l < "$F") lines)"; grep -n "^$MARK" "$F"
