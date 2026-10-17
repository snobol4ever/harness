#!/usr/bin/env bash
# ⛔⭐ A BOARD PARSER THAT RE-ARMS ON EVERY DASHED RULE READS THE LAST GRID, NOT THE FIRST, AND THE CONSUMING
# LOOP ASSIGNS BY KEY -- so a second grid under the same kernel names does not add rows, it SILENTLY WINS, and
# the triangulator prints a complete, plausible agreement table built from two different physical quantities
# (FINDING-2026-09-13-hq_P-a-board-parser-that-restarts-on-every-dashed-rule..., ceo ruling CEO-730).
# ⭐ THIS GATE PROVES THE SHAPE BY EXECUTION, NOT BY GREP ALONE: it runs BOTH awk programs over a two-grid
# fixture and asserts the OLD one is fooled (its own discriminator self-test -- a fixture that cannot expose
# the defect would let the cured arm pass vacuously) before asserting the CURED one is not. The census that
# follows strips comment lines first: a gate satisfied by the PROSE about a shape rather than by the shape is
# the defect hq_B measured in six package runners the same day.
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
OLD='/^-{5,}/{started=1;next} started&&NF==0{started=0} started{print $1"\t"$2}'
NEW='done{next} /^-{5,}/{if(!seen){started=1;seen=1} next} started&&NF==0{started=0;done=1;next} started{print $1"\t"$2}'
T="$(mktemp -d)" || exit 2
trap 'rm -rf "$T"' EXIT
cat > "$T/two_grids.txt" <<'FIX'
BENCHMARK                    sbl/s          m3/s
--------------------  ------------  ------------
kern_a                        100K          200K
kern_b                        300K          400K

two-number basis (work/overhead)
--------------------  ------------  ------------
kern_a                     OVERHEAD          9M9
kern_b                     OVERHEAD          8M8

FIX
old_out="$(awk "$OLD" < "$T/two_grids.txt")"
new_out="$(awk "$NEW" < "$T/two_grids.txt")"
[ -n "$old_out" ] || { echo "⛔ REFUSE(2): the fixture produced nothing under either shape -- cannot measure"; exit 2; }
printf '%s\n' "$old_out" | grep -q 'OVERHEAD' || {
  echo "⛔ REFUSE(2): the two-grid fixture does NOT fool the old shape, so it cannot prove the cured one."
  echo "   A discriminator that cannot fail proves nothing about the arm it guards. Fixture:"; sed 's/^/     /' "$T/two_grids.txt"; exit 2; }
printf '%s\n' "$new_out" | grep -q 'OVERHEAD' && {
  echo "⛔ GATE RED: the first-block-only shape ALSO read the second grid -- it does not cure the defect."
  printf '%s\n' "$new_out" | sed 's/^/     /'; exit 1; }
want="$(printf 'kern_a\t100K\nkern_b\t300K')"
[ "$new_out" = "$want" ] || {
  echo "⛔ GATE RED: the cured shape did not return exactly the first grid's rows."
  echo "   want:"; printf '%s\n' "$want"    | sed 's/^/     /'
  echo "   got:";  printf '%s\n' "$new_out" | sed 's/^/     /'; exit 1; }
pop=0; bad=0; names=""
for f in "$HERE"/bench_triangulate_*.sh; do
  [ -f "$f" ] || continue
  pop=$((pop + 1))
  n="$(sed 's/^[[:space:]]*#.*$//' "$f" | grep -c '/\^-{5,}/{started=1;next}')"
  [ "$n" = 0 ] || { bad=$((bad + 1)); names="$names $(basename "$f")($n)"; }
done
[ "$pop" -gt 0 ] || { echo "⛔ REFUSE(2): no bench_triangulate_*.sh found under $HERE -- a census over nothing"; exit 2; }
[ "$bad" = 0 ] || { echo "⛔ GATE RED: $bad of $pop triangulator(s) still re-arm on every dashed rule:$names"; exit 1; }
echo "GATE GREEN: the first-block-only shape reads exactly the first grid where the old shape reads the last, and all $pop triangulator(s) carry it"
exit 0
