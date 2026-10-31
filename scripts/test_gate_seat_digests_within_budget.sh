#!/usr/bin/env bash
# test_gate_seat_digests_within_budget.sh [root...] -- EVERY SEAT'S CLAUDE.md IS A SHORT SOP, NOT A HISTORY (Lon 2026-10-31, in-chat to the ceo,
# verbatim: "Reduce the size of CLAUDE.md files but ensure standard operating procedure, SOP, and motus operandi, mode of operations, etc are
# solid."; ceo CEO-2071). GREEN when every /home/claude_*/CLAUDE.md (or the roots named) is at most 24 KB AND carries the five SOP markers the
# generator writes: the standing law, the sitting order, the landing recipe, the go rule and the manuals folder. RED rc 1 names each root that
# fails and why. REFUSES rc 2 when no root is found. Measured 2026-10-31 09:3x before the cure: 19 of 19 roots red (44 to 107 KB, no markers).
BUDGET=24576
roots=("$@"); [ ${#roots[@]} -gt 0 ] || roots=(/home/claude_*)
n=0; red=0
for r in "${roots[@]}"; do
  f=$r/CLAUDE.md; [ -r "$f" ] || continue; n=$((n+1))
  why=""
  sz=$(wc -c < "$f"); [ "$sz" -le $BUDGET ] || why="$why size=$sz>$BUDGET"
  for k in '## ⛔ STANDING LAW' '## EVERY SITTING, IN ORDER' '## THE LANDING RECIPE' 'THE GO' '/home/resources/manuals'; do grep -qF -- "$k" "$f" || why="$why missing:'$k'"; done
  [ -z "$why" ] && echo "OK   $(basename "$r") $sz bytes" || { echo "RED  $(basename "$r")$why"; red=$((red+1)); }
done
[ "$n" -gt 0 ] || { echo "REFUSE(2): no CLAUDE.md under the roots named"; exit 2; }
echo "SEAT_DIGESTS roots=$n red=$red budget=$BUDGET"
[ "$red" = 0 ]
