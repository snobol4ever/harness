#!/usr/bin/env bash
# util_postoffice_sweep.sh — the consistency census for the seat bus (row msg-next-orphan-skip, seat4 s191).
# READ-ONLY BY CONSTRUCTION: it never writes a claim, a queue row, or another seat's tree. Three questions:
#   1. ORPHANED CLAIMS  — a claim whose topic has NO QUEUE.tsv row. OPEN ones USED to pin their holder forever
#      (fixed in s4e_msg.sh next); DONE ones are benign, HQ-59 drops DONE rows from the queue by design.
#   2. DONE-BUT-LISTED  — the inverse: a finished row still in QUEUE.tsv. Inert to next() (any claim file hides
#      the row) but it makes the rank column lie to every human who reads the file.
#   3. DIRTY SEAT TREES — uncommitted work. Cross-checked against that seat's OPEN claim: dirty+open = in flight;
#      dirty with NO open claim = STRANDED, the class that lost seat5's codegen at s189.
# ⛔ corpus/lon/ paths are SUPPRESSED to a count (RULES.md: not run, not read into a transcript).
# ⛔ git is invoked --no-optional-locks so a sweep can never contend with a seat's live build for the index lock.
# Exit 0 = consistent; 1 = at least one OPEN orphan or one stranded tree (the two conditions that lose work).
set -u
PO="${S4E_POST:-/home/resources/postoffice}"; Q="$PO/QUEUE.tsv"; rc=0
[ -f "$Q" ] || { echo "⛔ no $Q — a sweep against a missing queue would call EVERY claim an orphan. Refusing."; exit 2; }
qrows="$(grep -cP '^[0-9]+\t' "$Q" 2>/dev/null)"; qrows="${qrows:-0}"
[ "$qrows" -gt 0 ] || { echo "⛔ $Q has ZERO data rows — refusing to sweep (see above)."; exit 2; }
inq() { grep -qP "^[0-9]+\t\Q$1\E\t" "$Q" 2>/dev/null; }
echo "=== POSTOFFICE SWEEP — $qrows queue rows, $(ls "$PO"/claims/*.claim 2>/dev/null | wc -l) claim files ==="
echo "--- 1. ORPHANED CLAIMS (topic absent from QUEUE.tsv) ---"; no=0; nd=0
for c in "$PO"/claims/*.claim; do [ -f "$c" ] || continue; t="$(basename "$c" .claim)"; inq "$t" && continue
  own="$(head -1 "$c")"; if grep -q '^DONE$' "$c"; then nd=$((nd+1)); printf '  %-34s %-7s DONE  benign (HQ-59 prunes DONE rows)\n' "$t" "$own"
  else no=$((no+1)); rc=1; printf '  %-34s %-7s OPEN  ⛔ WOULD PIN %s — orphan-skip now frees it; HQ: re-mint or rule\n' "$t" "$own" "$own"; fi; done
echo "  TOTAL: $no OPEN (work-losing) + $nd DONE (benign)"
echo "--- 2. DONE BUT STILL LISTED (rank column overstates open work) ---"; nl=0
while IFS=$'\t' read -r rank topic brief step; do case "$rank" in ''|\#*) continue;; esac
  c="$PO/claims/$topic.claim"; [ -f "$c" ] && grep -q '^DONE$' "$c" && { nl=$((nl+1)); printf '  rank %-3s %-34s done by %s\n' "$rank" "$topic" "$(head -1 "$c")"; }; done < "$Q"
echo "  TOTAL: $nl of $qrows rows are finished; first row next() can actually hand out:"
while IFS=$'\t' read -r rank topic brief step; do case "$rank" in ''|\#*) continue;; esac
  [ -f "$PO/claims/$topic.claim" ] || { printf '  ==> rank %s %s\n' "$rank" "$topic"; break; }; done < "$Q"
echo "--- 3. SEAT TREES (dirty vs that seat's OPEN claim) ---"
for d in /home/claude /home/claude1 /home/claude2 /home/claude3 /home/claude4 /home/claude5 /home/claude6 /home/claude7 /home/claude8; do
  [ -d "$d" ] || continue; case "$d" in /home/claude) me=hq;; *) me="seat${d#/home/claude}";; esac
  open=""; for c in "$PO"/claims/*.claim; do [ -f "$c" ] || continue
    [ "$(head -1 "$c")" = "$me" ] && ! grep -q '^DONE$' "$c" && open="$open $(basename "$c" .claim)"; done
  for r in .github SCRIP corpus; do p="$d/$r"; [ -d "$p/.git" ] || continue
    out="$(git -C "$p" --no-optional-locks status --porcelain 2>/dev/null)"; [ -n "$out" ] || continue
    lon="$(printf '%s\n' "$out" | grep -c 'programs/lon/')"; n="$(printf '%s\n' "$out" | wc -l)"
    if [ -n "$open" ]; then v="in flight ⟵${open}"; else v="⛔ STRANDED — dirty with NO open claim"; rc=1; fi
    printf '  %-8s %-8s %2s entries  %s%s\n' "$me" "$r" "$n" "$v" "$([ "$lon" -gt 0 ] && echo "  [$lon lon path(s) SUPPRESSED]")"
    printf '%s\n' "$out" | grep -v 'programs/lon/' | head -8 | sed 's/^/             /'; done; done
echo "=== VERDICT: $([ $rc -eq 0 ] && echo CONSISTENT || echo 'ATTENTION — see ⛔ lines') ==="; exit $rc
